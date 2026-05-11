import 'package:flutter/material.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import 'glass_card_surface.dart';

/// Stat card — frosted glass with accent-color tint.
/// Layout: tinted icon-pill top-left, big value + mono uppercase label
/// bottom-left. Matches the "Frag dein Gehirn"-card vocabulary
/// (radiusMd, no hard borders, tonal accent).
class BrainStatCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = accentColor ?? BrainColors.primary;

    return GlassCardSurface(
      tintColor: color,
      onTap: onTap,
      borderRadius: BrainSpacing.radiusMd,
      child: Padding(
        padding: const EdgeInsets.all(BrainSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Tinted icon pill
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BrainSpacing.radiusFull,
              ),
              child: Icon(icon, size: 18, color: color),
            ),

            // Value + label, bottom-aligned
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: BrainTypography.headlineMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: BrainColors.onSurface,
                  ),
                ),
                Text(
                  label.toUpperCase(),
                  style: BrainTypography.labelSm.copyWith(
                    color: BrainColors.onSurfaceVariant,
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
