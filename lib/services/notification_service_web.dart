import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../models/note_model.dart';
import 'api_service.dart';
import 'cache_service.dart';

// ── JS-Bindings für die window.sbPush-Helper aus web/index.html ──────────────

@JS('sbPush')
external _SbPush? get _sbPush;

extension type _SbPush._(JSObject _) implements JSObject {
  external bool isSupported();
  external String permission();
  external JSPromise<JSString> requestPermission();
  external JSPromise<JSString> subscribe(String vapidPublicKey);
  external JSPromise<JSAny?> getExisting();
  external JSPromise<JSAny?> unsubscribe();
}

/// Web Push (Notifications Phase 1).
///
/// Echte, server-getriebene Notifications: Subscription via Service-
/// Worker, Zustellung durch den Server (auch bei geschlossener App).
/// Ersetzt die alte client-only web.Notification, die nur bei offenem
/// Tab feuerte. `checkAndNotify` bleibt als Sofort-Fallback bei offenem
/// Tab erhalten (zeigt fällige Reminder ohne auf den ~10-Min-Cron zu
/// warten).
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final Set<String> _notifiedIds = {};

  Future<void> init() async {
    if (!kIsWeb) return;
    _notifiedIds.addAll(CacheService.instance.getNotifiedReminderIds());
  }

  // ── Permission / Support ───────────────────────────────────────────────────

  String get permissionState {
    if (!kIsWeb) return 'denied';
    try {
      return _sbPush?.permission() ?? 'denied';
    } catch (_) {
      return 'denied';
    }
  }

  bool get isGranted => permissionState == 'granted';

  bool get isSupported {
    if (!kIsWeb) return false;
    try {
      return _sbPush?.isSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Enable / Disable (Pref) ─────────────────────────────────────────────────

  bool get notificationsEnabled => CacheService.instance.notificationsEnabled;

  void setEnabled(bool value) =>
      CacheService.instance.setNotificationsEnabled(value);

  /// Legacy-Permission-Request (Settings-Toggle ruft das). Für echtes
  /// Push danach [enablePush] aufrufen.
  Future<bool> requestPermission() async {
    final sb = _sbPush;
    if (sb == null) return false;
    try {
      final result = (await sb.requestPermission().toDart).toDart;
      return result == 'granted';
    } catch (_) {
      return false;
    }
  }

  // ── Web Push: Subscribe / Unsubscribe / Test ────────────────────────────────

  /// Voller Aktivierungs-Flow: Permission anfragen → VAPID-Key holen →
  /// Service-Worker-Subscription → an Server schicken. Returns
  /// (ok, error) — error ist ein UI-tauglicher Grund bei Misserfolg.
  Future<({bool ok, String? error})> enablePush() async {
    if (!isSupported) {
      return (ok: false, error: 'Dieses Gerät/Browser unterstützt keine Push-Notifications.');
    }
    final sb = _sbPush;
    if (sb == null) {
      return (ok: false, error: 'Push-Helfer nicht geladen.');
    }

    // 1. Permission
    final granted = await requestPermission();
    if (!granted) {
      return (ok: false, error: 'Benachrichtigungen wurden nicht erlaubt.');
    }

    // 2. VAPID-Key vom Server
    final vapidKey = await ApiService.instance.getVapidPublicKey();
    if (vapidKey == null || vapidKey.isEmpty) {
      return (ok: false, error: 'Push ist serverseitig nicht konfiguriert.');
    }

    // 3. Service-Worker-Subscription
    final String subJson;
    try {
      subJson = (await sb.subscribe(vapidKey).toDart).toDart;
    } catch (e) {
      return (ok: false, error: 'Subscription fehlgeschlagen: $e');
    }

    // 4. An Server schicken
    final parsed = _parseSubscription(subJson);
    if (parsed == null) {
      return (ok: false, error: 'Subscription-Format unerwartet.');
    }
    final ok = await ApiService.instance
        .subscribePush(parsed.endpoint, parsed.keys);
    if (!ok) {
      return (ok: false, error: 'Server hat die Subscription abgelehnt.');
    }

    setEnabled(true);
    return (ok: true, error: null);
  }

  /// Deaktiviert Push: Browser-Unsubscribe + Server-Cleanup + Pref off.
  Future<void> disablePush() async {
    setEnabled(false);
    final sb = _sbPush;
    if (sb == null) return;
    try {
      final endpoint = (await sb.unsubscribe().toDart);
      if (endpoint != null && endpoint.isA<JSString>()) {
        await ApiService.instance
            .unsubscribePush((endpoint as JSString).toDart);
      }
    } catch (_) {
      // best-effort
    }
  }

  /// Test-Push über den Server an alle eigenen Geräte. Returns Anzahl.
  Future<int> sendTest() => ApiService.instance.testPush();

  ({String endpoint, Map<String, dynamic> keys})? _parseSubscription(
      String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final endpoint = map['endpoint'] as String?;
      final keys = (map['keys'] as Map?)?.cast<String, dynamic>();
      if (endpoint == null || keys == null) return null;
      return (endpoint: endpoint, keys: keys);
    } catch (_) {
      return null;
    }
  }

  // ── In-App-Sofort-Fallback (Tab offen) ──────────────────────────────────────

  /// Zeigt fällige Reminder sofort, wenn der Tab offen ist — ergänzt den
  /// Server-Push (der bei geschlossener App greift, aber bis zu ~10 Min
  /// Cron-Latenz hat).
  Future<void> checkAndNotify(List<Note> dueReminders) async {
    if (!kIsWeb || !isGranted || !notificationsEnabled) return;
    for (final note in dueReminders) {
      if (_notifiedIds.contains(note.id)) continue;
      _notifiedIds.add(note.id);
      CacheService.instance.saveNotifiedReminderIds(_notifiedIds.toList());
      _showNotification(title: '⏰ Erinnerung fällig', body: note.title);
    }
  }

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
