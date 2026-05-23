import 'package:flutter/material.dart';

import '../../../models/note_model.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// PARA-Kategorie als Pillen-Badge. View-Modus: nur Label.
/// Edit-Modus: Popup-Menu mit allen Kategorien.
class ParaBadge extends StatelessWidget {
  final ParaCategory para;
  final bool editable;
  final ValueChanged<ParaCategory> onChanged;

  const ParaBadge({
    super.key,
    required this.para,
    required this.editable,
    required this.onChanged,
  });

  static const _labels = {
    ParaCategory.inbox: 'Inbox',
    ParaCategory.projects: 'Projects',
    ParaCategory.areas: 'Areas',
    ParaCategory.resources: 'Resources',
    ParaCategory.archive: 'Archive',
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[para] ?? 'Inbox';

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BrainColors.surfaceHigh,
        borderRadius: BrainSpacing.radiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: BrainTypography.labelSm),
          if (editable) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16, color: BrainColors.outline),
          ],
        ],
      ),
    );

    if (!editable) return badge;

    return PopupMenuButton<ParaCategory>(
      color: BrainColors.surfaceHigh,
      onSelected: onChanged,
      itemBuilder: (_) => _labels.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      child: badge,
    );
  }
}
