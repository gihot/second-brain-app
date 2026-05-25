import 'package:flutter/material.dart';

import '../models/note_model.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import 'glass_card_surface.dart';

/// Ambient retrieval: the app surfaces things itself instead of asking
/// the user to search. One calm, contextual dashboard element.
///
/// Priority: a discovered connection (server) outranks a resurfaced old
/// thought (local, time-based). When neither applies it renders nothing.
class AmbientRetrieval extends StatelessWidget {
  /// Server connection map: keys note_a_title, note_b_title, note_a_id,
  /// note_b_id, explanation, connection_type.
  final Map<String, dynamic>? connection;

  /// Triggered by the small dismiss-X on the connection card. The pair
  /// gets paused for 14 days on the server.
  final VoidCallback? onDismissConnection;

  /// A local note that comes back into view because it's a few weeks old.
  final Note? resurfacedNote;
  final VoidCallback? onResurfacedTap;

  const AmbientRetrieval({
    super.key,
    this.connection,
    this.onDismissConnection,
    this.resurfacedNote,
    this.onResurfacedTap,
  });

  @override
  Widget build(BuildContext context) {
    if (connection != null) return _connectionView();
    if (resurfacedNote != null) return _resurfacedView();
    return const SizedBox.shrink();
  }

  Widget _shell({
    required IconData icon,
    required Color accent,
    required String label,
    required Widget body,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrainSpacing.screenPadding,
        BrainSpacing.sm,
        BrainSpacing.screenPadding,
        BrainSpacing.sm,
      ),
      child: GlassCardSurface(
        padding: BrainSpacing.paddingCard,
        borderRadius: BrainSpacing.radiusLg,
        tintColor: accent,
        tintOpacityMultiplier: 0.7,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: accent.withValues(alpha: 0.85)),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: BrainTypography.labelSm.copyWith(
                    color: accent.withValues(alpha: 0.85),
                    letterSpacing: 1.1,
                    fontSize: 10,
                  ),
                ),
                if (onDismiss != null) ...[
                  const Spacer(),
                  InkResponse(
                    onTap: onDismiss,
                    radius: 14,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: BrainColors.onSurfaceVariant.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ),
                ] else if (onTap != null) ...[
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: BrainColors.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            const SizedBox(height: BrainSpacing.sm),
            body,
          ],
        ),
      ),
    );
  }

  Widget _connectionView() {
    final a = connection!['note_a_title'] as String? ?? '';
    final b = connection!['note_b_title'] as String? ?? '';
    final explanation = connection!['explanation'] as String? ?? '';

    return _shell(
      icon: Icons.hub_outlined,
      accent: BrainColors.secondary,
      label: 'DEIN GEHIRN SIEHT EINEN ZUSAMMENHANG',
      onDismiss: onDismissConnection,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '«$a»',
                  style: BrainTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: BrainColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BrainSpacing.sm,
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: BrainColors.secondary,
                ),
              ),
              Expanded(
                child: Text(
                  '«$b»',
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
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: BrainSpacing.xs),
            Text(
              explanation,
              style: BrainTypography.bodySm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _resurfacedView() {
    final note = resurfacedNote!;
    final days = DateTime.now().difference(note.created).inDays;
    final ago = days < 14
        ? 'Vor $days Tagen'
        : 'Vor ${(days / 7).round()} Wochen';

    return _shell(
      icon: Icons.history_rounded,
      accent: BrainColors.primary,
      label: 'TAUCHT WIEDER AUF',
      onTap: onResurfacedTap,
      body: Text(
        '$ago dachtest du über «${note.title}» nach.',
        style: BrainTypography.bodyMd.copyWith(color: BrainColors.onSurface),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
