/// Pure dashboard-helper functions. State-free so they can be unit-tested
/// without pumping a widget tree.
library;

import '../models/note_model.dart';

/// One-line status condensed from due reminders + inbox count.
///
/// Returns `null` when nothing's worth showing — the hero then stays
/// minimal. Reminders outrank inbox; both zero → null.
String? statusLine({required int dueReminders, required int inboxCount}) {
  if (dueReminders > 0) {
    return '$dueReminders ${dueReminders == 1 ? "Erinnerung wartet" : "Erinnerungen warten"}';
  }
  if (inboxCount > 0) {
    return '$inboxCount ${inboxCount == 1 ? "Gedanke wartet" : "Gedanken warten"} auf Sortierung';
  }
  return null;
}

/// Picks one note from 7–35 days ago to "resurface". Stable per day
/// (seeded by day-of-year) so the dashboard doesn't flicker on rebuild.
///
/// Returns `null` when nothing in that age window exists. `now` is
/// injectable so tests can pin a date.
Note? resurfacedNote(List<Note> notes, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final candidates = notes.where((n) {
    final age = t.difference(n.created).inDays;
    return age >= 7 && age <= 35;
  }).toList();
  if (candidates.isEmpty) return null;
  final dayOfYear = t.difference(DateTime(t.year)).inDays;
  return candidates[dayOfYear % candidates.length];
}
