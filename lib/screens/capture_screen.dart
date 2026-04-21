import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/capture_provider.dart';
import '../services/speech_service.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Full capture screen. Headline + minimal textarea + capture CTA.
/// Opened via the CAPTURE nav tab.
class CaptureScreen extends StatefulWidget {
  final String? initialText;
  const CaptureScreen({super.key, this.initialText});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _speech = SpeechService();

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _controller.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _speech.dispose();
    super.dispose();
  }

  void _toggleVoice() {
    if (!SpeechService.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Spracheingabe benötigt Chrome oder Edge.'),
          duration: const Duration(seconds: 3),
          backgroundColor: BrainColors.surfaceHigh,
        ),
      );
      return;
    }

    if (_speech.isListening) {
      _speech.stopListening();
      setState(() {});
      return;
    }

    _speech.startListening(
      onResult: (transcript) {
        setState(() {
          final current = _controller.text;
          _controller.text = current.isEmpty
              ? transcript
              : '$current $transcript';
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
      onEnd: () => setState(() {}),
      lang: 'de-DE',
    );
    setState(() {});
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
                  'NEUER GEDANKE',
                  style: BrainTypography.labelSm,
                ),
                const SizedBox(height: BrainSpacing.sm),

                // Headline
                Text(
                  'Was denkst\ndu gerade?',
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
                      hintText: 'Dein Gedankenstrom...',
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
                    _MicButton(
                      listening: _speech.isListening,
                      onTap: _toggleVoice,
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
                              Text('Erfasst',
                                  style: BrainTypography.button
                                      .copyWith(color: Colors.white)),
                            ] else ...[
                              Text(
                                'Erfassen',
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

class _MicButton extends StatefulWidget {
  final bool listening;
  final VoidCallback onTap;

  const _MicButton({required this.listening, required this.onTap});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_MicButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !old.listening) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening && old.listening) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.listening)
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BrainColors.error.withValues(alpha: 0.20),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.listening
                    ? BrainColors.error.withValues(alpha: 0.15)
                    : _hovered
                        ? BrainColors.surfaceHigh
                        : BrainColors.surfaceLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.listening ? Icons.mic_rounded : Icons.mic_outlined,
                size: 22,
                color: widget.listening
                    ? BrainColors.error
                    : BrainColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
