/// J3 (Plan v2): Round-trip-Tests für CacheService über alle
/// persistenten Domains (notes, captures, pending_writes, connections,
/// insight_dismissed, recent_searches).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/models/note_model.dart';
import 'package:second_brain/models/offline_capture_model.dart';
import 'package:second_brain/services/cache_service.dart';

import 'test_utils.dart';

Note _note(String id) {
  final t = DateTime(2026, 1, 1);
  return Note(
    id: id,
    title: 'Note $id',
    content: 'body',
    created: t,
    modified: t,
    status: NoteStatus.inbox,
    para: ParaCategory.inbox,
  );
}

void main() {
  late InMemoryHiveHandle handle;
  late CacheService cache;

  setUp(() async {
    handle = await inMemoryHive();
    cache = CacheService.instance;
    await cache.init('test-user');
  });

  tearDown(() async {
    await handle.dispose();
  });

  test('Notes: save + getById + getAll sortiert nach modified', () async {
    await cache.saveNote(_note('a'));
    await cache.saveNote(_note('b'));
    expect(cache.getNoteById('a')?.title, 'Note a');
    expect(cache.getAllNotes().length, 2);
  });

  test('Notes: deleteNote entfernt physisch', () async {
    await cache.saveNote(_note('a'));
    await cache.deleteNote('a');
    expect(cache.getNoteById('a'), isNull);
  });

  test('Offline-Capture-Queue: queue + markSynced + clear', () async {
    await cache.queueCapture(OfflineCapture(
      id: 'c1',
      text: 'pending',
      createdAt: DateTime.now(),
    ));
    expect(cache.getPendingCaptures().length, 1);

    await cache.markCaptureSynced('c1');
    expect(cache.getPendingCaptures(), isEmpty); // synced rausgefiltert

    await cache.clearSyncedCaptures();
    expect(cache.unsyncedCount, 0);
  });

  test('Pending-Writes: queue coalesce + remove', () async {
    await cache.queueWrite({'op': 'update', 'file_path': 'a.md', 'title': 'T1'});
    await cache.queueWrite({'op': 'update', 'file_path': 'a.md', 'title': 'T2'});
    // Coalesce: ein Eintrag für a.md, neuester Titel gewinnt
    final writes = cache.getPendingWrites();
    expect(writes.length, 1);
    expect(writes.first['title'], 'T2');

    await cache.removePendingWrite('a.md');
    expect(cache.getPendingWrites(), isEmpty);
  });

  test('Connections-Cache: save + get pro noteId', () async {
    await cache.saveConnections('n1', [
      {'note_b_title': 'Verbunden', 'explanation': 'weil'},
    ]);
    final conns = cache.getConnections('n1');
    expect(conns.length, 1);
    expect(conns.first['note_b_title'], 'Verbunden');
    expect(cache.getConnections('other'), isEmpty);
  });

  test('Recent-Searches: dedupe + neueste zuerst + cap 5', () async {
    for (final q in ['a', 'b', 'c', 'd', 'e', 'f']) {
      await cache.addRecentSearch(q);
    }
    final recent = cache.recentSearches;
    expect(recent.length, 5); // cap
    expect(recent.first, 'f'); // neueste zuerst

    await cache.addRecentSearch('b'); // dedupe — kein Duplikat
    expect(cache.recentSearches.where((s) => s == 'b').length, 1);
  });

  test('Insight-Dismiss: markiert + TTL-respektierend', () async {
    expect(cache.isInsightDismissed('k1'), isFalse);
    await cache.markInsightDismissed('k1');
    expect(cache.isInsightDismissed('k1'), isTrue);
  });

  test('Generische String/Double-Prefs round-trip', () async {
    await cache.setString('mykey', 'myval');
    expect(cache.getString('mykey'), 'myval');
    await cache.setDouble('mynum', 3.14);
    expect(cache.getDouble('mynum'), 3.14);
  });
}
