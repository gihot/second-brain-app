import 'package:flutter/material.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Top-of-dashboard atmospheric block — "dein Gehirn wacht auf".
///
/// Carries identity (the "SYSTEM AKTIV" label) + a time-of-day greeting.
/// Does NOT own any stats: the optional [statusLine] is composed by the
/// dashboard from current context and condensed to a single line. When
/// there is nothing relevant, [statusLine] is null and the hero stays
/// minimal.
class DashboardHero extends StatelessWidget {
  final String greeting;
  final String? statusLine;
  final VoidCallback? onStatusTap;

  const DashboardHero({
    super.key,
    required this.greeting,
    this.statusLine,
    this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        BrainSpacing.screenPadding,
        BrainSpacing.xxl,
        BrainSpacing.screenPadding,
        BrainSpacing.lg,
      ),
      decoration: BoxDecoration(
        // Subtle gradient wash — hero weight without shouting.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BrainColors.primary.withValues(alpha: 0.07),
            BrainColors.primary.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SYSTEM AKTIV',
            style: BrainTypography.labelSm.copyWith(
              color: BrainColors.secondary,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: BrainSpacing.sm),
          Text(
            '$greeting.',
            style: BrainTypography.displayMd,
          ),
          if (statusLine != null) ...[
            const SizedBox(height: BrainSpacing.sm),
            GestureDetector(
              onTap: onStatusTap,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      statusLine!,
                      style: BrainTypography.bodySm.copyWith(
                        color: BrainColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onStatusTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 11, color: BrainColors.onSurfaceVariant),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
