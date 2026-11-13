import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../providers/auth_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/resurfacing_provider.dart';
import '../widgets/brain_card.dart';
import '../widgets/tag_cloud.dart';
import '../widgets/hall_badge.dart';
import '../widgets/dashboard_hero.dart';
import '../widgets/capture_surface.dart';
import '../widgets/ambient_retrieval.dart';
import '../models/note_model.dart';
import '../utils/dashboard_signals.dart' as signals;
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

  void _showRemindersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BrainColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final reminders = sheetCtx.watch<VaultProvider>().dueReminders;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(BrainSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fällige Erinnerungen', style: BrainTypography.headlineSm),
                const SizedBox(height: BrainSpacing.sm),
                if (reminders.isEmpty)
                  Text('Gerade ist keine Erinnerung fällig.', style: BrainTypography.bodyMd),
                Expanded(
                  child: ListView.builder(
                    itemCount: reminders.length,
                    itemBuilder: (_, index) {
                      final note = reminders[index];
                      return ListTile(
                        leading: const Icon(Icons.alarm_rounded, color: BrainColors.tertiary),
                        title: Text(note.title),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// J2: Konflikt-Auflösungs-Sheet. Pro Konflikt-Fork zwei Aktionen:
  /// "Verwerfen" (löscht die lokale Kopie) und "Als neue Notiz behalten"
  /// (entfernt den Konflikt-Marker aus dem Titel, Notiz bleibt lokal).
  void _showConflictSheet(List<Note> conflicts) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: BrainColors.surfaceLow,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _ConflictSheet(
        conflicts: conflicts,
        onDiscard: (note) async {
          await context.read<VaultProvider>().deleteNote(note.id);
          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
        },
        onKeep: (note) async {
          // Konflikt-Marker aus dem Titel strippen, Notiz bleibt local.
          final cleanTitle = note.title
              .replaceAll(RegExp(r'\s*\(Konflikt[^)]*\)\s*$'), '')
              .trim();
          await context
              .read<VaultProvider>()
              .updateNote(note.copyWith(title: cleanTitle));
          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
        },
      ),
    );
  }

  /// Tap auf eine Resurface-Karte: erst Engaged-Signal (Provider entfernt
  /// die Karte optimistisch + pausiert 30 Tage server-seitig), dann
  /// Navigation. Reihenfolge irrelevant — Navigator wartet nicht auf den
  /// Server.
  void _openResurfaced(Note note) {
    context.read<ResurfacingProvider>().markEngaged(note.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteDetailScreen(noteId: note.id),
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

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final discovery = context.watch<DiscoveryProvider>();
    final resurfacing = context.watch<ResurfacingProvider>();
    final statusLine = signals.statusLine(
      dueReminders: vault.dueReminders.length,
      inboxCount: vault.status.inboxCount,
    );
    // Wave 3: Server liefert IDs, wir resolven gegen den lokalen Cache.
    // Wenn der Server nichts geliefert hat (Offline / Index aus), bleibt
    // der lokale Pseudo-Zufall als Fallback — Spec: Dashboard nie tot.
    final localById = {for (final n in vault.notes) n.id: n};
    final serverResurfaced = resurfacing.noteIds
        .map((id) => localById[id])
        .whereType<Note>()
        .toList(growable: false);
    final fallbackResurfaced = serverResurfaced.isEmpty
        ? signals.resurfacedNote(vault.notes)
        : null;

    final auth = context.watch<AuthProvider>();

    return CustomScrollView(
      slivers: [
        // 0. Pending-Deletion-Banner — nur sichtbar wenn Account in
        //    Soft-Delete-Frist steht. Roter Banner, Tap stellt wieder her.
        if (auth.isPendingDeletion)
          SliverToBoxAdapter(
            child: _PendingDeletionBanner(
              deletionAtIso: auth.pendingDeletionAt!,
              onRestore: () => auth.cancelPendingDeletion(),
            ),
          ),
        // 0b. Konflikt-Banner — J2: lokale Konflikt-Forks aus dem Sync.
        //     Tap öffnet das Auflösungs-Sheet.
        if (vault.conflictCopies.isNotEmpty)
          SliverToBoxAdapter(
            child: _ConflictBanner(
              count: vault.conflictCopies.length,
              onTap: () => _showConflictSheet(vault.conflictCopies),
            ),
          ),
        // 1. Hero — Identität + Begrüßung + konditionelle Status-Zeile
        SliverToBoxAdapter(
          child: DashboardHero(
            greeting: _greeting,
            statusLine: statusLine,
            onStatusTap: vault.dueReminders.isNotEmpty
                ? _showRemindersSheet
                : null,
          ),
        ),

        // 2. Capture Surface — lebendes Capture-Modul
        SliverToBoxAdapter(
          child: CaptureSurface(
            captureCount: vault.capturesToday,
            inboxCount: vault.status.inboxCount,
          ),
        ),

        // 2b. Ambient surfacing — taucht nur auf wenn relevant
        SliverToBoxAdapter(
          child: AmbientRetrieval(
            connection: discovery.hasConnection ? discovery.connection : null,
            onDismissConnection: () =>
                context.read<DiscoveryProvider>().dismiss(),
            resurfacedNotes: serverResurfaced,
            fallbackResurfaced: fallbackResurfaced,
            onResurfacedTap: _openResurfaced,
          ),
        ),

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


/// Plan 4.2: roter Banner ganz oben auf dem Dashboard, solange der
/// Account in Soft-Delete-Frist ist. Tap auf „Wiederherstellen" ruft
/// /auth/cancel-deletion — Banner verschwindet sofort.
class _PendingDeletionBanner extends StatelessWidget {
  final String deletionAtIso;
  final Future<bool> Function() onRestore;

  const _PendingDeletionBanner({
    required this.deletionAtIso,
    required this.onRestore,
  });

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}.${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrainSpacing.screenPadding,
        BrainSpacing.sm,
        BrainSpacing.screenPadding,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(BrainSpacing.md),
        decoration: BoxDecoration(
          color: BrainColors.error.withValues(alpha: 0.10),
          borderRadius: BrainSpacing.radiusMd,
          border: Border.all(
            color: BrainColors.error.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 20, color: BrainColors.error),
            const SizedBox(width: BrainSpacing.sm),
            Expanded(
              child: Text(
                'Dein Account wird am ${_formatDate(deletionAtIso)} '
                'gelöscht.',
                style: BrainTypography.bodyMd.copyWith(
                  color: BrainColors.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final ok = await onRestore();
                if (!ok || !context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Löschung aufgehoben.'),
                    backgroundColor: BrainColors.surfaceHigh,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                'Wiederherstellen',
                style: BrainTypography.button.copyWith(
                  color: BrainColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// J2 (Plan v2): Banner für lokale Konflikt-Forks. Tertiär-getönt
/// (nicht rot wie Pending-Deletion — Konflikte sind kein Notfall,
/// nur "schau mal drüber"). Tap öffnet das Auflösungs-Sheet.
class _ConflictBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ConflictBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrainSpacing.screenPadding,
        BrainSpacing.sm,
        BrainSpacing.screenPadding,
        0,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BrainSpacing.radiusMd,
        child: Container(
          padding: const EdgeInsets.all(BrainSpacing.md),
          decoration: BoxDecoration(
            color: BrainColors.tertiary.withValues(alpha: 0.10),
            borderRadius: BrainSpacing.radiusMd,
            border: Border.all(
              color: BrainColors.tertiary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.merge_type_rounded,
                  size: 20, color: BrainColors.tertiary),
              const SizedBox(width: BrainSpacing.sm),
              Expanded(
                child: Text(
                  count == 1
                      ? '1 Sync-Konflikt zu prüfen'
                      : '$count Sync-Konflikte zu prüfen',
                  style: BrainTypography.bodyMd.copyWith(
                    color: BrainColors.onSurface,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: BrainColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// J2: Auflösungs-Sheet. Pro Konflikt-Fork: Titel + Excerpt + zwei
/// Aktionen. "Verwerfen" (löscht lokal) und "Behalten" (entfernt den
/// Konflikt-Marker, Notiz bleibt lokal).
class _ConflictSheet extends StatelessWidget {
  final List<Note> conflicts;
  final Future<void> Function(Note) onDiscard;
  final Future<void> Function(Note) onKeep;

  const _ConflictSheet({
    required this.conflicts,
    required this.onDiscard,
    required this.onKeep,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BrainSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync-Konflikte', style: BrainTypography.titleMd),
            const SizedBox(height: BrainSpacing.xs),
            Text(
              'Diese Versionen kamen vom Server, während du lokal andere '
              'Änderungen hattest. Beide wurden behalten — entscheide pro '
              'Eintrag.',
              style: BrainTypography.bodySm.copyWith(
                color: BrainColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: BrainSpacing.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: conflicts.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: BrainSpacing.sm),
                itemBuilder: (_, i) {
                  final note = conflicts[i];
                  return Container(
                    padding: const EdgeInsets.all(BrainSpacing.md),
                    decoration: BoxDecoration(
                      color: BrainColors.surfaceHigh,
                      borderRadius: BrainSpacing.radiusSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: BrainTypography.bodyMd.copyWith(
                            color: BrainColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (note.excerpt.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            note.excerpt,
                            style: BrainTypography.bodySm,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: BrainSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => onDiscard(note),
                              child: Text(
                                'Verwerfen',
                                style: BrainTypography.button.copyWith(
                                  color: BrainColors.error,
                                ),
                              ),
                            ),
                            const SizedBox(width: BrainSpacing.sm),
                            TextButton(
                              onPressed: () => onKeep(note),
                              child: Text(
                                'Behalten',
                                style: BrainTypography.button.copyWith(
                                  color: BrainColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
