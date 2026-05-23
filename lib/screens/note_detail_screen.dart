import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/vault_provider.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../widgets/brain_button.dart';
import '../widgets/connection_card.dart';
import '../widgets/hall_badge.dart';

/// Read + edit + archive + delete a single note.
///
/// Pushed via Navigator, never a tab. Local edits are truth-of-record;
/// server sync is fire-and-forget via VaultProvider (which queues on failure).
class NoteDetailScreen extends StatefulWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _tagsCtrl;
  late ParaCategory _para;
  late MemoryHall _hall;
  late ThoughtType _thoughtType;
  String? _remindAt;
  late final TextEditingController _wingCtrl;
  bool _editing = false;
  bool _dirty = false;

  List<Map<String, dynamic>> _connections = [];
  bool _loadingConnections = false;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    final note = _readNote();
    _titleCtrl = TextEditingController(text: note?.title ?? '');
    _contentCtrl = TextEditingController(text: _stripFrontmatter(note?.content ?? ''));
    _tagsCtrl = TextEditingController(text: note?.tags.join(', ') ?? '');
    _para = note?.para ?? ParaCategory.inbox;
    _hall = note?.hall ?? MemoryHall.unclassified;
    _thoughtType = note?.thoughtType ?? ThoughtType.standard;
    _remindAt = note?.remindAt;
    final wingDisplay = note?.wing?.split('-').map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        }).join(' ') ??
        '';
    _wingCtrl = TextEditingController(text: wingDisplay);

    for (final c in [_titleCtrl, _contentCtrl, _tagsCtrl]) {
      c.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
    }

    // Load cached connections immediately (if any).
    _connections = CacheService.instance.getConnections(widget.noteId);

    // Retrieval-first: if no cached connections, auto-discover them once
    // the screen has settled — so the VERBINDUNGEN section is populated
    // instead of showing an empty "Verbindungen finden"-Button.
    if (_connections.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_editing) _findConnections(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    _wingCtrl.dispose();
    super.dispose();
  }

  Note? _readNote() {
    final vault = context.read<VaultProvider>();
    try {
      return vault.notes.firstWhere((n) => n.id == widget.noteId);
    } catch (_) {
      return null;
    }
  }

  String _stripFrontmatter(String content) {
    final match = RegExp(r'^---.*?---\s*', dotAll: true).firstMatch(content);
    if (match == null) return content;
    return content.substring(match.end);
  }

  Future<void> _save() async {
    final note = _readNote();
    if (note == null) return;

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim().replaceAll('#', ''))
        .where((t) => t.isNotEmpty)
        .toList();

    // Normalize wing to kebab-case
    final rawWing = _wingCtrl.text.trim();
    final normalizedWing = rawWing.isEmpty
        ? null
        : rawWing.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

    final updated = note.copyWith(
      title: _titleCtrl.text.trim().isEmpty ? 'Untitled' : _titleCtrl.text.trim(),
      content: _contentCtrl.text,
      tags: tags,
      para: _para,
      hall: _hall,
      wing: normalizedWing,
      clearWing: normalizedWing == null,
      thoughtType: _thoughtType,
      remindAt: _thoughtType == ThoughtType.reminder ? _remindAt : null,
      clearRemindAt: _thoughtType != ThoughtType.reminder,
    );

    await context.read<VaultProvider>().updateNote(updated);
    if (!mounted) return;
    setState(() {
      _editing = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gespeichert'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrainColors.surfaceHigh,
        title: const Text('Gedanke löschen?'),
        content: const Text('Dies kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: BrainColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<VaultProvider>().deleteNote(widget.noteId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _archive() async {
    await context.read<VaultProvider>().archiveNote(widget.noteId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  /// Fetches the embedding-index nearest neighbors for this note. Cheap and
  /// instant (no Claude call) since the vectors are already on the server.
  ///
  /// [silent] = true for the auto-trigger on screen open: a missing server
  /// must NOT surface an error. Manual invocation reports errors normally.
  Future<void> _findConnections({bool silent = false}) async {
    final note = _readNote();
    if (note == null) return;
    setState(() {
      _loadingConnections = true;
      _connectionError = null;
    });

    final response = await ApiService.instance.getRelated(note.id, limit: 5);

    if (!mounted) return;

    if (response == null) {
      setState(() {
        _loadingConnections = false;
        _connectionError = silent
            ? null
            : 'Verbindungssuche nicht erreichbar. Prüfe deine Verbindung.';
      });
      return;
    }

    // Map embedding hits to the ConnectionCard format we cache + render.
    final parsed = response.map((r) {
      final sim = (r['similarity'] as num?)?.toDouble() ?? 0.0;
      final percent = (sim * 100).round().clamp(0, 100);
      return {
        'file_path': r['file_path'] as String? ?? '',
        'title': r['title'] as String? ?? '',
        'connection_type': 'ähnlich',
        'explanation': '$percent% Übereinstimmung',
        'similarity': sim,
      };
    }).toList();

    await CacheService.instance.saveConnections(widget.noteId, parsed);
    setState(() {
      _connections = parsed;
      _loadingConnections = false;
      if (parsed.isEmpty) {
        _connectionError =
            'Noch keine Verbindungen gefunden. Füge mehr Gedanken hinzu.';
      }
    });
  }

  String _formatRemindAt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.day}.${local.month}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _openConnection(String filePath) {
    final target = context.read<VaultProvider>().getNoteByFilePath(filePath);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gedanke "$filePath" nicht lokal gefunden'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteDetailScreen(noteId: target.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch to rebuild if the note changes externally (sync result).
    final vault = context.watch<VaultProvider>();
    Note? note;
    try {
      note = vault.notes.firstWhere((n) => n.id == widget.noteId);
    } catch (_) {
      note = null;
    }

    if (note == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: BrainColors.base),
        body: const Center(child: Text('Gedanke nicht gefunden')),
      );
    }

    return PopScope(
      canPop: !(_editing && _dirty),
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: BrainColors.surfaceHigh,
            title: const Text('Änderungen verwerfen?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Zurück'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    foregroundColor: BrainColors.error),
                child: const Text('Verwerfen'),
              ),
            ],
          ),
        );
        if (discard == true && mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: BrainColors.base,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: BrainColors.glassSurface),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_editing && _dirty)
            IconButton(
              icon: const Icon(Icons.check_rounded, color: BrainColors.secondary),
              tooltip: 'Speichern',
              onPressed: _save,
            )
          else
            IconButton(
              icon: Icon(_editing ? Icons.close_rounded : Icons.edit_outlined),
              tooltip: _editing ? 'Abbrechen' : 'Bearbeiten',
              onPressed: () {
                setState(() {
                  if (_editing && _dirty) {
                    // Discard: reload from source.
                    final n = _readNote();
                    if (n != null) {
                      _titleCtrl.text = n.title;
                      _contentCtrl.text = _stripFrontmatter(n.content);
                      _tagsCtrl.text = n.tags.join(', ');
                      _para = n.para;
                      _hall = n.hall;
                      _thoughtType = n.thoughtType;
                      _remindAt = n.remindAt;
                      _wingCtrl.text = n.wing?.split('-').map((w) {
                            if (w.isEmpty) return w;
                            return w[0].toUpperCase() + w.substring(1);
                          }).join(' ') ??
                          '';
                    }
                    _dirty = false;
                  }
                  _editing = !_editing;
                });
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: BrainColors.surfaceHigh,
            onSelected: (v) {
              if (v == 'archive') _archive();
              if (v == 'delete') _confirmDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'archive',
                child: Row(children: [
                  Icon(Icons.archive_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Archivieren'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_outline_rounded,
                      size: 18, color: BrainColors.error),
                  const SizedBox(width: 8),
                  Text('Löschen',
                      style: TextStyle(color: BrainColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          BrainSpacing.screenPadding,
          MediaQuery.of(context).padding.top + kToolbarHeight + BrainSpacing.md,
          BrainSpacing.screenPadding,
          BrainSpacing.xxl,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxWidth: BrainSpacing.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  if (_editing)
                    TextField(
                      controller: _titleCtrl,
                      style: BrainTypography.headlineMd,
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Titel',
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  else
                    Text(note.title, style: BrainTypography.headlineMd),

                  const SizedBox(height: BrainSpacing.sm),

                  // Unified meta wrap: ThoughtType · Hall · PARA · (Wing chip view-only)
                  Wrap(
                    spacing: BrainSpacing.sm,
                    runSpacing: BrainSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _ThoughtTypeSelector(
                        thoughtType: _thoughtType,
                        editable: _editing,
                        onChanged: (t) => setState(() {
                          _thoughtType = t;
                          if (t != ThoughtType.reminder) _remindAt = null;
                          _dirty = true;
                        }),
                      ),
                      _HallSelector(
                        hall: _hall,
                        editable: _editing,
                        onChanged: (h) => setState(() {
                          _hall = h;
                          _dirty = true;
                        }),
                      ),
                      _ParaBadge(
                        para: _para,
                        editable: _editing,
                        onChanged: (p) => setState(() {
                          _para = p;
                          _dirty = true;
                        }),
                      ),
                      if (!_editing &&
                          note.wing != null &&
                          note.wing!.isNotEmpty)
                        _WingChip(wing: note.wing!),
                    ],
                  ),

                  const SizedBox(height: BrainSpacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      note.relativeTime,
                      style: BrainTypography.labelSm.copyWith(
                          color: BrainColors.onSurfaceVariant),
                    ),
                  ),

                  // Reminder Thought-Node (edit + view modes)
                  if (_editing && _thoughtType == ThoughtType.reminder) ...[
                    const SizedBox(height: BrainSpacing.sm),
                    _ReminderNode(
                      formatted:
                          _remindAt != null ? _formatRemindAt(_remindAt!) : null,
                      child: _RemindAtPicker(
                        value: _remindAt,
                        onChanged: (iso) => setState(() {
                          _remindAt = iso;
                          _dirty = true;
                        }),
                      ),
                    ),
                  ] else if (!_editing &&
                      note.thoughtType == ThoughtType.reminder &&
                      note.remindAt != null) ...[
                    const SizedBox(height: BrainSpacing.sm),
                    _ReminderNode(
                      formatted: _formatRemindAt(note.remindAt!),
                    ),
                  ],

                  const SizedBox(height: BrainSpacing.lg),

                  // Content
                  if (_editing)
                    TextField(
                      controller: _contentCtrl,
                      style: BrainTypography.bodyMd
                          .copyWith(color: BrainColors.onSurface, height: 1.55),
                      maxLines: null,
                      minLines: 8,
                      decoration: InputDecoration(
                        hintText: 'Schreib los...',
                        filled: true,
                        fillColor: BrainColors.surfaceLow,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: BrainSpacing.md,
                            vertical: BrainSpacing.md),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BrainSpacing.radiusMd,
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BrainSpacing.radiusMd,
                          borderSide: BorderSide(
                            color:
                                BrainColors.primary.withValues(alpha: 0.30),
                            width: 1,
                          ),
                        ),
                      ),
                    )
                  else
                    SelectableText(
                      _stripFrontmatter(note.content),
                      style: BrainTypography.bodyMd
                          .copyWith(color: BrainColors.onSurface, height: 1.55),
                    ),

          const SizedBox(height: BrainSpacing.xl),

          // Tags
          if (_editing)
            TextField(
              controller: _tagsCtrl,
              style: BrainTypography.bodySm,
              decoration: InputDecoration(
                hintText: 'tag1, tag2, tag3',
                prefixIcon: Icon(Icons.tag_rounded,
                    size: 16, color: BrainColors.outline),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )
          else if (note.tags.isNotEmpty)
            Wrap(
              spacing: BrainSpacing.sm,
              runSpacing: BrainSpacing.sm,
              children: note.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: BrainColors.primary.withValues(alpha: 0.10),
                          borderRadius: BrainSpacing.radiusFull,
                        ),
                        child: Text('#$t', style: BrainTypography.tag),
                      ))
                  .toList(),
            ),

          // Wing input
          if (_editing) ...[
            const SizedBox(height: BrainSpacing.sm),
            _WingInput(
              controller: _wingCtrl,
              wings: context.read<VaultProvider>().wings,
              onChanged: (_) {
                if (!_dirty) setState(() => _dirty = true);
              },
            ),
          ],

          // ── Connections section ────────────────────────────────────────
          if (!_editing) ...[
            const SizedBox(height: BrainSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('VERBINDUNGEN', style: BrainTypography.labelSm),
                if (_connections.isNotEmpty && !_loadingConnections)
                  GestureDetector(
                    onTap: _findConnections,
                    child: Text(
                      'Aktualisieren',
                      style: BrainTypography.labelSm
                          .copyWith(color: BrainColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: BrainSpacing.sm),
            if (_loadingConnections)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: BrainSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BrainColors.primary,
                    ),
                  ),
                ),
              )
            else if (_connectionError != null)
              Text(
                _connectionError!,
                style: BrainTypography.bodySm
                    .copyWith(color: BrainColors.error),
              )
            else if (_connections.isEmpty)
              SizedBox(
                width: double.infinity,
                child: BrainButton(
                  label: 'Verbindungen finden',
                  icon: Icons.hub_outlined,
                  variant: BrainButtonVariant.secondary,
                  onPressed: _findConnections,
                ),
              )
            else
              ..._connections.map((c) => Padding(
                    padding: const EdgeInsets.only(
                        bottom: BrainSpacing.cardGap),
                    child: ConnectionCard(
                      targetTitle: (c['title'] as String?)?.trim().isNotEmpty == true
                          ? c['title'] as String
                          : (c['file_path'] as String? ?? 'Unknown')
                              .split('/')
                              .last
                              .replaceAll('.md', ''),
                      connectionType:
                          c['connection_type'] as String? ?? 'related',
                      explanation: c['explanation'] as String? ?? '',
                      onTap: () =>
                          _openConnection(c['file_path'] as String? ?? ''),
                    ),
                  )),
          ],
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

class _ParaBadge extends StatelessWidget {
  final ParaCategory para;
  final bool editable;
  final ValueChanged<ParaCategory> onChanged;

  const _ParaBadge({
    required this.para,
    required this.editable,
    required this.onChanged,
  });

  static const _labels = {
    ParaCategory.inbox: 'Inbox',
    ParaCategory.projects: 'Projects',
    ParaCategory.areas: 'Areas',
    ParaCategory.resources: 'Resources',
    ParaCategory.archive: 'Archive',
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[para] ?? 'Inbox';

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BrainColors.surfaceHigh,
        borderRadius: BrainSpacing.radiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: BrainTypography.labelSm),
          if (editable) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16, color: BrainColors.outline),
          ],
        ],
      ),
    );

    if (!editable) return badge;

    return PopupMenuButton<ParaCategory>(
      color: BrainColors.surfaceHigh,
      onSelected: onChanged,
      itemBuilder: (_) => _labels.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      child: badge,
    );
  }
}

