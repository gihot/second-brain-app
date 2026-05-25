import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/search_provider.dart';
import '../providers/vault_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../widgets/brain_card.dart';
import '../widgets/brain_input.dart';
import '../widgets/hall_badge.dart';
import 'note_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SearchProvider>().submitSearch(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final wings = context.watch<VaultProvider>().wings;

    // When pushed as a route (e.g. from a tag tap on the dashboard) we have
    // no parent Scaffold — Navigator's default surface is light, which made
    // the page render white and trapped back-navigation. Detect that case
    // (canPop == true means we are not the initial route inside AppShell)
    // and wrap with a proper Scaffold + back button.
    final isPushedRoute = Navigator.of(context).canPop();

    final body = Padding(
      padding: EdgeInsets.only(
        top: isPushedRoute ? BrainSpacing.sm : BrainSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isPushedRoute) ...[
            Padding(
              padding: BrainSpacing.paddingScreen,
              child: Text('Suche', style: BrainTypography.displayMd),
            ),
            const SizedBox(height: BrainSpacing.md),
          ],

          // Search input
          Padding(
            padding: BrainSpacing.paddingScreen,
            child: BrainInput(
              controller: _controller,
              hint: 'Suche in deinem Gehirn...',
              prefixIcon: Icons.search_rounded,
              onChanged: context.read<SearchProvider>().search,
              onSubmitted: (q) {
                context.read<SearchProvider>().submitSearch(q);
              },
            ),
          ),

          // Filter row: Hall + Wing
          if (wings.isNotEmpty || true) ...[
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: BrainSpacing.paddingScreen,
                children: [
                  // Hall filter
                  PopupMenuButton<MemoryHall?>(
                    color: BrainColors.surfaceHigh,
                    onSelected: context.read<SearchProvider>().setHallFilter,
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: null,
                        onTap: () =>
                            ctx.read<SearchProvider>().setHallFilter(null),
                        child: const Text('Alle Kategorien'),
                      ),
                      ...MemoryHall.values.map(
                        (h) =>
                            PopupMenuItem(value: h, child: Text(hallLabel(h))),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: search.hallFilter != null
                            ? hallColor(
                                search.hallFilter!,
                              ).withValues(alpha: 0.15)
                            : BrainColors.surfaceHigh,
                        borderRadius: BrainSpacing.radiusFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            search.hallFilter != null
                                ? hallLabel(search.hallFilter!)
                                : 'Kategorie',
                            style: BrainTypography.labelSm.copyWith(
                              color: search.hallFilter != null
                                  ? hallColor(search.hallFilter!)
                                  : BrainColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 16,
                            color: search.hallFilter != null
                                ? hallColor(search.hallFilter!)
                                : BrainColors.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: BrainSpacing.sm),
                  // Wing filter
                  if (wings.isNotEmpty)
                    PopupMenuButton<String?>(
                      color: BrainColors.surfaceHigh,
                      onSelected: context.read<SearchProvider>().setWingFilter,
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: null,
                          child: Text('Alle Sammlungen'),
                        ),
                        ...wings.map(
                          (w) => PopupMenuItem(
                            value: w['wing'] as String,
                            child: Text(w['display'] as String),
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: search.wingFilter != null
                              ? BrainColors.primary.withValues(alpha: 0.12)
                              : BrainColors.surfaceHigh,
                          borderRadius: BrainSpacing.radiusFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              search.wingFilter != null
                                  ? search.wingFilter!
                                        .split('-')
                                        .map(
                                          (w) => w.isEmpty
                                              ? w
                                              : w[0].toUpperCase() +
                                                    w.substring(1),
                                        )
                                        .join(' ')
                                  : 'Sammlung',
                              style: BrainTypography.labelSm.copyWith(
                                color: search.wingFilter != null
                                    ? BrainColors.primary
                                    : BrainColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 16,
                              color: search.wingFilter != null
                                  ? BrainColors.primary
                                  : BrainColors.outline,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: BrainSpacing.sm),

          // Recent searches or results
          Expanded(
            child: search.hasQuery
                ? _ResultsList(
                    results: search.results,
                    query: search.query,
                    scoreFor: search.scoreFor,
                    onWingChipTap: (w) =>
                        context.read<SearchProvider>().setWingFilter(w),
                  )
                : _RecentSearches(
                    searches: search.recentSearches,
                    onTap: (q) {
                      _controller.text = q;
                      context.read<SearchProvider>().submitSearch(q);
                    },
                  ),
          ),
        ],
      ),
    );

    if (!isPushedRoute) return body;

    return Scaffold(
      backgroundColor: BrainColors.base,
      appBar: AppBar(
        backgroundColor: BrainColors.base,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.initialQuery != null && widget.initialQuery!.isNotEmpty
              ? '#${widget.initialQuery!.replaceFirst(RegExp(r'^#'), '')}'
              : 'Suche',
          style: BrainTypography.bodyMd.copyWith(color: BrainColors.onSurface),
        ),
      ),
      body: body,
    );
  }
}

class _RecentSearches extends StatelessWidget {
  final List<String> searches;
  final ValueChanged<String> onTap;

