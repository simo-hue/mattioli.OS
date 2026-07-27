import 'package:evolve_legal/evolve_legal.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
    final colors = context.evolveColors;
    final accent = context.evolveAccent;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero mark: real logo.
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 76,
                      height: 76,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    switch (_mode) {
                      _AuthMode.signIn => t.auth.signInTitle,
                      _AuthMode.signUp => t.auth.signUpTitle,
                      _AuthMode.resetPassword => t.auth.resetTitle,
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  EvolveSegmentedControl<_AuthMode>(
                    height: 44,
                    segments: {
                      _AuthMode.signIn: t.auth.signIn,
                      _AuthMode.signUp: t.auth.register,
                    },
                    selected: _mode,
                    onSelected: (mode) => setState(() => _mode = mode),
                  ),
                  const SizedBox(height: 22),
                  if (_mode == _AuthMode.signUp) ...[
                    EvolveFieldLabel(t.auth.nameLabel),
                    const SizedBox(height: 8),
                    TextFormField(controller: _nameController),
                    const SizedBox(height: 14),
                  ],
                  EvolveFieldLabel(t.auth.emailLabel),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value?.contains('@') ?? false
                        ? null
                        : t.auth.invalidEmail,
                  ),
                  if (_mode != _AuthMode.resetPassword) ...[
                    const SizedBox(height: 14),
                    EvolveFieldLabel(t.auth.password),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      validator: (value) => (value?.length ?? 0) >= 8
                          ? null
                          : t.auth.passwordMin8,
                    ),
                  ],
                  if (_mode == _AuthMode.signIn) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _mode = _AuthMode.resetPassword),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          t.auth.forgotPassword,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: EvolveColors.destructive.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: EvolveColors.destructive.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.circleAlert,
                            size: 16,
                            color: EvolveColors.destructive,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.errorMessage!,
                              style: const TextStyle(
                                color: EvolveColors.destructive,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: auth.isLoading
                          ? null
                          : [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                    ),
                    child: FilledButton(
                      onPressed: auth.isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: auth.isLoading
                          ? SizedBox.square(
                              dimension: 18,
                              child: EvolveSpinner(
                                radius: 9,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : Text(
                              _mode == _AuthMode.resetPassword
                                  ? t.auth.sendResetLink
                                  : _mode == _AuthMode.signUp
                                  ? t.auth.register
                                  : t.auth.signIn,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                    ),
                  ),
                  if (_mode != _AuthMode.resetPassword) ...[
                    const SizedBox(height: 18),
                    _AuthDivider(label: t.auth.or),
                    const SizedBox(height: 18),
                    // Apple's own button widget, not _SocialAuthButton:
                    // Guideline 4 requires the real Apple mark, and we
                    // previously drew LucideIcons.apple -- a generic outlined
                    // fruit that is not Apple's logo. The widget also owns the
                    // label sizing, icon proportions and padding the HIG
                    // prescribes. Height and radius are matched to
                    // _SocialAuthButton so the stack stays coherent; Opacity
                    // mirrors its disabled treatment, which the widget lacks.
                    Opacity(
                      opacity: auth.isLoading ? 0.55 : 1,
                      child: SignInWithAppleButton(
                        text: t.auth.continueWithApple,
                        height: 48,
                        borderRadius: BorderRadius.circular(14),
                        // The style enum is black/white only and is NOT
                        // theme-reactive, so pick it from our theme: the HIG
                        // wants a white button on dark backgrounds, black on
                        // light.
                        style: Theme.of(context).brightness == Brightness.dark
                            ? SignInWithAppleButtonStyle.white
                            : SignInWithAppleButtonStyle.black,
                        onPressed: auth.isLoading ? null : _signInWithApple,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SocialAuthButton(
                      imageAsset: 'assets/images/google_logo.png',
                      label: t.auth.continueWithGoogle,
                      onPressed: auth.isLoading ? null : _signInWithGoogle,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _mode == _AuthMode.signUp
                            ? t.auth.haveAccount
                            : t.auth.noAccount,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _mode = _mode == _AuthMode.signUp
                              ? _AuthMode.signIn
                              : _AuthMode.signUp;
                        }),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _mode == _AuthMode.signUp
                              ? t.auth.signIn
                              : t.auth.register,
                          style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: TextButton(
                      onPressed: _openPrivacyPolicy,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        t.auth.readPrivacyPolicy,
                        style: TextStyle(
                          color: colors.subtle,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: colors.subtle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AuthDivider(label: t.auth.or),
                  const SizedBox(height: 14),
                  _SocialAuthButton(
                    label: t.auth.continuePrivately,
                    onPressed: auth.isLoading ? null : _enterPrivateMode,
                  ),
                ],
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
      // Follows the app's language: the site serves each locale from its own
      // directory, and a reviewer on an English device must not land in Italian.
      LegalUrls.privacy(LocaleSettings.currentLocale.languageCode),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _enterPrivateMode() async {
    await ref.read(desktopAuthControllerProvider.notifier).enterPrivateMode();
  }

  void _showMessage(String message) {
    showEvolveToast(context, message: message);
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
    this.imageAsset,
    required this.label,
    required this.onPressed,
  });

  final String? imageAsset;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: Material(
        color: colors.panel.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (imageAsset != null) ...[
                  Image.asset(imageAsset!, width: 24, height: 24),
                  const SizedBox(width: 12),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
