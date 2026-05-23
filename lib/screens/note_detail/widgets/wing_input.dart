import 'package:flutter/material.dart';

import '../../../theme/brain_colors.dart';
import '../../../theme/brain_spacing.dart';
import '../../../theme/brain_typography.dart';

/// Autocomplete-Input für die Wing-Zugehörigkeit. Zeigt bestehende Wings
/// als Overlay-Vorschläge unter dem Feld an.
class WingInput extends StatefulWidget {
  final TextEditingController controller;
  final List<Map<String, dynamic>> wings;
  final ValueChanged<String>? onChanged;

  const WingInput({
    super.key,
    required this.controller,
    required this.wings,
    this.onChanged,
  });

  @override
  State<WingInput> createState() => _WingInputState();
}

class _WingInputState extends State<WingInput> {
  late final FocusNode _focus;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) _removeOverlay();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _focus.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _suggestions(String query) {
    if (query.isEmpty) return widget.wings;
    final q = query.toLowerCase();
    return widget.wings
        .where((w) =>
            (w['wing'] as String).contains(q) ||
            (w['display'] as String).toLowerCase().contains(q))
        .toList();
  }

  void _showSuggestions(String query) {
    _removeOverlay();
    final suggestions = _suggestions(query);
    if (suggestions.isEmpty) return;

    _overlay = OverlayEntry(
      builder: (ctx) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 36),
          child: Material(
            color: BrainColors.surfaceHigh,
            borderRadius: BrainSpacing.radiusSm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: suggestions
                  .take(5)
                  .map((w) => InkWell(
                        onTap: () {
                          widget.controller.text = w['display'] as String;
                          widget.onChanged?.call(w['display'] as String);
                          _removeOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(w['display'] as String,
                                    style: BrainTypography.bodySm),
                              ),
                              Text('${w['count']}',
                                  style: BrainTypography.labelSm),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        style: BrainTypography.bodySm,
        decoration: InputDecoration(
          hintText: 'Sammlung (z.B. Garten-Projekt)',
          prefixIcon: Icon(Icons.folder_outlined,
              size: 16, color: BrainColors.outline),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (v) {
          widget.onChanged?.call(v);
          _showSuggestions(v);
        },
      ),
    );
  }
}
