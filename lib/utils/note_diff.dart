/// Pure note-comparison helper for sync conflict detection.
///
/// Extracted from VaultProvider (J2, Plan v2) so the conflict logic is
/// unit-testable without pumping a provider + cache + fake-api stack.
/// State-free, same spirit as `dashboard_signals.dart`.
library;

import '../models/note_model.dart';

/// True when two notes are *effectively* the same from the user's point
/// of view — i.e. syncing the [remote] over the [local] would lose no
/// user intent.
///
/// J2 fix: the original implementation compared only title/content/tags,
/// which silently dropped local-only changes to status (archive!), para,
/// hall, wing, thoughtType and remindAt. A note archived locally but
/// unchanged in body on the server was treated as "equal" → the archive
/// was overwritten on the next sync. All user-meaningful fields are now
/// part of the comparison.
///
/// `deletedAt` is intentionally NOT compared — it's client-only soft-
/// delete state that never round-trips through the server.
bool notesEffectivelyEqual(Note a, Note b) {
  return a.title.trim() == b.title.trim() &&
      a.content.trim() == b.content.trim() &&
      _tagsEqual(a.tags, b.tags) &&
      a.status == b.status &&
      a.para == b.para &&
      a.hall == b.hall &&
      (a.wing ?? '') == (b.wing ?? '') &&
      a.thoughtType == b.thoughtType &&
      (a.remindAt ?? '') == (b.remindAt ?? '');
}

bool _tagsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
