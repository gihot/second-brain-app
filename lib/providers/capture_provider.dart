import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../models/offline_capture_model.dart';
import '../services/cache_service.dart';
import '../services/api_service.dart';
import 'vault_provider.dart';

enum CaptureState { idle, capturing, success, error }

/// Handles the capture flow:
/// 1. Create note locally immediately (P3: offline-first)
/// 2. Send to server (Scribe agent) when online → update local note with AI title/tags
/// 3. Queue for later sync if offline
class CaptureProvider extends ChangeNotifier {
  /// J1 (Plan v2): Constructor-Injection für Tests. Default-Args
  /// fallen auf die Singletons zurück.
  CaptureProvider(this._vault, {CacheService? cache, ApiService? api})
      : _cache = cache ?? CacheService.instance,
        _api = api ?? ApiService.instance;

  final CacheService _cache;
  final ApiService _api;
  final VaultProvider _vault;

  CaptureState _state = CaptureState.idle;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
  String? _error;
  List<CaptureSimilar> _lastSimilarNotes = const [];

  CaptureState get state => _state;
  bool get isCapturing => _state == CaptureState.capturing;
  bool get didSucceed => _state == CaptureState.success;
  String? get error => _error;
  /// Plan 2.1: Nachbarn der zuletzt gespeicherten Notiz. Wird beim
  /// nächsten capture() überschrieben (immer das Ergebnis der jüngsten
  /// Speicherung — auch wenn das eine leere Liste ist).
  List<CaptureSimilar> get lastSimilarNotes => _lastSimilarNotes;

  /// Captures a thought. Always succeeds locally.
  /// If server is reachable, the Scribe agent enriches with AI title + tags.
  ///
  /// [remindAtIso] — if non-null, marks the capture as a reminder with the
  /// given ISO-8601 timestamp. Overrides whatever Scribe may have decided
  /// about thought_type.
  Future<bool> capture(String text, {String? remindAtIso}) async {
    if (text.trim().isEmpty || isCapturing || _disposed) return false;
    final workspace = _cache.workspaceId;

    _state = CaptureState.capturing;
    _error = null;
    // Vorherige similar-notes räumen: solange capture läuft, ist die
    // Liste „stale" — UI darf sie nicht mehr anzeigen.
    _lastSimilarNotes = const [];
    notifyListeners();

    try {
      final noteId = const Uuid().v4();

      final localNote = await _vault.createLocalNote(
        text.trim(), id: noteId, remindAt: remindAtIso,
      );
      if (_disposed || workspace != _cache.workspaceId) return false;
      final result = await _api.capture(
        text.trim(), noteId: noteId, remindAt: remindAtIso,
      );
      if (_disposed || workspace != _cache.workspaceId) return false;
      if (result != null) {
        _lastSimilarNotes = result.similarNotes;
        await _saveCaptureResult(localNote, result);
      } else {
        await _cache.queueCapture(OfflineCapture(
          id: noteId,
          text: text.trim(),
          createdAt: DateTime.now(),
        ));
      }

      if (_disposed) return false;
      _state = CaptureState.success;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 800));
      if (_disposed) return true;
      _state = CaptureState.idle;
      notifyListeners();

      return true;
    } catch (e) {
      if (_disposed) return false;
      _state = CaptureState.error;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Promotes a queued offline capture into a local note WITHOUT touching
  /// the server. Used by the offline-queue inspector for manual recovery
  /// when the server is unreachable for an extended period.
  ///
  /// The capture remains in the queue (just marked synced=true so it won't
  /// be replayed). Caller should `clearSyncedCaptures()` to garbage-collect.
  Future<void> saveCaptureLocallyAsNote(OfflineCapture capture) async {
    await _vault.createLocalNote(capture.text, id: capture.id);
  }

  bool _syncing = false;

  Future<void> syncOfflineQueue() async {
    if (_syncing || !_api.hasToken) return;
    final workspace = _cache.workspaceId;
    _syncing = true;
    try {
      for (final capture in _cache.getPendingCaptures()) {
        final note = _cache.getNoteById(capture.id);
        if (note == null) continue;
        final result = await _api.capture(
          note.content, noteId: note.id, remindAt: note.remindAt,
        );
        if (_disposed || _cache.workspaceId != workspace) return;
        if (result == null) continue;
        await _saveCaptureResult(note, result);
        if (_disposed || _cache.workspaceId != workspace) return;
        await _cache.markCaptureSynced(capture.id);
      }
      await _cache.clearSyncedCaptures();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _saveCaptureResult(Note note, CaptureResult result) {
    final remindAt = note.remindAt ?? result.remindAt;
    return _vault.updateNote(note.copyWith(
      title: result.title,
      tags: result.tags,
      filePath: result.filePath,
      hall: result.hall,
      wing: result.suggestedWing?.isNotEmpty == true ? result.suggestedWing : null,
      thoughtType: remindAt == null ? note.thoughtType : ThoughtType.reminder,
      remindAt: remindAt,
    ));
  }

  void reset() {
    _state = CaptureState.idle;
    _error = null;
    notifyListeners();
  }
}
