import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/capture_provider.dart';
import '../providers/vault_provider.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';
import '../services/vault_export_service.dart';
import '../services/vault_import_service.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';
import 'settings/dialogs/clear_cache_dialog.dart';
import 'settings/sheets/offline_queue_sheet.dart';
import 'settings/sheets/pending_writes_sheet.dart';
import 'settings/widgets/background_image_tile.dart';
import 'settings/widgets/glass_settings_tile.dart';
import 'settings/widgets/input_dialog.dart';
import 'settings/widgets/notification_toggle_tile.dart';
import 'settings/widgets/settings_section.dart';
import 'settings/widgets/settings_tile.dart';

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
              SettingsSection(
                title: 'VERBINDUNG',
                items: [
                  SettingsTile(
                    icon: Icons.cloud_outlined,
                    label: 'API-Server',
                    value: _checking
                        ? 'Prüfe...'
                        : _serverReachable
                            ? 'Verbunden'
                            : 'Nicht erreichbar',
                    valueColor: _serverReachable
                        ? BrainColors.secondary
                        : BrainColors.tertiary,
                    // URL ist hardcoded — kein Edit-Dialog. Tap nur Re-Check.
                    onTap: _checkServer,
                  ),
                  SettingsTile(
                    icon: Icons.vpn_key_outlined,
                    label: 'API-Schlüssel',
                    value: api.isConfigured ? '••••••••' : 'Nicht gesetzt',
                    onTap: () => _showApiTokenDialog(context),
                  ),
                  SettingsTile(
                    icon: Icons.sync_outlined,
                    label: 'Letzter Sync',
                    value: vault.status.lastSyncText,
                    onTap: () async {
                      await vault.refresh();
                      await _checkServer();
                    },
                  ),
                  SettingsTile(
                    icon: Icons.wifi_tethering_rounded,
                    label: 'Verbindung testen',
                    value: '',
                    onTap: () => _runConnectionTest(context),
                  ),
                  SettingsTile(
                    icon: Icons.cloud_upload_outlined,
                    label: 'Pending Writes',
                    value:
                        '${CacheService.instance.getPendingWrites().length}',
                    onTap: () => _showPendingWritesSheet(context),
                  ),
                ],
              ),

              const SizedBox(height: BrainSpacing.lg),

              // ── Notifications ───────────────────────────────────────
              SettingsSection(
                title: 'BENACHRICHTIGUNGEN',
                items: [
                  NotificationToggleTile(
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
              SettingsSection(
                title: 'DARSTELLUNG',
                items: const [
                  BackgroundImageTile(),
                  GlassSettingsTile(),
                ],
              ),

              const SizedBox(height: BrainSpacing.lg),

              // ── Vault ───────────────────────────────────────────────
              SettingsSection(
                title: 'SPEICHER',
                items: [
                  SettingsTile(
                    icon: Icons.description_outlined,
                    label: 'Gesamt Gedanken',
                    value: '${vault.status.totalNotes}',
                  ),
                  SettingsTile(
                    icon: Icons.inbox_outlined,
                    label: 'Inbox',
                    value: '${vault.status.inboxCount}',
                  ),
                  SettingsTile(
                    icon: Icons.upload_file_outlined,
                    label: 'Aus Vault importieren',
                    value: '',
                    onTap: () => _importFromVault(context),
                  ),
                  SettingsTile(
                    icon: Icons.folder_zip_outlined,
                    label: 'Backup als ZIP',
                    value: _backupAgeText(),
                    valueColor: _backupAgeColor(),
                    onTap: () => _exportZip(context),
                  ),
                  SettingsTile(
                    icon: Icons.unarchive_outlined,
                    label: 'Aus ZIP importieren',
                    value: '',
                    onTap: () => _importZip(context),
                  ),
                  SettingsTile(
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
                            'Ich bin Architekt und baue mir ein zweites Gehirn. Ich denke in Systemen und mag Klarheit...',
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
              SettingsSection(
                title: 'ÜBER',
                items: [
                  SettingsTile(
                    icon: Icons.info_outlined,
                    label: 'Version',
                    value: 'v0.1.0',
                  ),
                  SettingsTile(
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

  void _showApiTokenDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => InputDialog(
        title: 'API-Schlüssel',
        hint: 'Deinen JWT-Schlüssel einfügen',
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

  Future<void> _runConnectionTest(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: BrainColors.primary),
        ),
      ),
    );
    final result = await ApiService.instance.pingWithLatency();
    if (!mounted) return;
    Navigator.of(context).pop(); // close spinner
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BrainColors.surfaceLow,
        title: Text(result.ok ? 'Server erreichbar' : 'Server nicht erreichbar',
            style: BrainTypography.titleMd),
        content: Text(
          result.ok
              ? 'Antwort in ${result.latencyMs} ms.'
              : 'Fehler: ${result.error ?? "unbekannt"}'
                  '${result.latencyMs != null ? "\n(Latenz vor Fehler: ${result.latencyMs} ms)" : ""}',
          style: BrainTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: BrainTypography.button.copyWith(
                    color: result.ok
                        ? BrainColors.secondary
                        : BrainColors.tertiary)),
          ),
        ],
      ),
    );
  }

  void _showPendingWritesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BrainColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) => PendingWritesSheet(
        onReplayAll: () async {
          final r = await context.read<VaultProvider>().replayPendingWrites();
          if (sheetCtx.mounted) {
            ScaffoldMessenger.of(sheetCtx).showSnackBar(
              SnackBar(
                content: Text(r.serverReachable
                    ? '${r.drained} synchronisiert, ${r.remaining} offen'
                    : 'Server nicht erreichbar'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        onDiscard: (filePath) async {
          await context.read<VaultProvider>().discardPendingWrite(filePath);
        },
        onDiscardAll: () async {
          final all = CacheService.instance.getPendingWrites();
          for (final w in all) {
            final fp = w['file_path'] as String?;
            if (fp != null) {
              await context.read<VaultProvider>().discardPendingWrite(fp);
            }
          }
        },
      ),
    );
  }

  String _backupAgeText() {
    final days = VaultExportService.instance.daysSinceLastBackup;
    if (days == null) return 'Nie';
    if (days == 0) return 'Heute';
    if (days == 1) return 'Gestern';
    return 'vor $days Tagen';
  }

  Color? _backupAgeColor() {
    final days = VaultExportService.instance.daysSinceLastBackup;
    if (days == null) return BrainColors.tertiary;
    if (days > 14) return BrainColors.tertiary;
    if (days <= 1) return BrainColors.secondary;
    return null;
  }

  Future<void> _exportZip(BuildContext context) async {
    try {
      final fileName = await VaultExportService.instance.exportZip();
      if (!mounted) return;
      setState(() {}); // refresh backup age tile
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup gespeichert: $fileName'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export fehlgeschlagen: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _importZip(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    try {
      final report = await VaultExportService.instance.importZip(bytes);
      if (!mounted) return;
      context.read<VaultProvider>().reloadFromCache();
      final msg = report.failed.isEmpty
          ? '${report.written} Gedanken importiert'
          : '${report.written} importiert, ${report.failed.length} übersprungen';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import fehlgeschlagen: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
      builder: (sheetCtx) => OfflineQueueSheet(
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
      builder: (_) => ClearCacheDialog(
        onConfirmed: () async {
          // Phase 2 safety net: always drop a fresh ZIP backup right
          // before wiping local notes — even if the user typed LÖSCHEN
          // they get a downloaded recovery file on the way out.
          String? backupName;
          try {
            backupName = await VaultExportService.instance.exportZip();
          } catch (_) {
            // Backup failed — proceed anyway, user confirmed twice.
          }
          try {
            await CacheService.instance.dangerouslyClearAllNotes();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(backupName != null
                    ? 'Cache geleert. Backup: $backupName'
                    : 'Cache geleert (Backup fehlgeschlagen)'),
                duration: const Duration(seconds: 4),
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
