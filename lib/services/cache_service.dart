import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/note_model.dart';
import '../models/offline_capture_model.dart';

/// Manages all local Hive storage, **per-user-namespaced**.
///
/// Web-compatible (uses IndexedDB via hive_flutter). Box names follow
/// `<kind>_<user_id>` so two users on the same browser never see each
/// other's data. Call [init] with the user-id after login; call [close]
/// on logout.
class CacheService {
  static String _notesBoxName(String uid) => 'notes_$uid';
  static String _captureQueueBoxName(String uid) => 'capture_queue_$uid';
  static String _metaBoxName(String uid) => 'meta_$uid';

  // Legacy global box names — read once by the one-time migration in [init]
  // and then deleted. New code never opens these.
  static const _legacyNotesBox = 'notes';
  static const _legacyCaptureQueueBox = 'capture_queue';
  static const _legacyMetaBox = 'meta';

  static CacheService? _instance;
  CacheService._();
  static CacheService get instance => _instance ??= CacheService._();

  Box<Note>? _notes;
  Box<OfflineCapture>? _captureQueue;
  Box<dynamic>? _meta;

  String? _currentUserId;
  bool _hiveInitialized = false;

  /// True iff a user is logged in and their boxes are open.
  bool get _initialized => _currentUserId != null;

  /// True iff the boxes for [userId] are open right now.
  bool isReadyFor(String userId) =>
      _currentUserId == userId && _notes != null;

  /// Open the cache for [userId]. Idempotent for the same user. On a
  /// user switch, closes the previous user's boxes first.
  ///
  /// Runs a one-time migration from the legacy global boxes to the new
  /// per-user boxes (see [_migrateLegacyIfNeeded]).
  Future<void> init(String userId) async {
    if (_currentUserId == userId && _notes != null) return;
    if (_currentUserId != null) {
      await close();
    }

    if (!_hiveInitialized) {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(NoteAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NoteStatusAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ParaCategoryAdapter());
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(OfflineCaptureAdapter());
      if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(MemoryHallAdapter());
      if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(ThoughtTypeAdapter());
      _hiveInitialized = true;
    }

    _notes = await Hive.openBox<Note>(_notesBoxName(userId));
    _captureQueue =
        await Hive.openBox<OfflineCapture>(_captureQueueBoxName(userId));
    _meta = await Hive.openBox<dynamic>(_metaBoxName(userId));

    // Migration is best-effort. If it throws (e.g. a corrupted legacy
    // box on web, or a Hive version mismatch), we must NOT block login —
    // the user can always recover their notes from the server. Failed
    // migrations leave the legacy box on disk for later cleanup or
    // export, but never gate the rest of the app.
    try {
      await _migrateLegacyIfNeeded();
    } catch (e, st) {
      // ignore: avoid_print
      print('Legacy cache migration skipped due to error: $e\n$st');
    }

    _currentUserId = userId;
  }

  /// Close all open boxes. Called on logout so the next user's [init]
  /// starts from a clean slate.
  Future<void> close() async {
    await _notes?.close();
    await _captureQueue?.close();
    await _meta?.close();
    _notes = null;
    _captureQueue = null;
    _meta = null;
    _currentUserId = null;
  }

  // ── One-time legacy → per-user migration ──────────────────────────────
  //
  // Two strictly-separated steps so a crash between them is safe:
  //   A) MIGRATE: if new box is EMPTY and legacy exists → copy values.
  //   B) CLEANUP: if new box is POPULATED and legacy exists → delete legacy.
  // Crash between A and B → next [init] finds the new box populated,
  // skips A (no double-write), runs B (cleanup). Idempotent.

  Future<void> _migrateLegacyIfNeeded() async {
    await _migrateBox<Note>(_legacyNotesBox, _notes!);
    await _migrateBox<OfflineCapture>(_legacyCaptureQueueBox, _captureQueue!);
    await _migrateBox<dynamic>(_legacyMetaBox, _meta!);
  }

  Future<void> _migrateBox<T>(String legacyName, Box<T> newBox) async {
    final hasLegacy = await Hive.boxExists(legacyName);
    if (!hasLegacy) return;

    // Step A — copy only if the new box is still empty.
    if (newBox.isEmpty) {
      final legacy = await Hive.openBox<T>(legacyName);
      final entries = <dynamic, T>{
        for (final k in legacy.keys) k: legacy.get(k) as T
      };
      await newBox.putAll(entries);
      await legacy.close();
    }

    // Step B — once the new box is populated, drop the legacy box.
    if (newBox.isNotEmpty) {
      await Hive.deleteBoxFromDisk(legacyName);
    }
  }

  // ── Notes ──────────────────────────────────

  List<Note> getAllNotes() {
    if (!_initialized) return [];
    return _notes!.values.toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
  }

  List<Note> getInboxNotes() {
    if (!_initialized) return const [];
    return _notes!.values
        .where((n) => n.status == NoteStatus.inbox)
        .toList()
          ..sort((a, b) => b.created.compareTo(a.created));
  }

