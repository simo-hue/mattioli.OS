import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import '../../core/theme.dart';
import '../../core/haptics.dart';
import '../../core/subscription_service.dart';
import '../../providers/settings_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const SubscriptionScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  Package? _monthlyPackage;
  Package? _yearlyPackage;
  Package? _selectedPackage;

  bool _isLoading = false;
  bool _isFetchingProducts = true;
  String _selectedMockPackage = 'yearly';

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  /// Loads the active offerings from the App Store dynamically via RevenueCat
  Future<void> _loadOfferings() async {
    try {
      final offerings = await ref.read(subscriptionServiceProvider).getOfferings();
      if (mounted && offerings != null && offerings.current != null) {
        final current = offerings.current!;
        setState(() {
          _monthlyPackage = current.monthly;
          _yearlyPackage = current.annual;

          // Default selection to Yearly (best value) or Monthly if Yearly is null
          _selectedPackage = _yearlyPackage ?? _monthlyPackage;
          _isFetchingProducts = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isFetchingProducts = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFetchingProducts = false;
        });
      }
    }
  }

  /// Restores previous purchases (Apple compliance required)
  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    ref.hapticMedium();

    try {
      final success = await ref.read(subscriptionServiceProvider).restorePurchases();
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acquisti ripristinati con successo! Accesso Pro sbloccato.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessun abbonamento attivo trovato su questo account Apple.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il ripristino: $e')),
      );
    }
  }

  /// Triggers Apple's payment sheet flow
  Future<void> _purchase() async {
    if (_selectedPackage == null) return;

    setState(() => _isLoading = true);
    ref.hapticMedium();

    try {
      final success = await ref.read(subscriptionServiceProvider).purchasePackage(_selectedPackage!);
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (success) {
        _showSuccessDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('L\'acquisto non è andato a buon fine o è stato annullato. Riprova.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Acquisto non completato: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isPro = settings.isPro;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.appColors.background,
          appBar: AppBar(
            backgroundColor: context.appColors.background,
            elevation: 0,
            leading: IconButton(
              icon: Icon(LucideIcons.chevronLeft, color: context.appColors.foreground),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Abbonamento',
              style: TextStyle(
                color: context.appColors.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: true,
            actions: [
              if (!isPro)
                TextButton(
                  onPressed: _isLoading ? null : _restorePurchases,
                  child: Text(
                    'Ripristina',
                    style: TextStyle(
                      color: context.appColors.foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          body: _isFetchingProducts
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.amber,
                  ),
                )
              : RefreshIndicator(
                  color: Colors.amber,
                  backgroundColor: context.appColors.card,
                  onRefresh: () async {
                    setState(() {
                      _isFetchingProducts = true;
                    });
                    await _loadOfferings();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isPro) ...[
                          _buildUpsellHeader(context),
                          const SizedBox(height: 32),
                          _buildFeaturesList(context),
                          const SizedBox(height: 40),
                          _buildPlanSelector(context),
                          const SizedBox(height: 24),
                          _buildComplianceLinks(context),
                        ] else ...[
                          _buildProStatusHeader(context),
                          const SizedBox(height: 32),
                          _buildSubscriptionDetails(context),
                          const SizedBox(height: 40),
                          _buildManageActions(context),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.amber,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUpsellHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withValues(alpha: 0.1),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Icon(LucideIcons.sparkles, size: 32, color: Colors.amber),
          ),
          const SizedBox(height: 16),
          Text(
            'Passa a Evolve Pro',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sblocca tutte le funzionalità e accelera la tua crescita.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.appColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COSA INCLUDE IL PIANO PRO',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.appColors.mutedForeground,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        _buildFeatureRow(context, LucideIcons.brainCircuit, 'AI Coach Personalizzato', 'Suggerimenti intelligenti basati sui tuoi dati.'),
        const SizedBox(height: 16),
        _buildFeatureRow(context, LucideIcons.trendingUp, 'Statistiche Avanzate', 'Grafici profondi e analisi dei trend.'),
        const SizedBox(height: 16),
        _buildFeatureRow(context, LucideIcons.infinity, 'Abitudini Illimitate', 'Crea tutti gli habits che desideri senza limiti.'),
        const SizedBox(height: 16),
        _buildFeatureRow(context, LucideIcons.cloud, 'Sincronizzazione Cloud', 'I tuoi dati al sicuro e sempre disponibili.'),
      ],
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appColors.border),
          ),
          child: Icon(icon, size: 18, color: Colors.amber),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: context.appColors.foreground),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(fontSize: 12, color: context.appColors.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSelector(BuildContext context) {
    if (_monthlyPackage == null && _yearlyPackage == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCEGLI IL TUO PIANO',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.appColors.mutedForeground,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildMockPlanCard('Mensile', '€4,99', 'Disdici quando vuoi', _selectedMockPackage == 'monthly', onTap: () {
            setState(() => _selectedMockPackage = 'monthly');
          }),
          const SizedBox(height: 12),
          _buildMockPlanCard('Annuale', '€29,99', 'Risparmia oltre il 40%', _selectedMockPackage == 'yearly', isBestValue: true, onTap: () {
            setState(() => _selectedMockPackage = 'yearly');
          }),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () async {
              ref.hapticMedium();
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _isLoading = true);
              try {
                // Background attempt to dynamically load real offerings
                final offerings = await ref.read(subscriptionServiceProvider).getOfferings();
                if (mounted && offerings != null && offerings.current != null) {
                  final current = offerings.current!;
                  final package = _selectedMockPackage == 'monthly' ? current.monthly : current.annual;
                  if (package != null) {
                    setState(() {
                      _monthlyPackage = current.monthly;
                      _yearlyPackage = current.annual;
                      _selectedPackage = package;
                      _isLoading = false;
                      _isFetchingProducts = false;
                    });
                    // Successfully bridged to real StoreKit purchase!
                    await _purchase();
                    return;
                  }
                }
              } catch (_) {}
              
              if (mounted) {
                setState(() => _isLoading = false);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Servizio acquisti non raggiungibile. Verifica la tua connessione e riprova.'),
                    backgroundColor: Colors.amber,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.amber.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Center(
                child: Text(
                  'Attiva Abbonamento',
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCEGLI IL TUO PIANO',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.appColors.mutedForeground,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (_monthlyPackage != null)
          _buildPlanCard(_monthlyPackage!, 'Mensile', 'Disdici quando vuoi'),
        if (_yearlyPackage != null) ...[
          const SizedBox(height: 12),
          _buildPlanCard(_yearlyPackage!, 'Annuale', 'Risparmia oltre il 40%', isBestValue: true),
        ],
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _purchase,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.amber.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Center(
              child: Text(
                'Attiva Abbonamento',
                style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => ref.read(subscriptionServiceProvider).presentPaywall(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.sparkles, color: Colors.amber, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Mostra Paywall Grafico di RevenueCat',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(Package package, String title, String subtitle, {bool isBestValue = false}) {
    final isSelected = _selectedPackage?.identifier == package.identifier;
    final priceStr = package.storeProduct.priceString;

    return GestureDetector(
      onTap: () {
        ref.hapticLight();
        setState(() {
          _selectedPackage = package;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.amber.withValues(alpha: 0.8) : context.appColors.border,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.amber : context.appColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Evolve Pro $title',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.foreground,
                          ),
                        ),
                      ),
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'CONVENIENTE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              priceStr,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays mandatory links for Apple guidelines: EULA & Privacy Policy (Guideline 3.1.2)
  Widget _buildComplianceLinks(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          'L\'abbonamento si rinnova automaticamente a meno che l\'autorinnovamento non venga disattivato nelle impostazioni dell\'account Apple almeno 24 ore prima della scadenza.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: context.appColors.mutedForeground,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://simo-hue.github.io/mattioli.OS/')),
              child: Text(
                'Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.amber,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              '  •  ',
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/')),
              child: Text(
                'Termini d\'Uso (EULA)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.amber,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProStatusHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.1),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: const Icon(LucideIcons.shieldCheck, size: 32, color: Colors.green),
          ),
          const SizedBox(height: 16),
          Text(
            'Sei un utente Pro!',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Grazie per sostenere lo sviluppo di Evolve.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.appColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionDetails(BuildContext context) {
    final nextRenewal = DateTime.now().add(const Duration(days: 30));
    final dateFormat = DateFormat('dd MMMM yyyy', 'it');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETTAGLI ABBONAMENTO',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.appColors.mutedForeground,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appColors.border),
          ),
          child: Column(
            children: [
              _buildDetailRow(context, 'Piano', 'Evolve Pro Attivo'),
              const Divider(height: 32),
              _buildDetailRow(context, 'Stato', 'Attivo', valueColor: Colors.green),
              const Divider(height: 32),
              _buildDetailRow(context, 'Prossimo Rinnovo', dateFormat.format(nextRenewal)),
              const Divider(height: 32),
              _buildDetailRow(context, 'Metodo di Pagamento', 'Apple Pay / App Store'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.appColors.mutedForeground, fontSize: 14)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor ?? context.appColors.foreground, fontSize: 14)),
      ],
    );
  }

  Widget _buildManageActions(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            ref.hapticLight();
            // Opens the official RevenueCat Customer Center directly inside the app
            ref.read(subscriptionServiceProvider).presentCustomerCenter();
          },
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: context.appColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appColors.border),
            ),
            child: Center(
              child: Text(
                'Gestisci Abbonamento',
                style: TextStyle(color: context.appColors.foreground, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            ref.hapticHeavy();
            _showCancelDialog(context);
          },
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.destructive.withValues(alpha: 0.1)),
            ),
            child: const Center(
              child: Text(
                'Disdici Abbonamento',
                style: TextStyle(color: AppColors.destructive, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog(BuildContext context) {
    ref.hapticHeavy(); // Trigger deep haptic feedback for celebration!

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.appColors.card.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Benvenuto in Evolve Pro!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.appColors.foreground,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'La tua iscrizione è attiva. Ora hai accesso completo ed illimitato all\'AI Coach personalizzato, alle statistiche avanzate dei trend e a tutti gli strumenti di crescita personale di Evolve.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.appColors.mutedForeground,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () {
                    ref.hapticLight();
                    Navigator.pop(dialogContext);
                    Navigator.pop(context); // Close the subscription screen to return home!
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade400, Colors.amber.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Inizia il tuo Percorso',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: context.appColors.card.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.destructive.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 32,
                    color: AppColors.destructive,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Gestisci Abbonamento',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.foreground,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Per modificare, aggiornare o disdire il tuo abbonamento Pro, verrai indirizzato al portale ufficiale di RevenueCat o del tuo Account Apple.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: context.appColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: context.appColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.appColors.border),
                          ),
                          child: Center(
                            child: Text(
                              'Annulla',
                              style: TextStyle(
                                color: context.appColors.foreground,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(dialogContext);
                          // Trigger the modern compliant Customer Center
                          ref.read(subscriptionServiceProvider).presentCustomerCenter();
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.destructive,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.destructive.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Continua',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildMockPlanCard(
    String title,
    String priceStr,
    String subtitle,
    bool isSelected, {
    bool isBestValue = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        ref.hapticLight();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.amber.withValues(alpha: 0.8) : context.appColors.border,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.amber : context.appColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Evolve Pro $title',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.foreground,
                          ),
                        ),
                      ),
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'CONVENIENTE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              priceStr,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