class _HallSelector extends StatelessWidget {
  final MemoryHall hall;
  final bool editable;
  final ValueChanged<MemoryHall> onChanged;

  const _HallSelector({
    required this.hall,
    required this.editable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = hallColor(hall);
    final label = hallLabel(hall);

    // View-mode: a thin colored stripe + neutral label — recedes into the
    // background, matches the card-list vocabulary (3px stripe = hall).
    if (!editable) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: BrainTypography.labelSm
                .copyWith(color: BrainColors.onSurfaceVariant),
          ),
        ],
      );
    }

    // Edit-mode: keep the affordance — tinted badge with chevron.
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BrainSpacing.radiusFull,
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: BrainTypography.labelSm.copyWith(color: color)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down_rounded, size: 16, color: color),
        ],
      ),
    );

    return PopupMenuButton<MemoryHall>(
      color: BrainColors.surfaceHigh,
      onSelected: onChanged,
      itemBuilder: (_) => MemoryHall.values
          .map((h) => PopupMenuItem(
                value: h,
                child: Text(hallLabel(h),
                    style: BrainTypography.bodyMd
                        .copyWith(color: hallColor(h))),
              ))
          .toList(),
      child: badge,
    );
  }
}

class _WingInput extends StatefulWidget {
  final TextEditingController controller;
  final List<Map<String, dynamic>> wings;
  final ValueChanged<String>? onChanged;

