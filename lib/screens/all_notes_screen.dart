import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../widgets/brain_card.dart';
import '../widgets/hall_badge.dart';
import 'note_detail_screen.dart';

/// Full list of all notes, sorted by most recently modified. Pushed as a
/// route from the Dashboard's "Alle anzeigen" link.
class AllNotesScreen extends StatelessWidget {
  const AllNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<VaultProvider>().notes;

    return Scaffold(
      backgroundColor: BrainColors.base,
      appBar: AppBar(
        backgroundColor: BrainColors.base,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Alle Gedanken',
            style: BrainTypography.bodyMd
                .copyWith(color: BrainColors.onSurface)),
      ),
      body: notes.isEmpty
          ? Center(
              child: Text('Noch keine Gedanken',
                  style: BrainTypography.bodyMd
                      .copyWith(color: BrainColors.onSurfaceVariant)),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                BrainSpacing.screenPadding,
                BrainSpacing.md,
                BrainSpacing.screenPadding,
                BrainSpacing.xxl,
              ),
              itemCount: notes.length,
              separatorBuilder: (_, _x) =>
                  const SizedBox(height: BrainSpacing.sm),
              itemBuilder: (_, i) {
                final note = notes[i];
                return BrainCard(
                  glass: true,
                  tintColor: hallColor(note.hall),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteDetailScreen(noteId: note.id),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title,
                              style: BrainTypography.bodySm.copyWith(
                                fontWeight: FontWeight.w600,
                                color: BrainColors.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (note.excerpt.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(note.excerpt,
                                  style: BrainTypography.bodySm,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: BrainSpacing.sm),
                      Text(note.relativeTime,
                          style: BrainTypography.bodySm.copyWith(
                            fontSize: 11,
                            color: BrainColors.onSurfaceVariant
                                .withValues(alpha: 0.50),
                          )),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
