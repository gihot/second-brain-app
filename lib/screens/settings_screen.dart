import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../models/offline_capture_model.dart';
import '../providers/background_provider.dart';
import '../providers/capture_provider.dart';
import '../providers/vault_provider.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';
import '../services/vault_import_service.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _serverReachable = false;
  bool _checking = false;
  final _identityCtrl = TextEditingController();
  bool _identitySaving = false;
  bool _notificationsEnabled = false;
  String _notificationPermission = 'default';

  @override
  void initState() {
    super.initState();
    _checkServer();
    _loadIdentity();
    _loadNotificationState();
  }

  void _loadNotificationState() {
    final ns = NotificationService.instance;
    setState(() {
      _notificationsEnabled = ns.notificationsEnabled;
      _notificationPermission = ns.permissionState;
    });
  }

  Future<void> _handleNotificationToggle(bool value) async {
    final ns = NotificationService.instance;
    if (value && !ns.isGranted) {
      final granted = await ns.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Benachrichtigungen wurden vom Browser blockiert. Bitte in den Browser-Einstellungen freigeben.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }
    ns.setEnabled(value);
    if (mounted) {
      setState(() {
        _notificationsEnabled = value;
        _notificationPermission = ns.permissionState;
      });
    }
  }

  @override
  void dispose() {
    _identityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIdentity() async {
    final content = await ApiService.instance.getIdentity();
    if (content != null && mounted) {
      setState(() {
        _identityCtrl.text = content;
      });
    }
  }

  Future<void> _saveIdentity() async {
    setState(() => _identitySaving = true);
    await ApiService.instance.updateIdentity(_identityCtrl.text);
    if (mounted) {
      setState(() => _identitySaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Identität gespeichert'),
            duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _checkServer() async {
    setState(() => _checking = true);
    final ok = await ApiService.instance.ping();
    if (mounted) setState(() { _serverReachable = ok; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final api = ApiService.instance;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BrainSpacing.screenPadding,
              BrainSpacing.xxl,
              BrainSpacing.screenPadding,
              BrainSpacing.lg,
            ),
            child: Text('Einstellungen', style: BrainTypography.displayMd),
          ),
        ),

        SliverPadding(
          padding: BrainSpacing.paddingScreen,
          sliver: SliverList.list(
            children: [
              // ── Connection ──────────────────────────────────────────
              _SettingsSection(
                title: 'CONNECTION',
                items: [
                  _SettingsTile(
                    icon: Icons.cloud_outlined,
                    label: 'API Server',
                    value: api.isConfigured
                        ? (_checking
                            ? 'Prüfe...'
                            : _serverReachable ? 'Verbunden' : 'Nicht erreichbar')
                        : 'Nicht konfiguriert',
                    valueColor: api.isConfigured
                        ? (_serverReachable ? BrainColors.secondary : BrainColors.tertiary)
                        : null,
                    onTap: () => _showApiUrlDialog(context),
                  ),
                  _SettingsTile(
                    icon: Icons.vpn_key_outlined,
                    label: 'API Token',
                    value: api.isConfigured ? '••••••••' : 'Nicht gesetzt',
                    onTap: () => _showApiTokenDialog(context),
                  ),
                  _SettingsTile(
                    icon: Icons.sync_outlined,
                    label: 'Letzter Sync',
                    value: vault.status.lastSyncText,
                    onTap: () async {
                      await vault.refresh();
                      await _checkServer();
                    },
                  ),
                ],
              ),

              const SizedBox(height: BrainSpacing.lg),

              // ── Notifications ───────────────────────────────────────
              _SettingsSection(
                title: 'BENACHRICHTIGUNGEN',
                items: [
                  _NotificationToggleTile(
                    enabled: _notificationsEnabled,
                    permission: _notificationPermission,
                    onToggle: _handleNotificationToggle,
                    onRequestPermission: () async {
                      final granted =
                          await NotificationService.instance.requestPermission();
                      if (mounted) {
                        setState(() {
                          _notificationPermission =
                              NotificationService.instance.permissionState;
                          if (granted) _notificationsEnabled = true;
                        });
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: BrainSpacing.lg),

              // ── Darstellung ─────────────────────────────────────────
              _SettingsSection(
                title: 'DARSTELLUNG',
                items: const [_BackgroundImageTile()],
              ),

              const SizedBox(height: BrainSpacing.lg),

              // ── Vault ───────────────────────────────────────────────
              _SettingsSection(
                title: 'VAULT',
                items: [
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    label: 'Gesamt Gedanken',
                    value: '${vault.status.totalNotes}',
                  ),
                  _SettingsTile(
                    icon: Icons.inbox_outlined,
                    label: 'Inbox',
                    value: '${vault.status.inboxCount}',
                  ),
                  _SettingsTile(
                    icon: Icons.hub_outlined,
                    label: 'Verknüpft',
                    value: '${vault.status.connectedCount}',
                  ),
                  _SettingsTile(
                    icon: Icons.upload_file_outlined,
                    label: 'Aus Vault importieren',
                    value: '',
                    onTap: () => _importFromVault(context),
                  ),
                  _SettingsTile(
                    icon: Icons.cloud_off_outlined,
                    label: 'Offline-Captures',
                    value:
                        '${CacheService.instance.getPendingCaptures().length}',
                    onTap: () => _showOfflineQueueSheet(context),
                  ),
                ],
              ),

              const SizedBox(height: BrainSpacing.lg),

              // ── Identity ────────────────────────────────────────────
              Text('IDENTITY', style: BrainTypography.labelSm),
              const SizedBox(height: BrainSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: BrainColors.surfaceLow,
                  borderRadius: BrainSpacing.radiusMd,
                  border: Border.all(
                      color: BrainColors.outlineVariant.withValues(alpha: 0.15),
                      width: 0.5),
                ),
                padding: const EdgeInsets.all(BrainSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Erzähl deinem Gehirn, wer du bist. Dieser Kontext wird jeder KI-Konversation vorangestellt.',
                      style: BrainTypography.bodySm,
                    ),
                    const SizedBox(height: BrainSpacing.sm),
                    TextField(
                      controller: _identityCtrl,
                      maxLines: 5,
                      maxLength: 800,
                      style: BrainTypography.bodySm,
                      decoration: const InputDecoration(
                        hintText:
                            'I\'m a software engineer building a second brain. I think in systems and value precision...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: BrainSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _identitySaving ? null : _saveIdentity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: BrainColors.primary.withValues(alpha: 0.15),
                            borderRadius: BrainSpacing.radiusFull,
                          ),
                          child: Text(
                            _identitySaving ? 'Speichert...' : 'Identität speichern',
                            style: BrainTypography.button
                                .copyWith(color: BrainColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: BrainSpacing.lg),

              // ── About ───────────────────────────────────────────────
              _SettingsSection(
                title: 'ÜBER',
                items: [
                  _SettingsTile(
                    icon: Icons.info_outlined,
                    label: 'Version',
                    value: 'v0.1.0',
                  ),
                  _SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Lokalen Cache leeren',
                    value: '',
                    onTap: () => _confirmClearCache(context),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: BrainSpacing.bottomNavHeight + BrainSpacing.xl),
        ),
      ],
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  void _showApiUrlDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _InputDialog(
        title: 'API Server URL',
        hint: 'https://your-app.railway.app',
        controller: ctrl,
        onSave: (value) async {
          final token = ApiService.instance.isConfigured
              ? (await const FlutterSecureStorage().read(key: 'api_token') ?? '')
              : '';
          await ApiService.instance.configure(baseUrl: value, token: token);
          if (mounted) {
            setState(() {});
            _checkServer();
          }
        },
      ),
    );
  }

  void _showApiTokenDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _InputDialog(
        title: 'API Token',
        hint: 'Paste your JWT token',
        controller: ctrl,
        obscureText: true,
        onSave: (value) async {
          final url = ApiService.instance.savedBaseUrl ?? '';
          await ApiService.instance.configure(baseUrl: url, token: value);
          if (mounted) {
            setState(() {});
            _checkServer();
          }
        },
      ),
    );
  }

  Future<void> _importFromVault(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final files = result.files
        .where((f) => f.bytes != null)
        .map((f) => (filename: f.name, bytes: f.bytes!))
        .toList();

    final report = await VaultImportService.instance.importFiles(files);
    if (!mounted) return;

    // Trigger UI refresh — the imported notes are now in Hive but the
    // VaultProvider's in-memory list hasn't been rebuilt yet.
    context.read<VaultProvider>().reloadFromCache();

    final msg = report.failed.isEmpty
        ? '${report.written} Gedanken importiert'
        : '${report.written} importiert, ${report.failed.length} '
            'übersprungen (kein gültiges Frontmatter)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  void _showOfflineQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BrainColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) => _OfflineQueueSheet(
        onAdopt: (capture) async {
          // Treat the queued raw text like a fresh capture: create an inbox
          // note locally without server round-trip.
          await context
              .read<CaptureProvider>()
              .saveCaptureLocallyAsNote(capture);
          await CacheService.instance.markCaptureSynced(capture.id);
          await CacheService.instance.clearSyncedCaptures();
        },
        onDiscard: (capture) async {
          await CacheService.instance.markCaptureSynced(capture.id);
          await CacheService.instance.clearSyncedCaptures();
        },
      ),
    );
  }

  void _confirmClearCache(BuildContext context) {
    final unsynced = CacheService.instance.unsyncedCount;

    // Block clear entirely if there are unsynced items — would orphan data.
    if (unsynced > 0) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: BrainColors.surfaceLow,
          title: Text('Cache enthält ungesyncte Daten',
              style: BrainTypography.titleMd),
          content: Text(
            'Es liegen $unsynced Eintrag/-träge in der Sync-Queue, die '
            'noch nicht beim Server angekommen sind. Cache-Leeren ist '
            'gerade blockiert, damit nichts verlorengeht.\n\n'
            'Schau unter „Offline-Captures" / „Pending Writes" nach und '
            'übernimm oder verwirf die Einträge zuerst.',
            style: BrainTypography.bodyMd,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Verstanden',
                  style: BrainTypography.button
                      .copyWith(color: BrainColors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => _ClearCacheDialog(
        onConfirmed: () async {
          try {
            await CacheService.instance.dangerouslyClearAllNotes();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cache geleert'),
                duration: Duration(seconds: 2),
              ),
            );
          } on StateError catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.message),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: BrainTypography.labelSm),
        const SizedBox(height: BrainSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: BrainColors.surfaceLow,
            borderRadius: BrainSpacing.radiusMd,
            border: Border.all(
                color: BrainColors.outlineVariant.withValues(alpha: 0.15),
                width: 0.5),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              return Column(
                children: [
                  items[i],
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      indent: 48,
                      color: BrainColors.outlineVariant.withValues(alpha: 0.10),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: BrainSpacing.md,
            vertical: BrainSpacing.cardGap,
          ),
          color: _hovered && widget.onTap != null
              ? BrainColors.surfaceHigh.withValues(alpha: 0.5)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: BrainColors.outline),
              const SizedBox(width: BrainSpacing.cardGap),
              Expanded(
                child: Text(widget.label, style: BrainTypography.bodyMd),
              ),
              if (widget.value.isNotEmpty)
                Text(
                  widget.value,
                  style: BrainTypography.bodySm.copyWith(
                    color: widget.valueColor ?? BrainColors.onSurfaceVariant,
                  ),
                ),
              if (widget.onTap != null) ...[
                const SizedBox(width: BrainSpacing.xs),
                Icon(Icons.chevron_right_rounded, size: 16, color: BrainColors.outline),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Notification toggle tile ──────────────────────────────────────────────────

class _NotificationToggleTile extends StatelessWidget {
  final bool enabled;
  final String permission; // 'granted' | 'denied' | 'default'
  final ValueChanged<bool> onToggle;
  final VoidCallback onRequestPermission;

  const _NotificationToggleTile({
    required this.enabled,
    required this.permission,
    required this.onToggle,
    required this.onRequestPermission,
  });

  String get _permissionLabel => switch (permission) {
        'granted' => 'Erlaubt',
        'denied' => 'Blockiert',
        _ => 'Ausstehend',
      };

  Color _permissionColor(BuildContext context) => switch (permission) {
        'granted' => BrainColors.secondary,
        'denied' => BrainColors.error,
        _ => BrainColors.outline,
      };

  @override
  Widget build(BuildContext context) {
    final ns = NotificationService.instance;
    final supported = ns.isSupported;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BrainSpacing.md,
        vertical: BrainSpacing.cardGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_outlined,
                  size: 18, color: BrainColors.outline),
              const SizedBox(width: BrainSpacing.cardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Erinnerungen', style: BrainTypography.bodyMd),
                    Text(
                      supported
                          ? 'Browser: $_permissionLabel'
                          : 'Nicht unterstützt',
                      style: BrainTypography.labelSm.copyWith(
                        color: supported
                            ? _permissionColor(context)
                            : BrainColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (supported) ...[
                if (permission == 'default')
                  GestureDetector(
                    onTap: onRequestPermission,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BrainColors.primary.withValues(alpha: 0.15),
                        borderRadius: BrainSpacing.radiusFull,
                      ),
                      child: Text('Erlauben',
                          style: BrainTypography.labelSm
                              .copyWith(color: BrainColors.primary)),
                    ),
                  )
                else
                  Switch(
                    value: enabled && permission == 'granted',
                    onChanged: permission == 'denied' ? null : onToggle,
                    activeThumbColor: BrainColors.secondary,
                  ),
              ],
            ],
          ),
          if (permission == 'denied' && supported)
            Padding(
              padding: const EdgeInsets.only(top: BrainSpacing.xs, left: 34),
              child: Text(
                'Benachrichtigungen sind im Browser blockiert. Bitte in den Website-Einstellungen freigeben.',
                style: BrainTypography.labelSm
                    .copyWith(color: BrainColors.outline),
              ),
            ),
        ],
      ),
    );
  }
}

class _InputDialog extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final Future<void> Function(String) onSave;

  const _InputDialog({
    required this.title,
    required this.hint,
    required this.controller,
    required this.onSave,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrainColors.surfaceLow,
      title: Text(title, style: BrainTypography.titleMd),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: obscureText,
        style: BrainTypography.bodyMd,
        cursorColor: BrainColors.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: BrainTypography.bodyMd
              .copyWith(color: BrainColors.outline),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Abbrechen',
              style: BrainTypography.button.copyWith(color: BrainColors.outline)),
        ),
        TextButton(
          onPressed: () async {
            final val = controller.text.trim();
            if (val.isNotEmpty) {
              Navigator.pop(context);
              await onSave(val);
            }
          },
          child: Text('Speichern',
              style: BrainTypography.button.copyWith(color: BrainColors.primary)),
        ),
      ],
    );
  }
}

