import 'package:flutter/material.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

enum BrainButtonVariant { primary, secondary, ghost }
enum BrainButtonSize { sm, md, lg }

/// Custom button with scale-on-press micro-interaction.
class BrainButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final BrainButtonVariant variant;
  final BrainButtonSize size;
  final IconData? icon;
  final bool loading;

  const BrainButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = BrainButtonVariant.primary,
    this.size = BrainButtonSize.md,
    this.icon,
    this.loading = false,
  });

  @override
  State<BrainButton> createState() => _BrainButtonState();
}

class _BrainButtonState extends State<BrainButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scale;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  double get _height {
    switch (widget.size) {
      case BrainButtonSize.sm:
        return BrainSpacing.buttonHeightSm;
      case BrainButtonSize.md:
        return BrainSpacing.buttonHeightMd;
      case BrainButtonSize.lg:
        return BrainSpacing.buttonHeightLg;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case BrainButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 12);
      case BrainButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 20);
      case BrainButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 24);
    }
  }

  Color get _backgroundColor {
    if (widget.onPressed == null) return BrainColors.surfaceHigh;
    switch (widget.variant) {
      case BrainButtonVariant.primary:
        return _hovered ? BrainColors.primaryContainer : BrainColors.primary;
      case BrainButtonVariant.secondary:
        return _hovered ? BrainColors.surfaceHigh : BrainColors.surfaceLow;
      case BrainButtonVariant.ghost:
        return _hovered
            ? BrainColors.primary.withValues(alpha: 0.08)
            : Colors.transparent;
    }
  }

  Color get _foregroundColor {
    if (widget.onPressed == null) return BrainColors.outline;
    switch (widget.variant) {
      case BrainButtonVariant.primary:
        return BrainColors.onPrimary;
      case BrainButtonVariant.secondary:
      case BrainButtonVariant.ghost:
        return BrainColors.onSurface;
    }
  }

  Border? get _border {
    if (widget.variant == BrainButtonVariant.secondary) {
      return Border.all(
          color: BrainColors.outlineVariant.withValues(alpha: 0.15), width: 1);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) {
          _scaleController.reverse();
          widget.onPressed?.call();
        },
        onTapCancel: () => _scaleController.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            height: _height,
            padding: _padding,
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BrainSpacing.radiusSm,
              border: _border,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.loading) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _foregroundColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: _foregroundColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: BrainTypography.button.copyWith(color: _foregroundColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
