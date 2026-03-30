import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'brain_colors.dart';

/// Second Brain Typography — "Editorial Authority"
/// Inter Variable for UI, JetBrains Mono for metadata/labels.
/// Hierarchy through value (color) not just weight.
class BrainTypography {
  BrainTypography._();

  // ── Display (high-impact landing moments) ──
  static TextStyle get displayLg => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -1.0,
        color: BrainColors.onSurface,
      );

  static TextStyle get displayMd => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.72,
        color: BrainColors.onSurface,
      );

  // ── Headlines (anchors of notes) ──
  static TextStyle get headlineMd => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.28,
        color: BrainColors.onSurface,
      );

  static TextStyle get headlineSm => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.22,
        color: BrainColors.onSurface,
      );

  // ── Title ──
  static TextStyle get titleMd => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.18,
        color: BrainColors.onSurface,
      );

  // ── Body — line-height 1.6 for reading comfort ──
  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: BrainColors.onSurface,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: BrainColors.onSurface,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: BrainColors.onSurfaceVariant,
      );

  // ── Metadata (JetBrains Mono) — signals "data" vs "thought" ──
  // Use for timestamps, tags, IDs, system labels
  static TextStyle get labelSm => GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0.8,
        color: BrainColors.onSurfaceVariant,
      );

  static TextStyle get labelMd => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0.5,
        color: BrainColors.onSurfaceVariant,
      );

  // ── Nav labels (mono uppercase) ──
  static TextStyle get navLabel => GoogleFonts.jetBrainsMono(
        fontSize: 9,
        fontWeight: FontWeight.w500,
        height: 1.0,
        letterSpacing: 0.9,
        color: BrainColors.onSurfaceVariant,
      );

  // ── Button ──
  static TextStyle get button => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.0,
        color: BrainColors.onSurface,
      );

  // ── Tag chips ──
  static TextStyle get tag => GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: BrainColors.primary,
      );
}
