import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

/// Fetches and caches the daily connection insight from /discovery/daily.
/// Local insights (reminder, related, pattern) are provided by VaultProvider.
class DiscoveryProvider extends ChangeNotifier {
  Map<String, dynamic>? _connection; // {note_a_title, note_b_title, explanation, connection_type}
  bool _loading = false;
  bool _loaded = false;

  Map<String, dynamic>? get connection => _connection;
  bool get loading => _loading;
  bool get hasConnection => _connection != null;

  /// Load from local cache immediately, then refresh from server if stale.
  Future<void> init() async {
    _loadFromCache();
    await maybeRefresh();
  }

  void _loadFromCache() {
    final raw = CacheService.instance.getDiscoveryCache();
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _connection = decoded['connection'] as Map<String, dynamic>?;
      final cachedAt = decoded['cached_at'] as String?;
      if (cachedAt != null) {
        final age = DateTime.now().difference(DateTime.parse(cachedAt));
        if (age.inHours < 24) {
          _loaded = true;
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Refresh only if cache is older than 24h or missing.
  Future<void> maybeRefresh() async {
    if (_loaded || _loading) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    final result = await ApiService.instance.getDiscovery();
    _loading = false;

    if (result != null) {
      _connection = result['connection'] as Map<String, dynamic>?;
      _loaded = true;
      // Persist to local cache
      await CacheService.instance.saveDiscoveryCache(jsonEncode({
        'connection': _connection,
        'cached_at': result['cached_at'] ?? DateTime.now().toIso8601String(),
      }));
    }

    notifyListeners();
  }

  /// "Wisch weg" — pauses this pair for 14 days on the server, clears
  /// the local connection so the card disappears immediately.
  /// Server failure is non-fatal: the local card still vanishes for the
  /// rest of the session, the user just sees it again tomorrow.
  Future<void> dismiss() async {
    final c = _connection;
    if (c == null) return;
    final aId = (c['note_a_id'] as String?) ?? '';
    final bId = (c['note_b_id'] as String?) ?? '';

    // Optimistic UI update — card goes away right now.
    _connection = null;
    notifyListeners();
    await CacheService.instance.saveDiscoveryCache(jsonEncode({
      'connection': null,
      'cached_at': DateTime.now().toIso8601String(),
    }));

    if (aId.isNotEmpty && bId.isNotEmpty) {
      await ApiService.instance.dismissConnection(aId, bId);
    }
  }
}
