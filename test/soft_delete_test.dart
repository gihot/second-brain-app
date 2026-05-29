/// J2 (Plan v2): Tests für Soft-Clear + Recovery + Prune.
///
/// Beweist dass „Cache leeren" nicht mehr sofort unwiderruflich ist:
/// Notizen bleiben 30 Tage wiederherstellbar, danach physischer Prune.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/models/note_model.dart';
import 'package:second_brain/services/cache_service.dart';

import 'test_utils.dart';

Note _note(String id, {String? deletedAt}) {
  final t = DateTime(2026, 1, 1);
  return Note(
    id: id,
    title: 'Note $id',
    content: 'body $id',
    created: t,
    modified: t,
    status: NoteStatus.inbox,
    para: ParaCategory.inbox,
    deletedAt: deletedAt,
  );
}

void main() {
  late InMemoryHiveHandle handle;

  setUp(() async {
    handle = await inMemoryHive();
    await CacheService.instance.init('test-user');
  });

  tearDown(() async {
    await handle.dispose();
  });

  test('softDeleteAllNotes versteckt Notizen aus getAllNotes', () async {
    final cache = CacheService.instance;
    await cache.saveNote(_note('a'));
    await cache.saveNote(_note('b'));
    expect(cache.getAllNotes().length, 2);

    await cache.softDeleteAllNotes();

    expect(cache.getAllNotes(), isEmpty);
    expect(cache.getSoftDeletedNotes().length, 2);
  });

  test('restoreSoftDeleted bringt eine Notiz zurück', () async {
    final cache = CacheService.instance;
    await cache.saveNote(_note('a'));
    await cache.softDeleteAllNotes();
    expect(cache.getAllNotes(), isEmpty);

    await cache.restoreSoftDeleted('a');

    expect(cache.getAllNotes().length, 1);
    expect(cache.getSoftDeletedNotes(), isEmpty);
    expect(cache.getNoteById('a')?.deletedAt, isNull);
  });

  test('Soft-Delete hält 30 Tage, dann prune', () async {
    final cache = CacheService.instance;
    // Frisch gelöscht (jetzt) — überlebt den Prune.
    await cache.saveNote(_note('fresh', deletedAt: DateTime.now().toIso8601String()));
    // Vor 31 Tagen gelöscht — wird gepruned.
    final old = DateTime.now().subtract(const Duration(days: 31));
    await cache.saveNote(_note('old', deletedAt: old.toIso8601String()));

    final removed =
        await cache.pruneSoftDeletedOlderThan(const Duration(days: 30));

    expect(removed, 1);
    expect(cache.getNoteById('old'), isNull); // physisch weg
    expect(cache.getNoteById('fresh'), isNotNull); // bleibt
  });

  test('Prune lässt live Notizen unangetastet', () async {
    final cache = CacheService.instance;
    await cache.saveNote(_note('live'));
    final removed =
        await cache.pruneSoftDeletedOlderThan(const Duration(days: 30));
    expect(removed, 0);
    expect(cache.getAllNotes().length, 1);
  });

  test('getInboxNotes + searchNotes schließen soft-deleted aus', () async {
    final cache = CacheService.instance;
    await cache.saveNote(_note('a'));
    await cache.softDeleteAllNotes();

    expect(cache.getInboxNotes(), isEmpty);
    expect(cache.searchNotes('Note'), isEmpty);
  });
}
