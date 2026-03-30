import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// HTTP client for the Second Brain Cloud Bridge.
/// All calls fail gracefully — callers should handle null returns as "offline".
class ApiService {
  static ApiService? _instance;
  ApiService._();
  static ApiService get instance => _instance ??= ApiService._();

  static const _storage = FlutterSecureStorage();
  static const _baseUrlKey = 'api_base_url';
  static const _tokenKey = 'api_token';

  String? _baseUrl;
  String? _token;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _baseUrl = await _storage.read(key: _baseUrlKey);
    _token = await _storage.read(key: _tokenKey);
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
    return CaptureResult(
      noteId: body['note_id'] as String,
      title: body['title'] as String,
      tags: List<String>.from(body['tags'] as List),
      filePath: body['file_path'] as String,
      para: body['para'] as String,
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> search(String query) async {
    final body = await _get('/search?q=${Uri.encodeComponent(query)}');
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

  const CaptureResult({
    required this.noteId,
    required this.title,
    required this.tags,
    required this.filePath,
    required this.para,
  });
}
