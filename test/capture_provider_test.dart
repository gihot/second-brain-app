/// J3 (Plan v2): Tests für CaptureProvider — Success / Offline / Queue.
///
/// Nutzt FakeApiService + inMemoryHive aus dem J1-Rahmen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/models/note_model.dart';
import 'package:second_brain/services/cache_service.dart';

import 'test_utils.dart';

void main() {
  late InMemoryHiveHandle handle;

  setUp(() async {
    handle = await inMemoryHive();
    await CacheService.instance.init('test-user');
  });

  tearDown(() async {
    await handle.dispose();
  });

  test('capture mit erreichbarem Server reichert die lokale Notiz an',
      () async {
    final api = FakeApiService()
      ..captureResponse = const CaptureResult(
        noteId: 'ignored', // capture() generiert eigene UUID
        title: 'Angereicherter Titel',
        tags: ['ai', 'tag'],
        filePath: '00-Inbox/note.md',
        para: '00-Inbox',
        hall: MemoryHall.discovery,
      );
    final providers = await buildProviders(api: api, initCache: false);

    final ok = await providers.capture.capture('roher gedanke');

    expect(ok, isTrue);
    expect(api.capturedTexts, contains('roher gedanke'));
    // Lokale Notiz wurde mit Server-Enrichment aktualisiert
    final notes = providers.vault.notes;
    expect(notes.length, 1);
    expect(notes.first.title, 'Angereicherter Titel');
    expect(notes.first.tags, ['ai', 'tag']);
    expect(notes.first.filePath, '00-Inbox/note.md');
  });

  test('capture offline erstellt lokale Notiz + queued für Sync', () async {
    final api = FakeApiService()..captureResponse = null; // Server down
    final providers = await buildProviders(api: api, initCache: false);

    final ok = await providers.capture.capture('offline gedanke');

    expect(ok, isTrue); // lokal immer erfolgreich
    expect(providers.vault.notes.length, 1);
    // Roh-Titel (kein AI-Enrichment), generiert aus erstem Text
    expect(providers.vault.notes.first.title, 'offline gedanke');
    // In der Offline-Queue für späteren Sync
    expect(CacheService.instance.getPendingCaptures().length, 1);
  });

  test('leerer Text wird abgelehnt', () async {
    final providers = await buildProviders(initCache: false);
    final ok = await providers.capture.capture('   ');
    expect(ok, isFalse);
    expect(providers.vault.notes, isEmpty);
  });

  test('similarNotes aus der Server-Antwort landen im Provider', () async {
    final api = FakeApiService()
      ..captureResponse = const CaptureResult(
        noteId: 'x',
        title: 'T',
        tags: [],
        filePath: 'x.md',
        para: '00-Inbox',
        similarNotes: [
          CaptureSimilar(noteId: 'old1', title: 'Alt 1', similarity: 0.9),
          CaptureSimilar(noteId: 'old2', title: 'Alt 2', similarity: 0.8),
        ],
      );
    final providers = await buildProviders(api: api, initCache: false);

    await providers.capture.capture('neuer gedanke');

    expect(providers.capture.lastSimilarNotes.length, 2);
    expect(providers.capture.lastSimilarNotes.first.noteId, 'old1');
  });
}
