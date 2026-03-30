import 'package:flutter/material.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';

/// A styled card with optional ghost border, hover effect (web), and tap handler.
class BrainCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final bool showBorder;

  const BrainCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = BrainSpacing.paddingCard,
    this.color,
    this.showBorder = false,
  });

  @override
  State<BrainCard> createState() => _BrainCardState();
}

class _BrainCardState extends State<BrainCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.color ?? BrainColors.surfaceLow;

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
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null
                ? BrainColors.surfaceHigh
                : bgColor,
            borderRadius: BrainSpacing.radiusMd,
            border: widget.showBorder
                ? Border.all(
                    color: _hovered
                        ? BrainColors.primary.withValues(alpha: 0.30)
                        : BrainColors.outlineVariant.withValues(alpha: 0.15),
                    width: 1,
                  )
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
