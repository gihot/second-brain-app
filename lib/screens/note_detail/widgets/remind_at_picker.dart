import 'package:flutter/material.dart';

import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Datum + Uhrzeit-Picker für ein Reminder-`remind_at`. Liefert ISO-8601-UTC.
class RemindAtPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const RemindAtPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value != null
        ? (DateTime.tryParse(value!)?.toLocal() ?? now)
        : now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: BrainColors.primary,
            surface: BrainColors.surfaceHigh,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: BrainColors.primary,
            surface: BrainColors.surfaceHigh,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    final combined = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    onChanged(combined.toUtc().toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BrainSpacing.radiusFull,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_calendar_outlined,
                  size: 14, color: BrainColors.primary),
              const SizedBox(width: 6),
              Text(
                value != null ? 'Datum ändern' : 'Datum & Uhrzeit wählen',
                style: BrainTypography.labelSm
                    .copyWith(color: BrainColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
