import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../services/cache_service.dart';
import '../services/api_service.dart';

/// Handles search: local full-text (<100ms) with optional AI semantic reranking.
class SearchProvider extends ChangeNotifier {
  final CacheService _cache = CacheService.instance;
  final ApiService _api = ApiService.instance;

  String _query = '';
  List<Note> _results = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;

  String get query => _query;
  List<Note> get results => _results;
  List<String> get recentSearches => _recentSearches;
  bool get hasQuery => _query.trim().isNotEmpty;
  bool get hasResults => _results.isNotEmpty;
  bool get isSearching => _isSearching;

  void loadRecentSearches() {
    _recentSearches = _cache.recentSearches;
    notifyListeners();
  }

  /// Instant local search on every keystroke.
  void search(String query) {
    _query = query;
    if (query.trim().isEmpty) {
      _results = [];
      notifyListeners();
      return;
    }
    _results = _cache.searchNotes(query);
    notifyListeners();
  }

  /// On submit: save to history + try server for semantic search.
  Future<void> submitSearch(String query) async {
    if (query.trim().isEmpty) return;
    await _cache.addRecentSearch(query.trim());
    _recentSearches = _cache.recentSearches;

    // Start with local results immediately
    search(query);

    // Try server search (Seeker agent) — enriches results if online
    final serverResults = await _api.search(query.trim());
    if (serverResults != null && serverResults.isNotEmpty) {
      // Merge: server provides AI-ranked file paths, we pull from local cache
      final serverIds = serverResults
          .map((r) => r['id']?.toString())
          .whereType<String>()
          .toSet();
      final localById = {for (final n in _cache.getAllNotes()) n.id: n};

      final merged = <Note>[];
      for (final id in serverIds) {
        if (localById.containsKey(id)) merged.add(localById[id]!);
      }
      // Append any local results not already in server list
      for (final n in _results) {
        if (!serverIds.contains(n.id)) merged.add(n);
      }
      _results = merged;
      notifyListeners();
    }
  }

  void clear() {
    _query = '';
    _results = [];
    notifyListeners();
  }
}
