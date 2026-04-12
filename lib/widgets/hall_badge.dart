import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_typography.dart';

Color hallColor(MemoryHall hall) {
  switch (hall) {
    case MemoryHall.fact:
      return BrainColors.hallFact;
    case MemoryHall.event:
      return BrainColors.hallEvent;
    case MemoryHall.discovery:
      return BrainColors.hallDiscovery;
    case MemoryHall.preference:
      return BrainColors.hallPreference;
    case MemoryHall.advice:
      return BrainColors.hallAdvice;
    case MemoryHall.unclassified:
      return BrainColors.hallUnclassified;
  }
}

String hallLabel(MemoryHall hall) {
  switch (hall) {
    case MemoryHall.fact:        return 'Fact';
    case MemoryHall.event:       return 'Event';
    case MemoryHall.discovery:   return 'Discovery';
    case MemoryHall.preference:  return 'Preference';
    case MemoryHall.advice:      return 'Advice';
    case MemoryHall.unclassified: return 'Unclassified';
  }
}

class HallBadge extends StatelessWidget {
  final MemoryHall hall;
  const HallBadge({super.key, required this.hall});

  @override
  Widget build(BuildContext context) {
    final color = hallColor(hall);
    if (hall == MemoryHall.unclassified) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Text(
        hallLabel(hall),
        style: BrainTypography.tag.copyWith(color: color),
      ),
    );
  }
}
