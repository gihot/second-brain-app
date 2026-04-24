import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
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
            child: Text('Settings', style: BrainTypography.displayMd),
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
                    label: 'Last Sync',
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
                    label: 'Connected',
                    value: '${vault.status.connectedCount}',
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
                title: 'ABOUT',
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

  void _confirmClearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BrainColors.surfaceLow,
        title: Text('Cache leeren?', style: BrainTypography.titleMd),
        content: Text(
          'Dies löscht alle lokal gecachten Gedanken. Gedanken in deinem Git-Vault bleiben unberührt.',
          style: BrainTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Abbrechen', style: BrainTypography.button.copyWith(color: BrainColors.outline)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: implement cache clear
            },
            child: Text('Leeren', style: BrainTypography.button.copyWith(color: BrainColors.error)),
          ),
        ],
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