  const _WingInput({
    required this.controller,
    required this.wings,
    this.onChanged,
  });

  @override
  State<_WingInput> createState() => _WingInputState();
}

class _WingInputState extends State<_WingInput> {
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

// ── ThoughtType Selector ──────────────────────────────────────────────────────

class _ThoughtTypeSelector extends StatelessWidget {
  final ThoughtType thoughtType;
  final bool editable;
  final ValueChanged<ThoughtType> onChanged;

  const _ThoughtTypeSelector({
    required this.thoughtType,
    required this.editable,
    required this.onChanged,
  });

  static const _labels = {
    ThoughtType.standard: 'Gedanke',
    ThoughtType.reminder: 'Erinnerung',
    ThoughtType.question: 'Frage',
    ThoughtType.idea: 'Idee',
  };

  static const _icons = {
    ThoughtType.standard: Icons.edit_note_outlined,
    ThoughtType.reminder: Icons.alarm_outlined,
    ThoughtType.question: Icons.help_outline_rounded,
    ThoughtType.idea: Icons.lightbulb_outline_rounded,
  };

  static const _colors = {
    ThoughtType.standard: BrainColors.outline,
    ThoughtType.reminder: BrainColors.tertiary,
    ThoughtType.question: BrainColors.secondary,
    ThoughtType.idea: BrainColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[thoughtType] ?? 'Gedanke';
    final icon = _icons[thoughtType] ?? Icons.edit_note_outlined;
    final color = _colors[thoughtType] ?? BrainColors.outline;

    final isStandard = thoughtType == ThoughtType.standard;
    final fillColor = isStandard
        ? BrainColors.surfaceHigh
        : color.withValues(alpha: 0.12);
    final borderColor = isStandard
        ? Colors.transparent
        : BrainColors.outlineVariant.withValues(alpha: 0.10);
    final fgColor = isStandard ? BrainColors.onSurfaceVariant : color;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BrainSpacing.radiusFull,
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 6),
          Text(label, style: BrainTypography.labelSm.copyWith(color: fgColor)),
          if (editable) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 14, color: fgColor),
          ],
        ],
      ),
    );

    if (!editable) return badge;

    return PopupMenuButton<ThoughtType>(
      color: BrainColors.surfaceHigh,
      onSelected: onChanged,
      itemBuilder: (_) => ThoughtType.values
          .map((t) => PopupMenuItem(
                value: t,
                child: Row(
                  children: [
                    Icon(_icons[t], size: 16, color: _colors[t]),
                    const SizedBox(width: 8),
                    Text(_labels[t]!,
                        style: BrainTypography.bodyMd
                            .copyWith(color: _colors[t])),
                  ],
                ),
              ))
          .toList(),
      child: badge,
    );
  }
}

