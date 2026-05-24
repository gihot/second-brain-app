import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/note_model.dart';

/// HTTP client for the Second Brain Cloud Bridge.
/// All calls fail gracefully — callers should handle null returns as "offline".
class ApiService {
  static ApiService? _instance;
  ApiService._();
  static ApiService get instance => _instance ??= ApiService._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'api_token';

  // Server URL is a build-time constant — that's not a secret, just a
  // deployment detail. Updating the URL means a new release.
  static const _kServerBaseUrl =
      'https://second-brain-app-production-dcee.up.railway.app';

  String? _token;
  bool _initialized = false;

  /// Set by [AuthProvider] so the api layer can trigger logout on any 401.
  void Function()? onUnauthorized;

  String get baseUrl => _kServerBaseUrl;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
    _initialized = true;
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Returns `(user, errorMessage)`: on success `user` is set; on failure
  /// `user` is null and `errorMessage` carries a user-friendly hint.
  Future<({Map<String, dynamic>? user, String? error})> login(
      String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        await setToken(body['token'] as String);
        return (user: body['user'] as Map<String, dynamic>, error: null);
      }
      if (response.statusCode == 401) {
        return (user: null, error: 'E-Mail oder Passwort falsch.');
      }
      return (user: null, error: 'Anmeldung fehlgeschlagen (HTTP ${response.statusCode}).');
    } catch (e) {
      return (user: null, error: 'Server nicht erreichbar.');
    }
  }

  /// Returns the current user from the server. `null` on any failure
  /// (incl. 401 — caller should treat that as "log out").
  Future<Map<String, dynamic>?> getMe() async {
    final body = await _get('/auth/me');
    return body?['user'] as Map<String, dynamic>?;
  }

  // ── Capture ───────────────────────────────────────────────────────────────

  /// Returns null on failure (offline / server down).
  Future<CaptureResult?> capture(String text, {String? noteId}) async {
    final body = await _post('/capture', {'text': text, if (noteId != null) 'note_id': noteId});
    if (body == null) return null;
    final hallStr = (body['hall'] as String? ?? 'unclassified').toLowerCase();
    final hall = switch (hallStr) {
      'fact' => MemoryHall.fact,
      'event' => MemoryHall.event,
      'discovery' => MemoryHall.discovery,
      'preference' => MemoryHall.preference,
      'advice' => MemoryHall.advice,
      _ => MemoryHall.unclassified,
    };
    return CaptureResult(
      noteId: body['note_id'] as String,
      title: body['title'] as String,
      tags: List<String>.from(body['tags'] as List),
      filePath: body['file_path'] as String,
      para: body['para'] as String,
      hall: hall,
      suggestedWing: body['suggested_wing'] as String?,
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> search(
    String query, {
    String? wing,
    String? hall,
  }) async {
    var url = '/search?q=${Uri.encodeComponent(query)}';
    if (wing != null) url += '&wing=${Uri.encodeComponent(wing)}';
    if (hall != null) url += '&hall=${Uri.encodeComponent(hall)}';
    final body = await _get(url);
    if (body == null) return null;
    return List<Map<String, dynamic>>.from(body['results'] as List);
  }

  // ── Inbox ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> getInbox() async {
    final body = await _get('/inbox');
    if (body == null) return null;
    return List<Map<String, dynamic>>.from(body['notes'] as List);
  }

  Future<bool> triageAll() async {
    final body = await _post('/inbox/triage', {});
    return body != null;
  }

  // ── Vault Status ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getVaultStatus() async {
    return _get('/vault/status');
  }

  // ── Vault Notes (full sync) ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> getVaultNotes({int limit = 200}) async {
    final body = await _get('/vault/notes?limit=$limit');
    if (body == null) return null;
    return List<Map<String, dynamic>>.from(body['notes'] as List);
  }

  /// Update an existing note on the server. Returns the new file path on
  /// success, null on failure (offline, not-found, validation error).
  /// Caller should treat null as "queue for retry".
  Future<String?> updateNote({
    required String filePath,
    String? title,
    String? content,
    List<String>? tags,
    String? status,
    String? para,
    String? hall,
    String? wing,
    String? thoughtType,
    String? remindAt,
  }) async {
    final body = await _put('/vault/notes', {
      'file_path': filePath,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (tags != null) 'tags': tags,
      if (status != null) 'status': status,
      if (para != null) 'para': para,
      if (hall != null) 'hall': hall,
      if (wing != null) 'wing': wing,
      if (thoughtType != null) 'thought_type': thoughtType,
      if (remindAt != null) 'remind_at': remindAt,
    });
    if (body == null) return null;
    return body['file_path'] as String?;
  }

  /// Delete a note on the server. Returns true on success.
  Future<bool> deleteVaultNote(String filePath) async {
    final body = await _delete('/vault/notes', {'file_path': filePath});
    return body != null;
  }

  // ── Related Notes (embedding-based) ───────────────────────────────────────

  /// Returns up to [limit] notes most similar to [noteId] per the embedding
  /// index. Returns null on transport failure, `[]` if the index is disabled
  /// or the note isn't indexed yet.
  Future<List<Map<String, dynamic>>?> getRelated(String noteId,
      {int limit = 5}) async {
    final body = await _get(
      '/vault/related/${Uri.encodeComponent(noteId)}?limit=$limit',
    );
    if (body == null) return null;
    final list = body['related'] as List?;
    return list?.cast<Map<String, dynamic>>() ?? const [];
  }

  // ── Wings ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> getWings() async {
    final body = await _get('/vault/wings');
    if (body == null) return null;
    final list = body['wings'] as List?;
    return list?.cast<Map<String, dynamic>>();
  }

  Future<int?> renameWing(String oldWing, String newWing) async {
    final body = await _put('/vault/wings/rename', {
      'old_wing': oldWing,
      'new_wing': newWing,
    });
    if (body == null) return null;
    return body['updated'] as int?;
  }

  // ── Identity ──────────────────────────────────────────────────────────────

  Future<String?> getIdentity() async {
    final body = await _get('/vault/identity');
    return body?['content'] as String?;
  }

  Future<bool> updateIdentity(String content) async {
    final body = await _put('/vault/identity', {'content': content});
    return body != null;
  }

  // ── Agents ────────────────────────────────────────────────────────────────

  /// Invoke an agent by name (scribe, seeker, sorter, librarian, connector).
  /// Returns the full response dict: {agent, content, metadata}.
  Future<Map<String, dynamic>?> invokeAgent(
    String name,
    String message, {
    Map<String, dynamic>? context,
  }) async {
    return _post('/agent/$name', {
      'message': message,
      if (context != null) 'context': context,
    });
  }

  // ── Discovery ─────────────────────────────────────────────────────────────

  /// Fetch daily discovery insight (connection between recent notes).
  /// Cached 24h on the server. Returns null on failure.
  Future<Map<String, dynamic>?> getDiscovery() async {
    return _get('/discovery/daily');
  }

  /// Pause the (note_a, note_b) pair for 14 days on the server so the
  /// daily-discovery card stops suggesting it.
  Future<bool> dismissConnection(String noteAId, String noteBId) async {
    final body = await _post('/discovery/dismiss', {
      'note_a_id': noteAId,
      'note_b_id': noteBId,
    });
    return body != null;
  }

  // ── Health Check ───────────────────────────────────────────────────────────

  Future<bool> ping() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Verbose health check used by the Settings "Test Connection" button.
  /// Returns latency in ms when reachable, or a short error message.
  Future<({bool ok, int? latencyMs, String? error})>
      pingWithLatency() async {
    final sw = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      sw.stop();
      if (response.statusCode == 200) {
        return (ok: true, latencyMs: sw.elapsedMilliseconds, error: null);
      }
      return (
        ok: false,
        latencyMs: sw.elapsedMilliseconds,
        error: 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return (ok: false, latencyMs: null, error: e.toString());
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Centralized 401-handling: fires the AuthProvider's logout once.
  void _handle401(int statusCode) {
    if (statusCode == 401) {
      try {
        onUnauthorized?.call();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    if (!hasToken) return null;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      _handle401(response.statusCode);
      debugPrint('ApiService GET $path → ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ApiService GET $path error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _put(String path, Map<String, dynamic> body) async {
    if (!hasToken) return null;
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      _handle401(response.statusCode);
      debugPrint('ApiService PUT $path → ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ApiService PUT $path error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _delete(String path, Map<String, dynamic> body) async {
    if (!hasToken) return null;
    try {
      final request = http.Request('DELETE', Uri.parse('$baseUrl$path'))
        ..headers.addAll(_headers)
        ..body = jsonEncode(body);
      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      _handle401(response.statusCode);
      debugPrint('ApiService DELETE $path → ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ApiService DELETE $path error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    if (!hasToken) return null;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      _handle401(response.statusCode);
      debugPrint('ApiService POST $path → ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ApiService POST $path error: $e');
      return null;
    }
  }
}

class CaptureResult {
  final String noteId;
  final String title;
  final List<String> tags;
  final String filePath;
  final String para;
  final MemoryHall hall;
  final String? suggestedWing;

  const CaptureResult({
    required this.noteId,
    required this.title,
    required this.tags,
    required this.filePath,
    required this.para,
    this.hall = MemoryHall.unclassified,
    this.suggestedWing,
  });
}
