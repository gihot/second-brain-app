import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
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
  final CacheService _cache = CacheService.instance;
  final ApiService _api = ApiService.instance;
  final VaultProvider _vault;

  CaptureState _state = CaptureState.idle;
  String? _error;

  CaptureState get state => _state;
  bool get isCapturing => _state == CaptureState.capturing;
  bool get didSucceed => _state == CaptureState.success;
  String? get error => _error;

  CaptureProvider(this._vault);

  /// Captures a thought. Always succeeds locally.
  /// If server is reachable, the Scribe agent enriches with AI title + tags.
  Future<bool> capture(String text) async {
    if (text.trim().isEmpty) return false;

    _state = CaptureState.capturing;
    _error = null;
    notifyListeners();

    try {
      final noteId = const Uuid().v4();

      // 1. Create locally immediately
      final localNote = await _vault.createLocalNote(text.trim(), id: noteId);

      // 2. Try server (Scribe agent) — non-blocking on failure
      final serverResult = await _api.capture(text.trim(), noteId: noteId);

      if (serverResult != null) {
        // Update local note with AI-generated title + tags
        await _vault.updateNote(localNote.copyWith(
          title: serverResult.title,
          tags: serverResult.tags,
          filePath: serverResult.filePath,
        ));
      } else {
        // Queue for sync when server comes back online
        await _cache.queueCapture(OfflineCapture(
          id: noteId,
          text: text.trim(),
          createdAt: DateTime.now(),
        ));
      }

      _state = CaptureState.success;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 800));
      _state = CaptureState.idle;
      notifyListeners();

      return true;
    } catch (e) {
      _state = CaptureState.error;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Sync pending offline captures when server becomes reachable.
  Future<void> syncOfflineQueue() async {
    final pending = _cache.getPendingCaptures();
    if (pending.isEmpty) return;

    for (final capture in pending) {
      final result = await _api.capture(capture.text, noteId: capture.id);
      if (result != null) {
        // Update local note with AI enrichment
        final note = _cache.getNoteById(capture.id);
        if (note != null) {
          await _vault.updateNote(note.copyWith(
            title: result.title,
            tags: result.tags,
            filePath: result.filePath,
          ));
        }
        await _cache.markCaptureSynced(capture.id);
      }
    }
    await _cache.clearSyncedCaptures();
  }

  void reset() {
    _state = CaptureState.idle;
    _error = null;
    notifyListeners();
  }
}
