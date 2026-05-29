/// J2 (Plan v2): Tests für die Conflict-Vergleichslogik.
///
/// Der ursprüngliche Bug: Status-/Para-/Hall-/Wing-/ThoughtType-/RemindAt-
/// Änderungen wurden ignoriert → lokale Aktionen (z.B. Archivieren)
/// wurden beim Sync silently überschrieben.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/models/note_model.dart';
import 'package:second_brain/utils/note_diff.dart';

Note _base() {
  final t = DateTime(2026, 1, 1);
  return Note(
    id: 'n1',
    title: 'Titel',
    content: 'Body',
    tags: const ['a', 'b'],
    created: t,
    modified: t,
    status: NoteStatus.inbox,
    para: ParaCategory.inbox,
    hall: MemoryHall.discovery,
    wing: 'urban-arcanum',
    thoughtType: ThoughtType.standard,
  );
}

void main() {
  group('notesEffectivelyEqual', () {
    test('identische Notizen sind gleich', () {
      expect(notesEffectivelyEqual(_base(), _base()), isTrue);
    });

    test('Status-Änderung (archive) ist ein Konflikt', () {
      final archived = _base().copyWith(status: NoteStatus.archived);
      expect(notesEffectivelyEqual(_base(), archived), isFalse);
    });

    test('Para-Änderung ist ein Konflikt', () {
      final moved = _base().copyWith(para: ParaCategory.projects);
      expect(notesEffectivelyEqual(_base(), moved), isFalse);
    });

    test('Hall-Änderung ist ein Konflikt', () {
      final reclassified = _base().copyWith(hall: MemoryHall.fact);
      expect(notesEffectivelyEqual(_base(), reclassified), isFalse);
    });

    test('Wing-Änderung ist ein Konflikt', () {
      final rewinged = _base().copyWith(wing: 'health-journey');
      expect(notesEffectivelyEqual(_base(), rewinged), isFalse);
    });

    test('Wing entfernt ist ein Konflikt', () {
      final dewinged = _base().copyWith(clearWing: true);
      expect(notesEffectivelyEqual(_base(), dewinged), isFalse);
    });

    test('ThoughtType-Änderung ist ein Konflikt', () {
      final reminder = _base().copyWith(thoughtType: ThoughtType.reminder);
      expect(notesEffectivelyEqual(_base(), reminder), isFalse);
    });

    test('RemindAt-Änderung ist ein Konflikt', () {
      final reminded =
          _base().copyWith(remindAt: '2026-02-01T09:00:00Z');
      expect(notesEffectivelyEqual(_base(), reminded), isFalse);
    });

    test('Title-Änderung ist ein Konflikt', () {
      final retitled = _base().copyWith(title: 'Anders');
      expect(notesEffectivelyEqual(_base(), retitled), isFalse);
    });

    test('Body-Änderung ist ein Konflikt', () {
      final rewritten = _base().copyWith(content: 'Neuer Body');
      expect(notesEffectivelyEqual(_base(), rewritten), isFalse);
    });

    test('Tag-Änderung ist ein Konflikt', () {
      final retagged = _base().copyWith(tags: const ['a', 'c']);
      expect(notesEffectivelyEqual(_base(), retagged), isFalse);
    });

    test('deletedAt wird NICHT verglichen (client-only)', () {
      final softDeleted =
          _base().copyWith(deletedAt: DateTime.now().toIso8601String());
      expect(notesEffectivelyEqual(_base(), softDeleted), isTrue);
    });

    test('Whitespace-Unterschiede in title/content werden ignoriert', () {
      final padded = _base().copyWith(title: '  Titel  ', content: 'Body\n');
      expect(notesEffectivelyEqual(_base(), padded), isTrue);
    });
  });
}
