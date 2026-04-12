import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/note_model.dart';
import '../models/offline_capture_model.dart';

/// Manages all local Hive storage. Web-compatible (uses IndexedDB via hive_flutter).
class CacheService {
  static const _notesBox = 'notes';
  static const _captureQueueBox = 'capture_queue';
  static const _metaBox = 'meta';

  static CacheService? _instance;
  CacheService._();
  static CacheService get instance => _instance ??= CacheService._();

  late Box<Note> _notes;
  late Box<OfflineCapture> _captureQueue;
  late Box<dynamic> _meta;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(NoteAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NoteStatusAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ParaCategoryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(OfflineCaptureAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(MemoryHallAdapter());

    _notes = await Hive.openBox<Note>(_notesBox);
    _captureQueue = await Hive.openBox<OfflineCapture>(_captureQueueBox);
    _meta = await Hive.openBox<dynamic>(_metaBox);

    _initialized = true;
  }

  // ── Notes ──────────────────────────────────

  List<Note> getAllNotes() {
    if (!_initialized) return [];
    return _notes.values.toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
  }

  List<Note> getInboxNotes() => _notes.values
      .where((n) => n.status == NoteStatus.inbox)
      .toList()
        ..sort((a, b) => b.created.compareTo(a.created));

  Note? getNoteById(String id) =>
      _notes.values.where((n) => n.id == id).firstOrNull;

  Future<void> saveNote(Note note) async {
    await _notes.put(note.id, note);
  }

  Future<void> saveNotes(List<Note> notes) async {
    final map = {for (final n in notes) n.id: n};
    await _notes.putAll(map);
  }

  Future<void> deleteNote(String id) async {
    final key = _notes.keys.firstWhere(
      (k) => _notes.get(k)?.id == id,
      orElse: () => null,
    );
    if (key != null) await _notes.delete(key);
  }

  List<Note> searchNotes(String query) {
    if (!_initialized || query.trim().isEmpty) return [];
    final lower = query.toLowerCase();
    return _notes.values
        .where((n) =>
            n.title.toLowerCase().contains(lower) ||
            n.content.toLowerCase().contains(lower) ||
            n.tags.any((t) => t.toLowerCase().contains(lower)))
        .toList()
          ..sort((a, b) => b.modified.compareTo(a.modified));
  }

  // ── Offline Capture Queue ──────────────────

  List<OfflineCapture> getPendingCaptures() =>
      _captureQueue.values.where((c) => !c.synced).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> queueCapture(OfflineCapture capture) async {
    await _captureQueue.put(capture.id, capture);
  }

  Future<void> markCaptureSynced(String id) async {
    final capture = _captureQueue.get(id);
    if (capture != null) {
      capture.synced = true;
      await capture.save();
    }
  }

  Future<void> clearSyncedCaptures() async {
    final synced = _captureQueue.keys
        .where((k) => _captureQueue.get(k)?.synced == true)
        .toList();
    await _captureQueue.deleteAll(synced);
  }

  // ── Meta / Settings ────────────────────────

  DateTime? get lastSync {
    final ts = _meta.get('last_sync');
    return ts != null ? DateTime.tryParse(ts as String) : null;
  }

  Future<void> setLastSync(DateTime dt) async {
    await _meta.put('last_sync', dt.toIso8601String());
  }

  List<String> get recentSearches {
    if (!_initialized) return [];
    final raw = _meta.get('recent_searches');
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  Future<void> addRecentSearch(String query) async {
    if (!_initialized) return;
    final searches = recentSearches.toList();
    searches.removeWhere((s) => s == query);
    searches.insert(0, query);
    await _meta.put('recent_searches', searches.take(5).toList());
  }

  // ── Pending Write Queue (edits/deletes that need to reach the server) ────
  //
  // Stored as a JSON-encoded list in the meta box — no new Hive type.
  // Each entry: {op: "update"|"delete", file_path, title?, content?, tags?, status?, para?}

  List<Map<String, dynamic>> getPendingWrites() {
    if (!_initialized) return [];
    final raw = _meta.get('pending_writes');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw as String);
      return List<Map<String, dynamic>>.from(decoded as List);
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePendingWrites(List<Map<String, dynamic>> writes) async {
    await _meta.put('pending_writes', jsonEncode(writes));
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
    final raw = _meta.get('connections:$noteId');
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
    await _meta.put('connections:$noteId', jsonEncode(connections));
  }
}
