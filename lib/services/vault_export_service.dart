import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../models/note_model.dart';
import 'cache_service.dart';
import 'vault_import_service.dart';

/// Bundles all local notes into a ZIP and (on web) triggers a browser
/// download. Symmetric counterpart of [VaultImportService] — the same
/// frontmatter format is used so a ZIP exported here can be re-imported
/// later, or extracted and committed to the GitHub vault manually.
class VaultExportService {
  VaultExportService._();
  static final instance = VaultExportService._();

  static const String _lastBackupKey = 'last_backup_at';

  /// Returns the file name that was offered for download.
  Future<String> exportZip() async {
    final notes = CacheService.instance.getAllNotes();
    final archive = Archive();

    for (final n in notes) {
      final md = _toMarkdown(n);
      final bytes = utf8.encode(md);
      // Mirror the vault folder layout the server uses.
      final folder = _paraFolder(n.para);
      final filename = _safeFilename(n.title.isEmpty ? n.id : n.title);
      archive.addFile(
        ArchiveFile('$folder/$filename.md', bytes.length, bytes),
      );
    }

    // Manifest for traceability + future migration tools.
    final manifest = {
      'exportedAt': DateTime.now().toIso8601String(),
      'noteCount': notes.length,
      'schemaVersion': 1,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final zipBytes = ZipEncoder().encode(archive);
    final ts = DateTime.now();
    final stamp =
        '${ts.year}${_pad(ts.month)}${_pad(ts.day)}-${_pad(ts.hour)}${_pad(ts.minute)}';
    final fileName = 'brain-vault-$stamp.zip';

    if (kIsWeb) {
      _triggerWebDownload(Uint8List.fromList(zipBytes), fileName);
    }

    await _stampLastBackup();
    return fileName;
  }

  /// Imports a ZIP previously exported (or any zip containing matching
  /// `.md` files with our frontmatter). Returns the same report shape as
  /// [VaultImportService.importFiles].
  Future<ImportReport> importZip(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final files = <({String filename, Uint8List bytes})>[];
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (!f.name.toLowerCase().endsWith('.md')) continue;
      final raw = f.content as List<int>;
      files.add((filename: f.name, bytes: Uint8List.fromList(raw)));
    }
    return VaultImportService.instance.importFiles(files);
  }

  // ── Backup-Reminder helpers ─────────────────────────────────────────────

  DateTime? get lastBackupAt {
    final iso = CacheService.instance.getString(_lastBackupKey);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  int? get daysSinceLastBackup {
    final last = lastBackupAt;
    if (last == null) return null;
    return DateTime.now().difference(last).inDays;
  }

  Future<void> _stampLastBackup() =>
      CacheService.instance.setString(_lastBackupKey, DateTime.now().toIso8601String());

  // ── Format helpers (mirror server/services/vault_service.py) ────────────

  String _toMarkdown(Note n) {
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('id: ${n.id}');
    buf.writeln('title: ${n.title}');
    buf.writeln('tags: ${jsonEncode(n.tags)}');
    buf.writeln('created: ${n.created.toIso8601String()}');
    buf.writeln('modified: ${n.modified.toIso8601String()}');
    buf.writeln('status: ${n.status.name}');
    buf.writeln('para: ${_paraFolder(n.para)}');
    buf.writeln('hall: ${n.hall.name}');
    if (n.wing != null && n.wing!.isNotEmpty) {
      buf.writeln('wing: ${n.wing}');
    }
    buf.writeln('thought_type: ${n.thoughtType.name}');
    if (n.remindAt != null && n.remindAt!.isNotEmpty) {
      buf.writeln('remind_at: ${n.remindAt}');
    }
    buf.writeln('---');
    buf.writeln();
    buf.write(_stripExistingFrontmatter(n.content));
    return buf.toString();
  }

  String _stripExistingFrontmatter(String content) {
    final match = RegExp(r'^---.*?---\s*', dotAll: true).firstMatch(content);
    if (match == null) return content;
    return content.substring(match.end);
  }

  String _paraFolder(ParaCategory p) => switch (p) {
        ParaCategory.projects => '01-Projects',
        ParaCategory.areas => '02-Areas',
        ParaCategory.resources => '03-Resources',
        ParaCategory.archive => '04-Archive',
        ParaCategory.inbox => '00-Inbox',
      };

  String _safeFilename(String s) {
    // Drop characters Windows / iOS would choke on.
    final cleaned = s.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '').trim();
    if (cleaned.isEmpty) return 'note';
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _triggerWebDownload(Uint8List bytes, String fileName) {
    final blob = html.Blob([bytes], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
