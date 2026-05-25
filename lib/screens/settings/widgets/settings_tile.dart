import 'package:flutter/material.dart';

import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Standard-Listen-Tile für die Settings-Sektionen: Icon, Label, Wert,
/// optionaler `onTap`. Highlightet sich beim Hovern.
class SettingsTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? statusDotColor;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.statusDotColor,
    this.onTap,
  });

  @override
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: BrainSpacing.md,
            vertical: BrainSpacing.md,
          ),
          color: _hovered && widget.onTap != null
              ? BrainColors.innerSurface
              : Colors.transparent,
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: 16,
                        color: BrainColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (widget.statusDotColor != null)
                    Positioned(
                      top: -2,
                      right: -3,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: widget.statusDotColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.statusDotColor!.withValues(
                                alpha: 0.55,
                              ),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(widget.label, style: BrainTypography.bodyMd),
              ),
              if (widget.value.isNotEmpty)
                Text(
                  widget.value,
                  style: BrainTypography.bodySm.copyWith(
                    color: widget.valueColor ?? BrainColors.onSurfaceVariant,
                  ),
                ),
              if (widget.onTap != null) ...[
                const SizedBox(width: BrainSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: BrainColors.outline.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
