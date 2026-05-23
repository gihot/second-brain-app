import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/background_provider.dart';
import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Tile mit Vorschau + Auswahl/Entfernen-Buttons fürs Hintergrundbild.
class BackgroundImageTile extends StatelessWidget {
  const BackgroundImageTile({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = context.watch<BackgroundProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: BrainSpacing.md, vertical: BrainSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_outlined,
                  size: 18, color: BrainColors.outline),
              const SizedBox(width: BrainSpacing.sm),
              Text('Hintergrundbild',
                  style: BrainTypography.bodyMd
                      .copyWith(color: BrainColors.onSurface)),
              const Spacer(),
              Text(
                bg.hasImage ? 'Aktiv' : 'Aus',
                style: BrainTypography.labelSm.copyWith(
                  color: bg.hasImage
                      ? BrainColors.secondary
                      : BrainColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: BrainSpacing.sm),
          // Preview
          ClipRRect(
            borderRadius: BrainSpacing.radiusMd,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: bg.hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(bg.bytes!, fit: BoxFit.cover),
                        Container(
                            color: Colors.black.withValues(alpha: 0.60)),
                      ],
                    )
                  : Container(
                      color: BrainColors.surfaceLow,
                      alignment: Alignment.center,
                      child: Icon(Icons.image_outlined,
                          size: 32, color: BrainColors.outline),
                    ),
            ),
          ),
          const SizedBox(height: BrainSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: bg.picking ? null : () => bg.pick(),
                icon: bg.picking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_outlined, size: 16),
                label: Text(bg.hasImage ? 'Ersetzen' : 'Bild auswählen'),
                style: TextButton.styleFrom(
                    foregroundColor: BrainColors.primary),
              ),
              if (bg.hasImage)
                TextButton.icon(
                  onPressed: () => bg.clear(),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Entfernen'),
                  style: TextButton.styleFrom(
                      foregroundColor: BrainColors.error),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
