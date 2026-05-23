import 'package:flutter/material.dart';

import '../../../services/cache_service.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// BottomSheet listing queued vault writes (edits/deletes that couldn't
/// reach the server). User can retry the whole queue or discard individual
/// entries.
class PendingWritesSheet extends StatefulWidget {
  final Future<void> Function() onReplayAll;
  final Future<void> Function(String filePath) onDiscard;
  final Future<void> Function() onDiscardAll;

  const PendingWritesSheet({
    super.key,
    required this.onReplayAll,
    required this.onDiscard,
    required this.onDiscardAll,
  });

  @override
  State<PendingWritesSheet> createState() => _PendingWritesSheetState();
}

class _PendingWritesSheetState extends State<PendingWritesSheet> {
  late List<Map<String, dynamic>> _writes;
  bool _replaying = false;

  @override
  void initState() {
    super.initState();
    _writes = CacheService.instance.getPendingWrites();
  }

  void _refresh() {
    setState(() {
      _writes = CacheService.instance.getPendingWrites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            BrainSpacing.md, BrainSpacing.sm, BrainSpacing.md, BrainSpacing.md),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Pending Writes (${_writes.length})',
                      style: BrainTypography.headlineSm),
                ),
                if (_writes.isNotEmpty) ...[
                  TextButton(
                    onPressed: _replaying
                        ? null
                        : () async {
                            setState(() => _replaying = true);
                            await widget.onReplayAll();
                            if (!mounted) return;
                            setState(() => _replaying = false);
                            _refresh();
                          },
                    child: Text(
                      _replaying ? 'Versuche...' : 'Erneut versuchen',
                      style: BrainTypography.button
                          .copyWith(color: BrainColors.primary),
                    ),
                  ),
                  TextButton(
                    onPressed: _replaying
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: BrainColors.surfaceLow,
                                title: Text(
                                    'Alle ${_writes.length} verwerfen?',
                                    style: BrainTypography.titleMd),
                                content: Text(
                                  'Die lokalen Gedanken bleiben erhalten — '
                                  'nur die Sync-Anfragen an den Server werden '
                                  'gelöscht. Sinnvoll wenn die Einträge auf '
                                  'Gedanken verweisen, die nie beim Server '
                                  'ankamen.',
                                  style: BrainTypography.bodyMd,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text('Abbrechen',
                                        style: BrainTypography.button.copyWith(
                                            color: BrainColors.outline)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text('Verwerfen',
                                        style: BrainTypography.button.copyWith(
                                            color: BrainColors.error)),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await widget.onDiscardAll();
                              _refresh();
                            }
                          },
                    child: Text('Alle verwerfen',
                        style: BrainTypography.button
                            .copyWith(color: BrainColors.error)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: BrainSpacing.sm),
            if (_writes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(BrainSpacing.lg),
                child: Center(
                  child: Text(
                    'Alles synchronisiert',
                    style: BrainTypography.bodyMd
                        .copyWith(color: BrainColors.onSurfaceVariant),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _writes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: BrainSpacing.sm),
                  itemBuilder: (_, i) {
                    final w = _writes[i];
                    final filePath = w['file_path'] as String? ?? '';
                    final op = w['op'] as String? ?? 'update';
                    return Container(
                      padding: BrainSpacing.paddingCard,
                      decoration: BoxDecoration(
                        color: BrainColors.surfaceHigh,
                        borderRadius: BrainSpacing.radiusMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (op == 'delete'
                                          ? BrainColors.error
                                          : BrainColors.primary)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BrainSpacing.radiusFull,
                                ),
                                child: Text(
                                  op.toUpperCase(),
                                  style: BrainTypography.labelSm.copyWith(
                                    color: op == 'delete'
                                        ? BrainColors.error
                                        : BrainColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(filePath,
                              style: BrainTypography.bodySm,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: BrainSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () async {
                                await widget.onDiscard(filePath);
                                _refresh();
                              },
                              child: Text('Verwerfen',
                                  style: BrainTypography.button.copyWith(
                                      color: BrainColors.error)),
                            ),
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
