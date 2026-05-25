import 'package:flutter/material.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import 'glass_card_surface.dart';

/// A styled card with optional ghost border, hover effect (web), and tap handler.
///
/// Two visual modes:
///   • Default opaque (surfaceLow fill, ghost border, optional left-stripe).
///   • Frosted glass when [glass] is true — delegates to [GlassCardSurface].
///     In glass mode, [tintColor] becomes the hall hue blended into the
///     dark frost. [leftBorderColor] is **ignored** in glass mode because
///     the tint already conveys the same information without a hard edge.
class BrainCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final bool showBorder;
  final Color? leftBorderColor;
  final bool glass;
  final Color? tintColor;

  const BrainCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = BrainSpacing.paddingCard,
    this.color,
    this.showBorder = false,
    this.leftBorderColor,
    this.glass = false,
    this.tintColor,
  });

  @override
  State<BrainCard> createState() => _BrainCardState();
}

class _BrainCardState extends State<BrainCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.glass) {
      return GlassCardSurface(
        tintColor: widget.tintColor ?? widget.leftBorderColor,
        onTap: widget.onTap,
        child: Padding(padding: widget.padding, child: widget.child),
      );
    }

    final bgColor = widget.color ?? BrainColors.solidSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null
                ? BrainColors.solidSurfaceHigh
                : bgColor,
            borderRadius: BrainSpacing.radiusLg,
            border: widget.showBorder
                ? Border.all(
                    color: _hovered
                        ? BrainColors.primary.withValues(alpha: 0.30)
                        : BrainColors.solidBorder,
                    width: 1,
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: BrainSpacing.radiusLg,
            child: Stack(
              children: [
                if (widget.leftBorderColor != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: widget.leftBorderColor),
                  ),
                Padding(padding: widget.padding, child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
