import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/vault_export_service.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Plan 4.2: drei-Schritte-Flow für Soft-Delete:
///   1. Backup-Pflicht — Button „Backup als ZIP" muss frisch geklickt
///      worden sein (<1h alt), sonst geht's nicht weiter.
///   2. Re-Auth — aktuelles Passwort + Type-to-confirm „LÖSCHEN".
///   3. Server-Call → Bestätigungs-Screen mit dem Datum.
/// Daten überleben Misklick + 30 Tage Reue. Hard-Delete passiert
/// erst wenn die Frist tatsächlich abläuft.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

enum _Step { backup, confirm, done }

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  _Step _step = _Step.backup;
  final _pwCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _deletionAt; // ISO-Timestamp aus Server-Antwort

  static const _expected = 'LÖSCHEN';
  static const _maxBackupAgeMinutes = 60;

  @override
  void dispose() {
    _pwCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  bool get _backupFresh {
    final last = VaultExportService.instance.lastBackupAt;
    if (last == null) return false;
    final age = DateTime.now().difference(last);
    return age.inMinutes < _maxBackupAgeMinutes;
  }

  Future<void> _runBackup() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await VaultExportService.instance.exportZip();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Backup fehlgeschlagen: $e';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Backup-Timestamp wurde von exportZip selbst gesetzt; durch
      // setState rebuildet sich der UI-Zustand → _backupFresh = true.
    });
  }

  bool get _confirmValid =>
      _pwCtrl.text.isNotEmpty && _typeCtrl.text.trim() == _expected;

  Future<void> _submitDeletion() async {
    if (_busy || !_confirmValid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await ApiService.instance.requestDeletion(_pwCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }
    setState(() {
      _deletionAt = result.deletionAt;
      _step = _Step.done;
    });
    // AuthProvider neu laden, damit der Banner triggert.
    // ignore: use_build_context_synchronously
    await context.read<AuthProvider>().refreshUser();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}.${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrainColors.surfaceLow,
      title: Text(_titleForStep(), style: BrainTypography.titleMd),
      content: _buildContent(),
      actions: _buildActions(),
    );
  }

  String _titleForStep() {
    switch (_step) {
      case _Step.backup:
        return 'Account löschen — Backup';
      case _Step.confirm:
        return 'Account löschen — Bestätigung';
      case _Step.done:
        return 'Löschung vorgemerkt';
    }
  }

  Widget _buildContent() {
    switch (_step) {
      case _Step.backup:
        return _backupStep();
      case _Step.confirm:
        return _confirmStep();
      case _Step.done:
        return _doneStep();
    }
  }

  Widget _backupStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bevor wir deinen Account zur Löschung vormerken: lade ein '
          'frisches ZIP-Backup deiner Notizen herunter. Du kannst es '
          'jederzeit per „Aus ZIP importieren" wieder einspielen — '
          'auch in einen neuen Account.',
          style: BrainTypography.bodyMd,
        ),
        const SizedBox(height: BrainSpacing.md),
        if (_backupFresh)
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 18, color: BrainColors.secondary),
              const SizedBox(width: 6),
              Text(
                'Backup frisch (<1h alt). Du kannst weiter.',
                style: BrainTypography.labelSm.copyWith(
                  color: BrainColors.secondary,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: BrainColors.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Kein frisches Backup. Bitte erst sichern.',
                  style: BrainTypography.labelSm.copyWith(
                    color: BrainColors.tertiary,
                  ),
                ),
              ),
            ],
          ),
        if (_error != null) ...[
          const SizedBox(height: BrainSpacing.sm),
          Text(_error!,
              style: BrainTypography.labelSm
                  .copyWith(color: BrainColors.error)),
        ],
      ],
    );
  }

  Widget _confirmStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dein Account wird in 30 Tagen final gelöscht. Bis dahin '
          'kannst du das jederzeit mit einem Klick rückgängig machen — '
          'der Banner erscheint auf dem Dashboard.',
          style: BrainTypography.bodyMd,
        ),
        const SizedBox(height: BrainSpacing.md),
        TextField(
          controller: _pwCtrl,
          obscureText: true,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true,
            fillColor: BrainColors.surfaceHigh,
            labelText: 'Aktuelles Passwort',
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BrainSpacing.radiusSm,
              borderSide: BorderSide.none,
            ),
          ),
          style: BrainTypography.bodyMd,
        ),
        const SizedBox(height: BrainSpacing.sm),
        Text(
          'Tippe „$_expected" zur Bestätigung:',
          style: BrainTypography.labelSm,
        ),
        const SizedBox(height: BrainSpacing.xs),
        TextField(
          controller: _typeCtrl,
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
        if (_error != null) ...[
          const SizedBox(height: BrainSpacing.sm),
          Text(_error!,
              style: BrainTypography.labelSm
                  .copyWith(color: BrainColors.error)),
        ],
      ],
    );
  }

  Widget _doneStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_rounded,
                size: 22, color: BrainColors.tertiary),
            const SizedBox(width: BrainSpacing.sm),
            Expanded(
              child: Text(
                'Dein Account wird am ${_formatDate(_deletionAt)} '
                'gelöscht.',
                style: BrainTypography.bodyMd
                    .copyWith(color: BrainColors.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: BrainSpacing.sm),
        Text(
          'Bis dahin kannst du das jederzeit über den Banner auf '
          'dem Dashboard rückgängig machen.',
          style: BrainTypography.bodySm,
        ),
      ],
    );
  }

  List<Widget> _buildActions() {
    switch (_step) {
      case _Step.backup:
        return [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text('Abbrechen',
                style: BrainTypography.button
                    .copyWith(color: BrainColors.outline)),
          ),
          if (!_backupFresh)
            TextButton(
              onPressed: _busy ? null : _runBackup,
              child: Text(
                _busy ? 'Sichere…' : 'Backup als ZIP',
                style: BrainTypography.button
                    .copyWith(color: BrainColors.secondary),
              ),
            ),
          TextButton(
            onPressed: _backupFresh
                ? () => setState(() => _step = _Step.confirm)
                : null,
            child: Text(
              'Weiter',
              style: BrainTypography.button.copyWith(
                color: _backupFresh
                    ? BrainColors.primary
                    : BrainColors.outline.withValues(alpha: 0.4),
              ),
            ),
          ),
        ];
      case _Step.confirm:
        return [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text('Abbrechen',
                style: BrainTypography.button
                    .copyWith(color: BrainColors.outline)),
          ),
          TextButton(
            onPressed: (_confirmValid && !_busy) ? _submitDeletion : null,
            child: Text(
              _busy ? 'Sende…' : 'Account löschen',
              style: BrainTypography.button.copyWith(
                color: (_confirmValid && !_busy)
                    ? BrainColors.error
                    : BrainColors.outline.withValues(alpha: 0.4),
              ),
            ),
          ),
        ];
      case _Step.done:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Schließen',
                style: BrainTypography.button
                    .copyWith(color: BrainColors.primary)),
          ),
        ];
    }
  }
}
