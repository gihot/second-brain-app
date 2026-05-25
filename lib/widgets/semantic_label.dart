import 'package:flutter/material.dart';

import '../theme/brain_colors.dart';
import '../theme/brain_typography.dart';

enum SemanticTone { mint, amber, lavender, muted }

Color semanticToneColor(SemanticTone tone) {
  return switch (tone) {
    SemanticTone.mint => BrainColors.secondary,
    SemanticTone.amber => BrainColors.tertiary,
    SemanticTone.lavender => BrainColors.primary,
    SemanticTone.muted => BrainColors.onSurfaceVariant.withValues(alpha: 0.50),
  };
}

class SystemKicker extends StatelessWidget {
  final IconData? icon;
  final String label;
  final SemanticTone tone;

  const SystemKicker({
    super.key,
    this.icon,
    required this.label,
    this.tone = SemanticTone.mint,
  });

  @override
  Widget build(BuildContext context) {
    final color = semanticToneColor(tone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 6),
        ],
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BrainTypography.labelSm.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }
}

class MetaLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const MetaLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: BrainTypography.labelSm.copyWith(
        color: color ?? BrainColors.onSurfaceVariant.withValues(alpha: 0.50),
        letterSpacing: 1,
      ),
    );
  }
}