  Note? getNoteById(String id) {
    if (!_initialized) return null;
    return _notes!.values.where((n) => n.id == id).firstOrNull;
  }

  Future<void> saveNote(Note note) async {
    if (!_initialized) return;
    await _notes!.put(note.id, note);
  }

  Future<void> saveNotes(List<Note> notes) async {
    if (!_initialized) return;
    final map = {for (final n in notes) n.id: n};
    await _notes!.putAll(map);
  }

  Future<void> deleteNote(String id) async {
    if (!_initialized) return;
    final key = _notes!.keys.firstWhere(
      (k) => _notes!.get(k)?.id == id,
      orElse: () => null,
    );
    if (key != null) await _notes!.delete(key);
  }

  List<Note> searchNotes(String query) {
    if (!_initialized || query.trim().isEmpty) return [];
    final lower = query.toLowerCase();
    return _notes!.values
        .where((n) =>
            n.title.toLowerCase().contains(lower) ||
            n.content.toLowerCase().contains(lower) ||
            n.tags.any((t) => t.toLowerCase().contains(lower)))
        .toList()
          ..sort((a, b) => b.modified.compareTo(a.modified));
  }

  /// Number of capture-queue entries that have not been synced yet.
  /// A non-zero value here means data would be lost if the user clears.
  int get unsyncedCount {
    if (!_initialized) return 0;
    return _captureQueue!.values.where((c) => !c.synced).length +
        getPendingWrites().length;
  }

  /// Wipes the local Notes cache (does NOT touch the offline capture queue
  /// or the meta box). The wrapper name is intentionally scary — call sites
  /// must guard with confirmation UI.
  ///
  /// Throws [StateError] if there are pending captures or pending writes
  /// that would be orphaned by clearing notes. The caller must replay or
  /// discard those first.
  Future<void> dangerouslyClearAllNotes() async {
    if (!_initialized) return;
    if (unsyncedCount > 0) {
      throw StateError(
          'Refusing to clear: $unsyncedCount unsynced item(s) in queue. '
          'Replay or discard them first.');
    }
    await _notes!.clear();
  }

  // ── Offline Capture Queue ──────────────────

