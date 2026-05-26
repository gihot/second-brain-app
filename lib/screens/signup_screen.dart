import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

/// Plan 4.3: Signup mit Einladungs-Code. Erst der Server-Endpoint
/// validiert den Code — der Client hat keine Vorab-Prüfung. UX-Hinweis:
/// E-Mail-Validierung passiert in EmailStr serverseitig, hier nur
/// triviales nicht-leer.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _emailCtrl.text.trim().isNotEmpty &&
      _passwordCtrl.text.length >= 8 &&
      _inviteCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_submitting || !_valid) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ApiService.instance.signup(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      inviteCode: _inviteCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.user == null) {
      setState(() => _error = result.error ?? 'Unbekannter Fehler.');
      return;
    }
    // Auto-Login: AuthProvider muss den frisch gesetzten Token + User
    // übernehmen — wir nutzen denselben Init-Pfad wie boot-time auth.
    await CacheService.instance.init(result.user!['id'] as String);
    if (!mounted) return;
    // Provider direkt füttern wie LoginScreen via login() das tut.
    // Wir können login() nicht nutzen (Token ist schon gesetzt). Statt-
    // dessen refreshUser → AuthProvider holt /auth/me und flippt
    // intern auf loggedIn — Status-Flip braucht den public setter.
    // AuthGate watch'd auf den Status, also rufen wir hier explizit.
    final auth = context.read<AuthProvider>();
    await auth.refreshUser();
    // refreshUser füllt _user, aber Status muss noch flippen. Kurz-
    // schluss: AuthProvider.init() bei vorhandenem Token bringt uns
    // sauber in loggedIn-Mode.
    await auth.init();
    if (!mounted) return;
    Navigator.pop(context); // SignupScreen schließen, AuthGate zeigt AppShell
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrainColors.base,
      appBar: AppBar(
        backgroundColor: BrainColors.base,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Registrieren',
            style: BrainTypography.bodyMd
                .copyWith(color: BrainColors.onSurface)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(BrainSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Einladungs-Code',
                      textAlign: TextAlign.center,
                      style: BrainTypography.headlineMd),
                  const SizedBox(height: BrainSpacing.xs),
                  Text(
                    'Du brauchst einen Code von jemandem, der dich '
                    'einlädt. Codes laufen nach 14 Tagen ab.',
                    textAlign: TextAlign.center,
                    style: BrainTypography.bodySm.copyWith(
                      color: BrainColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: BrainSpacing.xl),
                  ClipRRect(
                    borderRadius: BrainSpacing.radiusMd,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(BrainSpacing.lg),
                        decoration: BoxDecoration(
                          color: BrainColors.surfaceLow.withValues(alpha: 0.7),
                          borderRadius: BrainSpacing.radiusMd,
                          border: Border.all(
                            color: BrainColors.outlineVariant
                                .withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _inviteCtrl,
                              textCapitalization:
                                  TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              style: BrainTypography.bodyMd
                                  .copyWith(letterSpacing: 1.5),
                              decoration: const InputDecoration(
                                labelText: 'Einladungs-Code',
                                prefixIcon:
                                    Icon(Icons.confirmation_number_outlined,
                                        size: 18),
                              ),
                            ),
                            const SizedBox(height: BrainSpacing.md),
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              style: BrainTypography.bodyMd,
                              decoration: const InputDecoration(
                                labelText: 'E-Mail',
                                prefixIcon:
                                    Icon(Icons.alternate_email_rounded,
                                        size: 18),
                              ),
                            ),
                            const SizedBox(height: BrainSpacing.md),
                            TextField(
                              controller: _passwordCtrl,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _submit(),
                              style: BrainTypography.bodyMd,
                              decoration: InputDecoration(
                                labelText: 'Passwort (≥ 8 Zeichen)',
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: BrainSpacing.sm),
                              Text(
                                _error!,
                                style: BrainTypography.labelSm.copyWith(
                                    color: BrainColors.error),
                              ),
                            ],
                            const SizedBox(height: BrainSpacing.lg),
                            FilledButton(
                              onPressed:
                                  (_valid && !_submitting) ? _submit : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: BrainColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    vertical: BrainSpacing.md),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Text('Account erstellen',
                                      style: BrainTypography.button
                                          .copyWith(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
