import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/notification_service.dart';
import 'settings_section.dart';
import 'settings_tile.dart';

class ReminderDeliverySettings extends StatefulWidget {
  const ReminderDeliverySettings({super.key});

  @override
  State<ReminderDeliverySettings> createState() => _ReminderDeliverySettingsState();
}

class _ReminderDeliverySettingsState extends State<ReminderDeliverySettings> {
  final _notifications = NotificationService.instance;
  final _api = ApiService.instance;
  Map<String, dynamic>? _settings;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (context.read<AuthProvider>().isLoggedIn) _load();
  }

  Future<void> _load() async {
    final settings = await _api.getReminderSettings();
    if (mounted) setState(() => _settings = settings);
  }

  Future<void> _update(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted && message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pushEnabled = _notifications.notificationsEnabled;
    final emailAvailable = _settings?['email_available'] == true;
    final emailEnabled = _settings?['email_enabled'] == true;

    return SettingsSection(
      title: 'ERINNERUNGEN',
      items: [
        const SettingsTile(
          icon: Icons.schedule_rounded,
          label: 'In der App',
          value: 'Im Dashboard',
        ),
        SettingsTile(
          icon: Icons.notifications_outlined,
          label: 'Push auf diesem Gerät',
          value: !auth.isLoggedIn
              ? 'Vault verbinden'
              : !_notifications.isSupported
              ? 'Hier nicht verfügbar'
              : pushEnabled ? 'An' : 'Aus',
          onTap: !auth.isLoggedIn || !_notifications.isSupported || _busy
              ? null
              : () => _update(() async {
                  if (pushEnabled) {
                    await _notifications.disablePush();
                    return null;
                  }
                  return (await _notifications.enablePush()).error;
                }),
        ),
        if (auth.isLoggedIn && pushEnabled)
          SettingsTile(
            icon: Icons.notifications_active_outlined,
            label: 'Test-Push senden',
            value: '',
            onTap: _busy ? null : () => _update(() async {
              final sent = await _notifications.sendTest();
              return sent > 0 ? 'Test-Push gesendet.' : 'Push konnte nicht gesendet werden.';
            }),
          ),
        SettingsTile(
          icon: Icons.mail_outline_rounded,
          label: 'E-Mail',
          value: !auth.isLoggedIn
              ? 'Vault verbinden'
              : _settings == null
              ? 'Status abrufen'
              : emailAvailable
              ? (emailEnabled ? 'An' : 'Aus')
              : 'Serverseitig nicht eingerichtet',
          onTap: !auth.isLoggedIn || _busy || (_settings != null && !emailAvailable)
              ? null
              : () => _update(() async {
                  if (_settings == null) {
                    await _load();
                    return _settings == null ? 'Server momentan nicht erreichbar.' : null;
                  }
                  final saved = await _api.setReminderEmail(!emailEnabled);
                  await _load();
                  return saved ? null : 'Einstellung konnte nicht gespeichert werden.';
                }),
        ),
        if (auth.isLoggedIn && emailEnabled && emailAvailable)
          SettingsTile(
            icon: Icons.send_outlined,
            label: 'Test-E-Mail senden',
            value: '',
            onTap: _busy ? null : () => _update(() async {
              return await _api.testReminderEmail()
                  ? 'Test-E-Mail an deine Konto-Adresse gesendet.'
                  : 'E-Mail konnte nicht gesendet werden.';
            }),
          ),
      ],
    );
  }
}
