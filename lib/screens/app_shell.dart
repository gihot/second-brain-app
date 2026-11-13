import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/background_provider.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
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

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  // Incremented each time the user taps the MIC tab — CaptureScreen
  // listens and starts voice-capture immediately. Survives across rebuilds.
  final ValueNotifier<int> _voiceTrigger = ValueNotifier<int>(0);

  static const int _captureTabIndex = 4;
  static const double _desktopBreakpoint = 900;
  static const double _desktopContentWidth = 920;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceTrigger.dispose();
    super.dispose();
  }

  /// Sync beim Zurückkehren in den Vordergrund. Ohne das holte die App
  /// neue Gedanken (z.B. vom PC erfasst) nur alle 5 Min per Timer — auf
  /// iOS-PWA im Hintergrund unzuverlässig, also taucht ein frischer
  /// Gedanke beim Öffnen oft nicht auf.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<VaultProvider>().refresh();
    }
  }

  /// Combines `?title=`, `?text=`, `?url=` from the URL into a single
  /// capture string. Used both by the legacy `?text=` shortcut and by
  /// the PWA-Share-Target (manifest.json) which sends the system share
  /// payload as the same three params.
  ///
  /// Examples:
  /// - Share a quote from a browser: title="Article Title", text=quote,
  ///   url="https://..." → all three lines glued together.
  /// - Share just a URL: only url is set → that's the capture.
  /// - Legacy `?text=foo` → just "foo".
  static String? _captureTextFromQuery() {
    if (!kIsWeb) return null;
    try {
      final params = Uri.base.queryParameters;
      final title = (params['title'] ?? '').trim();
      final text = (params['text'] ?? '').trim();
      final url = (params['url'] ?? '').trim();
      final parts = [
        if (title.isNotEmpty) title,
        if (text.isNotEmpty) text,
        if (url.isNotEmpty) url,
      ];
      if (parts.isEmpty) return null;
      return parts.join('\n\n');
    } catch (_) {
      return null;
    }
  }

  /// Plan 1.4b: erkennt `?voice=immediate` (oder jeden truthy-Wert) in
  /// der Start-URL. Trigger für Quick-Capture-Voice aus iOS-Shortcuts,
  /// Android-Quick-Tiles oder einfach einem Bookmark — überall wo der
  /// User mit einer Geste vom Homescreen direkt sprechen will, ohne
  /// erst die App zu öffnen und MIC zu drücken.
  ///
  /// Query-Param statt eigener Route, weil Flutter-Web hier ohne Router
  /// läuft und der bestehende Share-Target-Pfad ebenfalls Query-basiert
  /// ist (Konsistenz, keine neue Routing-Schicht für eine Boolean-Geste).
  static bool _voiceImmediateFromQuery() {
    if (!kIsWeb) return false;
    try {
      final raw = (Uri.base.queryParameters['voice'] ?? '').trim().toLowerCase();
      return raw == 'immediate' || raw == '1' || raw == 'true' || raw == 'yes';
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialCaptureText = _captureTextFromQuery();
    final voiceImmediate = _voiceImmediateFromQuery();
    // Beide Pfade landen auf dem Capture-Tab. Wenn Text geteilt wurde
    // (Share-Target), gewinnt Text — der User hat Inhalt mitgebracht,
    // wir starten keine Voice-Session „über" den Text drüber.
    if (initialCaptureText != null || voiceImmediate) {
      _currentIndex = _captureTabIndex;
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
    // Voice-Trigger erst nach dem ersten Frame bumpen — CaptureScreen
    // muss seinen Listener registriert haben, sonst läuft das Event
    // ins Leere. addPostFrameCallback garantiert das.
    if (voiceImmediate && initialCaptureText == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _voiceTrigger.value++;
      });
    }
  }

  void _selectTab(int index, {bool startVoice = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _currentIndex = index);
    if (startVoice) _voiceTrigger.value++;
  }

  @override
  Widget build(BuildContext context) {
    final background = context.watch<BackgroundProvider>().bytes;
    final inboxCount = context.watch<VaultProvider>().status.inboxCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= _desktopBreakpoint;
        final content = Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: desktop ? _desktopContentWidth : BrainSpacing.maxContentWidth,
            ),
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            if (background != null) ...[
              Image.memory(background, fit: BoxFit.cover, gaplessPlayback: true),
              ColoredBox(color: Colors.black.withValues(alpha: 0.60)),
            ],
            Scaffold(
              backgroundColor: background == null ? BrainColors.base : Colors.transparent,
              body: Row(
                children: [
                  if (desktop)
                    NavigationRail(
                      backgroundColor: BrainColors.surfaceLowest,
                      minExtendedWidth: 204,
                      extended: true,
                      selectedIndex: _currentIndex,
                      onDestinationSelected: _selectTab,
                      groupAlignment: -1,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: BrainSpacing.lg),
                        child: Text('Second Brain', style: BrainTypography.titleMd),
                      ),
                      destinations: [
                        const NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: Text('Home'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.search_rounded),
                          label: Text('Suche'),
                        ),
                        NavigationRailDestination(
                          icon: Badge(
                            isLabelVisible: inboxCount > 0,
                            label: Text('$inboxCount'),
                            child: const Icon(Icons.inbox_outlined),
                          ),
                          label: const Text('Inbox'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings_rounded),
                          label: Text('Einstellungen'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.edit_outlined),
                          selectedIcon: Icon(Icons.edit_rounded),
                          label: Text('Gedanke erfassen'),
                        ),
                      ],
                    ),
                  Expanded(key: const ValueKey('workspace-content'), child: content),
                ],
              ),
              bottomNavigationBar: desktop
                  ? null
                  : BrainBottomNav(
                      currentIndex: _currentIndex,
                      onTap: (index) => _selectTab(
                        index,
                        startVoice: index == _captureTabIndex,
                      ),
                      onCaptureLongPress: () => _selectTab(_captureTabIndex),
                      inboxCount: inboxCount,
                    ),
            ),
          ],
        );
      },
    );
  }
}