class _BackgroundImageTile extends StatelessWidget {
  const _BackgroundImageTile();

  @override
  Widget build(BuildContext context) {
    final bg = context.watch<BackgroundProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: BrainSpacing.md, vertical: BrainSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_outlined,
                  size: 18, color: BrainColors.outline),
              const SizedBox(width: BrainSpacing.sm),
              Text('Hintergrundbild',
                  style: BrainTypography.bodyMd
                      .copyWith(color: BrainColors.onSurface)),
              const Spacer(),
              Text(
                bg.hasImage ? 'Aktiv' : 'Aus',
                style: BrainTypography.labelSm.copyWith(
                  color: bg.hasImage
                      ? BrainColors.secondary
                      : BrainColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: BrainSpacing.sm),
          // Preview
          ClipRRect(
            borderRadius: BrainSpacing.radiusMd,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: bg.hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(bg.bytes!, fit: BoxFit.cover),
                        Container(
                            color: Colors.black.withValues(alpha: 0.60)),
                      ],
                    )
                  : Container(
                      color: BrainColors.surfaceLow,
                      alignment: Alignment.center,
                      child: Icon(Icons.image_outlined,
                          size: 32, color: BrainColors.outline),
                    ),
            ),
          ),
          const SizedBox(height: BrainSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: bg.picking ? null : () => bg.pick(),
                icon: bg.picking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_outlined, size: 16),
                label: Text(bg.hasImage ? 'Ersetzen' : 'Bild auswählen'),
                style: TextButton.styleFrom(
                    foregroundColor: BrainColors.primary),
              ),
              if (bg.hasImage)
                TextButton.icon(
                  onPressed: () => bg.clear(),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Entfernen'),
                  style: TextButton.styleFrom(
                      foregroundColor: BrainColors.error),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Type-to-confirm dialog for cache clear. Disables the destructive button
/// until the user types "LÖSCHEN" exactly.
class _ClearCacheDialog extends StatefulWidget {
  final Future<void> Function() onConfirmed;
  const _ClearCacheDialog({required this.onConfirmed});

  @override
  State<_ClearCacheDialog> createState() => _ClearCacheDialogState();
}

class _ClearCacheDialogState extends State<_ClearCacheDialog> {
  static const _expected = 'LÖSCHEN';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _ctrl.text.trim() == _expected;

    return AlertDialog(
      backgroundColor: BrainColors.surfaceLow,
      title: Text('Cache leeren?', style: BrainTypography.titleMd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Es gibt noch kein automatisches Backup. Wenn du jetzt löschst, '
            'sind die Notes nur noch im Server-Vault wiederherstellbar — '
            'falls der Server gerade läuft.',
            style: BrainTypography.bodyMd,
          ),
          const SizedBox(height: BrainSpacing.md),
          Text(
            'Tippe „$_expected" zur Bestätigung:',
            style: BrainTypography.labelSm,
          ),
          const SizedBox(height: BrainSpacing.xs),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: BrainColors.surfaceHigh,
              hintText: _expected,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BrainSpacing.radiusSm,
                borderSide: BorderSide.none,
              ),
            ),
            style: BrainTypography.bodyMd,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Abbrechen',
              style: BrainTypography.button
                  .copyWith(color: BrainColors.outline)),
        ),
        TextButton(
          onPressed: canConfirm
              ? () async {
                  Navigator.pop(context);
                  await widget.onConfirmed();
                }
              : null,
          child: Text(
            'Endgültig löschen',
            style: BrainTypography.button.copyWith(
              color: canConfirm
                  ? BrainColors.error
                  : BrainColors.outline.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}

/// BottomSheet that lists all unsynced captures and lets the user adopt
/// or discard each one. "Adopt" promotes the raw text to an inbox note;
/// "discard" removes the queue entry.
class _OfflineQueueSheet extends StatefulWidget {
  final Future<void> Function(OfflineCapture) onAdopt;
  final Future<void> Function(OfflineCapture) onDiscard;

  const _OfflineQueueSheet({required this.onAdopt, required this.onDiscard});

  @override
  State<_OfflineQueueSheet> createState() => _OfflineQueueSheetState();
}

class _OfflineQueueSheetState extends State<_OfflineQueueSheet> {
  late List<OfflineCapture> _captures;

  @override
  void initState() {
    super.initState();
    _captures = CacheService.instance.getPendingCaptures();
  }

  void _refresh() {
    setState(() {
      _captures = CacheService.instance.getPendingCaptures();
    });
  }

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${l.day}.${l.month}.${l.year} ${pad(l.hour)}:${pad(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            BrainSpacing.md, BrainSpacing.sm, BrainSpacing.md, BrainSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: BrainColors.outlineVariant.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: BrainSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Offline-Captures (${_captures.length})',
                    style: BrainTypography.headlineSm),
                if (_captures.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      // Adopt all in one go.
                      for (final c in List.of(_captures)) {
                        await widget.onAdopt(c);
                      }
                      _refresh();
                    },
                    child: Text('Alle übernehmen',
                        style: BrainTypography.button
                            .copyWith(color: BrainColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: BrainSpacing.sm),
            if (_captures.isEmpty)
              Padding(
                padding: const EdgeInsets.all(BrainSpacing.lg),
                child: Center(
                  child: Text(
                    'Keine ungesyncten Captures',
                    style: BrainTypography.bodyMd
                        .copyWith(color: BrainColors.onSurfaceVariant),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _captures.length,
                  separatorBuilder: (_, _x) =>
                      const SizedBox(height: BrainSpacing.sm),
                  itemBuilder: (_, i) {
                    final c = _captures[i];
                    return Container(
                      padding: BrainSpacing.paddingCard,
                      decoration: BoxDecoration(
                        color: BrainColors.surfaceHigh,
                        borderRadius: BrainSpacing.radiusMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatTime(c.createdAt),
                              style: BrainTypography.labelSm.copyWith(
                                  color: BrainColors.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(c.text,
                              style: BrainTypography.bodyMd,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: BrainSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await widget.onDiscard(c);
                                  _refresh();
                                },
                                child: Text('Verwerfen',
                                    style: BrainTypography.button.copyWith(
                                        color: BrainColors.error)),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await widget.onAdopt(c);
                                  _refresh();
                                },
                                child: Text('Als Note übernehmen',
                                    style: BrainTypography.button.copyWith(
                                        color: BrainColors.primary)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

