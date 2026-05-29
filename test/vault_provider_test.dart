/// J2 (Plan v2): Provider-Level-Tests für Conflict-Exposure + Soft-Delete-
/// Durchreichung. Die reine Vergleichslogik ist in note_diff_test.dart,
/// die Cache-Mechanik in soft_delete_test.dart — hier: dass VaultProvider
/// sie korrekt nach außen gibt.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/models/note_model.dart';
import 'package:second_brain/services/cache_service.dart';

import 'test_utils.dart';

Note _note(String id, {String? title, String? filePath, String? deletedAt}) {
  final t = DateTime(2026, 1, 1);
  return Note(
    id: id,
    title: title ?? 'Note $id',
    content: 'body $id',
    created: t,
    modified: t,
    status: NoteStatus.inbox,
    para: ParaCategory.inbox,
    filePath: filePath,
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

  test('conflictCopies exponiert local-only Konflikt-Forks', () async {
    final providers = await buildProviders(initCache: false);
    final cache = CacheService.instance;

    // Normale Notiz mit filePath (kein Konflikt)
    await cache.saveNote(_note('a', filePath: '00-Inbox/a.md'));
    // Konflikt-Fork: local-only + Konflikt-Marker im Titel
    await cache.saveNote(_note('c',
        title: 'Wichtig (Konflikt 5.1. 14:30)', filePath: null));
    providers.vault.reloadFromCache();

    final conflicts = providers.vault.conflictCopies;
    expect(conflicts.length, 1);
    expect(conflicts.first.id, 'c');
  });

  test('conflictCopies ignoriert Notizen mit filePath', () async {
    final providers = await buildProviders(initCache: false);
    // Hätte Konflikt-Marker, ist aber server-backed (filePath gesetzt)
    // → kein local-only Fork.
    await CacheService.instance.saveNote(
      _note('x', title: 'X (Konflikt 1.1.)', filePath: '00-Inbox/x.md'),
    );
    providers.vault.reloadFromCache();
    expect(providers.vault.conflictCopies, isEmpty);
  });

  test('softDeletedCount reflektiert den Cache', () async {
    final providers = await buildProviders(initCache: false);
    await CacheService.instance.saveNote(_note('a'));
    await CacheService.instance.saveNote(
      _note('b', deletedAt: DateTime.now().toIso8601String()),
    );
    providers.vault.reloadFromCache();
    expect(providers.vault.softDeletedCount, 1);
  });

  test('softDeleteAllNotes über Provider versteckt alles', () async {
    final providers = await buildProviders(initCache: false);
    await CacheService.instance.saveNote(_note('a'));
    await CacheService.instance.saveNote(_note('b'));
    providers.vault.reloadFromCache();
    expect(providers.vault.notes.length, 2);

    await providers.vault.softDeleteAllNotes();

    expect(providers.vault.notes, isEmpty);
    expect(providers.vault.softDeletedCount, 2);
  });
}
