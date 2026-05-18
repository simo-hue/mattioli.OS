import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';
import '../../providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class SubscriptionScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isPro = settings.isPro;

    return Scaffold(
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isPro) ...[
              _buildUpsellHeader(context),
              const SizedBox(height: 32),
              _buildFeaturesList(context),
              const SizedBox(height: 40),
              _buildPlanSelector(context, ref),
            ] else ...[
              _buildProStatusHeader(context),
              const SizedBox(height: 32),
              _buildSubscriptionDetails(context),
              const SizedBox(height: 40),
              _buildManageActions(context, ref),
            ],
          ],
        ),
      ),
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
        _buildFeatureRow(context, LucideIcons.shieldCheck, 'Protezione Biometrica', 'Accedi con FaceID o TouchID.'),
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

  Widget _buildPlanSelector(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PIANO',
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
            border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evolve Pro Mensile',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: context.appColors.foreground),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '€4,99 al mese, disdici quando vuoi.',
                      style: GoogleFonts.inter(fontSize: 13, color: context.appColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              Text(
                '€4,99',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: context.appColors.foreground),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () {
            final hapticsEnabled = ref.read(settingsProvider).hapticFeedback;
            ref.hapticMedium();
            _showComingSoonDialog(context, hapticsEnabled);
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

  void _showComingSoonDialog(BuildContext context, bool hapticsEnabled) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.appColors.card.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.appColors.border.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 4,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'In Arrivo!',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.appColors.foreground,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ci stiamo ancora lavorando! La sottoscrizione ad Evolve Pro ed i relativi servizi di pagamento saranno disponibili tra pochissimo in un prossimo aggiornamento.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: context.appColors.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (hapticsEnabled) {
                            HapticFeedback.mediumImpact();
                          }
                          Navigator.pop(dialogContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            'Ho capito',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
        );
      },
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
              _buildDetailRow(context, 'Piano', 'Evolve Pro Mensile'),
              const Divider(height: 32),
              _buildDetailRow(context, 'Stato', 'Attivo', valueColor: Colors.green),
              const Divider(height: 32),
              _buildDetailRow(context, 'Prossimo Rinnovo', dateFormat.format(nextRenewal)),
              const Divider(height: 32),
              _buildDetailRow(context, 'Metodo di Pagamento', 'Visa **** 4242'),
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

  Widget _buildManageActions(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            ref.hapticLight();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Funzionalità di cambio piano non disponibile nel mock.')),
            );
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
                'Cambia Piano',
                style: TextStyle(color: context.appColors.foreground, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            ref.hapticHeavy();
            _showCancelDialog(context, ref);
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

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
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
                  'Disdici Abbonamento',
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
                  'Sei sicuro di voler disdire il tuo abbonamento Pro? Perderai l\'accesso alle funzionalità avanzate al termine del periodo di fatturazione.',
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
                        onTap: () => Navigator.pop(context),
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
                          Navigator.pop(context);
                          final settings = ref.read(settingsProvider);
                          ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(isPro: false));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Abbonamento disdetto con successo.')),
                          );
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
                              'Disdici',
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
}
