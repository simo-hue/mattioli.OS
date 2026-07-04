import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum _AuthMode { signIn, signUp, resetPassword }

class DesktopAuthPage extends ConsumerStatefulWidget {
  const DesktopAuthPage({super.key});

  @override
  ConsumerState<DesktopAuthPage> createState() => _DesktopAuthPageState();
}

class _DesktopAuthPageState extends ConsumerState<DesktopAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(desktopAuthControllerProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: EvolvePanel(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 38,
                      color: context.evolveAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      switch (_mode) {
                        _AuthMode.signIn => t.auth.signInTitle,
                        _AuthMode.signUp => t.auth.signUpTitle,
                        _AuthMode.resetPassword => t.auth.resetTitle,
                      },
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    if (_mode == _AuthMode.signUp) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: t.auth.nameLabel,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: t.auth.emailLabel),
                      validator: (value) => value?.contains('@') ?? false
                          ? null
                          : t.auth.invalidEmail,
                    ),
                    if (_mode != _AuthMode.resetPassword) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(labelText: t.auth.password),
                        validator: (value) => (value?.length ?? 0) >= 8
                            ? null
                            : t.auth.passwordMin8,
                      ),
                    ],
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        auth.errorMessage!,
                        style: const TextStyle(color: EvolveColors.rose),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _mode == _AuthMode.resetPassword
                                  ? t.auth.sendResetLink
                                  : _mode == _AuthMode.signUp
                                  ? t.auth.register
                                  : t.auth.signIn,
                            ),
                    ),
                    if (_mode != _AuthMode.resetPassword) ...[
                      const SizedBox(height: 18),
                      _AuthDivider(label: t.auth.or),
                      const SizedBox(height: 18),
                      _SocialAuthButton(
                        icon: Icons.apple,
                        label: t.auth.continueWithApple,
                        onPressed: auth.isLoading ? null : _signInWithApple,
                      ),
                      const SizedBox(height: 10),
                      _SocialAuthButton(
                        icon: Icons.g_mobiledata_rounded,
                        label: t.auth.continueWithGoogle,
                        onPressed: auth.isLoading ? null : _signInWithGoogle,
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (_mode == _AuthMode.signIn)
                      TextButton(
                        onPressed: () =>
                            setState(() => _mode = _AuthMode.resetPassword),
                        child: Text(t.auth.forgotPassword),
                      ),
                    TextButton(
                      onPressed: () => setState(() {
                        _mode = _mode == _AuthMode.signUp
                            ? _AuthMode.signIn
                            : _AuthMode.signUp;
                      }),
                      child: Text(
                        _mode == _AuthMode.signUp
                            ? '${t.auth.haveAccount} ${t.auth.signIn}'
                            : '${t.auth.noAccount} ${t.auth.register}',
                      ),
                    ),
                    IconButton(
                      onPressed: _openPrivacyPolicy,
                      icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                      tooltip: t.auth.readPrivacyPolicy,
                      color: context.evolveColors.subtle,
                    ),
                    const SizedBox(height: 14),
                    _AuthDivider(label: t.auth.or),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: auth.isLoading ? null : _enterPrivateMode,
                      icon: Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: context.evolveColors.subtle,
                      ),
                      label: Text(t.auth.continuePrivately),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.center,
                        foregroundColor: context.evolveColors.foreground,
                        side: BorderSide(color: context.evolveColors.border),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = ref.read(desktopAuthControllerProvider.notifier);
    try {
      switch (_mode) {
        case _AuthMode.signIn:
          await auth.signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        case _AuthMode.signUp:
          final requiresConfirmation = await auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text,
          );
          if (!mounted || !requiresConfirmation) return;
          _showMessage(t.auth.confirmEmail);
          setState(() => _mode = _AuthMode.signIn);
        case _AuthMode.resetPassword:
          await auth.sendPasswordReset(_emailController.text.trim());
          if (!mounted) return;
          _showMessage(t.auth.resetSent);
          setState(() => _mode = _AuthMode.signIn);
      }
    } catch (_) {}
  }

  Future<void> _signInWithApple() async {
    try {
      await ref.read(desktopAuthControllerProvider.notifier).signInWithApple();
    } catch (_) {}
  }

  Future<void> _signInWithGoogle() async {
    try {
      await ref.read(desktopAuthControllerProvider.notifier).signInWithGoogle();
    } catch (_) {}
  }

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(
      Uri.parse('https://simo-hue.github.io/evolve/privacy.html'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _enterPrivateMode() async {
    await ref.read(desktopAuthControllerProvider.notifier).enterPrivateMode();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: context.evolveColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.evolveColors.subtle,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.evolveColors.border)),
      ],
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.center,
        foregroundColor: context.evolveColors.foreground,
        side: BorderSide(color: context.evolveColors.borderStrong),
        minimumSize: const Size.fromHeight(44),
      ),
    );
  }
}
