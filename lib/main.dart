import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/brain_theme.dart';
import 'screens/app_shell.dart';
import 'providers/vault_provider.dart';
import 'providers/capture_provider.dart';
import 'providers/search_provider.dart';
import 'providers/chat_provider.dart';

void main() {
  runApp(const SecondBrainApp());
}

class SecondBrainApp extends StatelessWidget {
  const SecondBrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
      ],
      child: MaterialApp(
        title: 'Second Brain',
        debugShowCheckedModeBanner: false,
        theme: BrainTheme.dark(),
        home: const AppShell(),
      ),
    );
  }
}
