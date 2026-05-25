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
  String? _wingFilter;
  MemoryHall? _hallFilter;
  // Plan 2.3: serverseitig normalisierter Hybrid-Score je Notiz-ID
  // ([0,1], 1 = top-Treffer). Leer für rein lokale Ergebnisse — UI
  // verzichtet dann auf den Relevance-Indicator.
  Map<String, double> _scores = const {};

  String get query => _query;
  List<Note> get results => _results;
  List<String> get recentSearches => _recentSearches;
  bool get hasQuery => _query.trim().isNotEmpty;
  bool get hasResults => _results.isNotEmpty;
  bool get isSearching => _isSearching;
  String? get wingFilter => _wingFilter;
  MemoryHall? get hallFilter => _hallFilter;
  double? scoreFor(String noteId) => _scores[noteId];

  void setWingFilter(String? wing) {
    _wingFilter = wing;
    if (_query.isNotEmpty) search(_query);
    notifyListeners();
  }

  void setHallFilter(MemoryHall? hall) {
    _hallFilter = hall;
    if (_query.isNotEmpty) search(_query);
    notifyListeners();
  }

  void loadRecentSearches() {
    _recentSearches = _cache.recentSearches;
    notifyListeners();
  }

  /// Instant local search on every keystroke.
  void search(String query) {
    _query = query;
    // Stale Scores beim neuen Query verwerfen — sie gehören zum
    // vorherigen submitSearch(). Erst wenn der Server für die neue
    // Query antwortet, wird _scores neu gefüllt.
    _scores = const {};
    if (query.trim().isEmpty) {
      _results = [];
      notifyListeners();
      return;
    }
    var results = _cache.searchNotes(query);
    if (_wingFilter != null) {
      results = results.where((n) => n.wing == _wingFilter).toList();
    }
    if (_hallFilter != null) {
      results = results.where((n) => n.hall == _hallFilter).toList();
    }
    _results = results;
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
    final serverResults = await _api.search(
      query.trim(),
      wing: _wingFilter,
      hall: _hallFilter?.name,
    );
    if (serverResults != null && serverResults.isNotEmpty) {
      // Merge: server provides AI-ranked file paths, we pull from local cache.
      // Score-Map parallel mitführen für den Relevance-Indicator (Plan 2.3).
      final serverIds = <String>{};
      final scores = <String, double>{};
      for (final r in serverResults) {
        final id = r['id']?.toString();
        if (id == null) continue;
        serverIds.add(id);
        final s = r['score'];
        if (s is num) scores[id] = s.toDouble();
      }
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
      _scores = scores;
      notifyListeners();
    }
  }

  void clear() {
    _query = '';
    _results = [];
    _scores = const {};
    notifyListeners();
  }
}
