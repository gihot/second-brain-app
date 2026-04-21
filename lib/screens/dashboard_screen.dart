import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../widgets/brain_stat_card.dart';
import '../widgets/brain_card.dart';
import '../widgets/tag_cloud.dart';
import '../models/note_model.dart';
import '../widgets/hall_badge.dart';
import 'note_detail_screen.dart';
import 'agent_chat_screen.dart';
import 'search_screen.dart';
import 'wing_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Gute Nacht';
    if (hour < 12) return 'Guten Morgen';
    if (hour < 18) return 'Guten Tag';
    return 'Guten Abend';
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();

    return CustomScrollView(
      slivers: [
        // System label + Greeting
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BrainSpacing.screenPadding,
              BrainSpacing.xxl,
              BrainSpacing.screenPadding,
              BrainSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM STATUS: ACTIVE',
                  style: BrainTypography.labelSm.copyWith(
                    color: BrainColors.secondary,
                  ),
                ),
                const SizedBox(height: BrainSpacing.sm),
                Text('$_greeting.', style: BrainTypography.displayMd),
              ],
            ),
          ),
        ),

        // Stat Cards Grid
        SliverPadding(
          padding: BrainSpacing.paddingScreen,
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: BrainSpacing.cardGap,
            crossAxisSpacing: BrainSpacing.cardGap,
            childAspectRatio: 1.4,
            children: [
              BrainStatCard(
                value: '${vault.status.totalNotes}',
                label: 'Gedanken',
                icon: Icons.description_outlined,
                accentColor: BrainColors.primary,
              ),
              BrainStatCard(
                value: '${vault.status.inboxCount}',
                label: 'Inbox',
                icon: Icons.inbox_outlined,
                accentColor: BrainColors.tertiary,
              ),
              BrainStatCard(
                value: '${vault.status.connectedCount}',
                label: 'Connected',
                icon: Icons.hub_outlined,
                accentColor: BrainColors.secondary,
              ),
              BrainStatCard(
                value: vault.status.lastSyncText,
                label: 'Last Sync',
                icon: Icons.sync_outlined,
                accentColor: BrainColors.outline,
              ),
            ],
          ),
        ),

        // PARA Distribution chart
        if (vault.notes.isNotEmpty)
          SliverPadding(
            padding: BrainSpacing.paddingScreen,
            sliver: SliverToBoxAdapter(
              child: _ParaChart(distribution: vault.paraDistribution),
            ),
          ),

        // Tag Cloud
        if (vault.tagFrequencies.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              BrainSpacing.screenPadding,
              0,
              BrainSpacing.screenPadding,
              BrainSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOPICS', style: BrainTypography.labelSm),
                  const SizedBox(height: BrainSpacing.sm),
                  TagCloud(
                    frequencies: vault.tagFrequencies,
                    onTagTap: (tag) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(initialQuery: tag),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Wings section
        if (vault.wings.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              BrainSpacing.screenPadding,
              0,
              BrainSpacing.screenPadding,
              BrainSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WINGS', style: BrainTypography.labelSm),
                  const SizedBox(height: BrainSpacing.sm),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: vault.wings.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: BrainSpacing.sm),
                      itemBuilder: (ctx, i) {
                        final w = vault.wings[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => WingScreen(
                                wing: w['wing'] as String,
                                display: w['display'] as String,
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: BrainColors.surfaceLow,
                              borderRadius: BrainSpacing.radiusMd,
                              border: Border.all(
                                color: BrainColors.outlineVariant
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w['display'] as String,
                                    style: BrainTypography.bodyMd.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: BrainColors.onSurface)),
                                Text('${w['count']} Gedanken',
                                    style: BrainTypography.labelSm),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Ask your Brain card
        SliverPadding(
          padding: BrainSpacing.paddingScreen,
          sliver: SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AgentChatScreen()),
              ),
              child: Container(
                padding: BrainSpacing.paddingCard,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      BrainColors.primary.withValues(alpha: 0.12),
                      BrainColors.secondary.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BrainSpacing.radiusMd,
                  border: Border.all(
                    color: BrainColors.primary.withValues(alpha: 0.20),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.psychology_outlined,
                        color: BrainColors.primary, size: 22),
                    const SizedBox(width: BrainSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Frag dein Gehirn',
                              style: BrainTypography.bodyMd.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: BrainColors.onSurface)),
                          Text('Chat mit Seeker, Librarian oder Connector',
                              style: BrainTypography.bodySm),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: BrainColors.outline),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Recent Notes header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BrainSpacing.screenPadding,
              BrainSpacing.lg,
              BrainSpacing.screenPadding,
              BrainSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Letzte Gedanken', style: BrainTypography.headlineSm),
                Text(
                  'Alle anzeigen',
                  style: BrainTypography.bodySm
                      .copyWith(color: BrainColors.primary),
                ),
              ],
            ),
          ),
        ),

        // Recent Notes list or empty state
        if (vault.recentNotes.isEmpty)
          SliverPadding(
            padding: BrainSpacing.paddingScreen,
            sliver: SliverToBoxAdapter(
              child: BrainCard(
                padding: const EdgeInsets.all(BrainSpacing.xxl),
                child: Column(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 40, color: BrainColors.outline),
                    const SizedBox(height: BrainSpacing.md),
                    Text(
                      'Dein Gehirn ist leer',
                      style: BrainTypography.headlineSm
                          .copyWith(color: BrainColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: BrainSpacing.xs),
                    Text(
                      'Tippe auf Capture, um deinen ersten Gedanken hinzuzufügen',
                      style: BrainTypography.bodySm,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: BrainSpacing.paddingScreen,
            sliver: SliverList.separated(
              itemCount: vault.recentNotes.length,
              separatorBuilder: (_, _x) =>
                  const SizedBox(height: BrainSpacing.cardGap),
              itemBuilder: (context, i) {
                final note = vault.recentNotes[i];
                return BrainCard(
                  showBorder: true,
                  leftBorderColor: hallColor(note.hall),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: BrainSpacing.sm),
                      Text(note.relativeTime, style: BrainTypography.labelSm),
                    ],
                  ),
                );
              },
            ),
          ),

        const SliverToBoxAdapter(
          child: SizedBox(
              height: BrainSpacing.bottomNavHeight + BrainSpacing.xl),
        ),
      ],
    );
  }
}

