import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../widgets/brain_card.dart';
import '../widgets/brain_input.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();

    return Padding(
      padding: const EdgeInsets.only(top: BrainSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input
          Padding(
            padding: BrainSpacing.paddingScreen,
            child: BrainInput(
              controller: _controller,
              hint: 'Search your brain...',
              prefixIcon: Icons.search_rounded,
              onChanged: context.read<SearchProvider>().search,
              onSubmitted: (q) {
                context.read<SearchProvider>().submitSearch(q);
              },
            ),
          ),

          const SizedBox(height: BrainSpacing.md),

          // Recent searches or results
          Expanded(
            child: search.hasQuery
                ? _ResultsList(results: search.results, query: search.query)
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
            Icon(Icons.search_off_rounded,
                size: 48, color: BrainColors.outline),
            const SizedBox(height: BrainSpacing.md),
            Text(
              'Search across all your notes',
              style: BrainTypography.bodyMd
                  .copyWith(color: BrainColors.onSurfaceVariant),
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
                .map((q) => GestureDetector(
                      onTap: () => onTap(q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: BrainColors.surfaceHigh,
                          borderRadius: BrainSpacing.radiusSm,
                        ),
                        child: Text(q, style: BrainTypography.bodySm),
                      ),
                    ))
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

  const _ResultsList({required this.results, required this.query});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          'No notes found for "$query"',
          style: BrainTypography.bodyMd.copyWith(color: BrainColors.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      padding: BrainSpacing.paddingScreen,
      itemCount: results.length,
      separatorBuilder: (_, _x) =>
          const SizedBox(height: BrainSpacing.cardGap),
      itemBuilder: (_, i) {
        final note = results[i];
        return BrainCard(
          showBorder: true,
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: BrainTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: BrainColors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (note.excerpt.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.excerpt,
                  style: BrainTypography.bodySm,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: BrainSpacing.sm),
              Row(
                children: [
                  ...note.tags.take(3).map((t) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: BrainColors.primary.withValues(alpha: 0.10),
                            borderRadius: BrainSpacing.radiusFull,
                          ),
                          child: Text('#$t',
                              style: BrainTypography.tag),
                        ),
                      )),
                  const Spacer(),
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
