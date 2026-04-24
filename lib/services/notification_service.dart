import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import 'cache_service.dart';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Manages browser push notifications for due reminders.
///
/// - Uses the Web Notifications API (dart:html) — no-op on non-web.
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
    if (!kIsWeb) return 'denied';
    try {
      return html.Notification.permission ?? 'default';
    } catch (_) {
      return 'denied';
    }
  }

  bool get isGranted => permissionState == 'granted';

  bool get isSupported {
    if (!kIsWeb) return false;
    try {
      return html.Notification.supported;
    } catch (_) {
      return false;
    }
  }

  /// Asks the browser for notification permission.
  /// Returns true if the user grants it.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      final result = await html.Notification.requestPermission();
      return result == 'granted';
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

  void _showNotification({required String title, required String body}) {
    try {
      html.Notification(
        title,
        body: body,
        icon: 'icons/Icon-192.png',
      );
    } catch (_) {}
  }
}
