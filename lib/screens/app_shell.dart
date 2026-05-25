import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/background_provider.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_spacing.dart';
import '../widgets/brain_bottom_nav.dart';
import 'capture_screen.dart';
import 'dashboard_screen.dart';
import 'search_screen.dart';
import 'inbox_screen.dart';
import 'settings_screen.dart';

/// Root shell: 5-tab navigation.
/// Tab order: 0=Home, 1=Search, 2=Inbox, 3=Settings, 4=Capture (MIC).
/// Capture sits rightmost as a prominent MIC button — voice is the
/// hauptweg-into-capture. Tab order = visual order in BrainBottomNav.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  // Incremented each time the user taps the MIC tab — CaptureScreen
  // listens and starts voice-capture immediately. Survives across rebuilds.
  final ValueNotifier<int> _voiceTrigger = ValueNotifier<int>(0);

  static const int _captureTabIndex = 4;

  @override
  void dispose() {
    _voiceTrigger.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    String? initialCaptureText;
    if (kIsWeb) {
      try {
        final params = Uri.base.queryParameters;
        final text = params['text'];
        if (text != null && text.isNotEmpty) {
          initialCaptureText = Uri.decodeComponent(text);
          _currentIndex = 4; // jump to Capture tab (new rightmost position)
        }
      } catch (_) {}
    }
    _screens = [
      const DashboardScreen(),
      const SearchScreen(),
      const InboxScreen(),
      const SettingsScreen(),
      CaptureScreen(
        initialText: initialCaptureText,
        voiceTrigger: _voiceTrigger,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bgBytes = context.watch<BackgroundProvider>().bytes;
    final hasBg = bgBytes != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasBg) ...[
          // Background image (covers full screen, behind everything)
          Positioned.fill(
            child: Image.memory(
              bgBytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          // 60% dark overlay so cards/text stay readable
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.60)),
          ),
        ],
        Scaffold(
      backgroundColor: hasBg ? Colors.transparent : const Color(0xFF111319),
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
        onTap: (i) {
          setState(() => _currentIndex = i);
          // Tap auf MIC startet immer eine neue Voice-Session — auch wenn
          // wir schon auf dem Capture-Tab waren (User-Intent „jetzt sprechen").
          if (i == _captureTabIndex) _voiceTrigger.value++;
        },
        inboxCount: context.watch<VaultProvider>().status.inboxCount,
      ),
    ),
      ],
    );
  }
}
