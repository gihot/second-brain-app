import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/capture_provider.dart';
import '../services/speech_service.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Macro-state of the capture surface. One field replaces what used to
/// be four orthogonal-ish bools (_holdRecording, _pendingHoldCapture,
/// _saving, _justSaved). Focus and reminder-toggle remain separate
/// because they're independent concerns (the field can be focused while
/// recording or while saving — they're not macro modes).
///
/// Transitions (happy paths):
///   idle  → recording      (tap mic)
///   idle  → holdRecording  (long-press mic)
///   recording → idle       (tap mic again / speech.onEnd)
///   holdRecording → holdSettling   (release mic)
///   holdSettling → saving           (got text → auto-submit)
///   holdSettling → idle             (no text → back to rest)
///   idle  → saving         (tap "Erfassen")
///   saving → justSaved → idle (1.4s success flash)
///   saving → idle          (server failure)
enum CaptureUiState {
  idle,
  recording,
  holdRecording,
  holdSettling,
  saving,
  justSaved,
}

/// Inline "living" capture module for the dashboard. Capture as mental
/// discharge — not "create a note".
///
/// Three visual states, no screen change:
///  1. Resting — calm surface, contextual prompt, subtle voice + reminder.
///  2. Focus   — text field active, surface expands, tag + reminder row.
///  3. Saved   — brief "Gespeichert ✓", then collapses back to resting.
class CaptureSurface extends StatefulWidget {
  final int captureCount;
  final int inboxCount;

  const CaptureSurface({
    super.key,
    required this.captureCount,
    required this.inboxCount,
  });

  @override
  State<CaptureSurface> createState() => _CaptureSurfaceState();
}

class _CaptureSurfaceState extends State<CaptureSurface> {
  final _controller = TextEditingController();
  final _tagsController = TextEditingController();
  final _focusNode = FocusNode();
  final _speech = SpeechService();

  bool _isReminder = false;
  DateTime? _remindAt;
  Timer? _savedTimer;

  /// Macro-state. See [CaptureUiState] for the transition map.
  CaptureUiState _state = CaptureUiState.idle;

  bool get _isRecording =>
      _state == CaptureUiState.recording ||
      _state == CaptureUiState.holdRecording;

  void _setState(CaptureUiState next) {
    if (_state == next) return;
    setState(() => _state = next);
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    _controller.dispose();
    _tagsController.dispose();
    _focusNode.dispose();
    _speech.dispose();
    super.dispose();
  }

  bool get _focused => _focusNode.hasFocus;

  String get _prompt {
    if (widget.inboxCount > 0) {
      return 'Du hast ${widget.inboxCount} unsortierte Gedanken — '
          'oder erfass einen neuen';
    }
    if (widget.captureCount > 0) {
      return 'Heute schon ${widget.captureCount} erfasst. Was noch?';
    }
    return 'Was geht dir gerade durch den Kopf?';
  }

  void _toggleVoice() {
    if (!SpeechService.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spracheingabe benötigt Chrome oder Edge.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    if (_speech.isListening) {
      _speech.stopListening();
      // Speech.onEnd will flip back to idle; do it eagerly too in case
      // onEnd is slow to fire.
      _setState(CaptureUiState.idle);
      return;
    }
    _focusNode.requestFocus();
    _setState(CaptureUiState.recording);
    _speech.startListening(
      onResult: (transcript) {
        setState(() {
          final cur = _controller.text;
          _controller.text = cur.isEmpty ? transcript : '$cur $transcript';
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
      onEnd: () {
        if (_state == CaptureUiState.recording) {
          _setState(CaptureUiState.idle);
        }
      },
      lang: 'de-DE',
    );
  }

  // ── Voice-First: Hold-to-Talk ───────────────────────────────────────────

  void _startHoldToTalk() {
    if (!SpeechService.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spracheingabe benötigt Chrome oder Edge.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    _focusNode.unfocus(); // hands-free — no keyboard
    _setState(CaptureUiState.holdRecording);
    _speech.startListening(
      onResult: (transcript) {
        final cur = _controller.text;
        _controller.text =
            cur.isEmpty ? transcript : '$cur $transcript';
      },
      onEnd: _onHoldSpeechEnd,
      lang: 'de-DE',
    );
  }

  void _endHoldToTalk() {
    if (_state != CaptureUiState.holdRecording) return;
    _setState(CaptureUiState.holdSettling);
    _speech.stopListening();
    // onEnd (_onHoldSpeechEnd) fires once recognition has settled and
    // pushes us either into saving (if we got text) or back to idle.
  }

  void _onHoldSpeechEnd() {
    if (_state != CaptureUiState.holdSettling) {
      // We're already past settling (e.g. another transition kicked in).
      if (mounted) setState(() {});
      return;
    }
    // Speech finished after release — capture immediately if we got text.
    if (_controller.text.trim().isNotEmpty) {
      _handleCapture();
    } else {
      _setState(CaptureUiState.idle);
    }
  }

  Future<void> _pickRemindAt() async {
    final now = DateTime.now();
    final initial = _remindAt ?? now.add(const Duration(hours: 1));
    Widget theme(BuildContext ctx, Widget? child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: BrainColors.primary,
              surface: BrainColors.surfaceHigh,
            ),
          ),
          child: child!,
        );
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: theme,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: theme,
    );
    if (time == null) return;
    setState(() {
      _isReminder = true;
      _remindAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatRemindAt(DateTime dt) {
    final l = dt.toLocal();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${l.day}.${l.month}. ${p(l.hour)}:${p(l.minute)}';
  }

  Future<void> _handleCapture() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _state == CaptureUiState.saving) return;

    // Tags are appended as inline #hashtags — keeps the capture-flow
    // (CaptureProvider.capture) untouched; Scribe extracts them server-side.
    final tags = _tagsController.text
        .split(RegExp(r'[,\s]+'))
        .map((t) => t.trim().replaceAll('#', ''))
        .where((t) => t.isNotEmpty)
        .map((t) => '#$t')
        .join(' ');
    final fullText = tags.isEmpty ? text : '$text\n\n$tags';
    final reminderIso = _isReminder && _remindAt != null
        ? _remindAt!.toUtc().toIso8601String()
        : null;

    _setState(CaptureUiState.saving);
    final ok = await context
        .read<CaptureProvider>()
        .capture(fullText, remindAtIso: reminderIso);
    if (!mounted) return;

    if (ok) {
      _controller.clear();
      _tagsController.clear();
      _focusNode.unfocus();
      setState(() {
        _isReminder = false;
        _remindAt = null;
      });
      _setState(CaptureUiState.justSaved);
      _savedTimer?.cancel();
      _savedTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted && _state == CaptureUiState.justSaved) {
          _setState(CaptureUiState.idle);
        }
      });
    } else {
      _setState(CaptureUiState.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrainSpacing.screenPadding,
        BrainSpacing.sm,
        BrainSpacing.screenPadding,
        BrainSpacing.sm,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BrainSpacing.md),
          decoration: BoxDecoration(
            color: BrainColors.surfaceLow,
            borderRadius: BrainSpacing.radiusLg,
            border: Border.all(
              color: _focused
                  ? BrainColors.primary.withValues(alpha: 0.30)
                  : BrainColors.outlineVariant.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: switch (_state) {
            CaptureUiState.holdRecording => _listeningView(),
            CaptureUiState.justSaved => _savedView(),
            _ => _captureView(hasText),
          },
        ),
      ),
    );
  }

