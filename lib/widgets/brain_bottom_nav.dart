import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Frosted glass bottom navigation.
/// MIC sits as the rightmost item — biggest, gradient accent, slight glow.
/// Voice is the hero capture path; this is its hauptplatz.
/// Labels: JetBrains Mono, uppercase, 9px tracking-wide.
///
/// Index mapping (matches AppShell._screens):
///   0 = Home, 1 = Search, 2 = Inbox, 3 = Settings, 4 = Capture (MIC).
class BrainBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int inboxCount;

  const BrainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.inboxCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0C12).withValues(alpha: 0.55),
            border: Border(
              top: BorderSide(color: BrainColors.glassBorder, width: 0.5),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'HOME',
                    isActive: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.search_rounded,
                    label: 'SUCHE',
                    isActive: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.inbox_outlined,
                    label: 'INBOX',
                    isActive: currentIndex == 2,
                    onTap: () => onTap(2),
                    badgeCount: inboxCount,
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'OPTIONEN',
                    isActive: currentIndex == 3,
                    onTap: () => onTap(3),
                  ),
                  _CaptureNavItem(
                    isActive: currentIndex == 4,
                    onTap: () => onTap(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? BrainColors.primary
        : _hovered
        ? BrainColors.onSurfaceVariant
        : BrainColors.onSurfaceVariant.withValues(alpha: 0.6);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive
                ? BrainColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BrainSpacing.radiusFull,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(widget.icon, size: 20, color: color),
                  if (widget.badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: BrainColors.secondary,
                          borderRadius: BrainSpacing.radiusFull,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          widget.badgeCount > 99
                              ? '99+'
                              : '${widget.badgeCount}',
                          style: BrainTypography.labelSm.copyWith(
                            color: BrainColors.onSecondary,
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: BrainTypography.navLabel.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// MIC — die Haupt-Capture-Aktion. Größer, kräftiger Gradient, immer
/// sichtbarer Glow (auch wenn inaktiv) damit der Button als „das
/// macht hier was" erkannt wird. Voice-Capture ist der schnellste
/// Capture-Weg unterwegs.
class _CaptureNavItem extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _CaptureNavItem({required this.isActive, required this.onTap});

  @override
  State<_CaptureNavItem> createState() => _CaptureNavItemState();
}

class _CaptureNavItemState extends State<_CaptureNavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  // Always gradient — MIC ist immer „da", nicht erst wenn
                  // aktiv. Aktiv = noch heller, etwas mehr Glow.
                  gradient: BrainColors.captureGradient,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: BrainColors.captureGlow.withValues(
                        alpha: widget.isActive ? 0.75 : 0.45,
                      ),
                      blurRadius: widget.isActive ? 22 : 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  size: 26,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SPRECHEN',
                style: BrainTypography.navLabel.copyWith(
                  color: widget.isActive
                      ? BrainColors.primary
                      : BrainColors.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
