import 'dart:convert';
import 'dart:typed_data';

import '../models/note_model.dart';
import 'cache_service.dart';

/// Parses markdown notes exported from the GitHub vault and writes them
/// back to the local Hive cache. Used for emergency recovery and the
/// future ZIP-Import flow.
///
/// Vault file format (matches `server/services/vault_service.py`):
///
/// ```
/// ---
/// id: <uuid>
/// title: <string>
/// tags: ["a", "b"]
/// created: 2026-04-24T19:44:51.114315
/// modified: 2026-04-24T19:45:17.478469
/// source: capture
/// status: inbox|processed|archived
/// para: 00-Inbox|01-Projects|02-Areas|03-Resources|04-Archive
/// hall: fact|event|discovery|preference|advice|unclassified
/// wing: <kebab-case>            # optional
/// thought_type: standard|reminder|question|idea
/// remind_at: 2026-04-25T09:01:00  # optional, only if thought_type==reminder
/// ---
///
/// <markdown body>
/// ```
class VaultImportService {
  VaultImportService._();
  static final instance = VaultImportService._();

  /// Parses raw bytes of a single `.md` file. Returns `null` on parse error.
  /// Caller is responsible for collecting/reporting failures.
  Note? parseFile(Uint8List bytes, {required String filename}) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return parseString(text, filename: filename);
  }

  Note? parseString(String text, {required String filename}) {
    final fmMatch = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n?', multiLine: false)
        .firstMatch(text);
    if (fmMatch == null) return null;

    final yaml = fmMatch.group(1)!;
    final body = text.substring(fmMatch.end);
    final fm = _parseFrontmatter(yaml);

    final id = fm['id']?.toString().trim();
    final title = fm['title']?.toString().trim();
    if (id == null || id.isEmpty || title == null || title.isEmpty) {
      return null;
    }

    return Note(
      id: id,
      title: title,
      content: body,
      tags: _parseTagList(fm['tags']),
      created: _parseDate(fm['created']) ?? DateTime.now(),
      modified: _parseDate(fm['modified']) ?? DateTime.now(),
      status: _parseStatus(fm['status']),
      para: _parsePara(fm['para']),
      filePath: filename,
      hall: _parseHall(fm['hall']),
      wing: _nullIfEmpty(fm['wing']?.toString().trim()),
      thoughtType: _parseThoughtType(fm['thought_type']),
      remindAt: _nullIfEmpty(fm['remind_at']?.toString().trim()),
    );
  }

  /// Imports a list of (filename, bytes) tuples. Returns counts.
  Future<ImportReport> importFiles(
      List<({String filename, Uint8List bytes})> files) async {
    int parsed = 0;
    int written = 0;
    final failures = <String>[];

    for (final f in files) {
      final note = parseFile(f.bytes, filename: f.filename);
      if (note == null) {
        failures.add(f.filename);
        continue;
      }
      parsed++;
      await CacheService.instance.saveNote(note);
      written++;
    }

    return ImportReport(
      parsed: parsed,
      written: written,
      failed: failures,
    );
  }

  // ── Frontmatter helpers (tiny YAML subset, no package needed) ───────────

  Map<String, dynamic> _parseFrontmatter(String yaml) {
    final out = <String, dynamic>{};
    for (final raw in yaml.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final idx = line.indexOf(':');
      if (idx < 0) continue;
      final key = line.substring(0, idx).trim();
      var value = line.substring(idx + 1).trim();
      // Strip surrounding quotes for plain scalars.
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      out[key] = value;
    }
    return out;
  }

  List<String> _parseTagList(dynamic raw) {
    if (raw == null) return const [];
    final s = raw.toString().trim();
    if (s.isEmpty) return const [];
    // Inline list: ["a", "b"] or [a, b]
    if (s.startsWith('[') && s.endsWith(']')) {
      final inner = s.substring(1, s.length - 1);
      return inner
          .split(',')
          .map((t) => t.trim().replaceAll(RegExp("^[\"']|[\"']\$"), ''))
          .where((t) => t.isNotEmpty)
          .toList();
    }
    return [s];
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString().trim());
  }

  String? _nullIfEmpty(String? s) {
    if (s == null || s.isEmpty) return null;
    return s;
  }

  NoteStatus _parseStatus(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase() ?? '';
    return switch (s) {
      'processed' => NoteStatus.processed,
      'archived' => NoteStatus.archived,
      _ => NoteStatus.inbox,
    };
  }

  ParaCategory _parsePara(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase() ?? '';
    return switch (s) {
      // Folder-style values from server
      '01-projects' || 'projects' => ParaCategory.projects,
      '02-areas' || 'areas' => ParaCategory.areas,
      '03-resources' || 'resources' => ParaCategory.resources,
      '04-archive' || 'archive' => ParaCategory.archive,
      _ => ParaCategory.inbox, // 00-Inbox or anything else
    };
  }

  MemoryHall _parseHall(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase() ?? '';
    return switch (s) {
      'fact' => MemoryHall.fact,
      'event' => MemoryHall.event,
      'discovery' => MemoryHall.discovery,
      'preference' => MemoryHall.preference,
      'advice' => MemoryHall.advice,
      _ => MemoryHall.unclassified,
    };
  }

  ThoughtType _parseThoughtType(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase() ?? '';
    return switch (s) {
      'reminder' => ThoughtType.reminder,
      'question' => ThoughtType.question,
      'idea' => ThoughtType.idea,
      _ => ThoughtType.standard,
    };
  }
}

class ImportReport {
  final int parsed;
  final int written;
  final List<String> failed;

  ImportReport({
    required this.parsed,
    required this.written,
    required this.failed,
  });
}
