import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../models/note_model.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import '../services/api_service.dart';
import '../widgets/brain_button.dart';
import '../widgets/hall_badge.dart';
import 'note_detail_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _triaging = false;

  Future<void> _triageAll(VaultProvider vault) async {
    if (_triaging) return;
    setState(() => _triaging = true);

    final snapshot = List<Note>.from(vault.inboxNotes);
    final count = snapshot.length;

    // Fire server-side Sorter (background task — returns immediately)
    await ApiService.instance.triageAll();

    // Optimistically mark all as processed locally
    for (final note in snapshot) {
      await vault.processNote(note.id);
    }

    if (mounted) {
      setState(() => _triaging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count Gedanke${count == 1 ? '' : 'n'} sortiert',
            style: BrainTypography.bodyMd
                .copyWith(color: BrainColors.onSurface),
          ),
          backgroundColor: BrainColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final inbox = vault.inboxNotes;

    return Padding(
      padding: const EdgeInsets.only(top: BrainSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: BrainSpacing.paddingScreen,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Inbox', style: BrainTypography.displayMd),
                Text(
                  '${inbox.length} Gedanke${inbox.length == 1 ? '' : 'n'}',
                  style: BrainTypography.bodySm,
                ),
              ],
            ),
          ),

          // Triage All button — at the top when inbox has items
          if (inbox.isNotEmpty) ...[
            const SizedBox(height: BrainSpacing.md),
            Padding(
              padding: BrainSpacing.paddingScreen,
              child: SizedBox(
                width: double.infinity,
                child: BrainButton(
                  label: _triaging ? 'Sortiert...' : 'Alle sortieren — KI ordnet alles',
                  icon: Icons.auto_fix_high_rounded,
                  variant: BrainButtonVariant.secondary,
                  loading: _triaging,
                  onPressed: _triaging ? null : () => _triageAll(vault),
                ),
              ),
            ),
          ],

          const SizedBox(height: BrainSpacing.md),

          inbox.isEmpty
              ? Expanded(child: _EmptyInbox())
              : Expanded(
                  child: ListView.separated(
                    padding: BrainSpacing.paddingScreen,
                    itemCount: inbox.length,
                    separatorBuilder: (_, _x) =>
                        const SizedBox(height: BrainSpacing.cardGap),
                    itemBuilder: (_, i) =>
                        _InboxCard(note: inbox[i]),
                  ),
                ),

          SizedBox(height: BrainSpacing.bottomNavHeight),
        ],
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 56,
            color: BrainColors.secondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: BrainSpacing.md),
          Text(
            'Alles erledigt',
            style: BrainTypography.headlineSm
                .copyWith(color: BrainColors.onSurfaceVariant),
          ),
          const SizedBox(height: BrainSpacing.xs),
          Text('Alle Gedanken wurden verarbeitet',
              style: BrainTypography.bodySm),
        ],
      ),
    );
  }
}

class _InboxCard extends StatelessWidget {
  final Note note;

  const _InboxCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final vault = context.read<VaultProvider>();

    return Dismissible(
      key: Key(note.id),
      background: _SwipeBg(
        color: BrainColors.errorContainer,
        icon: Icons.archive_outlined,
        label: 'Archivieren',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBg(
        color: BrainColors.primary.withValues(alpha: 0.20),
        icon: Icons.drive_file_move_outlined,
        label: 'Ablegen',
        alignment: Alignment.centerRight,
      ),
      onDismissed: (dir) {
        if (dir == DismissDirection.startToEnd) {
          vault.archiveNote(note.id);
        } else {
          vault.processNote(note.id);
        }
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BrainSpacing.radiusMd,
        child: InkWell(
          borderRadius: BrainSpacing.radiusMd,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteDetailScreen(noteId: note.id),
            ),
          ),
          child: Container(
            padding: BrainSpacing.paddingCard,
            decoration: BoxDecoration(
              color: BrainColors.surfaceLow,
              borderRadius: BrainSpacing.radiusMd,
              border: Border(
                left: BorderSide(color: hallColor(note.hall), width: 3),
                top: BorderSide(
                    color: BrainColors.outlineVariant.withValues(alpha: 0.15),
                    width: 0.5),
                right: BorderSide(
                    color: BrainColors.outlineVariant.withValues(alpha: 0.15),
                    width: 0.5),
                bottom: BorderSide(
                    color: BrainColors.outlineVariant.withValues(alpha: 0.15),
                    width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: BrainTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: BrainColors.onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note.excerpt,
                      style: BrainTypography.bodySm,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: BrainSpacing.sm),
                Text('Erfasst ${note.relativeTime}',
                    style: BrainTypography.labelSm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  const _SwipeBg(
      {required this.color,
      required this.icon,
      required this.label,
      required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BrainSpacing.lg),
      decoration: BoxDecoration(
          color: color, borderRadius: BrainSpacing.radiusMd),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: BrainColors.onSurface),
          const SizedBox(width: 6),
          Text(label,
              style: BrainTypography.labelSm
                  .copyWith(color: BrainColors.onSurface)),
        ],
      ),
    );
  }
}
