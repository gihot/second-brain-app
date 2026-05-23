import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/brain_theme.dart';
import 'screens/auth_gate.dart';
import 'providers/auth_provider.dart';
import 'providers/vault_provider.dart';
import 'providers/capture_provider.dart';
import 'providers/search_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/discovery_provider.dart';
import 'providers/background_provider.dart';
import 'providers/glass_settings_provider.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.instance.init();
  runApp(const SecondBrainApp());
}

class SecondBrainApp extends StatelessWidget {
  const SecondBrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthProvider must come first — it wires ApiService.onUnauthorized
        // in its init(), and every downstream provider relies on the API
        // layer. The AuthGate widget hides the AppShell until login resolves.
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        // Vault loads from local cache immediately; remote sync waits for
        // a token (ApiService returns null without one). On login the
        // AuthGate triggers VaultProvider.refresh() to pull from server.
        ChangeNotifierProvider(create: (_) => VaultProvider()..initialize()),
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
          create: (_) => BackgroundProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => GlassSettingsProvider()..init(),
        ),
      ],
      child: MaterialApp(
        title: 'Second Brain',
        debugShowCheckedModeBanner: false,
        theme: BrainTheme.dark(),
        home: const AuthGate(),
      ),
    );
  }
}
