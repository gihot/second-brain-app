import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Plan 4.1: Passwort ändern. Drei Felder (aktuell, neu, neu wiederholt),
/// Submit nur wenn alle plausibel sind. Server validiert nochmal — die
/// Client-Checks (Länge ≥ 8, neu != alt, beide neuen gleich) sind nur
/// UX-Komfort, damit der User nicht für 401-Pingpong hin und her muss.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _clientValid {
    final cur = _current.text;
    final nx = _next.text;
    final cf = _confirm.text;
    if (cur.isEmpty) return false;
    if (nx.length < 8) return false;
    if (nx != cf) return false;
    if (nx == cur) return false;
    return true;
  }

  String? get _hint {
    final nx = _next.text;
    final cf = _confirm.text;
    if (nx.isNotEmpty && nx.length < 8) {
      return 'Mindestens 8 Zeichen.';
    }
    if (cf.isNotEmpty && nx != cf) {
      return 'Wiederholung stimmt nicht überein.';
    }
    if (nx.isNotEmpty && nx == _current.text) {
      return 'Neues Passwort muss sich unterscheiden.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy || !_clientValid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ApiService.instance.changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = error);
    }
  }

  Widget _pwField(
    TextEditingController c,
    String label, {
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: BrainSpacing.xs),
      child: TextField(
        controller: c,
        obscureText: true,
        autofocus: autofocus,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          filled: true,
          fillColor: BrainColors.surfaceHigh,
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BrainSpacing.radiusSm,
            borderSide: BorderSide.none,
          ),
        ),
        style: BrainTypography.bodyMd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hint = _error ?? _hint;
    return AlertDialog(
      backgroundColor: BrainColors.surfaceLow,
      title: Text('Passwort ändern', style: BrainTypography.titleMd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pwField(_current, 'Aktuelles Passwort', autofocus: true),
          _pwField(_next, 'Neues Passwort'),
          _pwField(_confirm, 'Neues Passwort wiederholen'),
          if (hint != null) ...[
            const SizedBox(height: BrainSpacing.sm),
            Text(
              hint,
              style: BrainTypography.labelSm.copyWith(
                color: _error != null ? BrainColors.error : BrainColors.outline,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(
            'Abbrechen',
            style: BrainTypography.button.copyWith(color: BrainColors.outline),
          ),
        ),
        TextButton(
          onPressed: (_clientValid && !_busy) ? _submit : null,
          child: Text(
            _busy ? 'Speichere…' : 'Speichern',
            style: BrainTypography.button.copyWith(
              color: (_clientValid && !_busy)
                  ? BrainColors.primary
                  : BrainColors.outline.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}
