import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../models/note_model.dart';
import 'cache_service.dart';

/// Manages browser push notifications for due reminders.
///
/// - Uses the Web Notifications API (package:web) — no-op on non-web.
/// - Tracks already-notified note IDs to avoid re-firing after page reload.
/// - Enabled/disabled preference stored in Hive meta box.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final Set<String> _notifiedIds = {};

  Future<void> init() async {
    if (!kIsWeb) return;
    _notifiedIds.addAll(CacheService.instance.getNotifiedReminderIds());
  }

  // ── Permission ───────────────────────────────────────────────────────────

  /// 'granted' | 'denied' | 'default'
  String get permissionState {
    if (!kIsWeb || !isSupported) return 'denied';
    try {
      return web.Notification.permission;
    } catch (_) {
      return 'denied';
    }
  }

  bool get isGranted => permissionState == 'granted';

  bool get isSupported {
    if (!kIsWeb) return false;
    try {
      return globalContext.has('Notification');
    } catch (_) {
      return false;
    }
  }

  /// Asks the browser for notification permission.
  /// Returns true if the user grants it.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      final result =
          await web.Notification.requestPermission().toDart;
      return result.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  // ── Enable / Disable toggle ──────────────────────────────────────────────

  bool get notificationsEnabled => CacheService.instance.notificationsEnabled;

  void setEnabled(bool value) =>
      CacheService.instance.setNotificationsEnabled(value);

  // ── Notify ───────────────────────────────────────────────────────────────

  /// Shows a browser notification for each due reminder that hasn't been
  /// notified yet in this session (or persisted across reloads).
  Future<void> checkAndNotify(List<Note> dueReminders) async {
    if (!kIsWeb || !isGranted || !notificationsEnabled) return;
    for (final note in dueReminders) {
      if (_notifiedIds.contains(note.id)) continue;
      _notifiedIds.add(note.id);
      CacheService.instance.saveNotifiedReminderIds(_notifiedIds.toList());
      _showNotification(
        title: '⏰ Erinnerung fällig',
        body: note.title,
      );
    }
  }

  /// Removes any [_notifiedIds] entry for reminders whose [remindAt] still
  /// lies in the future. Heals the legacy bug where future reminders were
  /// wrongly flagged as due and "notified" immediately — those should fire
  /// again when their actual time arrives.
  void prunePrematureNotifications(List<Note> allNotes) {
    if (_notifiedIds.isEmpty) return;
    final now = DateTime.now();
    final stillFuture = <String>{};
    for (final n in allNotes) {
      if (n.thoughtType != ThoughtType.reminder) continue;
      if (n.remindAt == null) continue;
      if (!_notifiedIds.contains(n.id)) continue;
      final dt = DateTime.tryParse(n.remindAt!);
      if (dt != null && dt.isAfter(now)) stillFuture.add(n.id);
    }
    if (stillFuture.isEmpty) return;
    _notifiedIds.removeAll(stillFuture);
    CacheService.instance.saveNotifiedReminderIds(_notifiedIds.toList());
  }

  void _showNotification({required String title, required String body}) {
    try {
      web.Notification(
        title,
        web.NotificationOptions(body: body, icon: 'icons/Icon-192.png'),
      );
    } catch (_) {}
  }
}
