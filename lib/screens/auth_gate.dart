import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_theme.dart';
import 'app_shell.dart';
import '../providers/auth_provider.dart';
import '../providers/vault_provider.dart';
import '../providers/capture_provider.dart';
import '../providers/search_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/resurfacing_provider.dart';
import '../providers/background_provider.dart';
import '../providers/glass_settings_provider.dart';

/// Opens the app once its local cache is ready.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.status == AuthStatus.loading) {
      return const _WorkspaceApp(home: _SplashScreen());
    }
    return _BrainWorkspace(key: ValueKey(auth.session?.id));
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

class _BrainWorkspace extends StatelessWidget {
  const _BrainWorkspace({required super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VaultProvider()),
        ChangeNotifierProxyProvider<VaultProvider, CaptureProvider>(
          create: (ctx) => CaptureProvider(
            Provider.of<VaultProvider>(ctx, listen: false),
          ),
          update: (_, vault, prev) => prev ?? CaptureProvider(vault),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchProvider()..loadRecentSearches(),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => DiscoveryProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => ResurfacingProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => BackgroundProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => GlassSettingsProvider()..init(),
        ),
      ],
      child: const _WorkspaceApp(home: _WorkspaceHome()),
    );
  }
}

class _WorkspaceApp extends StatelessWidget {
  const _WorkspaceApp({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Second Brain',
    debugShowCheckedModeBanner: false,
    theme: BrainTheme.dark(),
    home: home,
  );
}

class _WorkspaceHome extends StatefulWidget {
  const _WorkspaceHome();

  @override
  State<_WorkspaceHome> createState() => _WorkspaceHomeState();
}

class _WorkspaceHomeState extends State<_WorkspaceHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vault = context.read<VaultProvider>();
      vault.syncCaptures = context.read<CaptureProvider>().syncOfflineQueue;
      vault.initialize();
      if (context.read<AuthProvider>().isLoggedIn) {
        vault.pruneSoftDeleted();
        NotificationService.instance.refreshSubscription();
      }
    });
  }

  @override
  Widget build(BuildContext context) => const AppShell();
}
