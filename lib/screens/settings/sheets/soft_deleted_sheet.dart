import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/note_model.dart';
import '../../../providers/vault_provider.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// J2 (Plan v2): Recovery-Bin für soft-gelöschte Notizen. Zeigt die
/// 30-Tage-Liste, "Wiederherstellen" pro Eintrag setzt deletedAt = null.
/// Der physische Prune läuft automatisch beim App-Start (> 30 Tage).
class SoftDeletedSheet extends StatelessWidget {
  const SoftDeletedSheet({super.key});

  String _deletedAgo(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    final daysLeft = 30 - diff.inDays;
    if (daysLeft <= 0) return 'läuft bald ab';
    return 'noch $daysLeft ${daysLeft == 1 ? "Tag" : "Tage"}';
  }

  @override
  Widget build(BuildContext context) {
    // watch: wenn der letzte Eintrag wiederhergestellt wird, schließt
    // sich das Sheet von selbst (leere Liste → Auto-Pop).
    final deleted = context.watch<VaultProvider>().softDeletedNotes;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BrainSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gelöschte Notizen', style: BrainTypography.titleMd),
            const SizedBox(height: BrainSpacing.xs),
            Text(
              'Beim Cache-Leeren entfernte Notizen bleiben 30 Tage '
              'wiederherstellbar. Danach werden sie automatisch endgültig '
              'entfernt.',
              style: BrainTypography.bodySm.copyWith(
                color: BrainColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: BrainSpacing.md),
            if (deleted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: BrainSpacing.md),
                child: Text(
                  'Keine gelöschten Notizen.',
                  style: BrainTypography.bodySm.copyWith(
                    color: BrainColors.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: deleted.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: BrainSpacing.xs),
                  itemBuilder: (_, i) => _row(context, deleted[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Note note) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BrainColors.surfaceHigh,
        borderRadius: BrainSpacing.radiusSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note.title,
                  style: BrainTypography.bodyMd.copyWith(
                    color: BrainColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note.deletedAt != null)
                  Text(
                    _deletedAgo(note.deletedAt!),
                    style: BrainTypography.labelSm.copyWith(
                      color: BrainColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                context.read<VaultProvider>().restoreSoftDeleted(note.id),
            child: Text(
              'Wiederherstellen',
              style: BrainTypography.button.copyWith(
                color: BrainColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
