import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/api_service.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Plan 4.3: „Freund einladen"-Sheet. Listet alle Codes des Users
/// (offen, eingelöst, abgelaufen), plus Button für neue Einladung.
/// Tap auf einen offenen Code → ins Clipboard.
class InvitesSheet extends StatefulWidget {
  const InvitesSheet({super.key});

  @override
  State<InvitesSheet> createState() => _InvitesSheetState();
}

class _InvitesSheetState extends State<InvitesSheet> {
  List<Map<String, dynamic>>? _codes;
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final codes = await ApiService.instance.listInvites();
    if (!mounted) return;
    setState(() {
      _codes = codes ?? [];
      _loading = false;
    });
  }

  Future<void> _createNew() async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    final result = await ApiService.instance.createInvite();
    if (!mounted) return;
    setState(() => _creating = false);
    if (result.code == null) {
      setState(() => _error = result.error ?? 'Unbekannter Fehler.');
      return;
    }
    await _load();
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code „$code" kopiert.'),
        backgroundColor: BrainColors.surfaceHigh,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}.${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final codes = _codes ?? const <Map<String, dynamic>>[];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BrainSpacing.lg,
          BrainSpacing.lg,
          BrainSpacing.lg,
          BrainSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Freunde einladen', style: BrainTypography.titleMd),
            const SizedBox(height: BrainSpacing.xs),
            Text(
              'Codes sind 14 Tage gültig und einmal einlösbar. '
              'Maximal 10 offene Einladungen gleichzeitig.',
              style: BrainTypography.bodySm.copyWith(
                color: BrainColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: BrainSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: BrainSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (codes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: BrainSpacing.sm),
                child: Text(
                  'Noch keine Einladungen erstellt.',
                  style: BrainTypography.bodySm.copyWith(
                    color: BrainColors.onSurfaceVariant,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: codes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: BrainSpacing.xs),
                  itemBuilder: (_, i) => _CodeRow(
                    data: codes[i],
                    onCopy: _copyToClipboard,
                    formatDate: _formatDate,
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: BrainSpacing.sm),
              Text(_error!,
                  style: BrainTypography.labelSm
                      .copyWith(color: BrainColors.error)),
            ],
            const SizedBox(height: BrainSpacing.md),
            FilledButton.icon(
              onPressed: _creating ? null : _createNew,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_creating
                  ? 'Erzeuge…'
                  : 'Neue Einladung erstellen'),
              style: FilledButton.styleFrom(
                backgroundColor: BrainColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final void Function(String code) onCopy;
  final String Function(String iso) formatDate;

  const _CodeRow({
    required this.data,
    required this.onCopy,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final code = data['code'] as String;
    final state = data['state'] as String? ?? 'open';
    final expiresAt = data['expires_at'] as String?;
    final usedAt = data['used_at'] as String?;

    final (label, color) = switch (state) {
      'used' => ('Eingelöst', BrainColors.onSurfaceVariant),
      'expired' => ('Abgelaufen', BrainColors.outline),
      _ => ('Offen', BrainColors.secondary),
    };

    final subtitle = switch (state) {
      'used' when usedAt != null => 'Eingelöst am ${formatDate(usedAt)}',
      'expired' when expiresAt != null =>
        'Abgelaufen am ${formatDate(expiresAt)}',
      _ when expiresAt != null => 'Gültig bis ${formatDate(expiresAt)}',
      _ => '',
    };

    final canCopy = state == 'open';
    return InkWell(
      onTap: canCopy ? () => onCopy(code) : null,
      borderRadius: BrainSpacing.radiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: BrainColors.surfaceHigh,
          borderRadius: BrainSpacing.radiusSm,
          border: Border.all(
            color: BrainColors.outlineVariant.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: BrainTypography.bodyMd.copyWith(
                      color: BrainColors.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      decoration: state == 'open'
                          ? null
                          : TextDecoration.lineThrough,
                      decorationColor:
                          BrainColors.outline.withValues(alpha: 0.6),
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: BrainTypography.labelSm.copyWith(
                          color: BrainColors.onSurfaceVariant,
                        )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BrainSpacing.radiusFull,
              ),
              child: Text(
                label,
                style: BrainTypography.labelSm.copyWith(color: color),
              ),
            ),
            if (canCopy) ...[
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded,
                  size: 16, color: BrainColors.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}
