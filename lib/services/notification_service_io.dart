/// VM/IO-Stub für NotificationService.
///
/// Browser-Notifications gibt's nur auf Web — auf VM (z.B. in
/// `flutter test`) sind alle Methoden no-ops. Selbe Signatur wie der
/// Web-Impl, damit Production-Code und Test-Code denselben
/// Symbol-Namen verwenden können.
library;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  String get permissionState => 'denied';
  bool get isGranted => false;
  bool get isSupported => false;
  Future<bool> requestPermission() async => false;

  bool get notificationsEnabled => false;
  void setEnabled(bool value) {}

  // Web-Push-Interface — no-ops auf VM/IO.
  Future<({bool ok, String? error})> enablePush() async =>
      (ok: false, error: 'Nur im Browser verfügbar.');
  Future<void> disablePush() async {}
  Future<int> sendTest() async => 0;
  Future<void> refreshSubscription() async {}
}
