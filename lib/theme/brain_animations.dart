/// Second Brain Animation Constants
/// All durations and curves for consistent micro-interactions.
class BrainAnimations {
  BrainAnimations._();

  // ── Durations ──
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration emphasis = Duration(milliseconds: 600);

  // ── Stagger delays for list items ──
  static const Duration staggerDelay = Duration(milliseconds: 50);
}
