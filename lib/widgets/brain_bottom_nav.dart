import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Frosted glass bottom navigation.
/// Capture is the center nav item with a gradient accent — not a floating FAB.
/// Labels: JetBrains Mono, uppercase, 9px tracking-wide.
class BrainBottomNav extends StatelessWidget {
  final int currentIndex; // 0=Home 1=Search 2=Capture 3=Inbox 4=Settings
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
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: BrainColors.base.withValues(alpha: 0.60),
            border: Border(
              top: BorderSide(
                color: BrainColors.outlineVariant.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    label: 'SEARCH',
                    isActive: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _CaptureNavItem(
                    isActive: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  _NavItem(
                    icon: Icons.inbox_outlined,
                    label: 'INBOX',
                    isActive: currentIndex == 3,
                    onTap: () => onTap(3),
                    badgeCount: inboxCount,
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'SETTINGS',
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
            borderRadius: BrainSpacing.radiusMd,
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
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: BrainColors.secondary,
                          borderRadius: BrainSpacing.radiusFull,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 14, minHeight: 14),
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

/// Center capture item — gradient accent, slightly larger icon.
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: widget.isActive
                      ? BrainColors.captureGradient
                      : null,
                  color: widget.isActive
                      ? null
                      : BrainColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: BrainColors.captureGlow,
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: widget.isActive
                      ? Colors.white
                      : BrainColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CAPTURE',
                style: BrainTypography.navLabel.copyWith(
                  color: widget.isActive
                      ? BrainColors.primary
                      : BrainColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
