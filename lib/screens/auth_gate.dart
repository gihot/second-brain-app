import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/background_provider.dart';
import '../providers/glass_settings_provider.dart';
import '../providers/resurfacing_provider.dart';
import '../providers/vault_provider.dart';
import '../services/notification_service.dart';
import '../theme/brain_colors.dart';
import 'app_shell.dart';
import 'login_screen.dart';

/// Top-level gate: drives the visible screen from [AuthStatus] and triggers
/// VaultProvider sync exactly once when the user transitions into
/// `loggedIn` (boot, fresh login).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthStatus? _lastStatus;

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    if (status != _lastStatus) {
      _lastStatus = status;
      if (status == AuthStatus.loggedIn) {
        // Kick off the first sync after auth resolves. We schedule this
        // post-frame so it doesn't race with the current build phase, and
        // so VaultProvider.notifyListeners during refresh doesn't trip the
        // "setState during build" check.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Re-read per-user cache contents now that the cache is open.
          context.read<BackgroundProvider>().init();
          context.read<GlassSettingsProvider>().init();
          context.read<VaultProvider>().refresh();
          // J2: soft-deleted Notizen die > 30 Tage alt sind physisch
          // wegräumen. Fire-and-forget, blockiert den Login nicht.
          context.read<VaultProvider>().pruneSoftDeleted();
          // Wave 3: Resurfacing erst nach Login holen — vorher kein
          // Token, gäbe nur 401. init() ist idempotent (1h-Throttle).
          context.read<ResurfacingProvider>().init();
          // Push-Subscription auffrischen (iOS verwirft sie bei längerer
          // Inaktivität — siehe Problem B). No-op wenn Push aus.
          NotificationService.instance.refreshSubscription();
        });
      }
      if (status == AuthStatus.loggedOut) {
        // Resurface-Liste der Vor-Session räumen, damit der nächste
        // Login sie nicht erbt.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<ResurfacingProvider>().clear();
        });
      }
    }

    switch (status) {
      case AuthStatus.loading:
        return const _SplashScreen();
      case AuthStatus.loggedOut:
        return const LoginScreen();
      case AuthStatus.loggedIn:
        return const AppShell();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BrainColors.base,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: BrainColors.primary),
        ),
      ),
    );
  }
}