// ── PARA Distribution Bar ─────────────────────────────────────────────────

class _ParaChart extends StatelessWidget {
  final Map<ParaCategory, int> distribution;

  const _ParaChart({required this.distribution});

  static const _colors = {
    ParaCategory.projects: BrainColors.primary,
    ParaCategory.areas: BrainColors.secondary,
    ParaCategory.resources: BrainColors.tertiary,
    ParaCategory.archive: BrainColors.outline,
    ParaCategory.inbox: BrainColors.surfaceHighest,
  };

  static const _labels = {
    ParaCategory.projects: 'Projects',
    ParaCategory.areas: 'Areas',
    ParaCategory.resources: 'Resources',
    ParaCategory.archive: 'Archive',
    ParaCategory.inbox: 'Inbox',
  };

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('KNOWLEDGE MAP', style: BrainTypography.labelSm),
        const SizedBox(height: BrainSpacing.sm),
        // Stacked bar using Expanded flex
        ClipRRect(
          borderRadius: BrainSpacing.radiusSm,
          child: SizedBox(
            height: 8,
            child: Row(
              children: ParaCategory.values
                  .where((c) => (distribution[c] ?? 0) > 0)
                  .map((c) => Expanded(
                        flex: distribution[c]!,
                        child: Container(color: _colors[c]),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: BrainSpacing.sm),
        // Legend
        Wrap(
          spacing: BrainSpacing.md,
          runSpacing: 4,
          children: ParaCategory.values
              .where((c) => (distribution[c] ?? 0) > 0)
              .map((c) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _colors[c],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_labels[c]} ${distribution[c]}',
                        style: BrainTypography.labelSm,
                      ),
                    ],
                  ))
              .toList(),
        ),
      ],
    );
  }
}
