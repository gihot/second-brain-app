import 'package:flutter_test/flutter_test.dart';

import 'package:second_brain/models/note_model.dart';
import 'package:second_brain/utils/dashboard_signals.dart';

Note _note({required String id, required DateTime created}) => Note(
      id: id,
      title: 'note-$id',
      content: '',
      created: created,
      modified: created,
    );

void main() {
  group('statusLine', () {
    test('reminders > 0 → reminder line wins over inbox', () {
      expect(
        statusLine(dueReminders: 3, inboxCount: 5),
        '3 Erinnerungen warten',
      );
    });

    test('single reminder uses singular', () {
      expect(statusLine(dueReminders: 1, inboxCount: 0),
          '1 Erinnerung wartet');
    });

    test('no reminders, inbox > 0 → inbox line', () {
      expect(
        statusLine(dueReminders: 0, inboxCount: 4),
        '4 Gedanken warten auf Sortierung',
      );
    });

    test('single inbox uses singular', () {
      expect(statusLine(dueReminders: 0, inboxCount: 1),
          '1 Gedanke wartet auf Sortierung');
    });

    test('both zero → null', () {
      expect(statusLine(dueReminders: 0, inboxCount: 0), isNull);
    });
  });

  group('resurfacedNote', () {
    final now = DateTime(2026, 5, 24);

    test('empty list → null', () {
      expect(resurfacedNote([], now: now), isNull);
    });

    test('only fresh notes (<7d) → null', () {
      final notes = [
        _note(id: 'a', created: now.subtract(const Duration(days: 1))),
        _note(id: 'b', created: now.subtract(const Duration(days: 6))),
      ];
      expect(resurfacedNote(notes, now: now), isNull);
    });

    test('only old notes (>35d) → null', () {
      final notes = [
        _note(id: 'c', created: now.subtract(const Duration(days: 60))),
      ];
      expect(resurfacedNote(notes, now: now), isNull);
    });

    test('one in-window candidate → returned', () {
      final candidate =
          _note(id: 'win', created: now.subtract(const Duration(days: 14)));
      final notes = [
        _note(id: 'too-new', created: now.subtract(const Duration(days: 2))),
        candidate,
        _note(id: 'too-old', created: now.subtract(const Duration(days: 60))),
      ];
      expect(resurfacedNote(notes, now: now)?.id, 'win');
    });

    test('multiple candidates: deterministic for the same day', () {
      final candidates = [
        for (var i = 7; i <= 35; i++)
          _note(id: 'd$i', created: now.subtract(Duration(days: i))),
      ];
      final a = resurfacedNote(candidates, now: now);
      final b = resurfacedNote(candidates, now: now);
      expect(a?.id, b?.id);
    });

    test('different days pick different candidates from large pool', () {
      final candidates = [
        for (var i = 7; i <= 35; i++)
          _note(id: 'd$i', created: now.subtract(Duration(days: i))),
      ];
      final today = resurfacedNote(candidates, now: now);
      final tomorrow =
          resurfacedNote(candidates, now: now.add(const Duration(days: 1)));
      // Not strictly guaranteed (modulo collision possible if pool size
      // divides 365 evenly), but with 29 candidates and dayOfYear shifting
      // by 1, picks differ.
      expect(today?.id, isNot(tomorrow?.id));
    });
  });
}
