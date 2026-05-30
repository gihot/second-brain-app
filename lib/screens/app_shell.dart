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

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  // Incremented each time the user taps the MIC tab — CaptureScreen
  // listens and starts voice-capture immediately. Survives across rebuilds.
  final ValueNotifier<int> _voiceTrigger = ValueNotifier<int>(0);

  static const int _captureTabIndex = 4;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceTrigger.dispose();
    super.dispose();
  }

  /// Sync beim Zurückkehren in den Vordergrund. Ohne das holte die App
  /// neue Gedanken (z.B. vom PC erfasst) nur alle 5 Min per Timer — auf
  /// iOS-PWA im Hintergrund unzuverlässig, also taucht ein frischer
  /// Gedanke beim Öffnen oft nicht auf. Der Sync triggert auch das
  /// In-App-Feuern gerade fälliger Reminder (_loadFromCache).
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
      _currentIndex = 4; // jump to Capture tab (new rightmost position)
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
        // Plan 1.1: Long-Press auf MIC = Escape-Hatch für Tipper.
        // Öffnet Capture-Tab ohne Voice-Trigger → User landet im Text-
        // Eingabefeld statt im sofortigen Sprach-Modus.
        onCaptureLongPress: () {
          setState(() => _currentIndex = _captureTabIndex);
        },
        inboxCount: context.watch<VaultProvider>().status.inboxCount,
      ),
    ),
      ],
    );
  }
}
