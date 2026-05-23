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
import 'note_detail/widgets/hall_selector.dart';
import 'note_detail/widgets/para_badge.dart';
import 'note_detail/widgets/remind_at_picker.dart';
import 'note_detail/widgets/reminder_node.dart';
import 'note_detail/widgets/thought_type_selector.dart';
import 'note_detail/widgets/wing_chip.dart';
import 'note_detail/widgets/wing_input.dart';

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
                      ThoughtTypeSelector(
                        thoughtType: _thoughtType,
                        editable: _editing,
                        onChanged: (t) => setState(() {
                          _thoughtType = t;
                          if (t != ThoughtType.reminder) _remindAt = null;
                          _dirty = true;
                        }),
                      ),
                      HallSelector(
                        hall: _hall,
                        editable: _editing,
                        onChanged: (h) => setState(() {
                          _hall = h;
                          _dirty = true;
                        }),
                      ),
                      ParaBadge(
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
                        WingChip(wing: note.wing!),
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
                    ReminderNode(
                      formatted:
                          _remindAt != null ? _formatRemindAt(_remindAt!) : null,
                      child: RemindAtPicker(
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
                    ReminderNode(
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
            WingInput(
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
