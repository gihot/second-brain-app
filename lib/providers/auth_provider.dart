import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

/// Tristate auth status — UI gates on this.
enum AuthStatus { loading, loggedOut, loggedIn }

/// Owns the auth lifecycle: boot-time token check, login, logout.
///
/// J5 (Plan v2): besitzt genau eine [AuthSession] als Single Source of
/// Truth. ApiService hält den Token nicht mehr selbst — es ruft den
/// `tokenProvider`-Callback, den dieser Provider verdrahtet. Damit gibt
/// es physisch nur eine Quelle für „bin ich eingeloggt + mit welchem
/// Token".
class AuthProvider extends ChangeNotifier {
  /// J1 (Plan v2): Constructor-Injection für Tests.
  AuthProvider({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;
  static const _localWorkspace = 'local-device';

  AuthStatus _status = AuthStatus.loading;
  AuthSession? _session;
  String? _loginError;
  bool _rejectedDuringStartup = false;

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  String get email => _session?.email ?? '';
  String? get loginError => _loginError;
  bool get isLoggedIn => _status == AuthStatus.loggedIn;

  /// Plan 4.2: ISO-Timestamp wenn der Account gerade in Pending-
  /// Deletion ist, sonst null. Treibt den roten Dashboard-Banner.
  String? get pendingDeletionAt => _session?.pendingDeletionAt;
  bool get isPendingDeletion => pendingDeletionAt != null;

  /// Aufgerufen vom Banner-„Wiederherstellen"-Tap. Erfolg → /auth/me
  /// neu laden, damit der Banner sofort verschwindet.
  Future<bool> cancelPendingDeletion() async {
    final ok = await _api.cancelDeletion();
    if (!ok) return false;
    await refreshUser();
    return true;
  }

  /// Nach request-/cancel-deletion: /me neu laden, Session aktualisieren.
  Future<void> refreshUser() async {
    final me = await _api.getMe();
    final token = _session?.token;
    if (me != null && token != null) {
      final session = AuthSession.fromUserMap(me, token);
      if (session == null || _session?.token != token) return;
      _session = session;
      await _api.rememberProfile(session);
      notifyListeners();
    }
  }

  Future<void> init() async {
    _api.tokenProvider = () => _session?.token;
    _api.onUnauthorized = _onUnauthorized;
    await _api.init();

    final token = await _api.readPersistedToken();
    if (token != null && token.isNotEmpty) {
      _session = AuthSession(id: '', email: '', token: token);
      final me = await _api.getMe();
      final verified = AuthSession.fromUserMap(
        me ?? (_rejectedDuringStartup ? null : await _api.readRememberedProfile(token)),
        token,
      );
      if (verified != null) {
        await _openSession(verified);
        return;
      }
      _session = null;
      await _api.clearPersistedToken();
    }
    await _openLocalWorkspace();
  }

  Future<void> _openLocalWorkspace() async {
    await CacheService.instance.init(_localWorkspace, migrateLegacy: false);
    _setStatus(AuthStatus.loggedOut);
  }

  Future<void> _openSession(AuthSession session) async {
    await CacheService.instance.init(session.id);
    _session = session;
    await _api.rememberProfile(session);
    _setStatus(AuthStatus.loggedIn);
  }

  Future<bool> login(String email, String password) async {
    _loginError = null;
    notifyListeners();
    final result = await _api.login(email, password);
    if (result.user == null || result.token == null) {
      _loginError = result.error ?? 'Unbekannter Fehler.';
      notifyListeners();
      return false;
    }
    return _completeAuth(result.user!, result.token!);
  }

  /// J5: gemeinsamer Erfolgs-Pfad für login UND signup. Ein einziger
  /// Aufruf statt des früheren refreshUser+init-Tanzes im SignupScreen.
  Future<bool> completeSignup(
      Map<String, dynamic> user, String token) async {
    _loginError = null;
    return _completeAuth(user, token);
  }

  Future<bool> _completeAuth(Map<String, dynamic> user, String token) async {
    final session = AuthSession.fromUserMap(user, token);
    if (session == null) {
      _loginError = 'Ungültige Server-Antwort.';
      notifyListeners();
      return false;
    }
    _setStatus(AuthStatus.loading);
    await _openSession(session);
    return true;
  }

  Future<void> logout() async {
    _session = null;
    _loginError = null;
    _setStatus(AuthStatus.loading);
    await _api.clearPersistedToken();
    await _openLocalWorkspace();
  }

  /// Called by ApiService on any 401 — invoked from anywhere in the app.
  void _onUnauthorized() {
    if (_status == AuthStatus.loading) {
      _rejectedDuringStartup = true;
      return;
    }
    if (_status != AuthStatus.loggedIn) return;
    // Fire and forget — logout() itself does no network I/O.
    logout();
  }

  void _setStatus(AuthStatus s) {
    _status = s;
    notifyListeners();
  }
}
