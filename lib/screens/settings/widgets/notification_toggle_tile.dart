import 'package:flutter/material.dart';

import '../../../services/notification_service.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Spezial-Tile für die Benachrichtigungs-Sektion. Zeigt den Browser-
/// Permission-Status und schaltet den Erinnerungs-Switch (oder den
/// "Erlauben"-Button, wenn die Permission noch nicht angefragt wurde).
class NotificationToggleTile extends StatelessWidget {
  final bool enabled;
  final String permission; // 'granted' | 'denied' | 'default'
  final ValueChanged<bool> onToggle;
  final VoidCallback onRequestPermission;

  const NotificationToggleTile({
    super.key,
    required this.enabled,
    required this.permission,
    required this.onToggle,
    required this.onRequestPermission,
  });

  String get _permissionLabel => switch (permission) {
        'granted' => 'Erlaubt',
        'denied' => 'Blockiert',
        _ => 'Ausstehend',
      };

  Color _permissionColor(BuildContext context) => switch (permission) {
        'granted' => BrainColors.secondary,
        'denied' => BrainColors.error,
        _ => BrainColors.outline,
      };

  @override
  Widget build(BuildContext context) {
    final ns = NotificationService.instance;
    final supported = ns.isSupported;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BrainSpacing.md,
        vertical: BrainSpacing.cardGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_outlined,
                  size: 18, color: BrainColors.outline),
              const SizedBox(width: BrainSpacing.cardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Erinnerungen', style: BrainTypography.bodyMd),
                    Text(
                      supported
                          ? 'Browser: $_permissionLabel'
                          : 'Nicht unterstützt',
                      style: BrainTypography.labelSm.copyWith(
                        color: supported
                            ? _permissionColor(context)
                            : BrainColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (supported) ...[
                if (permission == 'default')
                  GestureDetector(
                    onTap: onRequestPermission,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BrainColors.primary.withValues(alpha: 0.15),
                        borderRadius: BrainSpacing.radiusFull,
                      ),
                      child: Text('Erlauben',
                          style: BrainTypography.labelSm
                              .copyWith(color: BrainColors.primary)),
                    ),
                  )
                else
                  Switch(
                    value: enabled && permission == 'granted',
                    onChanged: permission == 'denied' ? null : onToggle,
                    activeThumbColor: BrainColors.secondary,
                  ),
              ],
            ],
          ),
          if (permission == 'denied' && supported)
            Padding(
              padding: const EdgeInsets.only(top: BrainSpacing.xs, left: 34),
              child: Text(
                'Benachrichtigungen sind im Browser blockiert. Bitte in den Website-Einstellungen freigeben.',
                style: BrainTypography.labelSm
                    .copyWith(color: BrainColors.outline),
              ),
            ),
        ],
      ),
    );
  }
}
