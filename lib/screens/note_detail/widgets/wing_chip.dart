import 'package:flutter/material.dart';

import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// View-only Chip für die Wing-Zugehörigkeit (kebab-case → Title Case).
class WingChip extends StatelessWidget {
  final String wing;
  const WingChip({super.key, required this.wing});

  @override
  Widget build(BuildContext context) {
    final display = wing.split('-').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BrainColors.primary.withValues(alpha: 0.10),
        borderRadius: BrainSpacing.radiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 14, color: BrainColors.primary),
          const SizedBox(width: 4),
          Text(display, style: BrainTypography.tag),
        ],
      ),
    );
  }
}
