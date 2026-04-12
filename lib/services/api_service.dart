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

  // Test-phase fallbacks — used when no credentials are stored (e.g. fresh browser)
  static const _kDefaultBaseUrl = 'https://second-brain-app-production-dcee.up.railway.app';
  static const _kDefaultToken   = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzZWNvbmQtYnJhaW4tYXBwIiwiaWF0IjoxNzc0ODk5MTI1fQ.qAleBCkMXmNO7UVZ1kQEFyxzfsOfZEWmYq08zhXhVL4';

  String? _baseUrl;
  String? _token;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _baseUrl = await _storage.read(key: _baseUrlKey) ?? _kDefaultBaseUrl;
    _token   = await _storage.read(key: _tokenKey)   ?? _kDefaultToken;
    _initialized = true;
  }

  Future<void> configure({required String baseUrl, required String token}) async {
    var url = baseUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _token = token;
    await _storage.write(key: _baseUrlKey, value: _baseUrl);
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
    });
    if (body == null) return null;
    return body['file_path'] as String?;
  }

  /// Delete a note on the server. Returns true on success.
  Future<bool> deleteVaultNote(String filePath) async {
    final body = await _delete('/vault/notes', {'file_path': filePath});
    return body != null;
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
