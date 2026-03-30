import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../widgets/brain_stat_card.dart';
import '../widgets/brain_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
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
                label: 'Notes',
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
                Text('Recent Notes', style: BrainTypography.headlineSm),
                Text(
                  'See all',
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
                      'Your brain is empty',
                      style: BrainTypography.headlineSm
                          .copyWith(color: BrainColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: BrainSpacing.xs),
                    Text(
                      'Tap Capture to add your first thought',
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
                  onTap: () {}, // TODO: navigate to NoteView
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
