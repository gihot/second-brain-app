import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/glass_settings_provider.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Settings-Tile für die Glas-Karten-Optik (Dunkelheit + Farbtönung).
class GlassSettingsTile extends StatelessWidget {
  const GlassSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GlassSettingsProvider>();

    String pct(double v) => '${(v * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: BrainSpacing.md, vertical: BrainSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.blur_on_outlined,
                  size: 18, color: BrainColors.outline),
              const SizedBox(width: BrainSpacing.sm),
              Text('Glas-Karten',
                  style: BrainTypography.bodyMd
                      .copyWith(color: BrainColors.onSurface)),
            ],
          ),
          const SizedBox(height: BrainSpacing.sm),
          _SliderRow(
            label: 'Dunkelheit',
            value: g.fillOpacity,
            min: GlassSettingsProvider.minFillOpacity,
            max: GlassSettingsProvider.maxFillOpacity,
            display: pct(g.fillOpacity),
            onChanged: g.setFillOpacity,
          ),
          _SliderRow(
            label: 'Farbtönung',
            value: g.tintOpacity,
            min: GlassSettingsProvider.minTintOpacity,
            max: GlassSettingsProvider.maxTintOpacity,
            display: pct(g.tintOpacity),
            onChanged: g.setTintOpacity,
          ),
        ],
      ),
    );
  }
}

/// Slider mit Label und Prozent-Anzeige rechts. File-private Helfer.
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BrainSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: BrainTypography.labelSm
                    .copyWith(color: BrainColors.onSurfaceVariant)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: BrainColors.primary,
                inactiveTrackColor:
                    BrainColors.outlineVariant.withValues(alpha: 0.30),
                thumbColor: BrainColors.primary,
                overlayColor: BrainColors.primary.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(display,
                textAlign: TextAlign.right,
                style: BrainTypography.labelSm
                    .copyWith(color: BrainColors.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
