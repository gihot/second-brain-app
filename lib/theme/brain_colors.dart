import 'package:flutter/material.dart';

/// Second Brain Color System — "The Digital Curator"
/// Based on Google Stitch export (neural_flux design system).
/// Rooted in #111319 Deep Ink with tonal layering, no hard borders.
class BrainColors {
  BrainColors._();

  // ── Surfaces (tonal depth through layering, not lines) ──
  static const Color base = Color(0xFF111319); // Canvas
  static const Color surfaceDim = Color(0xFF111319);
  static const Color surfaceLow = Color(0xFF191B22); // Section grouping
  static const Color surface = Color(0xFF1E1F26); // Container
  static const Color surfaceHigh = Color(0xFF282A30); // Hover / active card
  static const Color surfaceHighest = Color(0xFF33343B);
  static const Color surfaceBright = Color(0xFF373940); // Glassmorphism base
  static const Color surfaceLowest = Color(0xFF0C0E14); // Deepest recessed

  // ── Primary — Light Lavender ──
  static const Color primary = Color(0xFFC0C1FF);
  static const Color primaryContainer = Color(0xFF8083FF);
  static const Color primaryFixed = Color(0xFFE1E0FF);
  static const Color primaryFixedDim = Color(0xFFC0C1FF);
  static const Color onPrimary = Color(0xFF1000A9);
  static const Color inversePrimary = Color(0xFF494BD6);

  // ── Secondary — Mint Green ──
  static const Color secondary = Color(0xFF45DFA4);
  static const Color secondaryContainer = Color(0xFF00BD85);
  static const Color onSecondary = Color(0xFF003825);

  // ── Tertiary — Warm Amber ──
  static const Color tertiary = Color(0xFFFFB95F);
  static const Color tertiaryContainer = Color(0xFFCA8100);
  static const Color onTertiary = Color(0xFF472A00);

  // ── Capture CTA gradient (different from primary) ──
  static const LinearGradient captureGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  );

  // ── Primary gradient (for FAB, CTAs) ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment(0.0, -1.0),
    end: Alignment(1.0, 1.0),
    colors: [primary, primaryContainer],
  );

  // ── Semantic ──
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);

  // ── Text ──
  static const Color onSurface = Color(0xFFF2F2F6); // Primary text
  static const Color onSurfaceVariant = Color(0xFFC5C2D2); // Secondary text
  static const Color outline = Color(0xFF908FA0);
  static const Color outlineVariant = Color(
    0xFF464554,
  ); // Ghost borders (10–15% opacity only)

  // ── Inverse ──
  static const Color inverseSurface = Color(0xFFE2E2EB);
  static const Color inverseOnSurface = Color(0xFF2E3037);

  // ── Glass / Solid semantic surfaces (v2 handoff) ──
  // Glass → thoughts, atmosphere, living cards. Solid → lists, settings, system.
  static Color get glassSurface =>
      const Color(0xFF0A0C14).withValues(alpha: 0.42);
  static Color get glassSurfaceHigh =>
      const Color(0xFF0A0C14).withValues(alpha: 0.55);
  static Color get glassBorder =>
      const Color(0xFFFFFFFF).withValues(alpha: 0.07);
  static Color get solidSurface =>
      const Color(0xFF101218).withValues(alpha: 0.94);
  static Color get solidSurfaceHigh =>
      const Color(0xFF161820).withValues(alpha: 0.96);
  static Color get solidBorder =>
      const Color(0xFFFFFFFF).withValues(alpha: 0.04);
  static Color get innerSurface =>
      const Color(0xFFFFFFFF).withValues(alpha: 0.035);
  static Color get innerBorder =>
      const Color(0xFFFFFFFF).withValues(alpha: 0.05);
  static Color get divider => const Color(0xFFFFFFFF).withValues(alpha: 0.05);

  // ── Frosted-card glass (used over imagery / sunset backgrounds) ──────
  // Dark frost: black at 30%, distinct from glassSurface which is meant
  // for the AppBar's "bright" blur over deep ink.
  static Color get glassCardFill => glassSurface;
  static Color get glassCardBorder => glassBorder;
  // v2: less frosty haze; content should sit in atmosphere, not behind fog.
  static const double glassCardBlur = 8.0;

  // ── Tinted glow shadows (never neutral grey) ──
  static Color get primaryGlow => primary.withValues(alpha: 0.20);
  static Color get captureGlow =>
      const Color(0xFF6366F1).withValues(alpha: 0.20);

  // ── MemoryHall colors ──
  static const Color hallFact = Color(0xFFC0C1FF); // primary lavender
  static const Color hallEvent = Color(0xFF45DFA4); // secondary mint
  static const Color hallDiscovery = Color(0xFFFFB95F); // tertiary amber
  static const Color hallPreference = Color(0xFFC4A3E8); // soft purple
  static const Color hallAdvice = Color(0xFF7FD1FF); // sky blue
  static const Color hallUnclassified = Color(0xFF908FA0); // outline grey
}
