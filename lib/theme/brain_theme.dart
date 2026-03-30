import 'package:flutter/material.dart';
import 'brain_colors.dart';
import 'brain_spacing.dart';

/// Assembles the full ThemeData from the Digital Curator design tokens.
class BrainTheme {
  BrainTheme._();

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: BrainColors.base,
      colorScheme: const ColorScheme.dark(
        surface: BrainColors.base,
        primary: BrainColors.primary,
        onPrimary: BrainColors.onPrimary,
        secondary: BrainColors.secondary,
        onSecondary: BrainColors.onSecondary,
        tertiary: BrainColors.tertiary,
        error: BrainColors.error,
        onSurface: BrainColors.onSurface,
        onSurfaceVariant: BrainColors.onSurfaceVariant,
        outline: BrainColors.outline,
        outlineVariant: BrainColors.outlineVariant,
        inverseSurface: BrainColors.inverseSurface,
        onInverseSurface: BrainColors.inverseOnSurface,
        inversePrimary: BrainColors.inversePrimary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: BrainColors.onSurface, size: 20),
      ),

      // No elevation cards — tonal separation only
      cardTheme: CardThemeData(
        color: BrainColors.surfaceLow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BrainSpacing.radiusMd),
        margin: EdgeInsets.zero,
      ),

      // Minimal inputs — no borders, focus via background shift
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrainColors.surfaceLow,
        border: OutlineInputBorder(
          borderRadius: BrainSpacing.radiusMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BrainSpacing.radiusMd,
          borderSide: BorderSide(
            color: BrainColors.primary.withValues(alpha: 0.30),
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
          color: BrainColors.outlineVariant.withValues(alpha: 0.5),
          fontSize: 14,
        ),
      ),

      // No dividers — use spacing and tonal shifts
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),

      // Chip — for tags (mono style)
      chipTheme: ChipThemeData(
        backgroundColor: BrainColors.surfaceHigh,
        labelStyle: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          color: BrainColors.primary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BrainSpacing.radiusSm),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      splashColor: BrainColors.primary.withValues(alpha: 0.08),
      highlightColor: BrainColors.primary.withValues(alpha: 0.05),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          BrainColors.outlineVariant.withValues(alpha: 0.4),
        ),
        thickness: WidgetStateProperty.all(3),
        radius: const Radius.circular(2),
      ),
    );
  }
}
