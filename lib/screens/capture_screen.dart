import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/capture_provider.dart';
import '../services/speech_service.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../widgets/glass_card_surface.dart';

/// Full capture screen opened by the MIC tab.
class CaptureScreen extends StatefulWidget {
  final String? initialText;
  final ValueListenable<int>? voiceTrigger;

  const CaptureScreen({super.key, this.initialText, this.voiceTrigger});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _speech = SpeechService();
  bool _isReminder = false;
  DateTime? _remindAt;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _controller.text = widget.initialText!;
    }
    widget.voiceTrigger?.addListener(_onVoiceTrigger);
  }

  void _onVoiceTrigger() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _speech.isListening) return;
      _toggleVoice();
    });
  }

  @override
  void dispose() {
    widget.voiceTrigger?.removeListener(_onVoiceTrigger);
    _controller.dispose();
    _focusNode.dispose();
    _speech.dispose();
    super.dispose();
  }

  void _toggleVoice() {
    if (!SpeechService.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Spracheingabe benötigt Chrome oder Edge.'),
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
    final reminderIso = _isReminder && _remindAt != null
        ? _remindAt!.toUtc().toIso8601String()
        : null;
    final ok = await context.read<CaptureProvider>().capture(
      text,
      remindAtIso: reminderIso,
    );
    if (ok && mounted) {
      _controller.clear();
      setState(() {
        _isReminder = false;
        _remindAt = null;
      });
      _focusNode.requestFocus();
    }
  }

  Future<void> _pickRemindAt() async {
    final now = DateTime.now();
    final initial = _remindAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: BrainColors.primary,
            surface: BrainColors.surfaceHigh,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: BrainColors.primary,
            surface: BrainColors.surfaceHigh,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _isReminder = true;
      _remindAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formatRemindAt(DateTime dt) {
    final l = dt.toLocal();
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${l.day}.${l.month}.${l.year} ${pad(l.hour)}:${pad(l.minute)}';
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
        color: BrainColors.base.withValues(alpha: 0.92),
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
                Text('NEUER GEDANKE', style: BrainTypography.labelSm),
                const SizedBox(height: BrainSpacing.sm),
                Text(
                  'Was denkst\ndu gerade?',
                  style: BrainTypography.displayMd,
                ),
                const SizedBox(height: BrainSpacing.lg),
                Expanded(
                  child: GlassCardSurface(
                    borderRadius: BrainSpacing.radiusLg,
                    padding: const EdgeInsets.all(BrainSpacing.md),
                    child: Column(
                      children: [
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
                                color: BrainColors.outlineVariant.withValues(
                                  alpha: 0.50,
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              filled: false,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: BrainSpacing.sm,
                            runSpacing: BrainSpacing.sm,
                            children: [
                              _ReminderChip(
                                active: _isReminder,
                                label: _isReminder && _remindAt != null
                                    ? _formatRemindAt(_remindAt!)
                                    : 'Erinnerung',
                                onTap: () {
                                  if (_isReminder) {
                                    setState(() {
                                      _isReminder = false;
                                      _remindAt = null;
                                    });
                                  } else {
                                    _pickRemindAt();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: BrainSpacing.lg,
                          color: BrainColors.divider,
                        ),
                        Row(
                          children: [
                            _MicButton(
                              listening: _speech.isListening,
                              onTap: _toggleVoice,
                            ),
                            const Spacer(),
                            _CaptureButton(
                              enabled: hasText && !isCapturing,
                              loading: isCapturing,
                              success: didSucceed,
                              onTap: _handleCapture,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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

class _ReminderChip extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;

  const _ReminderChip({
    required this.active,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? BrainColors.tertiary : BrainColors.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? BrainColors.tertiary.withValues(alpha: 0.18)
              : BrainColors.innerSurface,
          borderRadius: BrainSpacing.radiusFull,
          border: active
              ? Border.all(
                  color: BrainColors.tertiary.withValues(alpha: 0.30),
                  width: 0.5,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.alarm_rounded : Icons.alarm_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(label, style: BrainTypography.labelSm.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final bool success;
  final VoidCallback onTap;

  const _CaptureButton({
    required this.enabled,
    required this.loading,
    required this.success,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: success
              ? null
              : enabled
              ? BrainColors.captureGradient
              : null,
          color: success
              ? BrainColors.secondary
              : enabled
              ? null
              : BrainColors.innerSurface,
          borderRadius: BrainSpacing.radiusFull,
          boxShadow: enabled && !success
              ? [
                  BoxShadow(
                    color: BrainColors.captureGlow,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else if (success) ...[
              const Icon(Icons.check_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Erfasst',
                style: BrainTypography.button.copyWith(color: Colors.white),
              ),
            ] else ...[
              Text(
                'Erfassen',
                style: BrainTypography.button.copyWith(
                  color: enabled
                      ? Colors.white
                      : BrainColors.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.north_rounded,
                size: 18,
                color: enabled
                    ? Colors.white
                    : BrainColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ],
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
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
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
                    : BrainColors.innerSurface,
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
