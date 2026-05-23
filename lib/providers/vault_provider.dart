import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note_codec.dart';
import '../models/note_model.dart';
import '../models/vault_status_model.dart';
import '../services/cache_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

/// Central state for the vault: all notes, inbox count, sync status.
class VaultProvider extends ChangeNotifier {
  final CacheService _cache = CacheService.instance;
  final ApiService _api = ApiService.instance;

  List<Note> _notes = [];
  VaultStatus _status = const VaultStatus();
  bool _loading = false;
  String? _error;
  bool _isServerReachable = false;
  Timer? _autoPullTimer;

  static const Duration _autoPullInterval = Duration(minutes: 5);

  List<Note> get notes => _notes;
  List<Note> get recentNotes => _notes.take(5).toList();

  /// Count of notes created since local midnight — the dashboard's
  /// "heute erfasst" pulse.
  int get capturesToday {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _notes.where((n) => n.created.isAfter(start)).length;
  }
  List<Note> get inboxNotes =>
      _notes.where((n) => n.status == NoteStatus.inbox).toList();
  /// Reminders whose [remindAt] is at-or-before now (i.e. actually due).
  /// Future reminders are NOT included — those wait until their time arrives.
  List<Note> get dueReminders => _notes.where((n) =>
      n.thoughtType == ThoughtType.reminder &&
      n.remindAt != null &&
      !(DateTime.tryParse(n.remindAt!)?.isAfter(DateTime.now()) ?? true)).toList();

