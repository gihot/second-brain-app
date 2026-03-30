import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/capture_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

class CaptureSheet extends StatefulWidget {
  const CaptureSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: Provider.of<CaptureProvider>(context, listen: false),
        child: const CaptureSheet(),
      ),
    );
  }

  @override
  State<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<CaptureSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final capture = context.read<CaptureProvider>();
    final ok = await capture.capture(text);
    if (ok && mounted) {
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final captureState = context.watch<CaptureProvider>().state;
    final hasText = _controller.text.trim().isNotEmpty;
    final isCapturing = captureState == CaptureState.capturing;
    final didSucceed = captureState == CaptureState.success;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: BrainColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: BrainSpacing.sm),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: BrainColors.border,
              borderRadius: BrainSpacing.radiusFull,
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                BrainSpacing.screenPadding, BrainSpacing.md, BrainSpacing.sm, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'What are you thinking?',
                  style: BrainTypography.heading
                      .copyWith(color: BrainColors.textSecondary),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: BrainColors.textTertiary),
                ),
              ],
            ),
          ),

          // Text input
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: BrainSpacing.screenPadding),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 3,
              style: BrainTypography.bodyLarge,
              cursorColor: BrainColors.accent,
              cursorWidth: 2,
              decoration: InputDecoration(
                hintText: 'Just start typing...',
                hintStyle: BrainTypography.bodyLarge
                    .copyWith(color: BrainColors.textDisabled),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(BrainSpacing.screenPadding,
                BrainSpacing.sm, BrainSpacing.screenPadding, BrainSpacing.lg),
            child: Row(
              children: [
                // Voice button (placeholder)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: BrainColors.subtle,
                    borderRadius: BrainSpacing.radiusSm,
                  ),
                  child: const Icon(Icons.mic_outlined,
                      size: 20, color: BrainColors.textTertiary),
                ),

                const Spacer(),

                // Send button with state animation
                GestureDetector(
                  onTap: hasText && !isCapturing ? _handleSend : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: didSucceed
                          ? BrainColors.success
                          : hasText
                              ? BrainColors.accent
                              : BrainColors.subtle,
                      borderRadius: BrainSpacing.radiusSm,
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
                              color: BrainColors.onAccent,
                            ),
                          )
                        else if (didSucceed)
                          const Icon(Icons.check_rounded,
                              size: 18, color: BrainColors.onAccent)
                        else ...[
                          Text(
                            'Capture',
                            style: BrainTypography.button.copyWith(
                              color: hasText
                                  ? BrainColors.onAccent
                                  : BrainColors.textDisabled,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            color: hasText
                                ? BrainColors.onAccent
                                : BrainColors.textDisabled,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
