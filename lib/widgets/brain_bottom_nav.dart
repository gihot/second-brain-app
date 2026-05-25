import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Frosted bottom navigation matching the handoff: one compact segmented pill
/// plus a fused mic endcap. The MIC is icon-only; capture remains visually
/// primary without turning the bar into a full-width bottom sheet.
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
    return SizedBox(
      height: BrainSpacing.bottomNavHeight,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: BrainSpacing.maxContentWidth,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentedPill(
                      children: [
                        _NavItem(
                          icon: Icons.home_outlined,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
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

class _SegmentedPill extends StatelessWidget {
  final List<Widget> children;

  const _SegmentedPill({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BrainSpacing.radiusFull,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0C12).withValues(alpha: 0.55),
            borderRadius: BrainSpacing.radiusFull,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.04),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 8),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const _NavDivider(),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavDivider extends StatelessWidget {
  const _NavDivider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 1,
        height: 14,
        color: Colors.white.withValues(alpha: 0.03),
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
        : BrainColors.onSurfaceVariant.withValues(alpha: 0.62);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isActive)
              Positioned.fill(
                top: 6,
                bottom: 6,
                left: 4,
                right: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BrainSpacing.radiusFull,
                    gradient: RadialGradient(
                      colors: [
                        BrainColors.primary.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.75],
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(widget.icon, size: 19, color: color),
                    if (widget.badgeCount > 0)
                      Positioned(
                        right: -7,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
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
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
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
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: BrainTypography.bodySm.copyWith(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    letterSpacing: 0.54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A0C12).withValues(alpha: 0.65),
                  border: Border.all(
                    color: BrainColors.primary.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.30),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                      spreadRadius: -6,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.02),
                      blurRadius: 0,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF6366F1).withValues(alpha: 0.38),
                            const Color(0xFF4F46E5).withValues(alpha: 0.30),
                          ],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.35, -0.45),
                          radius: 0.75,
                          colors: [
                            BrainColors.primary.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      Icons.mic_rounded,
                      size: 22,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
