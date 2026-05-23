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
  static const _baseUrlKey = 'api_base_url';
  static const _tokenKey = 'api_token';

  // Hardcoded server URL — single source of truth. Update this constant +
  // redeploy to migrate every client at once. Stored overrides are no
  // longer respected; any stale value from a previous session is purged
  // on next init.
  static const _kServerBaseUrl =
      'https://second-brain-app-production-dcee.up.railway.app';
  // JWT signed with JWT_SECRET=35445065cfe5c59681d9f72f4b6f3549f6132ebf05cde5572f9426200894003f
  // Payload: {"sub":"second-brain-app","iat":1778880250}
  // If you rotate JWT_SECRET on the server, regenerate this token to match.
  static const _kDefaultToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzZWNvbmQtYnJhaW4tYXBwIiwiaWF0IjoxNzc4ODgwMjUwfQ.fG7Y-NP4XDUjO4lI6dnUn0kYgHYSxAQeQz3S5DdGwzY';

  String? _baseUrl;
  String? _token;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // URL + token are both hardcoded — wipe any stored values so old
    // mismatched JWTs on a user's device can't override the fresh one.
    _baseUrl = _kServerBaseUrl;
    _token = _kDefaultToken;
    try {
      await _storage.delete(key: _baseUrlKey);
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
    _initialized = true;
  }

  /// Token can still be overridden per device. URL changes are no-ops.
  Future<void> configure({required String baseUrl, required String token}) async {
    // baseUrl param kept for API compatibility — ignored. URL is hardcoded.
    _token = token;
    await _storage.write(key: _tokenKey, value: _token);
  }

  bool get isConfigured => _baseUrl != null && _token != null;
  String? get savedBaseUrl => _baseUrl;

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

  // ── Health Check ───────────────────────────────────────────────────────────

  Future<bool> ping() async {
    if (!isConfigured) return false;
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
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
    if (!isConfigured) {
      return (ok: false, latencyMs: null, error: 'Nicht konfiguriert');
    }
    final sw = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
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
        'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>?> _get(String path) async {
    if (!isConfigured) return null;
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl$path'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('ApiService GET $path → ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ApiService GET $path error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _put(String path, Map<String, dynamic> body) async {
    if (!isConfigured) return null;
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('ApiService PUT $path → ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ApiService PUT $path error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _delete(String path, Map<String, dynamic> body) async {
    if (!isConfigured) return null;
    try {
      final request = http.Request('DELETE', Uri.parse('$_baseUrl$path'))
        ..headers.addAll(_headers)
        ..body = jsonEncode(body);
      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('ApiService DELETE $path → ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ApiService DELETE $path error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    if (!isConfigured) return null;
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
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
