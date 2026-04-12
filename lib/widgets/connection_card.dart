import 'package:flutter/material.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// A single connection surfaced by the Connector agent.
class ConnectionCard extends StatelessWidget {
  final String targetTitle;
  final String connectionType; // causal, contradictory, complementary, sequential, analogical
  final String explanation;
  final VoidCallback? onTap;

  const ConnectionCard({
    super.key,
    required this.targetTitle,
    required this.connectionType,
    required this.explanation,
    this.onTap,
  });

  Color get _typeColor => switch (connectionType.toLowerCase()) {
        'causal' => BrainColors.tertiary,
        'contradictory' => BrainColors.error,
        'complementary' => BrainColors.secondary,
        'sequential' => BrainColors.primary,
        'analogical' => BrainColors.primaryContainer,
        _ => BrainColors.outline,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BrainSpacing.radiusMd,
      child: InkWell(
        borderRadius: BrainSpacing.radiusMd,
        onTap: onTap,
        child: Container(
          padding: BrainSpacing.paddingCard,
          decoration: BoxDecoration(
            color: BrainColors.surfaceLow,
            borderRadius: BrainSpacing.radiusMd,
            border: Border(
              left: BorderSide(color: _typeColor, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.15),
                      borderRadius: BrainSpacing.radiusFull,
                    ),
                    child: Text(
                      connectionType.toUpperCase(),
                      style: BrainTypography.labelSm.copyWith(color: _typeColor),
                    ),
                  ),
                  const SizedBox(width: BrainSpacing.sm),
                  Expanded(
                    child: Text(
                      targetTitle,
                      style: BrainTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: BrainColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BrainSpacing.sm),
              Text(
                explanation,
                style: BrainTypography.bodySm,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
