import 'package:flutter/material.dart';

import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Type-to-confirm dialog for cache clear. Disables the destructive button
/// until the user types "LÖSCHEN" exactly.
class ClearCacheDialog extends StatefulWidget {
  final Future<void> Function() onConfirmed;
  const ClearCacheDialog({super.key, required this.onConfirmed});

  @override
  State<ClearCacheDialog> createState() => _ClearCacheDialogState();
}

class _ClearCacheDialogState extends State<ClearCacheDialog> {
  static const _expected = 'LÖSCHEN';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _ctrl.text.trim() == _expected;

    return AlertDialog(
      backgroundColor: BrainColors.surfaceLow,
      title: Text('Cache leeren?', style: BrainTypography.titleMd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vor dem Löschen wird automatisch ein ZIP-Backup heruntergeladen. '
            'Du kannst es bei Bedarf später über „Aus ZIP importieren" '
            'wieder einspielen.',
            style: BrainTypography.bodyMd,
          ),
          const SizedBox(height: BrainSpacing.md),
          Text(
            'Tippe „$_expected" zur Bestätigung:',
            style: BrainTypography.labelSm,
          ),
          const SizedBox(height: BrainSpacing.xs),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: BrainColors.surfaceHigh,
              hintText: _expected,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BrainSpacing.radiusSm,
                borderSide: BorderSide.none,
              ),
            ),
            style: BrainTypography.bodyMd,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Abbrechen',
              style: BrainTypography.button
                  .copyWith(color: BrainColors.outline)),
        ),
        TextButton(
          onPressed: canConfirm
              ? () async {
                  Navigator.pop(context);
                  await widget.onConfirmed();
                }
              : null,
          child: Text(
            'Endgültig löschen',
            style: BrainTypography.button.copyWith(
              color: canConfirm
                  ? BrainColors.error
                  : BrainColors.outline.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}
