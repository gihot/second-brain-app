import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/capture_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Full capture screen. Headline + minimal textarea + capture CTA.
/// Opened via the CAPTURE nav tab.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleCapture() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final ok = await context.read<CaptureProvider>().capture(text);
    if (ok && mounted) {
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final captureState = context.watch<CaptureProvider>().state;
    final isCapturing = captureState == CaptureState.capturing;
    final didSucceed = captureState == CaptureState.success;
    final hasText = _controller.text.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Container(
        color: BrainColors.base,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BrainSpacing.screenPadding,
              BrainSpacing.xxl,
              BrainSpacing.screenPadding,
              BrainSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // System label
                Text(
                  'NEW CAPTURE',
                  style: BrainTypography.labelSm,
                ),
                const SizedBox(height: BrainSpacing.sm),

                // Headline
                Text(
                  'What are you\nthinking?',
                  style: BrainTypography.displayMd,
                ),
                const SizedBox(height: BrainSpacing.lg),

                // Minimal textarea
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: BrainTypography.bodyLg.copyWith(
                      color: BrainColors.onSurfaceVariant,
                    ),
                    cursorColor: BrainColors.primary,
                    cursorWidth: 2,
                    decoration: InputDecoration(
                      hintText: 'Capture your thought stream...',
                      hintStyle: BrainTypography.bodyLg.copyWith(
                        color: BrainColors.outlineVariant
                            .withValues(alpha: 0.50),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(height: BrainSpacing.md),

                // Controls row
                Row(
                  children: [
                    // Voice mic
                    _CircleButton(
                      icon: Icons.mic_outlined,
                      onTap: () {},
                    ),
                    const Spacer(),

                    // Capture CTA — indigo gradient, rounded-full
                    GestureDetector(
                      onTap: hasText && !isCapturing ? _handleCapture : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: didSucceed
                              ? null
                              : hasText
                                  ? BrainColors.captureGradient
                                  : null,
                          color: didSucceed
                              ? BrainColors.secondary
                              : hasText
                                  ? null
                                  : BrainColors.surfaceHigh,
                          borderRadius: BrainSpacing.radiusFull,
                          boxShadow: hasText && !didSucceed
                              ? [
                                  BoxShadow(
                                    color: BrainColors.captureGlow,
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCapturing)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else if (didSucceed) ...[
                              const Icon(Icons.check_rounded,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('Captured',
                                  style: BrainTypography.button
                                      .copyWith(color: Colors.white)),
                            ] else ...[
                              Text(
                                'Capture',
                                style: BrainTypography.button.copyWith(
                                  color: hasText
                                      ? Colors.white
                                      : BrainColors.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.north_rounded,
                                size: 18,
                                color: hasText
                                    ? Colors.white
                                    : BrainColors.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: BrainSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _hovered ? BrainColors.surfaceHigh : BrainColors.surfaceLow,
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon,
              size: 22, color: BrainColors.onSurfaceVariant),
        ),
      ),
    );
  }
}
