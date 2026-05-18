import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';
import '../../providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProFeaturesModal extends ConsumerWidget {
  const ProFeaturesModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ProFeaturesModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: context.appColors.border, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          
          // Premium Icon Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.2),
                  Colors.amber.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ],
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 40,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Sblocca Evolve Pro',
            style: GoogleFonts.inter(
              color: context.appColors.foreground,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Porta il tuo sistema di abitudini al livello successivo',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: context.appColors.mutedForeground,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          
          // Features List
          _buildFeatureItem(
            context: context,
            icon: LucideIcons.brainCircuit,
            title: 'AI Coach Personalizzato',
            description: 'Analisi avanzata dei trend e suggerimenti intelligenti generati dall\'AI.',
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            context: context,
            icon: LucideIcons.cloud,
            title: 'Statistiche Specifiche Per Abitudine',
            description: 'Informazioni chiave per aumentare la tua produttività.',
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            context: context,
            icon: LucideIcons.trendingUp,
            title: 'Metriche Avanzate Obiettivi',
            description: 'Visualizza grafici dettagliati e statistiche di performance profonde per ogni anno.',
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            context: context,
            icon: LucideIcons.shieldCheck,
            title: 'Sicurezza Biometrica Avanzata',
            description: 'Proteggi i tuoi dati più sensibili con FaceID o TouchID.',
          ),
          
          const SizedBox(height: 40),
          
          // CTA Button
          GestureDetector(
            onTap: () {
              final settings = ref.read(settingsProvider);
              final hapticsEnabled = settings.hapticFeedback;
              ref.hapticMedium();
              Navigator.pop(context);
              _showComingSoonDialog(context, hapticsEnabled);
            },
            child: Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade400,
                    Colors.amber.shade700,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: const Center(
                child: Text(
                  'Ottieni Pro a €4,99 / mese',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Forse più tardi',
              style: GoogleFonts.inter(
                color: context.appColors.mutedForeground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appColors.border),
          ),
          child: Icon(icon, size: 20, color: Colors.amber),
        ),
        const SizedBox(width: 16),
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
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  color: context.appColors.mutedForeground,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
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
                    'Ci stiamo ancora lavorando! Sarà disponibile tra pochissimo...Ricordati di rimanere aggiornato',
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
}
