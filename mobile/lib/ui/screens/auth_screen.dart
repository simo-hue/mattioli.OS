import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/haptics.dart';
import '../../core/localization.dart';

enum AuthMode { login, signup }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  AuthMode _mode = AuthMode.login;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == AuthMode.login ? AuthMode.signup : AuthMode.login;
    });
    ref.hapticLight();
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      bool success;
      final hapticsEnabled = ref.read(settingsProvider).hapticFeedback;
      if (_mode == AuthMode.login) {
        success = await ref.read(authProvider.notifier).login(
              _emailController.text,
              _passwordController.text,
            );
      } else {
        success = await ref.read(authProvider.notifier).signUp(
              _emailController.text,
              _passwordController.text,
            );
        // signup potrebbe richiedere conferma email
        if (success && mounted) {
          final error = ref.read(authProvider).error;
          if (error != null && error.contains('email')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.translate(error)),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      }

      if (success) {
        AppHaptics.mediumImpactWithFlag(hapticsEnabled);
      }
    } else {
      ref.hapticHeavy();
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.translate('Inserisci la tua email per reimpostare la password.')),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    ref.hapticLight();
    final success = await ref.read(authProvider.notifier).resetPassword(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? context.l10n.passwordResetEmailSent
                : context.l10n.translate(
                    ref.read(authProvider).error ?? 'Errore. Riprova.',
                  ),
          ),
          backgroundColor: success ? const Color(0xFF10B981) : AppColors.destructive,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _openUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.translate('Impossibile aprire il link.')),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 780;

    final logoSize = isCompact ? 60.0 : 100.0;
    final titleSize = isCompact ? 22.0 : 28.0;
    final mottoSize = isCompact ? 12.0 : 14.0;

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: isCompact ? 8 : 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: isCompact ? 4 : 20),
                        // Logo/Header
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/logo Background Removed.png',
                                height: logoSize,
                                width: logoSize,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(height: isCompact ? 6 : 16),
                            Text(
                              'EVOLVE',
                              style: GoogleFonts.inter(
                                color: context.appColors.foreground,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                              ),
                            ),
                            SizedBox(height: isCompact ? 4 : 8),
                            if (_mode == AuthMode.login)
                              Text(
                                context.l10n.authLoginMotto,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  color: context.appColors.mutedForeground.withValues(alpha: 0.9),
                                  fontSize: isCompact ? 15 : 17,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                  height: 1.35,
                                ),
                              )
                            else
                              Text(
                                context.l10n.translate('Crea il tuo ecosistema personale.'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: context.appColors.mutedForeground,
                                  fontSize: mottoSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 12 : 32),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _emailController,
                                label: context.l10n.translate('Email'),
                                icon: LucideIcons.mail,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return context.l10n.translate('Inserisci la tua email.');
                                  }
                                  if (!value.contains('@') || !value.contains('.')) {
                                    return context.l10n.translate('Email non valida.');
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: isCompact ? 6 : 12),
                              _buildTextField(
                                controller: _passwordController,
                                label: context.l10n.translate('Password'),
                                icon: LucideIcons.lock,
                                isPassword: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return context.l10n.translate('Inserisci la password.');
                                  }
                                  if (value.length < 6) {
                                    return context.l10n.translate('Minimo 6 caratteri.');
                                  }
                                  return null;
                                },
                              ),
                              if (_mode == AuthMode.login)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _handleForgotPassword,
                                    child: Text(
                                      context.l10n.translate('Password dimenticata?'),
                                      style: TextStyle(
                                        color: context.appColors.mutedForeground,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              // Error banner da Supabase
                              Builder(builder: (context) {
                                final error = ref.watch(authProvider).error;
                                if (error == null || error.contains('email')) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.destructive.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.destructive.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(LucideIcons.circleAlert, size: 16, color: AppColors.destructive),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            context.l10n.translate(error),
                                            style: const TextStyle(
                                              color: AppColors.destructive,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              SizedBox(height: isCompact ? 10 : 24),
                              _buildSubmitButton(authState.isLoading),
                            ],
                          ),
                        ),

                        SizedBox(height: isCompact ? 10 : 24),

                        // OR Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: context.appColors.border, thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                context.l10n.translate('OPPURE'),
                                style: GoogleFonts.inter(
                                  color: context.appColors.mutedForeground.withValues(alpha: 0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: context.appColors.border, thickness: 1)),
                          ],
                        ),

                        SizedBox(height: isCompact ? 10 : 24),

                        // Social Logins
                        _buildSocialButton(
                          label: context.l10n.translate('Continua con Apple'),
                          icon: LucideIcons.apple,
                          onPressed: () async {
                            final hapticsEnabled = ref.read(settingsProvider).hapticFeedback;
                            final success = await ref.read(authProvider.notifier).signInWithApple();
                            if (success) {
                              AppHaptics.mediumImpactWithFlag(hapticsEnabled);
                            }
                          },
                        ),
                        SizedBox(height: isCompact ? 6 : 10),
                        _buildSocialButton(
                          label: context.l10n.translate('Continua con Google'),
                          icon: LucideIcons.mail, 
                          isGoogle: true,
                          onPressed: () async {
                            final hapticsEnabled = ref.read(settingsProvider).hapticFeedback;
                            final success = await ref.read(authProvider.notifier).signInWithGoogle();
                            if (success) {
                              AppHaptics.mediumImpactWithFlag(hapticsEnabled);
                            }
                          },
                        ),

                        SizedBox(height: isCompact ? 10 : 24),

                        // Toggle Mode
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _mode == AuthMode.login
                                  ? context.l10n.translate('Non hai un account?')
                                  : context.l10n.translate('Hai già un account?'),
                              style: TextStyle(color: context.appColors.mutedForeground, fontSize: isCompact ? 12 : 14),
                            ),
                            TextButton(
                              onPressed: _toggleMode,
                              child: Text(
                                _mode == AuthMode.login
                                    ? context.l10n.translate('Registrati')
                                    : context.l10n.translate('Accedi'),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: isCompact ? 12 : 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 2 : 8),
                        // Legal Links
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => _openUrl('https://simo-hue.github.io/evolve/privacy.html'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                context.l10n.readPrivacyPolicy,
                                style: TextStyle(
                                  color: context.appColors.mutedForeground,
                                  fontSize: isCompact ? 10 : 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            Text(
                              '•',
                              style: TextStyle(
                                color: context.appColors.mutedForeground,
                                fontSize: isCompact ? 10 : 12,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openUrl('https://simo-hue.github.io/evolve/privacy.html'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                context.l10n.translate('Termini di Servizio'),
                                style: TextStyle(
                                  color: context.appColors.mutedForeground,
                                  fontSize: isCompact ? 10 : 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          if (authState.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: CircularProgressIndicator(color: context.appColors.foreground),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border.withValues(alpha: 0.5)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: context.appColors.foreground, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.appColors.mutedForeground, fontSize: 14),
          prefixIcon: Icon(icon, size: 18, color: context.appColors.mutedForeground),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Reduced from 12
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isCompact = MediaQuery.sizeOf(context).height < 780;
    
    return GestureDetector(
      onTap: isLoading ? null : _handleSubmit,
      child: Container(
        width: double.infinity,
        height: isCompact ? 46 : 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor,
              primaryColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _mode == AuthMode.login
                      ? context.l10n.translate('Accedi')
                      : context.l10n.translate('Crea Account'),
                  style: TextStyle(
                    color: primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isGoogle = false,
  }) {
    final isCompact = MediaQuery.sizeOf(context).height < 780;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        height: isCompact ? 46 : 52,
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: context.appColors.foreground),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                color: context.appColors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
