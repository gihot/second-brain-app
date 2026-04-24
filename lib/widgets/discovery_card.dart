import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/vault_provider.dart';
import '../providers/discovery_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../screens/note_detail_screen.dart';

/// Proaktive Dashboard-Card — ersetzt den statischen Greeting-Header.
///
/// Priorität der angezeigten Insight:
///   1. Fällige Erinnerung (lokal, sofort)
///   2. Verbindungs-Entdeckung (Server, async geladen)
///   3. Verwandter Gedanke (letzter Capture, lokal)
///   4. Muster-Beobachtung (häufigster Tag, lokal)
///   5. Fallback: Greeting
class DiscoveryCard extends StatelessWidget {
  const DiscoveryCard({super.key});

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
    final discovery = context.watch<DiscoveryProvider>();

    // 1. Fällige Erinnerung
    if (vault.dueReminders.isNotEmpty) {
      return _ReminderInsight(note: vault.dueReminders.first);
    }

    // 2. Verbindungs-Entdeckung (Server)
    if (discovery.hasConnection) {
      final conn = discovery.connection!;
      return _ConnectionInsight(
        noteATitle: conn['note_a_title'] as String? ?? '',
        noteBTitle: conn['note_b_title'] as String? ?? '',
        explanation: conn['explanation'] as String? ?? '',
      );
    }

    // 3. Verwandter Gedanke (letzter Capture)
    if (vault.recentNotes.isNotEmpty) {
      return _RelatedInsight(note: vault.recentNotes.first, context: context);
    }

    // 4. Muster-Beobachtung (häufigster Tag)
    if (vault.tagFrequencies.isNotEmpty) {
      final topTag = vault.tagFrequencies.first.key;
      return _PatternInsight(topic: topTag);
    }

    // 5. Fallback: klassischer Greeting + Loading-Indikator
    return _GreetingFallback(
      greeting: _greeting,
      loading: discovery.loading,
    );
  }
}

// ── Insight Varianten ─────────────────────────────────────────────────────────

class _ReminderInsight extends StatelessWidget {
  final Note note;
  const _ReminderInsight({required this.note});

  @override
  Widget build(BuildContext context) {
    return _InsightShell(
      label: 'JETZT FÄLLIG',
      labelColor: BrainColors.tertiary,
      icon: Icons.alarm_rounded,
      iconColor: BrainColors.tertiary,
      borderColor: BrainColors.tertiary,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
      ),
      child: Text(
        note.title,
        style: BrainTypography.headlineSm
            .copyWith(color: BrainColors.onSurface),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ConnectionInsight extends StatelessWidget {
  final String noteATitle;
  final String noteBTitle;
  final String explanation;

  const _ConnectionInsight({
    required this.noteATitle,
    required this.noteBTitle,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    return _InsightShell(
      label: 'VERBINDUNG ENTDECKT',
      labelColor: BrainColors.secondary,
      icon: Icons.hub_outlined,
      iconColor: BrainColors.secondary,
      borderColor: BrainColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  noteATitle,
                  style: BrainTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: BrainColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BrainSpacing.sm),
                child: Icon(Icons.swap_horiz_rounded,
                    size: 16, color: BrainColors.secondary),
              ),
              Expanded(
                child: Text(
                  noteBTitle,
                  style: BrainTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: BrainColors.onSurface),
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
}

class _RelatedInsight extends StatelessWidget {
  final Note note;
  final BuildContext context;
  const _RelatedInsight({required this.note, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return _InsightShell(
      label: 'LETZTER GEDANKE',
      labelColor: BrainColors.primary,
      icon: Icons.psychology_outlined,
      iconColor: BrainColors.primary,
      borderColor: BrainColors.primary,
      onTap: () => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.title,
            style: BrainTypography.headlineSm
                .copyWith(color: BrainColors.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (note.excerpt.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              note.excerpt,
              style: BrainTypography.bodySm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _PatternInsight extends StatelessWidget {
  final String topic;
  const _PatternInsight({required this.topic});

  @override
  Widget build(BuildContext context) {
    return _InsightShell(
      label: 'DEIN MUSTER',
      labelColor: BrainColors.outline,
      icon: Icons.trending_up_rounded,
      iconColor: BrainColors.outline,
      borderColor: BrainColors.outline,
      child: Text(
        'Du schreibst oft über #$topic',
        style: BrainTypography.headlineSm
            .copyWith(color: BrainColors.onSurface),
      ),
    );
  }
}

class _GreetingFallback extends StatelessWidget {
  final String greeting;
  final bool loading;
  const _GreetingFallback({required this.greeting, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrainSpacing.screenPadding,
        BrainSpacing.xxl,
        BrainSpacing.screenPadding,
        BrainSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SYSTEM STATUS: ACTIVE',
                style: BrainTypography.labelSm
                    .copyWith(color: BrainColors.secondary),
              ),
              if (loading) ...[
                const SizedBox(width: BrainSpacing.sm),
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: BrainColors.secondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: BrainSpacing.sm),
          Text('$greeting.', style: BrainTypography.displayMd),
        ],
      ),
    );
  }
}

// ── Shell ─────────────────────────────────────────────────────────────────────

class _InsightShell extends StatelessWidget {
  final String label;
  final Color labelColor;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final Widget child;
  final VoidCallback? onTap;

  const _InsightShell({
    required this.label,
    required this.labelColor,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrainSpacing.screenPadding,
        BrainSpacing.xxl,
        BrainSpacing.screenPadding,
        BrainSpacing.lg,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: BrainSpacing.paddingCard,
          decoration: BoxDecoration(
            color: borderColor.withValues(alpha: 0.06),
            borderRadius: BrainSpacing.radiusMd,
            border: Border.all(
              color: borderColor.withValues(alpha: 0.20),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: iconColor),
                  const SizedBox(width: 5),
                  Text(label,
                      style: BrainTypography.labelSm
                          .copyWith(color: labelColor)),
                  if (onTap != null) ...[
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 11, color: labelColor),
                  ],
                ],
              ),
              const SizedBox(height: BrainSpacing.sm),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
