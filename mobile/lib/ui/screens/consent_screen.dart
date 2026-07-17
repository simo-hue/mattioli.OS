import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evolve_legal/evolve_legal.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_logger.dart';
import '../../core/data_mode.dart';
import '../../core/sentry_service.dart';
import '../../providers/consent_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import '../kit/evolve_toast.dart';
import '../../core/haptics.dart';
import '../../i18n/translations.g.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _acceptedTerms = false;
  final bool _sentryConsent = true;
  bool _notificationsAllowed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final status = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _notificationsAllowed = status.isGranted;
    });
  }

  Future<void> _requestNotificationPermission() async {
    ref.hapticLight();
    final status = await Permission.notification.request();
    if (!mounted) return;
    setState(() {
      _notificationsAllowed = status.isGranted;
    });
  }

  /// The site publishes each language from its own directory, so legal links
  /// follow the app's language.
  String get _lang => LocaleSettings.currentLocale.languageCode;

  Future<void> _openUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showEvolveToast(
          context,
          message: context.t.common.unableToOpenTheLink,
        );
      }
    }
  }

  Future<void> _handleContinue() async {
    if (!_acceptedTerms) {
      ref.hapticHeavy();
      showEvolveToast(
        context,
        message: context.t.consent.termsRequired,
      );
      return;
    }

    setState(() => _isLoading = true);
    ref.hapticMedium();

    // Every `ref` read has to happen before the first await. Persisting the
    // consent flips consentProvider, which rebuilds the router and unmounts this
    // screen; a `ref` read after that throws a StateError in release builds too.
    final consentNotifier = ref.read(consentProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);
    final isLoggedIn = ref.read(authProvider).isLoggedIn;
    final isPrivateMode =
        ref.read(activeDataModeProvider) == AppDataMode.private;

    // Salva il consenso nel provider
    await consentNotifier.setConsent(
      acceptedTerms: _acceptedTerms,
      sentryConsent: _sentryConsent,
      completed: true,
    );

    // Se l'utente è già loggato, salva il consenso anche nel DB
    if (isLoggedIn) {
      await authNotifier.updateConsentInDb(_acceptedTerms, _sentryConsent);
    }

    // Allinea Sentry alla risposta dell'utente.
    final sentryEnabled = _sentryConsent && !isPrivateMode;
    if (sentryEnabled) {
      AppLogger.setExternalReportingDisabled(false);
    }
    await SentryService.setEnabled(sentryEnabled);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // La navigazione verrà gestita automaticamente dal router in main.dart
    // grazie al cambio di stato in consentProvider.
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLightBg = primaryColor.computeLuminance() > 0.5;
    final activeTextColor = isLightBg ? Colors.black : Colors.white;
    final disabledTextColor =
        context.appColors.mutedForeground.computeLuminance() > 0.7
        ? Colors.grey[600]!
        : context.appColors.mutedForeground;
    final buttonTextColor = _acceptedTerms
        ? activeTextColor
        : disabledTextColor;

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: Stack(
        children: [
          // Background Gradient Orbs
          PositionedDirectional(
            top: -100,
            end: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // Header
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.appColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.appColors.border),
                        ),
                        child: Icon(
                          LucideIcons.shieldCheck,
                          size: 40,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.t.consent.onboardingTitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: context.appColors.foreground,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.t.consent.onboardingSubtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: context.appColors.mutedForeground,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Consent Items
                  Expanded(
                    child: ListView(
                      children: [
                        // Item 1: Terms & Privacy
                        _buildConsentCard(
                          icon: LucideIcons.fileText,
                          title: context.t.consent.termsAndPrivacy,
                          description: context.t.consent.termsDescription,
                          trailing: Checkbox(
                            value: _acceptedTerms,
                            onChanged: (val) {
                              setState(() => _acceptedTerms = val ?? false);
                              ref.hapticLight();
                            },
                            activeColor: primaryColor,
                            checkColor: activeTextColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Both documents, because the checkbox accepts both.
                          // This card asked the user to accept Terms it never
                          // linked — you cannot consent to a document you were
                          // not shown (Guideline 3.1.2).
                          links: [
                            TextButton(
                              onPressed: () => _openUrl(LegalUrls.privacy(_lang)),
                              child: Text(
                                context.t.auth.readPrivacyPolicy,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openUrl(LegalUrls.terms(_lang)),
                              child: Text(
                                context.t.auth.termsOfService,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Item 3: Notifications
                        _buildConsentCard(
                          icon: LucideIcons.bell,
                          title: context.t.consent.systemNotifications,
                          description: context.t.consent.notificationsDescription,
                          trailing: _notificationsAllowed
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                )
                              : ElevatedButton(
                                  onPressed: _requestNotificationPermission,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    foregroundColor: primaryColor,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    context.t.common.actions.enable,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Continue Button
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: GestureDetector(
                      onTap: _isLoading || !_acceptedTerms
                          ? null
                          : _handleContinue,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: _acceptedTerms
                              ? LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withValues(alpha: 0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: _acceptedTerms ? null : context.appColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: _acceptedTerms
                              ? null
                              : Border.all(color: context.appColors.border),
                          boxShadow: _acceptedTerms
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  context.t.consent.continueButton,
                                  style: TextStyle(
                                    color: buttonTextColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget trailing,
    List<Widget>? links,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.appColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: context.appColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        color: context.appColors.mutedForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
          if (links != null) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: links),
          ],
        ],
      ),
    );
  }
}
