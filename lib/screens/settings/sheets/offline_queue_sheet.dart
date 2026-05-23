import 'package:flutter/material.dart';

import '../../../models/offline_capture_model.dart';
import '../../../services/cache_service.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// BottomSheet that lists all unsynced captures and lets the user adopt
/// or discard each one. "Adopt" promotes the raw text to an inbox note;
/// "discard" removes the queue entry.
class OfflineQueueSheet extends StatefulWidget {
  final Future<void> Function(OfflineCapture) onAdopt;
  final Future<void> Function(OfflineCapture) onDiscard;

  const OfflineQueueSheet({
    super.key,
    required this.onAdopt,
    required this.onDiscard,
  });

  @override
  State<OfflineQueueSheet> createState() => _OfflineQueueSheetState();
}

class _OfflineQueueSheetState extends State<OfflineQueueSheet> {
  late List<OfflineCapture> _captures;

  @override
  void initState() {
    super.initState();
    _captures = CacheService.instance.getPendingCaptures();
  }

  void _refresh() {
    setState(() {
      _captures = CacheService.instance.getPendingCaptures();
    });
  }

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${l.day}.${l.month}.${l.year} ${pad(l.hour)}:${pad(l.minute)}';
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
                Text('Offline-Captures (${_captures.length})',
                    style: BrainTypography.headlineSm),
                if (_captures.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      for (final c in List.of(_captures)) {
                        await widget.onAdopt(c);
                      }
                      _refresh();
                    },
                    child: Text('Alle übernehmen',
                        style: BrainTypography.button
                            .copyWith(color: BrainColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: BrainSpacing.sm),
            if (_captures.isEmpty)
              Padding(
                padding: const EdgeInsets.all(BrainSpacing.lg),
                child: Center(
                  child: Text(
                    'Keine ungesyncten Captures',
                    style: BrainTypography.bodyMd
                        .copyWith(color: BrainColors.onSurfaceVariant),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _captures.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: BrainSpacing.sm),
                  itemBuilder: (_, i) {
                    final c = _captures[i];
                    return Container(
                      padding: BrainSpacing.paddingCard,
                      decoration: BoxDecoration(
                        color: BrainColors.surfaceHigh,
                        borderRadius: BrainSpacing.radiusMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatTime(c.createdAt),
                              style: BrainTypography.labelSm.copyWith(
                                  color: BrainColors.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(c.text,
                              style: BrainTypography.bodyMd,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: BrainSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await widget.onDiscard(c);
                                  _refresh();
                                },
                                child: Text('Verwerfen',
                                    style: BrainTypography.button.copyWith(
                                        color: BrainColors.error)),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await widget.onAdopt(c);
                                  _refresh();
                                },
                                child: Text('Als Gedanken übernehmen',
                                    style: BrainTypography.button.copyWith(
                                        color: BrainColors.primary)),
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