  List<OfflineCapture> getPendingCaptures() {
    // Guard: settings tiles read this during build, which can race the
    // async CacheService.init() at app start (LateInitializationError).
    if (!_initialized) return [];
    return _captureQueue!.values.where((c) => !c.synced).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> queueCapture(OfflineCapture capture) async {
    if (!_initialized) return;
    await _captureQueue!.put(capture.id, capture);
  }

  Future<void> markCaptureSynced(String id) async {
    if (!_initialized) return;
    final capture = _captureQueue!.get(id);
    if (capture != null) {
      capture.synced = true;
      await capture.save();
    }
  }

  Future<void> clearSyncedCaptures() async {
    if (!_initialized) return;
    final synced = _captureQueue!.keys
        .where((k) => _captureQueue!.get(k)?.synced == true)
        .toList();
    await _captureQueue!.deleteAll(synced);
  }

  // ── Meta / Settings ────────────────────────

  DateTime? get lastSync {
    if (!_initialized) return null;
    final ts = _meta!.get('last_sync');
    return ts != null ? DateTime.tryParse(ts as String) : null;
  }

  Future<void> setLastSync(DateTime dt) async {
    if (!_initialized) return;
    await _meta!.put('last_sync', dt.toIso8601String());
  }

  List<String> get recentSearches {
    if (!_initialized) return [];
    final raw = _meta!.get('recent_searches');
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  Future<void> addRecentSearch(String query) async {
    if (!_initialized) return;
    final searches = recentSearches.toList();
    searches.removeWhere((s) => s == query);
    searches.insert(0, query);
    await _meta!.put('recent_searches', searches.take(5).toList());
  }

  // ── Pending Write Queue (edits/deletes that need to reach the server) ────
  //
  // Stored as a JSON-encoded list in the meta box — no new Hive type.
  // Each entry: {op: "update"|"delete", file_path, title?, content?, tags?, status?, para?}

  List<Map<String, dynamic>> getPendingWrites() {
    if (!_initialized) return [];
    final raw = _meta!.get('pending_writes');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw as String);
      return List<Map<String, dynamic>>.from(decoded as List);
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePendingWrites(List<Map<String, dynamic>> writes) async {
    if (!_initialized) return;
    await _meta!.put('pending_writes', jsonEncode(writes));
  }

  /// Adds or coalesces a pending write. If an existing entry for the same
  /// file_path exists, it's merged (update) or replaced (delete).
  Future<void> queueWrite(Map<String, dynamic> entry) async {
    if (!_initialized) return;
    final writes = getPendingWrites();
    final filePath = entry['file_path'];
    final op = entry['op'];

    if (op == 'delete') {
      writes.removeWhere((w) => w['file_path'] == filePath);
      writes.add(entry);
    } else {
      final idx = writes.indexWhere(
          (w) => w['file_path'] == filePath && w['op'] == 'update');
      if (idx >= 0) {
        writes[idx] = {...writes[idx], ...entry};
      } else {
        writes.add(entry);
      }
    }
    await _savePendingWrites(writes);
  }

  Future<void> removePendingWrite(String filePath) async {
    if (!_initialized) return;
    final writes = getPendingWrites()
        ..removeWhere((w) => w['file_path'] == filePath);
    await _savePendingWrites(writes);
  }

  // ── Connection Cache (per note) ─────────────────────────────────────────
  //
  // Stored as JSON-encoded list under key `connections:<noteId>` in meta box.

  List<Map<String, dynamic>> getConnections(String noteId) {
    if (!_initialized) return [];
    final raw = _meta!.get('connections:$noteId');
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw as String) as List);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveConnections(
      String noteId, List<Map<String, dynamic>> connections) async {
    if (!_initialized) return;
    await _meta!.put('connections:$noteId', jsonEncode(connections));
  }

  // ── Discovery Cache ─────────────────────────────────────────────────────────

  String? getDiscoveryCache() {
    if (!_initialized) return null;
    return _meta!.get('discovery_cache') as String?;
  }

  Future<void> saveDiscoveryCache(String json) async {
    if (!_initialized) return;
    await _meta!.put('discovery_cache', json);
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  bool get notificationsEnabled {
    if (!_initialized) return true; // default on
    return (_meta!.get('notifications_enabled') as bool?) ?? true;
  }

  void setNotificationsEnabled(bool value) {
    if (!_initialized) return;
    _meta!.put('notifications_enabled', value);
  }

  // ── Generic string-preference helpers ────────────────────────────────────

  String? getString(String key) {
    if (!_initialized) return null;
    final v = _meta!.get(key);
    if (v is String) return v;
    return null;
  }

  Future<void> setString(String key, String value) async {
    if (!_initialized) return;
    await _meta!.put(key, value);
  }

  // ── Generic double-preference helpers ────────────────────────────────────

  double? getDouble(String key) {
    if (!_initialized) return null;
    final v = _meta!.get(key);
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return null;
  }

  Future<void> setDouble(String key, double value) async {
    if (!_initialized) return;
    await _meta!.put(key, value);
  }

  // ── Background Image ─────────────────────────────────────────────────────

  Uint8List? getBackgroundImage() {
    if (!_initialized) return null;
    final raw = _meta!.get('background_image_bytes');
    if (raw is Uint8List) return raw;
    if (raw is List) return Uint8List.fromList(List<int>.from(raw));
    return null;
  }

  Future<void> setBackgroundImage(Uint8List? bytes) async {
    if (!_initialized) return;
    if (bytes == null) {
      await _meta!.delete('background_image_bytes');
    } else {
      await _meta!.put('background_image_bytes', bytes);
    }
  }

  // ── Discovery Insight Dismiss ────────────────────────────────────────────
  // Map<insightKey, dismissedAtIsoString>. TTL: 24h.

  static const _insightDismissKey = 'insight_dismissed_v1';
  static const Duration _insightDismissTtl = Duration(hours: 24);

  Map<String, String> _readInsightDismissMap() {
    if (!_initialized) return {};
    final raw = _meta!.get(_insightDismissKey);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(
          jsonDecode(raw as String) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeInsightDismissMap(Map<String, String> map) async {
    if (!_initialized) return;
    await _meta!.put(_insightDismissKey, jsonEncode(map));
  }

  /// Returns true if [key] was dismissed within the TTL window.
  /// Side-effect: prunes expired entries.
  bool isInsightDismissed(String key) {
    if (!_initialized) return false;
    final map = _readInsightDismissMap();
    final iso = map[key];
    if (iso == null) return false;
    final dismissedAt = DateTime.tryParse(iso);
    if (dismissedAt == null) return false;
    if (DateTime.now().difference(dismissedAt) >= _insightDismissTtl) {
      // Expired — clean up lazily.
      map.remove(key);
      _writeInsightDismissMap(map);
      return false;
    }
    return true;
  }

  Future<void> markInsightDismissed(String key) async {
    if (!_initialized) return;
    final map = _readInsightDismissMap();
    // Prune any expired entries while we're here.
    final now = DateTime.now();
    map.removeWhere((_, iso) {
      final dt = DateTime.tryParse(iso);
      return dt == null ||
          now.difference(dt) >= _insightDismissTtl;
    });
    map[key] = now.toIso8601String();
    await _writeInsightDismissMap(map);
  }

  List<String> getNotifiedReminderIds() {
    if (!_initialized) return [];
    final raw = _meta!.get('notified_reminder_ids');
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  void saveNotifiedReminderIds(List<String> ids) {
    if (!_initialized) return;
    _meta!.put('notified_reminder_ids', ids);
  }
}
