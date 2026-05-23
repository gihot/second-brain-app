import 'package:flutter/material.dart';

import '../../../models/note_model.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Auswahl für den ThoughtType (Gedanke/Erinnerung/Frage/Idee).
class ThoughtTypeSelector extends StatelessWidget {
  final ThoughtType thoughtType;
  final bool editable;
  final ValueChanged<ThoughtType> onChanged;

  const ThoughtTypeSelector({
    super.key,
    required this.thoughtType,
    required this.editable,
    required this.onChanged,
  });

  static const _labels = {
    ThoughtType.standard: 'Gedanke',
    ThoughtType.reminder: 'Erinnerung',
    ThoughtType.question: 'Frage',
    ThoughtType.idea: 'Idee',
  };

  static const _icons = {
    ThoughtType.standard: Icons.edit_note_outlined,
    ThoughtType.reminder: Icons.alarm_outlined,
    ThoughtType.question: Icons.help_outline_rounded,
    ThoughtType.idea: Icons.lightbulb_outline_rounded,
  };

  static const _colors = {
    ThoughtType.standard: BrainColors.outline,
    ThoughtType.reminder: BrainColors.tertiary,
    ThoughtType.question: BrainColors.secondary,
    ThoughtType.idea: BrainColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[thoughtType] ?? 'Gedanke';
    final icon = _icons[thoughtType] ?? Icons.edit_note_outlined;
    final color = _colors[thoughtType] ?? BrainColors.outline;

    final isStandard = thoughtType == ThoughtType.standard;
    final fillColor = isStandard
        ? BrainColors.surfaceHigh
        : color.withValues(alpha: 0.12);
    final borderColor = isStandard
        ? Colors.transparent
        : BrainColors.outlineVariant.withValues(alpha: 0.10);
    final fgColor = isStandard ? BrainColors.onSurfaceVariant : color;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BrainSpacing.radiusFull,
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 6),
          Text(label, style: BrainTypography.labelSm.copyWith(color: fgColor)),
          if (editable) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 14, color: fgColor),
          ],
        ],
      ),
    );

    if (!editable) return badge;

    return PopupMenuButton<ThoughtType>(
      color: BrainColors.surfaceHigh,
      onSelected: onChanged,
      itemBuilder: (_) => ThoughtType.values
          .map((t) => PopupMenuItem(
                value: t,
                child: Row(
                  children: [
                    Icon(_icons[t], size: 16, color: _colors[t]),
                    const SizedBox(width: 8),
                    Text(_labels[t]!,
                        style: BrainTypography.bodyMd
                            .copyWith(color: _colors[t])),
                  ],
                ),
              ))
          .toList(),
      child: badge,
    );
  }
}
