import 'package:flutter/material.dart';

/// Second Brain Spacing & Layout System
/// 8px base grid with 4px fine-tuning.
class BrainSpacing {
  BrainSpacing._();

  // ── Spacing Scale ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  // ── Border Radius ──
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(100));

  // ── Layout ──
  static const double screenPadding = 24;
  static const double maxContentWidth = 640;
  static const double bottomNavHeight = 64;

  // ── Touch Targets ──
  static const double minTouchTarget = 44;
  static const double buttonHeightLg = 48;
  static const double buttonHeightMd = 40;
  static const double buttonHeightSm = 32;
  static const double fabSize = 56;

  // ── Card ──
  static const double cardPadding = 16;
  static const double cardGap = 12;

  // ── Convenience EdgeInsets ──
  static const EdgeInsets paddingScreen = EdgeInsets.symmetric(horizontal: screenPadding);
  static const EdgeInsets paddingCard = EdgeInsets.all(cardPadding);
  static const EdgeInsets paddingSection = EdgeInsets.symmetric(vertical: lg);
}