  const _RecentSearches({required this.searches, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: BrainColors.outline,
            ),
            const SizedBox(height: BrainSpacing.md),
            Text(
              'Suche in allen deinen Gedanken',
              style: BrainTypography.bodyMd.copyWith(
                color: BrainColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: BrainSpacing.paddingScreen,
          child: Text('RECENT', style: BrainTypography.labelSm),
        ),
        const SizedBox(height: BrainSpacing.sm),
        Padding(
          padding: BrainSpacing.paddingScreen,
          child: Wrap(
            spacing: BrainSpacing.sm,
            runSpacing: BrainSpacing.sm,
            children: searches
                .map(
                  (q) => GestureDetector(
                    onTap: () => onTap(q),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: BrainColors.surfaceHigh,
                        borderRadius: BrainSpacing.radiusSm,
                      ),
                      child: Text(q, style: BrainTypography.bodySm),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  final List results;
  final String query;
  // Plan 2.3: optional Score je Notiz → Relevance-Dots. Null wenn der
  // Server keinen geliefert hat (offline / lokal-only).
  final double? Function(String noteId) scoreFor;
  // Tap auf Wing-Chip → setzt den Wing-Filter im SearchProvider.
  final ValueChanged<String> onWingChipTap;

  const _ResultsList({
    required this.results,
    required this.query,
    required this.scoreFor,
    required this.onWingChipTap,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Keine Gedanken gefunden für "$query"',
          style: BrainTypography.bodyMd.copyWith(
            color: BrainColors.onSurfaceVariant,
          ),
        ),
      );
    }
    // Such-Tokens für das Excerpt-Highlight: Whitespace + Satzzeichen
    // splitten, Tokens < 2 Zeichen rauswerfen (verhindert dass "in"
    // oder "a" das halbe Excerpt einfärben).
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[^\wäöüß]+'))
        .where((t) => t.length >= 2)
        .toSet()
        .toList(growable: false);

    return ListView.separated(
      padding: BrainSpacing.paddingScreen,
      itemCount: results.length,
      separatorBuilder: (_, _x) => const SizedBox(height: BrainSpacing.cardGap),
      itemBuilder: (_, i) {
        final note = results[i];
        final wing = note.wing as String?;
        final score = scoreFor(note.id as String);
        return BrainCard(
          glass: true,
          tintColor: hallColor(note.hall),
          // Plan 2.3: 3px Hall-Stripe links — beschleunigt das Scannen
          // einer Liste deutlich, der weiche Tint allein reichte nicht.
          leftBorderColor: hallColor(note.hall),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteDetailScreen(noteId: note.id),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: BrainTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: BrainColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (wing != null && wing.isNotEmpty) ...[
                    const SizedBox(width: BrainSpacing.sm),
                    _WingChip(wing: wing, onTap: () => onWingChipTap(wing)),
                  ],
                ],
              ),
              if (note.excerpt.isNotEmpty) ...[
                const SizedBox(height: 4),
                _HighlightedExcerpt(text: note.excerpt, tokens: tokens),
              ],
              const SizedBox(height: BrainSpacing.sm),
              Row(
                children: [
                  ...note.tags
                      .take(3)
                      .map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: BrainColors.primary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BrainSpacing.radiusFull,
                            ),
                            child: Text('#$t', style: BrainTypography.tag),
                          ),
                        ),
                      ),
                  const Spacer(),
                  if (score != null) ...[
                    _RelevanceDots(score: score),
                    const SizedBox(width: 8),
                  ],
                  Text(note.relativeTime, style: BrainTypography.labelSm),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Plan 2.3: Excerpt mit hervorgehobenen Such-Tokens. Case-insensitive
/// match auf Wort-Ebene, Whitespace bleibt erhalten. Tokens werden vor
/// dem regex-escape geprüft, damit "(", ")" usw. in der Query nicht
/// die Match-Logik sprengen.
class _HighlightedExcerpt extends StatelessWidget {
  final String text;
  final List<String> tokens;

  const _HighlightedExcerpt({required this.text, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final base = BrainTypography.bodySm;
    if (tokens.isEmpty) {
      return Text(text,
          style: base, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final escaped = tokens.map(RegExp.escape).join('|');
    final pattern = RegExp(escaped, caseSensitive: false);
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start), style: base));
      }
      spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: base.copyWith(
          color: BrainColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: base));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Plan 2.3: 3-Punkt-Relevance-Skala. Score ∈ [0,1] (server-normalisiert).
/// Schwellen 0.66 / 0.33 — entspricht „starker / mittlerer / schwacher"
/// Treffer relativ zum besten Result der aktuellen Query.
class _RelevanceDots extends StatelessWidget {
  final double score;

  const _RelevanceDots({required this.score});

  @override
  Widget build(BuildContext context) {
    final active = score >= 0.66 ? 3 : (score >= 0.33 ? 2 : 1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final lit = i < active;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lit
                  ? BrainColors.primary.withValues(alpha: 0.85)
                  : BrainColors.onSurfaceVariant.withValues(alpha: 0.25),
            ),
          ),
        );
      }),
    );
  }
}

/// Plan 2.3: kompakter Wing-Chip rechts oben in der Karte. Tap →
/// Filter im SearchProvider (Drill-In ohne Filter-Menü). Wing-Slug
/// (kebab-case) wird für die Anzeige in Title-Case umgewandelt.
class _WingChip extends StatelessWidget {
  final String wing;
  final VoidCallback onTap;

  const _WingChip({required this.wing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final display = wing
        .split('-')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: BrainColors.primary.withValues(alpha: 0.10),
          borderRadius: BrainSpacing.radiusFull,
        ),
        child: Text(
          display,
          style: BrainTypography.labelSm.copyWith(
            color: BrainColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
