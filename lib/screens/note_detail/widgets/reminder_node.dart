import 'package:flutter/material.dart';

import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Karten-artiger Block für die "ERINNERUNG"-Sektion (im Edit- und View-Modus).
class ReminderNode extends StatelessWidget {
  final String? formatted;
  final Widget? child;

  const ReminderNode({super.key, this.formatted, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BrainSpacing.md),
      decoration: BoxDecoration(
        color: BrainColors.surfaceLow,
        borderRadius: BrainSpacing.radiusMd,
        border: Border.all(
          color: BrainColors.outlineVariant.withValues(alpha: 0.10),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alarm_outlined,
                  size: 14, color: BrainColors.tertiary),
              const SizedBox(width: 6),
              Text(
                'ERINNERUNG',
                style: BrainTypography.labelSm.copyWith(
                  color: BrainColors.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: BrainSpacing.xs),
          Text(
            formatted ?? '— noch kein Zeitpunkt —',
            style: BrainTypography.labelMd
                .copyWith(color: BrainColors.onSurface),
          ),
          if (child != null) ...[
            const SizedBox(height: BrainSpacing.xs),
            child!,
          ],
        ],
      ),
    );
  }
}
