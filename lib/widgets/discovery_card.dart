import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/discovery_provider.dart';
import '../services/cache_service.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Proaktive Dashboard-Card. Zeigt entweder eine Verbindungs-Entdeckung
/// (echte Retrieval-Hilfe) oder — wenn keine vorliegt — eine schlichte
/// Begrüßungszeile.
///
/// Hinweis: Frühere Insight-Varianten (Reminder / Related / Pattern) wurden
/// bewusst entfernt (Dashboard-Diät). Ihre alten Dismiss-Keys
/// (`reminder:` / `related:` / `pattern:`) können noch in der
/// `insight_dismissed_v1`-Map liegen — die 24h-TTL-Prune-Logik in
/// CacheService räumt sie von selbst weg, kein Migrations-Code nötig.
class DiscoveryCard extends StatefulWidget {
  const DiscoveryCard({super.key});

  @override
  State<DiscoveryCard> createState() => _DiscoveryCardState();
}

class _DiscoveryCardState extends State<DiscoveryCard> {
  // Local mirror of dismissed keys so a dismiss in this session takes effect
  // immediately without waiting for Hive read-after-write.
  final Set<String> _localDismissed = {};

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Gute Nacht';
    if (hour < 12) return 'Guten Morgen';
    if (hour < 18) return 'Guten Tag';
    return 'Guten Abend';
  }

  bool _isDismissed(String key) =>
      _localDismissed.contains(key) ||
      CacheService.instance.isInsightDismissed(key);

  void _dismiss(String key) {
    CacheService.instance.markInsightDismissed(key);
    setState(() {
      _localDismissed.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final discovery = context.watch<DiscoveryProvider>();

    // Verbindungs-Entdeckung (Server) — die einzige echte Retrieval-Insight.
    if (discovery.hasConnection) {
      final conn = discovery.connection!;
      final a = conn['note_a_title'] as String? ?? '';
      final b = conn['note_b_title'] as String? ?? '';
      final key = 'connection:$a::$b';
      if (!_isDismissed(key)) {
        return _ConnectionInsight(
          noteATitle: a,
          noteBTitle: b,
          explanation: conn['explanation'] as String? ?? '',
          onDismiss: () => _dismiss(key),
        );
      }
    }

    // Sonst: schlichte Begrüßung.
    return _GreetingFallback(
      greeting: _greeting,
      loading: discovery.loading,
    );
  }
}

// ── Insight Varianten ─────────────────────────────────────────────────────────

class _ConnectionInsight extends StatelessWidget {
  final String noteATitle;
  final String noteBTitle;
  final String explanation;
  final VoidCallback? onDismiss;

  const _ConnectionInsight({
    required this.noteATitle,
    required this.noteBTitle,
    required this.explanation,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return _InsightShell(
      label: 'VERBINDUNG ENTDECKT',
      labelColor: BrainColors.secondary,
      icon: Icons.hub_outlined,
      iconColor: BrainColors.secondary,
      borderColor: BrainColors.secondary,
      onDismiss: onDismiss,
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
                'SYSTEM AKTIV',
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
  final VoidCallback? onDismiss;

  const _InsightShell({
    required this.label,
    required this.labelColor,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.child,
    this.onDismiss,
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
                  const Spacer(),
                  if (onDismiss != null)
                    InkWell(
                      onTap: onDismiss,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.close_rounded,
                            size: 14, color: BrainColors.outline),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: BrainSpacing.sm),
              child,
            ],
          ),
      ),
    );
  }
}
