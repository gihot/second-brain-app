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

  AuthStatus _status = AuthStatus.loading;
  AuthSession? _session;
  String? _loginError;

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
      _session = AuthSession.fromUserMap(me, token);
      notifyListeners();
    }
  }

  /// Boot-time: persistierten Token lesen, Session provisorisch setzen
  /// (damit tokenProvider sofort liefert), via GET /auth/me verifizieren.
  /// Jeder Fehler (kein Token, expired, unknown user) → logged out.
  ///
  /// Öffnet bei Erfolg den per-User-Hive-Cache **vor** dem Flip auf
  /// `loggedIn`, damit die AppShell nie einen stale (other-user) Cache
  /// sieht.
  Future<void> init() async {
    // tokenProvider + 401-callback zuerst verdrahten, damit jeder
    // Request den aktuellen Session-Token liest.
    _api.tokenProvider = () => _session?.token;
    _api.onUnauthorized = _onUnauthorized;
    await _api.init();

    final token = await _api.readPersistedToken();
    if (token == null || token.isEmpty) {
      _setStatus(AuthStatus.loggedOut);
      return;
    }
    // Provisorische Session — nur der Token zählt für die /me-Verifikation.
    _session = AuthSession(id: '', email: '', token: token);

    final me = await _api.getMe();
    if (me == null) {
      // Token invalid / server unreachable → logged-out.
      _session = null;
      await _api.clearPersistedToken();
      _setStatus(AuthStatus.loggedOut);
      return;
    }
    _session = AuthSession.fromUserMap(me, token);
    await CacheService.instance.init(_session!.id);
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
    _session = session;
    await CacheService.instance.init(session.id);
    _setStatus(AuthStatus.loggedIn);
    return true;
  }

  Future<void> logout() async {
    // Close the cache BEFORE flipping state so any post-logout rebuild
    // sees a closed cache rather than the just-logged-out user's data.
    await CacheService.instance.close();
    await _api.clearPersistedToken();
    _session = null;
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
