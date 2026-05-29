/// J1 (Plan v2) — Test-Rahmen für Client-Tests.
///
/// Drei Bausteine:
///   - `FakeApiService` — implements ApiService, programmierbare
///     Antworten. Methoden die der Test nicht setzt: null/`{}`/leer.
///   - `inMemoryHive()` — Hive-Init mit temp-Dir-Backing + alle
///     Adapter, ohne path_provider (nicht verfügbar in `flutter test`).
///   - `buildProviders(...)` — komponiert AuthProvider + VaultProvider
///     + CaptureProvider mit injizierten Fakes.
///
/// Nichts hier macht echte HTTP- oder Cloud-Calls. Tests die LLM-Pfade
/// brauchen, mocken die Server-Seite über `server/tests/conftest.py`.
import 'dart:io';

import 'package:hive/hive.dart';

import 'package:second_brain/models/note_model.dart';
import 'package:second_brain/models/offline_capture_model.dart';
import 'package:second_brain/providers/auth_provider.dart';
import 'package:second_brain/providers/capture_provider.dart';
import 'package:second_brain/providers/vault_provider.dart';
import 'package:second_brain/services/api_service.dart';
import 'package:second_brain/services/cache_service.dart';

// Re-export für Tests, damit sie nicht api_service.dart separat
// importieren müssen.
export 'package:second_brain/services/api_service.dart'
    show ApiService, CaptureResult, CaptureSimilar;

// ── FakeApiService ──────────────────────────────────────────────────────────

/// Implements ApiService via `noSuchMethod`. Tests setzen die Felder
/// die sie brauchen; der Rest no-op't (returnt null).
///
/// Beispiel:
/// ```dart
/// final api = FakeApiService()
///   ..captureResponse = CaptureResult(noteId: 'x', title: 'T', tags: [],
///       filePath: 'a.md', para: '00-Inbox');
/// ```
class FakeApiService implements ApiService {
  // ── Programmierbare Antworten ──

  /// Antwort für `capture()`. Null = simuliert Offline/Server-Down.
  CaptureResult? captureResponse;

  /// Antwort für `getVaultNotes()`. Null = transport failure.
  List<Map<String, dynamic>>? vaultNotesResponse;

  /// Antwort für `getVaultStatus()`. Null = transport failure.
  Map<String, dynamic>? vaultStatusResponse;

  /// Antwort für `getMe()`. Null = 401 / transport failure.
  Map<String, dynamic>? meResponse;

  /// `ping()` Resultat.
  bool pingResponse = true;

  /// `updateNote()` returnt `file_path` bei Erfolg, null bei Fehler.
  String? updateNoteResponse = 'returned-file-path.md';

  /// `deleteVaultNote()` Erfolg.
  bool deleteResponse = true;

  /// Aufgezeichnete Aufrufe — für Assertions im Test.
  final List<String> capturedTexts = [];
  final List<String> updatedFilePaths = [];
  final List<String> deletedFilePaths = [];

  // ── ApiService-Surface ──

  @override
  Future<void> init() async {}

  @override
  bool get hasToken => meResponse != null;

  @override
  Future<void> setToken(String token) async {}

  @override
  Future<void> clearToken() async {}

  @override
  String get baseUrl => 'http://test.invalid';

  @override
  void Function()? onUnauthorized;

  @override
  Future<CaptureResult?> capture(String text, {String? noteId}) async {
    capturedTexts.add(text);
    return captureResponse;
  }

  @override
  Future<List<Map<String, dynamic>>?> getVaultNotes({int limit = 200}) async {
    return vaultNotesResponse;
  }

  @override
  Future<Map<String, dynamic>?> getVaultStatus() async {
    return vaultStatusResponse;
  }

  @override
  Future<Map<String, dynamic>?> getMe() async {
    return meResponse;
  }

  @override
  Future<bool> ping() async {
    return pingResponse;
  }

  @override
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
    updatedFilePaths.add(filePath);
    return updateNoteResponse;
  }

  @override
  Future<bool> deleteVaultNote(String filePath) async {
    deletedFilePaths.add(filePath);
    return deleteResponse;
  }

  /// Alles andere → null. Tests die einen ungesetzten Endpoint
  /// triggern, bekommen null zurück (= Offline / unbekannte Antwort).
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── inMemoryHive ────────────────────────────────────────────────────────────

/// Setzt Hive auf eine frische Temp-Directory auf, registriert alle
/// Adapter, markiert CacheService als initialisiert. Returns ein Handle
/// mit Teardown-Hook.
///
/// Aufruf:
/// ```dart
/// final h = await inMemoryHive();
/// await CacheService.instance.init('test-user');
/// // ... Test ...
/// await h.dispose();
/// ```
class InMemoryHiveHandle {
  final Directory _dir;
  InMemoryHiveHandle._(this._dir);

  Future<void> dispose() async {
    await Hive.close();
    CacheService.resetForTesting();
    try {
      if (_dir.existsSync()) _dir.deleteSync(recursive: true);
    } catch (_) {
      // Temp dir cleanup ist best-effort.
    }
  }
}

Future<InMemoryHiveHandle> inMemoryHive() async {
  // Frische, unique Temp-Dir pro Test
  final dir = Directory.systemTemp.createTempSync('sb_test_hive_');
  Hive.init(dir.path);

  // Adapter-Registrierung idempotent — gleiche Guards wie in CacheService
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(NoteAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NoteStatusAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ParaCategoryAdapter());
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(OfflineCaptureAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(MemoryHallAdapter());
  if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(ThoughtTypeAdapter());

  // CacheService.init überspringt `Hive.initFlutter()` jetzt
  CacheService.markHiveInitializedForTesting();

  return InMemoryHiveHandle._(dir);
}

// ── buildProviders ──────────────────────────────────────────────────────────

/// Bundle der drei Haupt-Provider mit injizierten Fakes. Tests bauen
/// sich damit ein vollständiges State-Bundle ohne main.dart-Wiring.
class TestProviders {
  final AuthProvider auth;
  final VaultProvider vault;
  final CaptureProvider capture;
  final FakeApiService api;

  TestProviders({
    required this.auth,
    required this.vault,
    required this.capture,
    required this.api,
  });

  /// dispose nicht selbst — pumpWidget hängt sie an die Tree-Lifecycle.
  /// Für reine Logik-Tests: kein dispose nötig (kein Timer aktiv weil
  /// _checkServerAndSync noch nicht angestoßen wurde).
}

/// Komponiert Provider mit einem [FakeApiService] und der Cache-Singleton
/// (die im Test via [inMemoryHive] vorbereitet wurde). Tests die den
/// Cache nicht brauchen, übergeben einfach einen api+vault+capture-Stack
/// und ignorieren CacheService.
Future<TestProviders> buildProviders({
  FakeApiService? api,
  String userId = 'test-user',
  bool initCache = true,
}) async {
  final fakeApi = api ?? FakeApiService();
  if (initCache) {
    await CacheService.instance.init(userId);
  }
  final auth = AuthProvider(api: fakeApi);
  final vault = VaultProvider(api: fakeApi);
  final capture = CaptureProvider(vault, api: fakeApi);
  return TestProviders(
    auth: auth,
    vault: vault,
    capture: capture,
    api: fakeApi,
  );
}
