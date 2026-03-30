import 'package:flutter/material.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Stat card — pill shape (rounded-full), no borders, tonal background.
/// Layout: icon pill top-left, large value bottom-left, mono label below.
class BrainStatCard extends StatefulWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const BrainStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  State<BrainStatCard> createState() => _BrainStatCardState();
}

class _BrainStatCardState extends State<BrainStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? BrainColors.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovered ? BrainColors.surfaceHigh : BrainColors.surfaceLow,
            borderRadius: BrainSpacing.radiusFull, // pill shape
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BrainSpacing.radiusFull,
                ),
                child: Icon(widget.icon, size: 18, color: color),
              ),

              const SizedBox(height: BrainSpacing.sm),

              // Value
              Text(
                widget.value,
                style: BrainTypography.headlineMd.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              // Label — mono uppercase
              Text(
                widget.label.toUpperCase(),
                style: BrainTypography.labelSm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
