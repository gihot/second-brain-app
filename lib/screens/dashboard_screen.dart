import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../providers/discovery_provider.dart';
import '../widgets/brain_card.dart';
import '../widgets/tag_cloud.dart';
import '../widgets/hall_badge.dart';
import '../widgets/dashboard_hero.dart';
import '../models/note_model.dart';
import 'all_notes_screen.dart';
import 'note_detail_screen.dart';
import 'agent_chat_screen.dart';
import 'search_screen.dart';
import 'wing_screen.dart';

// Hinweis: discovery_card.dart wurde entfernt. Greeting + Connection-Insight
// leben jetzt im DashboardHero. Alte insight_dismissed_v1-Keys (reminder:/
// related:/pattern:) verfallen via 24h-TTL-Prune in CacheService von selbst.

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _tagsExpanded = false;

  void _showRemindersSheet(List<Note> reminders) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BrainColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BrainSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BrainColors.outlineVariant.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: BrainSpacing.md),
              Text('Fällige Erinnerungen',
                  style: BrainTypography.headlineSm),
              const SizedBox(height: BrainSpacing.sm),
              ...reminders.map((note) => Padding(
                    padding: const EdgeInsets.only(bottom: BrainSpacing.sm),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                NoteDetailScreen(noteId: note.id),
                          ),
                        );
                      },
                      child: Container(
                        padding: BrainSpacing.paddingCard,
                        decoration: BoxDecoration(
                          color: BrainColors.tertiary.withValues(alpha: 0.08),
                          borderRadius: BrainSpacing.radiusMd,
                          border: Border.all(
                            color:
                                BrainColors.tertiary.withValues(alpha: 0.25),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.alarm_rounded,
                                size: 16, color: BrainColors.tertiary),
                            const SizedBox(width: BrainSpacing.sm),
                            Expanded(
                              child: Text(
                                note.title,
                                style: BrainTypography.bodyMd.copyWith(
                                  color: BrainColors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 12, color: BrainColors.tertiary),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return 'Gute Nacht';
    if (h < 12) return 'Guten Morgen';
    if (h < 18) return 'Guten Tag';
    return 'Guten Abend';
  }

  /// Condenses current context into a single status line. Returns null
  /// when nothing is mentally relevant — the hero then stays minimal.
  String? _statusLine(VaultProvider vault, DiscoveryProvider discovery) {
    final reminders = vault.dueReminders.length;
    final inbox = vault.status.inboxCount;
    final hasConn = discovery.hasConnection;

    if (reminders > 0) {
      return '$reminders ${reminders == 1 ? "Erinnerung wartet" : "Erinnerungen warten"}';
    }
    if (inbox > 0 && hasConn) {
      return '$inbox zum Sortieren · neue Verbindung';
    }
    if (inbox > 0) {
      return '$inbox ${inbox == 1 ? "Gedanke wartet" : "Gedanken warten"} auf Sortierung';
    }
    if (hasConn) return 'Neue Verbindung entdeckt';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final discovery = context.watch<DiscoveryProvider>();
    final statusLine = _statusLine(vault, discovery);

    return CustomScrollView(
      slivers: [
        // 1. Hero — Identität + Begrüßung + konditionelle Status-Zeile
        SliverToBoxAdapter(
          child: DashboardHero(
            greeting: _greeting,
            statusLine: statusLine,
            onStatusTap: vault.dueReminders.isNotEmpty
                ? () => _showRemindersSheet(vault.dueReminders)
                : null,
          ),
        ),

        // 2. Capture Surface — folgt in A6.

        // 3. Recent Notes — PRIME real estate
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
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AllNotesScreen()),
                  ),
                  child: Text(
                    'Alle anzeigen',
                    style: BrainTypography.bodySm
                        .copyWith(color: BrainColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              itemCount: vault.recentNotes.length > 5
                  ? 5
                  : vault.recentNotes.length,
              separatorBuilder: (_, _x) =>
                  const SizedBox(height: BrainSpacing.cardGap),
              itemBuilder: (context, i) {
                final note = vault.recentNotes[i];
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
                      Text(note.relativeTime,
                          style: BrainTypography.labelSm),
                    ],
                  ),
                );
              },
            ),
          ),

        // 4. Ask your Brain card
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            BrainSpacing.screenPadding,
            BrainSpacing.lg,
            BrainSpacing.screenPadding,
            0,
          ),
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
                          Text('Finde und verknüpfe deine Gedanken',
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

        // 5. Tag Cloud
        if (vault.tagFrequencies.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              BrainSpacing.screenPadding,
              BrainSpacing.lg,
              BrainSpacing.screenPadding,
              BrainSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THEMEN', style: BrainTypography.labelSm),
                  const SizedBox(height: BrainSpacing.sm),
                  TagCloud(
                    frequencies: vault.tagFrequencies,
                    maxItems: 10,
                    showAll: _tagsExpanded,
                    onShowAll: () => setState(() => _tagsExpanded = true),
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

        // 6. Wings section
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
                  Text('SAMMLUNGEN', style: BrainTypography.labelSm),
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

        const SliverToBoxAdapter(
          child: SizedBox(
              height: BrainSpacing.bottomNavHeight + BrainSpacing.xl),
        ),
      ],
    );
  }
}

