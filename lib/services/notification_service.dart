/// Conditional-Re-Export für NotificationService.
///
/// Auf Web: notification_service_web.dart (echte Browser-Notifications
/// via package:web + dart:js_interop). Sonst: notification_service_io.dart
/// (no-op-Stub).
///
/// Grund: package:web zieht dart:js_interop-Symbole rein, die auf VM-
/// Target nicht kompilieren. `flutter test` (VM) konnte vorher keinen
/// Provider importieren weil VaultProvider → NotificationService →
/// package:web. Mit dieser Trennung läuft VM-Code gegen den Stub,
/// Browser-Code unverändert gegen die echte Impl.
library;

export 'notification_service_io.dart'
    if (dart.library.html) 'notification_service_web.dart';