// ── RemindAt Picker ───────────────────────────────────────────────────────────

class _RemindAtPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _RemindAtPicker({required this.value, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value != null
        ? (DateTime.tryParse(value!)?.toLocal() ?? now)
        : now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: BrainColors.primary,
            surface: BrainColors.surfaceHigh,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: BrainColors.primary,
            surface: BrainColors.surfaceHigh,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    final combined = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    onChanged(combined.toUtc().toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BrainSpacing.radiusFull,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_calendar_outlined,
                  size: 14, color: BrainColors.primary),
              const SizedBox(width: 6),
              Text(
                value != null ? 'Datum ändern' : 'Datum & Uhrzeit wählen',
                style: BrainTypography.labelSm
                    .copyWith(color: BrainColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Wing Chip (view-only) ─────────────────────────────────────────────────────

class _WingChip extends StatelessWidget {
  final String wing;
  const _WingChip({required this.wing});

  @override
  Widget build(BuildContext context) {
    final display = wing.split('-').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BrainColors.primary.withValues(alpha: 0.10),
        borderRadius: BrainSpacing.radiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 14, color: BrainColors.primary),
          const SizedBox(width: 4),
          Text(display, style: BrainTypography.tag),
        ],
      ),
    );
  }
}

// ── Reminder Thought-Node ─────────────────────────────────────────────────────

class _ReminderNode extends StatelessWidget {
  final String? formatted;
  final Widget? child;

  const _ReminderNode({this.formatted, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BrainSpacing.md),
      decoration: BoxDecoration(
        color: BrainColors.surfaceLow,
        borderRadius: BrainSpacing.radiusMd,
        border: Border.all(
          color: BrainColors.outlineVariant.withValues(alpha: 0.10),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alarm_outlined,
                  size: 14, color: BrainColors.tertiary),
              const SizedBox(width: 6),
              Text(
                'ERINNERUNG',
                style: BrainTypography.labelSm.copyWith(
                  color: BrainColors.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: BrainSpacing.xs),
          Text(
            formatted ?? '— noch kein Zeitpunkt —',
            style: BrainTypography.labelMd
                .copyWith(color: BrainColors.onSurface),
          ),
          if (child != null) ...[
            const SizedBox(height: BrainSpacing.xs),
            child!,
          ],
        ],
      ),
    );
  }
}
