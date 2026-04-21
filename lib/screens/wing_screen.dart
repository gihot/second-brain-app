import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../widgets/brain_card.dart';
import '../widgets/hall_badge.dart';
import 'note_detail_screen.dart';

/// Shows all notes belonging to a Wing, grouped by Hall.
class WingScreen extends StatelessWidget {
  final String wing;
  final String display;

  const WingScreen({super.key, required this.wing, required this.display});

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final notes =
        vault.notes.where((n) => n.wing == wing).toList();

    // Group by hall
    final byHall = <MemoryHall, List<Note>>{};
    for (final n in notes) {
      byHall.putIfAbsent(n.hall, () => []).add(n);
    }
    final hallOrder = [
      MemoryHall.fact,
      MemoryHall.discovery,
      MemoryHall.preference,
      MemoryHall.advice,
      MemoryHall.event,
      MemoryHall.unclassified,
    ];

    return Scaffold(
      backgroundColor: BrainColors.base,
      appBar: AppBar(
        backgroundColor: BrainColors.base,
        title: Text(display, style: BrainTypography.headlineSm),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: notes.isEmpty
          ? Center(
              child: Text(
                'Noch keine Gedanken in diesem Wing',
                style: BrainTypography.bodyMd
                    .copyWith(color: BrainColors.onSurfaceVariant),
              ),
            )
          : CustomScrollView(
              slivers: [
                for (final hall in hallOrder)
                  if (byHall.containsKey(hall)) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          BrainSpacing.screenPadding,
                          BrainSpacing.lg,
                          BrainSpacing.screenPadding,
                          BrainSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: hallColor(hall),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              hallLabel(hall).toUpperCase(),
                              style: BrainTypography.labelSm
                                  .copyWith(color: hallColor(hall)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: BrainSpacing.paddingScreen,
                      sliver: SliverList.separated(
                        itemCount: byHall[hall]!.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: BrainSpacing.cardGap),
                        itemBuilder: (ctx, i) {
                          final note = byHall[hall]![i];
                          return BrainCard(
                            showBorder: true,
                            leftBorderColor: hallColor(hall),
                            onTap: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NoteDetailScreen(noteId: note.id),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.title,
                                  style: BrainTypography.bodyMd.copyWith(
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
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ],
                                const SizedBox(height: BrainSpacing.xs),
                                Text(note.relativeTime,
                                    style: BrainTypography.labelSm),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: BrainSpacing.xxl),
                ),
              ],
            ),
    );
  }
}
