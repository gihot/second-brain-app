import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../models/vault_status_model.dart';
import '../services/cache_service.dart';
import '../services/api_service.dart';

/// Central state for the vault: all notes, inbox count, sync status.
class VaultProvider extends ChangeNotifier {
  final CacheService _cache = CacheService.instance;
  final ApiService _api = ApiService.instance;

  List<Note> _notes = [];
  VaultStatus _status = const VaultStatus();
  bool _loading = false;
  String? _error;
  bool _isServerReachable = false;

  List<Note> get notes => _notes;
  List<Note> get recentNotes => _notes.take(5).toList();
  List<Note> get inboxNotes =>
      _notes.where((n) => n.status == NoteStatus.inbox).toList();

  /// PARA distribution for the stats chart.
  Map<ParaCategory, int> get paraDistribution {
    final counts = {for (final c in ParaCategory.values) c: 0};
    for (final n in _notes) {
      counts[n.para] = (counts[n.para] ?? 0) + 1;
    }
    return counts;
  }

  /// Tag frequencies, sorted descending. Used for Tag Cloud.
  List<MapEntry<String, int>> get tagFrequencies {
    final freq = <String, int>{};
    for (final n in _notes) {
      for (final t in n.tags) {
        if (t.isNotEmpty) freq[t] = (freq[t] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(30).toList();
  }

  /// Wings computed from notes (kebab-case key → display/count).
  List<Map<String, dynamic>> get wings {
    final counts = <String, int>{};
    for (final n in _notes) {
      final w = n.wing;
      if (w != null && w.isNotEmpty) counts[w] = (counts[w] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => {
              'wing': e.key,
              'display': e.key.split('-').map((w) {
                if (w.isEmpty) return w;
                return w[0].toUpperCase() + w.substring(1);
              }).join(' '),
              'count': e.value,
            })
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  Future<void> renameWing(String oldWing, String newWing) async {
    // Update local cache immediately
    final toUpdate = _notes.where((n) => n.wing == oldWing).toList();
    final normalized = newWing.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    for (final n in toUpdate) {
      await _cache.saveNote(n.copyWith(wing: normalized));
    }
    _loadFromCache();
    // Sync to server
    if (_isServerReachable) {
      await _api.renameWing(oldWing, newWing);
    }
  }

  /// Lookup by file path — used when navigating from a Connector result.
  Note? getNoteByFilePath(String filePath) {
    for (final n in _notes) {
      if (n.filePath == filePath) return n;
    }
    return null;
  }

  /// Compact summary of other notes, for passing to the Connector agent.
  /// Limited to 30 entries, ~200 chars each, to stay under token budget.
  List<Map<String, dynamic>> summarizeNotesForContext({
    String? excludeId,
    int limit = 30,
  }) {
    final out = <Map<String, dynamic>>[];
    for (final n in _notes) {
      if (n.id == excludeId) continue;
      out.add({
        'file_path': n.filePath ?? n.id,
        'title': n.title,
        'tags': n.tags,
        'excerpt': n.excerpt,
      });
      if (out.length >= limit) break;
    }
    return out;
  }
  VaultStatus get status => _status;
  bool get loading => _loading;
  String? get error => _error;
  bool get isServerReachable => _isServerReachable;

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();

    try {
      await _cache.init();
      await _api.init();
      _loadFromCache();

      // Async server check — doesn't block UI
      _checkServerAndSync();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _loadFromCache() {
    _notes = _cache.getAllNotes();
    _status = VaultStatus(
      totalNotes: _notes.length,
      inboxCount: _notes.where((n) => n.status == NoteStatus.inbox).length,
      connectedCount: _notes.where((n) => n.linkedNoteIds.isNotEmpty).length,
      lastSync: _cache.lastSync,
      isServerReachable: _isServerReachable,
    );
    notifyListeners();
  }

  Future<void> _checkServerAndSync() async {
    _isServerReachable = await _api.ping();
    if (_isServerReachable) {
      await _drainPendingWrites();
      await _syncFromServer();
    }
    _loadFromCache();
  }

  /// Flush queued edits/deletes to the server. Fire-and-forget on failure —
  /// the entry stays in the queue and will be retried on the next sync.
  Future<void> _drainPendingWrites() async {
    final pending = _cache.getPendingWrites();
    if (pending.isEmpty) return;

    for (final entry in List<Map<String, dynamic>>.from(pending)) {
      final filePath = entry['file_path'] as String?;
      if (filePath == null) continue;
      final op = entry['op'] as String?;

      bool ok = false;
      if (op == 'delete') {
        ok = await _api.deleteVaultNote(filePath);
      } else if (op == 'update') {
        final result = await _api.updateNote(
          filePath: filePath,
          title: entry['title'] as String?,
          content: entry['content'] as String?,
          tags: (entry['tags'] as List?)?.cast<String>(),
          status: entry['status'] as String?,
          para: entry['para'] as String?,
        );
        ok = result != null;
      }
      if (ok) {
        await _cache.removePendingWrite(filePath);
      } else {
        break; // stop draining on first failure — retry later
      }
    }
  }

  Future<void> _syncFromServer() async {
    // Pull all notes from vault into local cache
    final remoteNotes = await _api.getVaultNotes();
    if (remoteNotes != null) {
      final notes = remoteNotes
          .map(_noteFromServerMap)
          .where((n) => n != null)
          .cast<Note>()
          .toList();
      if (notes.isNotEmpty) {
        await _cache.saveNotes(notes);
      }
    }

    final serverStatus = await _api.getVaultStatus();
    if (serverStatus != null) {
      await _cache.setLastSync(DateTime.now());
      _status = _status.copyWith(
        totalNotes: serverStatus['total_notes'] as int? ?? _status.totalNotes,
        inboxCount: serverStatus['inbox_count'] as int? ?? _status.inboxCount,
        isServerReachable: true,
      );
      notifyListeners();
    }
  }

  Note? _noteFromServerMap(Map<String, dynamic> m) {
    try {
      final id = m['id'] as String? ?? m['file_path'] as String? ?? '';
      if (id.isEmpty) return null;
      final title = m['title'] as String? ?? 'Untitled';
      final content = m['content'] as String? ?? '';
      final tagsRaw = m['tags'] as String? ?? '';
      final tags = tagsRaw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',')
          .map((t) => t.trim().replaceAll('"', '').replaceAll("'", ''))
          .where((t) => t.isNotEmpty)
          .toList();
      final createdStr = m['created'] as String?;
      final modifiedStr = m['modified'] as String?;
      final created = createdStr != null ? DateTime.tryParse(createdStr) ?? DateTime.now() : DateTime.now();
      final modified = modifiedStr != null ? DateTime.tryParse(modifiedStr) ?? created : created;

      final statusStr = (m['status'] as String? ?? 'inbox').toLowerCase();
      final status = statusStr == 'archived'
          ? NoteStatus.archived
          : statusStr == 'processed'
              ? NoteStatus.processed
              : NoteStatus.inbox;

      final paraStr = (m['para'] as String? ?? '00-Inbox').toLowerCase();
      final para = paraStr.contains('project')
          ? ParaCategory.projects
          : paraStr.contains('area')
              ? ParaCategory.areas
              : paraStr.contains('resource')
                  ? ParaCategory.resources
                  : paraStr.contains('archive')
                      ? ParaCategory.archive
                      : ParaCategory.inbox;

      final hallStr = (m['hall'] as String? ?? 'unclassified').toLowerCase();
      final hall = _hallFromServer(hallStr);
      final wing = m['wing'] as String?;

      return Note(
        id: id,
        title: title,
        content: content,
        tags: tags,
        created: created,
        modified: modified,
        status: status,
        para: para,
        filePath: m['file_path'] as String?,
        hall: hall,
        wing: wing,
      );
    } catch (_) {
      return null;
    }
  }

  /// Creates a note locally. Called by CaptureProvider.
  Future<Note> createLocalNote(String rawText, {String? id}) async {
    final now = DateTime.now();
    final note = Note(
      id: id ?? const Uuid().v4(),
      title: _generateTitle(rawText),
      content: rawText,
      created: now,
      modified: now,
      status: NoteStatus.inbox,
      para: ParaCategory.inbox,
    );
    await _cache.saveNote(note);
    _loadFromCache();
    return note;
  }

  /// Update a note locally and sync to the server. Local save is the
  /// truth-of-record; server call is fire-and-forget. On failure the write
  /// is queued for retry on the next successful `_checkServerAndSync`.
  Future<void> updateNote(Note updated) async {
    final next = updated.copyWith(modified: DateTime.now());
    await _cache.saveNote(next);
    _loadFromCache();
    await _syncNoteToServer(next);
  }

  Future<void> _syncNoteToServer(Note note) async {
    if (note.filePath == null) return; // local-only note, nothing to sync
    final payload = <String, dynamic>{
      'op': 'update',
      'file_path': note.filePath,
      'title': note.title,
      'content': _stripFrontmatter(note.content),
      'tags': note.tags,
      'status': _statusToServer(note.status),
      'para': _paraToServer(note.para),
      'hall': _hallToServer(note.hall),
      if (note.wing != null) 'wing': note.wing,
    };

    if (!_isServerReachable) {
      await _cache.queueWrite(payload);
      return;
    }
    final result = await _api.updateNote(
      filePath: note.filePath!,
      title: note.title,
      content: payload['content'] as String,
      tags: note.tags,
      status: payload['status'] as String,
      para: payload['para'] as String,
      hall: payload['hall'] as String,
      wing: note.wing,
    );
    if (result == null) {
      await _cache.queueWrite(payload);
    } else if (result != note.filePath) {
      // Server moved the file (para change). Update local filePath.
      await _cache.saveNote(note.copyWith(filePath: result));
      _loadFromCache();
    }
  }

  Future<void> deleteNote(String id) async {
    final note = _cache.getNoteById(id);
    await _cache.deleteNote(id);
    _loadFromCache();
    if (note?.filePath != null) {
      if (_isServerReachable) {
        final ok = await _api.deleteVaultNote(note!.filePath!);
        if (!ok) {
          await _cache.queueWrite(
              {'op': 'delete', 'file_path': note.filePath});
        }
      } else {
        await _cache.queueWrite(
            {'op': 'delete', 'file_path': note!.filePath});
      }
    }
  }

  Future<void> archiveNote(String id) async {
    final note = _cache.getNoteById(id);
    if (note == null) return;
    final archived = note.copyWith(
      status: NoteStatus.archived,
      para: ParaCategory.archive,
      modified: DateTime.now(),
    );
    await _cache.saveNote(archived);
    _loadFromCache();
    await _syncNoteToServer(archived);
  }

  Future<void> processNote(String id) async {
    final note = _cache.getNoteById(id);
    if (note == null) return;
    final processed = note.copyWith(
      status: NoteStatus.processed,
      modified: DateTime.now(),
    );
    await _cache.saveNote(processed);
    _loadFromCache();
    await _syncNoteToServer(processed);
  }

  // ── Serialization helpers for server shape ──────────────────────────

  String _stripFrontmatter(String content) {
    final match = RegExp(r'^---.*?---\s*', dotAll: true).firstMatch(content);
    if (match == null) return content;
    return content.substring(match.end);
  }

  String _statusToServer(NoteStatus s) => switch (s) {
        NoteStatus.inbox => 'inbox',
        NoteStatus.processed => 'processed',
        NoteStatus.archived => 'archived',
      };

  String _paraToServer(ParaCategory p) => switch (p) {
        ParaCategory.inbox => '00-Inbox',
        ParaCategory.projects => '01-Projects',
        ParaCategory.areas => '02-Areas',
        ParaCategory.resources => '03-Resources',
        ParaCategory.archive => '04-Archive',
      };

  String _hallToServer(MemoryHall h) => switch (h) {
        MemoryHall.fact => 'fact',
        MemoryHall.event => 'event',
        MemoryHall.discovery => 'discovery',
        MemoryHall.preference => 'preference',
        MemoryHall.advice => 'advice',
        MemoryHall.unclassified => 'unclassified',
      };

  MemoryHall _hallFromServer(String s) => switch (s) {
        'fact' => MemoryHall.fact,
        'event' => MemoryHall.event,
        'discovery' => MemoryHall.discovery,
        'preference' => MemoryHall.preference,
        'advice' => MemoryHall.advice,
        _ => MemoryHall.unclassified,
      };

  /// Refresh from server on demand (pull-to-refresh).
  Future<void> refresh() async {
    await _checkServerAndSync();
  }

  String _generateTitle(String text) {
    final firstLine = text.split('\n').first.trim();
    if (firstLine.isEmpty) return 'Untitled';
    if (firstLine.length <= 60) return firstLine;
    return '${firstLine.split(' ').take(8).join(' ')}...';
  }
}
