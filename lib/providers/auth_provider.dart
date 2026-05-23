import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/cache_service.dart';

/// Tristate auth status — UI gates on this.
enum AuthStatus { loading, loggedOut, loggedIn }

/// Owns the auth lifecycle: boot-time token check, login, logout.
///
/// Wired in [main.dart] as the first provider so the AppShell can gate
/// every downstream provider (Vault, Capture, etc.) on `loggedIn`.
class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;

  AuthStatus _status = AuthStatus.loading;
  Map<String, dynamic>? _user;
  String? _loginError;

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  String get email => (_user?['email'] as String?) ?? '';
  String? get loginError => _loginError;
  bool get isLoggedIn => _status == AuthStatus.loggedIn;

  /// Boot-time: read stored token, verify via GET /auth/me. Any failure
  /// (no token, expired, unknown user) → logged out.
  ///
  /// On success, opens the per-user Hive cache **before** flipping into
  /// `loggedIn` so the AppShell never sees a stale (other-user) cache.
  Future<void> init() async {
    // Wire the 401-callback first so any in-flight request can trigger logout.
    _api.onUnauthorized = _onUnauthorized;
    await _api.init();
    if (!_api.hasToken) {
      _setStatus(AuthStatus.loggedOut);
      return;
    }
    final me = await _api.getMe();
    if (me == null) {
      // Token invalid / server unreachable. Treat as logged-out.
      await _api.clearToken();
      _user = null;
      _setStatus(AuthStatus.loggedOut);
      return;
    }
    await CacheService.instance.init(me['id'] as String);
    _user = me;
    _setStatus(AuthStatus.loggedIn);
  }

  Future<bool> login(String email, String password) async {
    _loginError = null;
    notifyListeners();
    final result = await _api.login(email, password);
    if (result.user == null) {
      _loginError = result.error ?? 'Unbekannter Fehler.';
      notifyListeners();
      return false;
    }
    await CacheService.instance.init(result.user!['id'] as String);
    _user = result.user;
    _setStatus(AuthStatus.loggedIn);
    return true;
  }

  Future<void> logout() async {
    // Close the cache BEFORE flipping state so any post-logout rebuild
    // sees a closed cache rather than the just-logged-out user's data.
    await CacheService.instance.close();
    await _api.clearToken();
    _user = null;
    _loginError = null;
    _setStatus(AuthStatus.loggedOut);
  }

  /// Called by ApiService on any 401 — invoked from anywhere in the app.
  void _onUnauthorized() {
    if (_status == AuthStatus.loggedOut) return; // already there
    // Fire and forget — logout() itself does no network I/O.
    logout();
  }

  void _setStatus(AuthStatus s) {
    _status = s;
    notifyListeners();
  }
}
