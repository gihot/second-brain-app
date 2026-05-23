import 'package:flutter/material.dart';

import '../../../theme/brain_colors.dart';
import '../../../theme/brain_typography.dart';

/// Generischer Eingabe-Dialog mit Speichern/Abbrechen-Buttons.
class InputDialog extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final Future<void> Function(String) onSave;

  const InputDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.controller,
    required this.onSave,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrainColors.surfaceLow,
      title: Text(title, style: BrainTypography.titleMd),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: obscureText,
        style: BrainTypography.bodyMd,
        cursorColor: BrainColors.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: BrainTypography.bodyMd
              .copyWith(color: BrainColors.outline),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Abbrechen',
              style: BrainTypography.button.copyWith(color: BrainColors.outline)),
        ),
        TextButton(
          onPressed: () async {
            final val = controller.text.trim();
            if (val.isNotEmpty) {
              Navigator.pop(context);
              await onSave(val);
            }
          },
          child: Text('Speichern',
              style: BrainTypography.button.copyWith(color: BrainColors.primary)),
        ),
      ],
    );
  }
}
