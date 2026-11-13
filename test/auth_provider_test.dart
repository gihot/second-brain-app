/// J5 (Plan v2): Tests für die Single-Source-of-Truth-Auth.
///
/// Kernaussage: ApiService hält keinen eigenen Token — der tokenProvider
/// liest immer aus der AuthSession des AuthProviders. Login setzt sie,
/// Logout räumt sie, ApiService.hasToken folgt automatisch.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/providers/auth_provider.dart';
import 'package:second_brain/services/cache_service.dart';

import 'test_utils.dart';

void main() {
  late InMemoryHiveHandle handle;

  setUp(() async {
    handle = await inMemoryHive();
  });

  tearDown(() async {
    await handle.dispose();
  });

  test('init verdrahtet tokenProvider — ApiService liest aus der Session',
      () async {
    final api = FakeApiService();
    final auth = AuthProvider(api: api);
    // Vor Login: kein Token
    await auth.init();
    expect(api.hasToken, isFalse);
    expect(api.tokenProvider, isNotNull); // wurde verdrahtet
  });

  test('login setzt die Session → ApiService.hasToken wird true', () async {
    final api = FakeApiService()
      ..authUser = const {'id': 'u1', 'email': 'u1@test.de'}
      ..authToken = 'tok-123';
    final auth = AuthProvider(api: api);
    await auth.init(); // tokenProvider verdrahten

    final ok = await auth.login('u1@test.de', 'pw');

    expect(ok, isTrue);
    expect(auth.isLoggedIn, isTrue);
    expect(auth.email, 'u1@test.de');
    // Single Source: ApiService liest den Token aus der Session
    expect(api.tokenProvider!(), 'tok-123');
    expect(api.hasToken, isTrue);
  });

  test('logout räumt die Session → ApiService.hasToken wird false',
      () async {
    final api = FakeApiService()..authToken = 'tok-123';
    final auth = AuthProvider(api: api);
    await auth.init();
    await auth.login('u1@test.de', 'pw');
    expect(api.hasToken, isTrue);

    await auth.logout();

    expect(auth.isLoggedIn, isFalse);
    expect(api.tokenProvider!(), isNull);
    expect(api.hasToken, isFalse);
    expect(api.persistedToken, isNull); // auch aus Storage geräumt
  });

  test('completeSignup flippt in einem Call auf loggedIn', () async {
    final api = FakeApiService();
    final auth = AuthProvider(api: api);
    await auth.init();

    final ok = await auth.completeSignup(
      const {'id': 'u2', 'email': 'neu@test.de'},
      'signup-token',
    );

    expect(ok, isTrue);
    expect(auth.isLoggedIn, isTrue);
    expect(auth.email, 'neu@test.de');
    expect(api.tokenProvider!(), 'signup-token');
    // Cache wurde für den neuen User geöffnet
    expect(CacheService.instance.isReadyFor('u2'), isTrue);
  });

  test('login-Fehler setzt keine Session', () async {
    final api = FakeApiService()..authError = 'E-Mail oder Passwort falsch.';
    final auth = AuthProvider(api: api);
    await auth.init();

    final ok = await auth.login('x@y.de', 'wrong');

    expect(ok, isFalse);
    expect(auth.isLoggedIn, isFalse);
    expect(auth.loginError, 'E-Mail oder Passwort falsch.');
    expect(api.hasToken, isFalse);
  });

  test('boot mit persistiertem Token + gültigem /me → loggedIn', () async {
    final api = FakeApiService()
      ..persistedToken = 'stored-tok'
      ..meResponse = const {'id': 'u1', 'email': 'u1@test.de'};
    final auth = AuthProvider(api: api);

    await auth.init();

    expect(auth.isLoggedIn, isTrue);
    expect(api.tokenProvider!(), 'stored-tok');
  });

  test('boot mit persistiertem Token aber /me=null → loggedOut + Storage geräumt',
      () async {
    final api = FakeApiService()
      ..persistedToken = 'stale-tok'
      ..meResponse = null; // 401 / expired
    final auth = AuthProvider(api: api);

    await auth.init();

    expect(auth.isLoggedIn, isFalse);
    expect(api.persistedToken, isNull);
  });

  test('verbundener Vault öffnet sich auch beim Offline-Start', () async {
    final api = FakeApiService()
      ..persistedToken = 'stored-token'
      ..rememberedProfile = {'id': 'u1', 'email': 'u1@test.de'};
    final auth = AuthProvider(api: api);

    await auth.init();

    expect(auth.isLoggedIn, isTrue);
    expect(CacheService.instance.isReadyFor('u1'), isTrue);
    expect(api.persistedToken, 'stored-token');
  });

  test('pendingDeletionAt kommt aus der Session', () async {
    final api = FakeApiService()
      ..persistedToken = 'tok'
      ..meResponse = const {
        'id': 'u1',
        'email': 'u1@test.de',
        'pending_deletion_at': '2026-07-01T00:00:00Z',
      };
    final auth = AuthProvider(api: api);
    await auth.init();
    expect(auth.isPendingDeletion, isTrue);
    expect(auth.pendingDeletionAt, '2026-07-01T00:00:00Z');
  });
}
