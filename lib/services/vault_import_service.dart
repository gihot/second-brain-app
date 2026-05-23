import 'dart:convert';
import 'dart:typed_data';

import '../models/note_codec.dart';
import '../models/note_model.dart';
import 'cache_service.dart';

/// Parses markdown notes exported from the GitHub vault and writes them
/// back to the local Hive cache. Used for emergency recovery and the
/// ZIP-Import flow.
///
/// Domain mapping (Map ↔ Note, enum ↔ server string) lives in
/// [note_codec.dart] — this file only owns the Dart-specific YAML parsing.
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

    // Hand the parsed map to the shared codec — it does enum mapping and
    // builds the Note, identically to how server payloads are deserialized.
    return noteFromMap({
      ...fm,
      'content': body,
      'file_path': filename,
    });
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

  // ── YAML helpers (tiny subset, no package needed) ────────────────────────

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
