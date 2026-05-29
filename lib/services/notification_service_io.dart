/// VM/IO-Stub für NotificationService.
///
/// Browser-Notifications gibt's nur auf Web — auf VM (z.B. in
/// `flutter test`) sind alle Methoden no-ops. Selbe Signatur wie der
/// Web-Impl, damit Production-Code und Test-Code denselben
/// Symbol-Namen verwenden können.
library;

import '../models/note_model.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  Future<void> init() async {}

  String get permissionState => 'denied';
  bool get isGranted => false;
  bool get isSupported => false;
  Future<bool> requestPermission() async => false;

  bool get notificationsEnabled => false;
  void setEnabled(bool value) {}

  Future<void> checkAndNotify(List<Note> dueReminders) async {}
  void prunePrematureNotifications(List<Note> allNotes) {}
}
