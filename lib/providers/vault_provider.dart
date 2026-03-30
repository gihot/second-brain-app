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
      await _syncFromServer();
    }
    _loadFromCache();
  }

  Future<void> _syncFromServer() async {
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

  Future<void> updateNote(Note updated) async {
    await _cache.saveNote(updated.copyWith(modified: DateTime.now()));
    _loadFromCache();
  }

  Future<void> deleteNote(String id) async {
    await _cache.deleteNote(id);
    _loadFromCache();
  }

  Future<void> archiveNote(String id) async {
    final note = _cache.getNoteById(id);
    if (note == null) return;
    await _cache.saveNote(note.copyWith(
      status: NoteStatus.archived,
      para: ParaCategory.archive,
      modified: DateTime.now(),
    ));
    _loadFromCache();
  }

  Future<void> processNote(String id) async {
    final note = _cache.getNoteById(id);
    if (note == null) return;
    await _cache.saveNote(note.copyWith(
      status: NoteStatus.processed,
      modified: DateTime.now(),
    ));
    _loadFromCache();
  }

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
