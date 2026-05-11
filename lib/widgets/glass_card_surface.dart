import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/glass_settings_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';

/// Reusable frosted-glass card surface.
///
/// Renders: `ClipRRect → BackdropFilter(blur) → Container(fill + tint + border)`.
/// The fill darkness and tint intensity are read from [GlassSettingsProvider]
/// so the user can tune the look from Settings.
///
/// - [tintColor] is blended over the dark fill at the configured tint opacity.
///   Pass `hallColor(note.hall)` to give each card a recognisable hue.
/// - [onTap] gets ink-well ripple behaviour. Pass null for a static surface.
class GlassCardSurface extends StatelessWidget {
  final Widget child;
  final Color? tintColor;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const GlassCardSurface({
    super.key,
    required this.child,
    this.tintColor,
    this.onTap,
    this.borderRadius = BrainSpacing.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GlassSettingsProvider>();

    final baseFill =
        const Color(0xFF000000).withValues(alpha: settings.fillOpacity);
    final tint = tintColor;
    final fill = tint == null || settings.tintOpacity == 0
        ? baseFill
        : Color.alphaBlend(
            tint.withValues(alpha: settings.tintOpacity),
            baseFill,
          );

    final surface = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: BrainColors.glassCardBlur,
          sigmaY: BrainColors.glassCardBlur,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: Border.all(
              color: BrainColors.glassCardBorder,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return surface;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: surface,
      ),
    );
  }
}
