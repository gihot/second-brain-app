import 'package:flutter/material.dart';

import '../../../models/note_model.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';
import '../../../widgets/hall_badge.dart';

/// MemoryHall-Auswahl. View-Modus: schmaler Farb-Stripe + neutrales Label
/// (zieht sich zurück). Edit-Modus: tonale Pille mit Popup-Menu.
class HallSelector extends StatelessWidget {
  final MemoryHall hall;
  final bool editable;
  final ValueChanged<MemoryHall> onChanged;

  const HallSelector({
    super.key,
    required this.hall,
    required this.editable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = hallColor(hall);
    final label = hallLabel(hall);

    if (!editable) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: BrainTypography.labelSm
                .copyWith(color: BrainColors.onSurfaceVariant),
          ),
        ],
      );
    }

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BrainSpacing.radiusFull,
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: BrainTypography.labelSm.copyWith(color: color)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down_rounded, size: 16, color: color),
        ],
      ),
    );

    return PopupMenuButton<MemoryHall>(
      color: BrainColors.surfaceHigh,
      onSelected: onChanged,
      itemBuilder: (_) => MemoryHall.values
          .map((h) => PopupMenuItem(
                value: h,
                child: Text(hallLabel(h),
                    style: BrainTypography.bodyMd
                        .copyWith(color: hallColor(h))),
              ))
          .toList(),
      child: badge,
    );
  }
}