  Widget _listeningView() {
    return Row(
      children: [
        Icon(Icons.mic_rounded, size: 22, color: BrainColors.error),
        const SizedBox(width: BrainSpacing.sm),
        Expanded(
          child: Text(
            _controller.text.trim().isEmpty
                ? 'Ich höre zu… loslassen zum Speichern'
                : _controller.text,
            style: BrainTypography.bodyMd
                .copyWith(color: BrainColors.onSurface),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _savedView() {
    return Row(
      children: [
        Icon(Icons.check_circle_rounded,
            size: 22, color: BrainColors.secondary),
        const SizedBox(width: BrainSpacing.sm),
        Text('Gedanke gespeichert',
            style: BrainTypography.bodyMd
                .copyWith(color: BrainColors.onSurface)),
      ],
    );
  }

  Widget _captureView(bool hasText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text field — hint carries the contextual prompt.
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: _focused ? null : 2,
          minLines: _focused ? 3 : 1,
          style: BrainTypography.bodyMd.copyWith(
            color: BrainColors.onSurface,
            height: 1.5,
          ),
          cursorColor: BrainColors.primary,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: _prompt,
            hintStyle: BrainTypography.bodyMd.copyWith(
              color: BrainColors.outlineVariant.withValues(alpha: 0.7),
            ),
            border: InputBorder.none,
            isCollapsed: true,
          ),
          onChanged: (_) => setState(() {}),
        ),

        // Focus-only: optional tags + active reminder pill.
        if (_focused) ...[
          const SizedBox(height: BrainSpacing.sm),
          TextField(
            controller: _tagsController,
            style: BrainTypography.bodySm,
            decoration: InputDecoration(
              hintText: 'Tags (optional)',
              hintStyle: BrainTypography.bodySm.copyWith(
                color: BrainColors.outlineVariant.withValues(alpha: 0.7),
              ),
              prefixIcon: Icon(Icons.tag_rounded,
                  size: 16, color: BrainColors.outline),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              isCollapsed: true,
              contentPadding: const EdgeInsets.only(left: 6),
              border: InputBorder.none,
            ),
          ),
        ],

        const SizedBox(height: BrainSpacing.sm),

        // Control row.
        Row(
          children: [
            _IconChip(
              icon: _isRecording
                  ? Icons.mic_rounded
                  : Icons.mic_none_rounded,
              active: _isRecording,
              // Tap = Diktat ins Feld. Halten = Hold-to-Talk: aufnehmen,
              // loslassen erfasst den Gedanken direkt.
              onTap: _toggleVoice,
              onLongPressStart: _startHoldToTalk,
              onLongPressEnd: _endHoldToTalk,
            ),
            const SizedBox(width: BrainSpacing.sm),
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
            const Spacer(),
            if (hasText)
              GestureDetector(
                onTap: _state == CaptureUiState.saving
                    ? null
                    : _handleCapture,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: BrainColors.captureGradient,
                    borderRadius: BrainSpacing.radiusFull,
                  ),
                  child: _state == CaptureUiState.saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Erfassen',
                                style: BrainTypography.button
                                    .copyWith(color: Colors.white)),
                            const SizedBox(width: 6),
                            const Icon(Icons.north_rounded,
                                size: 16, color: Colors.white),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  const _IconChip({
    required this.icon,
    required this.active,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart:
          onLongPressStart == null ? null : (_) => onLongPressStart!(),
      onLongPressEnd:
          onLongPressEnd == null ? null : (_) => onLongPressEnd!(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active
              ? BrainColors.error.withValues(alpha: 0.15)
              : BrainColors.surfaceHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 18,
            color: active
                ? BrainColors.error
                : BrainColors.onSurfaceVariant),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? BrainColors.tertiary.withValues(alpha: 0.15)
              : BrainColors.surfaceHigh,
          borderRadius: BrainSpacing.radiusFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? Icons.alarm_rounded : Icons.alarm_add_outlined,
                size: 15, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: BrainTypography.labelSm.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
