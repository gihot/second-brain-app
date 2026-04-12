import 'package:flutter/material.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Frequency-scaled tag chips. Higher frequency → larger font.
/// Tapping a tag calls [onTagTap] (typically navigates to Search).
class TagCloud extends StatelessWidget {
  final List<MapEntry<String, int>> frequencies;
  final ValueChanged<String> onTagTap;

  const TagCloud({
    super.key,
    required this.frequencies,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    if (frequencies.isEmpty) return const SizedBox.shrink();

    final maxCount = frequencies.first.value.toDouble();
    final minCount = frequencies.last.value.toDouble();
    const minSize = 10.0;
    const maxSize = 18.0;

    return Wrap(
      spacing: BrainSpacing.sm,
      runSpacing: BrainSpacing.sm,
      children: frequencies.map((e) {
        final ratio = maxCount == minCount
            ? 0.5
            : (e.value - minCount) / (maxCount - minCount);
        final fontSize = minSize + ratio * (maxSize - minSize);

        return GestureDetector(
          onTap: () => onTagTap(e.key),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BrainColors.primary
                  .withValues(alpha: 0.06 + ratio * 0.12),
              borderRadius: BrainSpacing.radiusFull,
            ),
            child: Text(
              '#${e.key}',
              style: BrainTypography.tag.copyWith(
                fontSize: fontSize,
                color: BrainColors.primary
                    .withValues(alpha: 0.5 + ratio * 0.5),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
