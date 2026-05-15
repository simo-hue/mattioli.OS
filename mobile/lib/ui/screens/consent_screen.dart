import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../core/sentry_config.dart';
import '../../providers/consent_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _acceptedTerms = false;
  bool _sentryConsent = true; // Default to true, but user can opt-out
  bool _notificationsAllowed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationsAllowed = status.isGranted;
    });
  }

  Future<void> _requestNotificationPermission() async {
    ref.hapticLight();
    final status = await Permission.notification.request();
    setState(() {
      _notificationsAllowed = status.isGranted;
    });
  }

  Future<void> _openUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il link.')),
        );
      }
    }
  }

  Future<void> _handleContinue() async {
    if (!_acceptedTerms) {
      ref.hapticHeavy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devi accettare i Termini e la Privacy Policy per continuare.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    ref.hapticMedium();

    // Salva il consenso nel provider
    await ref.read(consentProvider.notifier).setConsent(
      acceptedTerms: _acceptedTerms,
      sentryConsent: _sentryConsent,
      completed: true,
    );

    // Se l'utente è già loggato, salva il consenso anche nel DB
    final isLoggedIn = ref.read(authProvider).isLoggedIn;
    if (isLoggedIn) {
      await ref.read(authProvider.notifier).updateConsentInDb(_acceptedTerms, _sentryConsent);
    }

    // Inizializza Sentry immediatamente se l'utente ha dato il consenso
    if (_sentryConsent) {
      await SentryFlutter.init(
        (options) {
          options.dsn = SentryConfig.dsn;
          options.environment = SentryConfig.environment;
          options.tracesSampleRate = SentryConfig.tracesSampleRate;
          options.reportPackages = true;
          options.debug = false;
          options.beforeSend = (event, hint) {
            return SentryConfig.sanitizeEvent(event);
          };
        },
      );
    }

    setState(() => _isLoading = false);
    
    // La navigazione verrà gestita automaticamente dal router in main.dart
    // grazie al cambio di stato in consentProvider.
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isLightBg = primaryColor.computeLuminance() > 0.5;
    final activeTextColor = isLightBg ? Colors.black : Colors.white;
    final disabledTextColor = context.appColors.mutedForeground.computeLuminance() > 0.7
        ? Colors.grey[600]!
        : context.appColors.mutedForeground;
    final buttonTextColor = _acceptedTerms ? activeTextColor : disabledTextColor;

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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                        child: Icon(LucideIcons.shieldCheck, size: 40, color: primaryColor),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'La tua Privacy è Importante',
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
                        'Per garantirti un\'esperienza sicura e personalizzata, abbiamo bisogno di alcune conferme.',
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
                          title: 'Termini e Privacy Policy',
                          description: 'Dichiaro di aver letto e accettato i Termini di Servizio e la Privacy Policy. Confermo di avere almeno 14 anni.',
                          trailing: Checkbox(
                            value: _acceptedTerms,
                            onChanged: (val) {
                              setState(() => _acceptedTerms = val ?? false);
                              ref.hapticLight();
                            },
                            activeColor: primaryColor,
                            checkColor: activeTextColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          links: [
                            TextButton(
                              onPressed: () => _openUrl('https://simo-hue.github.io/mattioli.OS/'),
                              child: Text('Leggi Privacy Policy', style: TextStyle(color: primaryColor, fontSize: 12)),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Item 2: Sentry Consent
                        _buildConsentCard(
                          icon: LucideIcons.circleAlert,
                          title: 'Miglioramento App (Sentry)',
                          description: 'Consento l\'invio di segnalazioni di crash anonime per aiutarci a risolvere i problemi più velocemente.',
                          trailing: Switch(
                            value: _sentryConsent,
                            onChanged: (val) {
                              setState(() => _sentryConsent = val);
                              ref.hapticLight();
                            },
                            activeThumbColor: primaryColor,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Item 3: Notifications
                        _buildConsentCard(
                          icon: LucideIcons.bell,
                          title: 'Notifiche di Sistema',
                          description: 'Ricevi promemoria per le tue abitudini e report settimanali.',
                          trailing: _notificationsAllowed
                              ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
                              : ElevatedButton(
                                  onPressed: _requestNotificationPermission,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                                    foregroundColor: primaryColor,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: const Text('Abilita', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Continue Button
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: GestureDetector(
                      onTap: _isLoading || !_acceptedTerms ? null : _handleContinue,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: _acceptedTerms
                              ? LinearGradient(
                                  colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: _acceptedTerms ? null : context.appColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: _acceptedTerms ? null : Border.all(color: context.appColors.border),
                          boxShadow: _acceptedTerms
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Continua',
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
                child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: links,
            ),
          ],
        ],
      ),
    );
  }
}
