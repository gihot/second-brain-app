/// Single source of truth for translating between [Note] objects and the
/// JSON/Markdown representations used by the server, the vault export
/// pipeline, and any imported markdown files.
///
/// Everything that converts an enum to a server string (`'01-Projects'`,
/// `'inbox'`, `'preference'`, …) — or back — lives here. No state, just
/// pure functions. Add a new enum value? You only edit this file.
library;

import 'note_model.dart';

// ── Enum ↔ server-canonical string ───────────────────────────────────────

String statusToServer(NoteStatus s) => switch (s) {
      NoteStatus.inbox => 'inbox',
      NoteStatus.processed => 'processed',
      NoteStatus.archived => 'archived',
    };

NoteStatus statusFromServer(String? raw) {
  final s = raw?.trim().toLowerCase() ?? '';
  return switch (s) {
    'processed' => NoteStatus.processed,
    'archived' => NoteStatus.archived,
    _ => NoteStatus.inbox,
  };
}

String paraToServer(ParaCategory p) => switch (p) {
      ParaCategory.inbox => '00-Inbox',
      ParaCategory.projects => '01-Projects',
      ParaCategory.areas => '02-Areas',
      ParaCategory.resources => '03-Resources',
      ParaCategory.archive => '04-Archive',
    };

ParaCategory paraFromServer(String? raw) {
  final s = raw?.trim().toLowerCase() ?? '';
  // Tolerate both folder-form ("01-projects") and short form ("projects").
  return switch (s) {
    '01-projects' || 'projects' => ParaCategory.projects,
    '02-areas' || 'areas' => ParaCategory.areas,
    '03-resources' || 'resources' => ParaCategory.resources,
    '04-archive' || 'archive' => ParaCategory.archive,
    _ => ParaCategory.inbox,
  };
}

String hallToServer(MemoryHall h) => switch (h) {
      MemoryHall.fact => 'fact',
      MemoryHall.event => 'event',
      MemoryHall.discovery => 'discovery',
      MemoryHall.preference => 'preference',
      MemoryHall.advice => 'advice',
      MemoryHall.unclassified => 'unclassified',
    };

MemoryHall hallFromServer(String? raw) {
  final s = raw?.trim().toLowerCase() ?? '';
  return switch (s) {
    'fact' => MemoryHall.fact,
    'event' => MemoryHall.event,
    'discovery' => MemoryHall.discovery,
    'preference' => MemoryHall.preference,
    'advice' => MemoryHall.advice,
    _ => MemoryHall.unclassified,
  };
}

String thoughtTypeToServer(ThoughtType t) => switch (t) {
      ThoughtType.standard => 'standard',
      ThoughtType.reminder => 'reminder',
      ThoughtType.question => 'question',
      ThoughtType.idea => 'idea',
    };

ThoughtType thoughtTypeFromServer(String? raw) {
  final s = raw?.trim().toLowerCase() ?? '';
  return switch (s) {
    'reminder' => ThoughtType.reminder,
    'question' => ThoughtType.question,
    'idea' => ThoughtType.idea,
    _ => ThoughtType.standard,
  };
}

// ── Map ↔ Note ───────────────────────────────────────────────────────────

/// Builds a [Note] from a frontmatter/server map. Returns `null` for any
/// payload that's missing the bare essentials (id + title).
///
/// Tolerates the server's stringified tag list (`'["a", "b"]'`) as well as
/// a real `List<String>` (from the YAML importer).
Note? noteFromMap(Map<String, dynamic> m) {
  final id = (m['id'] as String?)?.trim();
  final title = (m['title'] as String?)?.trim();
  if (id == null || id.isEmpty || title == null || title.isEmpty) {
    return null;
  }

  final tags = _parseTagsField(m['tags']);
  final created = _parseDate(m['created']) ?? DateTime.now();
  final modified = _parseDate(m['modified']) ?? created;

  final wing = (m['wing'] as String?)?.trim();
  final remindAt = (m['remind_at'] as String?)?.trim();

  return Note(
    id: id,
    title: title,
    content: (m['content'] as String?) ?? '',
    tags: tags,
    created: created,
    modified: modified,
    status: statusFromServer(m['status'] as String?),
    para: paraFromServer(m['para'] as String?),
    filePath: m['file_path'] as String?,
    hall: hallFromServer(m['hall'] as String?),
    wing: (wing == null || wing.isEmpty) ? null : wing,
    thoughtType: thoughtTypeFromServer(m['thought_type'] as String?),
    remindAt: (remindAt == null || remindAt.isEmpty) ? null : remindAt,
  );
}

/// Serializes a [Note] into the map shape the `PUT /vault/notes` endpoint
/// (and the local pending-write queue) expects.
Map<String, dynamic> noteToServerMap(Note n) => {
      'op': 'update',
      'file_path': n.filePath,
      'title': n.title,
      'content': _stripFrontmatter(n.content),
      'tags': n.tags,
      'status': statusToServer(n.status),
      'para': paraToServer(n.para),
      'hall': hallToServer(n.hall),
      if (n.wing != null) 'wing': n.wing,
      'thought_type': thoughtTypeToServer(n.thoughtType),
      if (n.remindAt != null) 'remind_at': n.remindAt,
    };

// ── Internal helpers ─────────────────────────────────────────────────────

List<String> _parseTagsField(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw.map((e) => e.toString().trim()).where((t) => t.isNotEmpty).toList();
  }
  final s = raw.toString().trim();
  if (s.isEmpty) return const [];
  // Inline list form: ["a", "b"] or [a, b]
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

String _stripFrontmatter(String content) {
  final match = RegExp(r'^---.*?---\s*', dotAll: true).firstMatch(content);
  if (match == null) return content;
  return content.substring(match.end);
}
