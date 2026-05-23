import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/brain_colors.dart';
import '../theme/brain_spacing.dart';
import '../theme/brain_typography.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() => _submitting = true);
    final ok = await context.read<AuthProvider>().login(email, password);
    if (!mounted) return;
    setState(() => _submitting = false);
    // On success the AuthGate re-renders into AppShell automatically.
    if (!ok) {
      // Clear password field on failure to nudge a fresh attempt.
      _passwordCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: BrainColors.base,
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
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: BrainColors.captureGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: BrainColors.captureGlow,
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.psychology_alt_rounded,
                          size: 28, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: BrainSpacing.lg),
                  Text('Second Brain',
                      textAlign: TextAlign.center,
                      style: BrainTypography.headlineMd),
                  const SizedBox(height: BrainSpacing.xs),
                  Text(
                    'Melde dich an, um auf deine Gedanken zuzugreifen.',
                    textAlign: TextAlign.center,
                    style: BrainTypography.bodySm.copyWith(
                      color: BrainColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: BrainSpacing.xl),
                  // Glass form
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
                              controller: _emailCtrl,
                              autofillHints: const [AutofillHints.username],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: BrainTypography.bodyMd,
                              decoration: const InputDecoration(
                                labelText: 'E-Mail',
                                prefixIcon: Icon(Icons.alternate_email_rounded,
                                    size: 18),
                              ),
                            ),
                            const SizedBox(height: BrainSpacing.md),
                            TextField(
                              controller: _passwordCtrl,
                              autofillHints: const [AutofillHints.password],
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              style: BrainTypography.bodyMd,
                              decoration: InputDecoration(
                                labelText: 'Passwort',
                                prefixIcon: const Icon(Icons.lock_outline_rounded,
                                    size: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            if (auth.loginError != null) ...[
                              const SizedBox(height: BrainSpacing.sm),
                              Text(
                                auth.loginError!,
                                style: BrainTypography.labelSm
                                    .copyWith(color: BrainColors.error),
                              ),
                            ],
                            const SizedBox(height: BrainSpacing.lg),
                            FilledButton(
                              onPressed: _submitting ? null : _submit,
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
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text('Anmelden',
                                      style: BrainTypography.button
                                          .copyWith(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: BrainSpacing.lg),
                  Text(
                    'Konten werden nur durch den Administrator angelegt.',
                    textAlign: TextAlign.center,
                    style: BrainTypography.labelSm
                        .copyWith(color: BrainColors.outline),
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
