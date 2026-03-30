import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_spacing.dart';
import '../widgets/brain_bottom_nav.dart';
import 'capture_screen.dart';
import 'dashboard_screen.dart';
import 'search_screen.dart';
import 'inbox_screen.dart';
import 'settings_screen.dart';

/// Root shell: 5-tab navigation (Home, Search, Capture, Inbox, Settings).
/// Capture is index 2 — a full screen, not a bottom sheet.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    SearchScreen(),
    CaptureScreen(),
    InboxScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111319),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth > BrainSpacing.maxContentWidth + 48;

          Widget content = IndexedStack(
            index: _currentIndex,
            children: _screens,
          );

          if (isWide) {
            content = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: BrainSpacing.maxContentWidth),
                child: content,
              ),
            );
          }

          return content;
        },
      ),
      bottomNavigationBar: BrainBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        inboxCount: context.watch<VaultProvider>().status.inboxCount,
      ),
    );
  }
}