  /// PARA distribution for the stats chart.
  /// PARA distribution — excludes Inbox (not a real PARA category;
  /// inbox notes are shown separately via inboxCount stat card).
  Map<ParaCategory, int> get paraDistribution {
    final counts = {for (final c in ParaCategory.values) c: 0};
    for (final n in _notes) {
      if (n.para == ParaCategory.inbox) continue; // shown via stat card
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

  /// Light boot path — does NOT open the cache itself anymore
  /// (AuthProvider owns that, per-user). We still pre-init the API layer
  /// so the 401-callback can fire even before any user logs in, and start
  /// the auto-pull timer that no-ops when there's no token to use.
  Future<void> initialize() async {
    _loading = true;
    notifyListeners();

    try {
      await _api.init();
      // Cache may already be open (post-login init() raced ahead) or not
      // yet (pre-login boot). Either way: load whatever's there. If
      // nothing, _notes stays empty until the AuthGate calls refresh().
      _loadFromCache();

      _checkServerAndSync();
      _startAutoPull();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _startAutoPull() {
    _autoPullTimer?.cancel();
    _autoPullTimer = Timer.periodic(_autoPullInterval, (_) {
      // Fire-and-forget — if server is unreachable, _checkServerAndSync
      // returns quickly and the timer continues without side-effects.
      _checkServerAndSync();
    });
  }

  @override
  void dispose() {
    _autoPullTimer?.cancel();
    super.dispose();
  }

  void _loadFromCache() {
    _notes = _cache.getAllNotes();
    _status = VaultStatus(
      totalNotes: _notes.length,
      inboxCount: _notes.where((n) => n.status == NoteStatus.inbox).length,
      lastSync: _cache.lastSync,
      isServerReachable: _isServerReachable,
    );
    notifyListeners();
    // Heal legacy bug: any reminder whose remindAt is still in the future
    // but was wrongly marked notified gets un-marked here so it fires when
    // its actual time arrives.
    NotificationService.instance.prunePrematureNotifications(_notes);
    // Fire-and-forget: show browser notification for any newly due reminders.
    NotificationService.instance.checkAndNotify(dueReminders);
  }

  Future<void> _checkServerAndSync() async {
    _isServerReachable = await _api.ping();
    if (_isServerReachable) {
      await _drainPendingWrites();
      await _syncFromServer();
      // Whenever the server was successfully pinged, stamp lastSync —
      // even if vault-status endpoint is missing/broken, the ping itself
      // proves a recent connection.
      await _cache.setLastSync(DateTime.now());
    }
    _loadFromCache();
  }

  /// Flush queued edits/deletes to the server. Tries every entry
  /// independently — one failure (e.g. 404 on a note that never reached
  /// the server) doesn't block the rest. Failed entries stay in the queue
  /// for the user to inspect and discard manually.
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
      }
      // On failure: leave the entry in the queue, move on to the next.
      // User can manually discard via the Pending-Writes sheet.
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
        await _writeNotesWithConflictDetection(notes);
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

  /// Saves incoming server notes to the cache, but if a local note has
  /// pending changes (= queued in pending_writes) AND the server version
  /// differs in body/title/tags, preserve BOTH by keeping the local note
  /// untouched and writing the server copy as a new note with a
  /// "(Konflikt …)" title suffix. User can then reconcile by hand.
  Future<void> _writeNotesWithConflictDetection(
      List<Note> incoming) async {
    final pendingPaths = {
      for (final w in _cache.getPendingWrites())
        if (w['file_path'] is String) w['file_path'] as String
    };
    final byId = {for (final n in _cache.getAllNotes()) n.id: n};

    final toSave = <Note>[];
    for (final remote in incoming) {
      final local = byId[remote.id];
      final hasPending = local?.filePath != null &&
          pendingPaths.contains(local!.filePath);

      if (local == null || !hasPending) {
        toSave.add(remote);
        continue;
      }

      // Local has unsynced edits. Only flag a conflict if the bodies
      // actually differ — otherwise the server version is just our own
      // unsynced edit echoed back and we can keep local.
      if (_notesEffectivelyEqual(local, remote)) continue;

      // Fork: keep local untouched, write a separate Konflikt-Copy.
      final conflictCopy = remote.copyWith(
        title: '${remote.title} (Konflikt '
            '${_stamp(DateTime.now())})',
      );
      // New id so it doesn't overwrite anything.
      toSave.add(Note(
        id: const Uuid().v4(),
        title: conflictCopy.title,
        content: conflictCopy.content,
        tags: conflictCopy.tags,
        created: conflictCopy.created,
        modified: DateTime.now(),
        status: conflictCopy.status,
        para: conflictCopy.para,
        filePath: null, // local-only; user decides what to do
        hall: conflictCopy.hall,
        wing: conflictCopy.wing,
        thoughtType: conflictCopy.thoughtType,
        remindAt: conflictCopy.remindAt,
      ));
    }
    if (toSave.isNotEmpty) {
      await _cache.saveNotes(toSave);
    }
  }

  bool _notesEffectivelyEqual(Note a, Note b) {
    if (a.title.trim() != b.title.trim()) return false;
    if (a.content.trim() != b.content.trim()) return false;
    if (a.tags.join(',') != b.tags.join(',')) return false;
    return true;
  }

  String _stamp(DateTime dt) {
    final l = dt.toLocal();
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${l.day}.${l.month}. ${pad(l.hour)}:${pad(l.minute)}';
  }

  Note? _noteFromServerMap(Map<String, dynamic> m) {
    try {
      // Server omits `id` for legacy notes — fall back to file_path so the
      // note still round-trips.
      final patched = (m['id'] == null || (m['id'] as String).isEmpty)
          ? {...m, 'id': m['file_path'] ?? ''}
          : m;
      // Server also omits `title` sometimes — keep the historical default.
      final withTitle = (patched['title'] == null ||
              (patched['title'] as String).isEmpty)
          ? {...patched, 'title': 'Unbenannt'}
          : patched;
      return noteFromMap(withTitle);
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
    final payload = noteToServerMap(note);

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
      thoughtType: payload['thought_type'] as String,
      remindAt: note.remindAt,
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

  /// Refresh from server on demand (pull-to-refresh).
  Future<void> refresh() async {
    await _checkServerAndSync();
  }

  /// Re-reads the in-memory note list from Hive without touching the server.
  /// Used after bulk-imports (vault recovery, ZIP-import) so the UI reflects
  /// the freshly-written notes immediately.
  void reloadFromCache() => _loadFromCache();

  /// Manual replay of pending writes. Pings the server first; if reachable,
  /// drains; returns counts so the UI can show progress.
  Future<({int drained, int remaining, bool serverReachable})>
      replayPendingWrites() async {
    final before = _cache.getPendingWrites().length;
    if (before == 0) {
      return (drained: 0, remaining: 0, serverReachable: true);
    }
    _isServerReachable = await _api.ping();
    if (!_isServerReachable) {
      return (drained: 0, remaining: before, serverReachable: false);
    }
    await _drainPendingWrites();
    final after = _cache.getPendingWrites().length;
    _loadFromCache();
    return (
      drained: before - after,
      remaining: after,
      serverReachable: true,
    );
  }

  /// Discard a single pending write (e.g. user gave up after repeated
  /// failures). Does NOT touch the corresponding local Note.
  Future<void> discardPendingWrite(String filePath) async {
    await _cache.removePendingWrite(filePath);
    notifyListeners();
  }

  String _generateTitle(String text) {
    final firstLine = text.split('\n').first.trim();
    if (firstLine.isEmpty) return 'Unbenannt';
    if (firstLine.length <= 60) return firstLine;
    return '${firstLine.split(' ').take(8).join(' ')}...';
  }
}
