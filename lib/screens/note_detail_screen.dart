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
    );

    await context.read<VaultProvider>().updateNote(updated);
    if (!mounted) return;
    setState(() {
      _editing = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrainColors.surfaceHigh,
        title: const Text('Delete note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: BrainColors.error),
            child: const Text('Delete'),
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

  Future<void> _findConnections() async {
    final note = _readNote();
    if (note == null) return;
    setState(() {
      _loadingConnections = true;
      _connectionError = null;
    });

    final vault = context.read<VaultProvider>();
    final otherNotes = vault.summarizeNotesForContext(excludeId: note.id);

    final message =
        'Find meaningful connections for this note:\n\nTitle: ${note.title}\n\nContent:\n${_stripFrontmatter(note.content)}\n\nTags: ${note.tags.join(', ')}';

    final response = await ApiService.instance.invokeAgent(
      'connector',
      message,
      context: {'notes': otherNotes, 'response_format': 'json'},
    );

    if (!mounted) return;

    if (response == null) {
      setState(() {
        _loadingConnections = false;
        _connectionError = 'Could not reach the Connector. Check your connection.';
      });
      return;
    }

    final metadata = response['metadata'] as Map<String, dynamic>?;
    final rawConnections = metadata?['connections'] as List?;
    if (rawConnections == null) {
      setState(() {
        _loadingConnections = false;
        _connectionError = 'No connections found.';
      });
      return;
    }

    final parsed = rawConnections
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    await CacheService.instance.saveConnections(widget.noteId, parsed);
    setState(() {
      _connections = parsed;
      _loadingConnections = false;
      if (parsed.isEmpty) {
        _connectionError =
            'No meaningful connections found yet. Try adding more notes.';
      }
    });
  }

  void _openConnection(String filePath) {
    final target = context.read<VaultProvider>().getNoteByFilePath(filePath);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note "$filePath" not found locally'),
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
        body: const Center(child: Text('Note not found')),
      );
    }

    return Scaffold(
      backgroundColor: BrainColors.base,
      appBar: AppBar(
        backgroundColor: BrainColors.base,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_editing && _dirty)
            IconButton(
              icon: const Icon(Icons.check_rounded, color: BrainColors.secondary),
              tooltip: 'Save',
              onPressed: _save,
            )
          else
            IconButton(
              icon: Icon(_editing ? Icons.close_rounded : Icons.edit_outlined),
              tooltip: _editing ? 'Cancel' : 'Edit',
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
                  Text('Archive'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_outline_rounded,
                      size: 18, color: BrainColors.error),
                  const SizedBox(width: 8),
                  Text('Delete',
                      style: TextStyle(color: BrainColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BrainSpacing.screenPadding,
          BrainSpacing.sm,
          BrainSpacing.screenPadding,
          BrainSpacing.xxl,
        ),
        children: [
          // Title
          if (_editing)
            TextField(
              controller: _titleCtrl,
              style: BrainTypography.headlineMd,
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Title',
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            )
          else
            Text(note.title, style: BrainTypography.headlineMd),

          const SizedBox(height: BrainSpacing.sm),

          // Meta row: PARA + Hall + time
          Row(
            children: [
              _ParaBadge(
                para: _para,
                editable: _editing,
                onChanged: (p) => setState(() {
                  _para = p;
                  _dirty = true;
                }),
              ),
              const SizedBox(width: BrainSpacing.sm),
              _HallSelector(
                hall: _hall,
                editable: _editing,
                onChanged: (h) => setState(() {
                  _hall = h;
                  _dirty = true;
                }),
              ),
              const Spacer(),
              Text(
                note.relativeTime,
                style: BrainTypography.labelSm,
              ),
            ],
          ),

          const SizedBox(height: BrainSpacing.lg),

          // Content
          if (_editing)
            TextField(
              controller: _contentCtrl,
              style: BrainTypography.bodyMd
                  .copyWith(color: BrainColors.onSurface, height: 1.55),
              maxLines: null,
              minLines: 8,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Start writing...',
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
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
          ] else if (note.wing != null && note.wing!.isNotEmpty) ...[
            const SizedBox(height: BrainSpacing.sm),
            Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 14, color: BrainColors.outline),
                const SizedBox(width: 4),
                Text(
                  note.wing!.split('-').map((w) {
                    if (w.isEmpty) return w;
                    return w[0].toUpperCase() + w.substring(1);
                  }).join(' '),
                  style: BrainTypography.labelSm
                      .copyWith(color: BrainColors.outline),
                ),
              ],
            ),
          ],

          // ── Connections section ────────────────────────────────────────
          if (!_editing) ...[
            const SizedBox(height: BrainSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('CONNECTIONS', style: BrainTypography.labelSm),
                if (_connections.isNotEmpty && !_loadingConnections)
                  GestureDetector(
                    onTap: _findConnections,
                    child: Text(
                      'Refresh',
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
                  label: 'Find Connections',
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
                      targetTitle: (c['file_path'] as String? ?? 'Unknown')
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
    );
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
          if (editable) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 16, color: color),
          ],
        ],
      ),
    );

    if (!editable) return badge;

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
          hintText: 'Wing (e.g. Urban Arcanum)',
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
