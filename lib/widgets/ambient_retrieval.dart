import 'package:flutter/material.dart';

import '../models/note_model.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import 'glass_card_surface.dart';
import 'semantic_label.dart';

/// Ambient retrieval: the app surfaces things itself instead of asking
/// the user to search. Calm, contextual dashboard cards.
///
/// Wave 3: `resurfacedNotes` ist jetzt eine Liste — kommt vom Server-
/// Score (`/resurfacing/today`). `fallbackResurfaced` bleibt als
/// lokaler Eingang erhalten, damit ein Offline-Dashboard nicht „tot"
/// wirkt (Resurfacing-Spec).
///
/// Layout-Regel (J7): genau **eine** Karte pro Tag. Connection hat
/// Priorität (server-gewählter Zusammenhang > Zeit-Resurface), sonst
/// die top-1 Resurfacing-Notiz. Keine Stapelung — „Dashboard bleibt
/// ruhig" (Resurfacing-Spec) ist hier Architektur, nicht nur Mantra.
class AmbientRetrieval extends StatelessWidget {
  /// Server connection map: keys note_a_title, note_b_title, note_a_id,
  /// note_b_id, explanation, connection_type.
  final Map<String, dynamic>? connection;

  /// Triggered by the small dismiss-X on the connection card. The pair
  /// gets paused for 14 days on the server.
  final VoidCallback? onDismissConnection;

  /// Liste der vom Server gewählten Resurfacing-Notizen (Wave 3).
  /// Leer = Server hat nichts geliefert / Index nicht initialisiert.
  final List<Note> resurfacedNotes;

  /// Tap-Handler je Resurfacing-Notiz. Bekommt die Notiz, damit
  /// `markEngaged` server-seitig den richtigen Eintrag pausiert.
  final ValueChanged<Note>? onResurfacedTap;

  /// Fallback für Offline / Server-down: lokal gepickte Notiz, wenn
  /// `resurfacedNotes` leer ist. Folge der Spec „Dashboard niemals tot".
  final Note? fallbackResurfaced;

  const AmbientRetrieval({
    super.key,
    this.connection,
    this.onDismissConnection,
    this.resurfacedNotes = const [],
    this.onResurfacedTap,
    this.fallbackResurfaced,
  });

  @override
  Widget build(BuildContext context) {
    final hasConnection = connection != null;
    final source = resurfacedNotes.isNotEmpty
        ? resurfacedNotes
        : (fallbackResurfaced != null ? [fallbackResurfaced!] : const <Note>[]);

    // J7 (Plan v2): genau EINE Karte pro Tag — „Dashboard bleibt ruhig"
    // wird Architektur, nicht nur Mantra. Connection hat Priorität
    // (server-gewählter Zusammenhang ist wertvoller als ein Zeit-
    // Resurface); sonst die top-1 Resurfacing-Notiz. Keine Stapelung.
    if (hasConnection) {
      return _connectionView();
    }
    if (source.isNotEmpty) {
      return _resurfacedView(source.first);
    }
    return const SizedBox.shrink();
  }

  Widget _shell({
    required IconData icon,
    required Color accent,
    required String label,
    required SemanticTone tone,
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
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SystemKicker(icon: icon, label: label, tone: tone),
                  ),
                ),
                if (onDismiss != null) ...[
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
      tone: SemanticTone.mint,
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

  Widget _resurfacedView(Note note) {
    final days = DateTime.now().difference(note.created).inDays;
    final ago = days < 14
        ? 'Vor $days Tagen'
        : 'Vor ${(days / 7).round()} Wochen';

    return _shell(
      icon: Icons.history_rounded,
      accent: BrainColors.tertiary,
      label: 'TAUCHT WIEDER AUF',
      tone: SemanticTone.amber,
      onTap: onResurfacedTap == null ? null : () => onResurfacedTap!(note),
      body: Text(
        '$ago dachtest du über «${note.title}» nach.',
        style: BrainTypography.bodyMd.copyWith(color: BrainColors.onSurface),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
