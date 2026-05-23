import 'package:flutter/material.dart';

import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Abschnitts-Block für die Settings-Liste: Label oben, gerundeter Container
/// mit Trennlinien zwischen den Einträgen.
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const SettingsSection({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: BrainTypography.labelSm),
        const SizedBox(height: BrainSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: BrainColors.surfaceLow,
            borderRadius: BrainSpacing.radiusMd,
            border: Border.all(
                color: BrainColors.outlineVariant.withValues(alpha: 0.15),
                width: 0.5),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              return Column(
                children: [
                  items[i],
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      indent: 48,
                      color: BrainColors.outlineVariant.withValues(alpha: 0.10),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
