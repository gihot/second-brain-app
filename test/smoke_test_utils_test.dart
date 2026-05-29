/// J1-Smoke-Tests für test_utils.dart.
///
/// Die richtigen Tests folgen in J2/J3. Hier nur: bestätigen dass das
/// Rahmenwerk hält.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:second_brain/models/note_model.dart';
import 'package:second_brain/services/cache_service.dart';

import 'test_utils.dart';

void main() {
  group('FakeApiService', () {
    test('default capture returnt null = simuliert Offline', () async {
      final api = FakeApiService();
      final result = await api.capture('hallo');
      expect(result, isNull);
      expect(api.capturedTexts, ['hallo']);
    });

    test('captureResponse programmiert die Antwort', () async {
      final api = FakeApiService()
        ..captureResponse = const CaptureResult(
          noteId: 'n1',
          title: 'Mock',
          tags: ['t'],
          filePath: '00-Inbox/n1.md',
          para: '00-Inbox',
        );
      final result = await api.capture('x');
      expect(result?.noteId, 'n1');
      expect(result?.title, 'Mock');
    });

    test('ungesetzte Getter returnen null via noSuchMethod', () async {
      final api = FakeApiService();
      // hasToken ist überschrieben (gibt false zurück wenn meResponse null)
      expect(api.hasToken, isFalse);
      // Hinweis für J2/J3: Future-returnende ungesetzte Methoden
      // werfen einen Type-Error (Null statt Future). Wenn ein Test
      // sie braucht, ergänze sie als expliziten Override in
      // FakeApiService oder programmiere ihre Response.
    });
  });

  group('inMemoryHive + CacheService', () {
    late InMemoryHiveHandle handle;

    setUp(() async {
      handle = await inMemoryHive();
    });

    tearDown(() async {
      await handle.dispose();
    });

    test('Round-trip einer Note via CacheService', () async {
      await CacheService.instance.init('test-user');
      final now = DateTime.now();
      final note = Note(
        id: 'n1',
        title: 'Hallo Welt',
        content: 'body text',
        created: now,
        modified: now,
        status: NoteStatus.inbox,
        para: ParaCategory.inbox,
      );
      await CacheService.instance.saveNote(note);

      final loaded = CacheService.instance.getNoteById('n1');
      expect(loaded, isNotNull);
      expect(loaded?.title, 'Hallo Welt');
      expect(loaded?.content, 'body text');
    });

    test('Hive ist auf temp-Dir initialisiert, nicht prod', () async {
      // Sanity-check: wir können eine Box direkt öffnen ohne path_provider
      final probe = await Hive.openBox<String>('__test_probe__');
      await probe.put('k', 'v');
      expect(probe.get('k'), 'v');
      await probe.close();
    });
  });

  group('buildProviders', () {
    late InMemoryHiveHandle handle;

    setUp(() async {
      handle = await inMemoryHive();
    });

    tearDown(() async {
      await handle.dispose();
    });

    test('komponiert AuthProvider + VaultProvider + CaptureProvider', () async {
      final providers = await buildProviders();
      expect(providers.auth, isNotNull);
      expect(providers.vault, isNotNull);
      expect(providers.capture, isNotNull);
      expect(providers.api, isA<FakeApiService>());
    });

    test('FakeApiService wird in allen drei Provider durchgereicht', () async {
      final api = FakeApiService()
        ..captureResponse = const CaptureResult(
          noteId: 'n1',
          title: 'From Fake',
          tags: [],
          filePath: 'x.md',
          para: '00-Inbox',
        );
      final providers = await buildProviders(api: api);
      final ok = await providers.capture.capture('hello');
      expect(ok, isTrue);
      expect(api.capturedTexts, contains('hello'));
    });
  });
}
