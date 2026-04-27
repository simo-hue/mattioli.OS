import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProFeaturesModal extends ConsumerWidget {
  const ProFeaturesModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
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
        color: AppColors.background.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
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
            'Sblocca Mattioli.OS Pro',
            style: GoogleFonts.inter(
              color: AppColors.foreground,
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
              color: AppColors.mutedForeground,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          
          // Features List
          _buildFeatureItem(
            icon: LucideIcons.brainCircuit,
            title: 'AI Coach Personalizzato',
            description: 'Analisi avanzata dei trend e suggerimenti intelligenti generati dall\'AI.',
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            icon: LucideIcons.cloud,
            title: 'Sincronizzazione Cloud illimitata',
            description: 'Accedi ai tuoi dati da qualsiasi dispositivo in tempo reale.',
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            icon: LucideIcons.trendingUp,
            title: 'Metriche Avanzate',
            description: 'Visualizza grafici dettagliati e statistiche di performance profonde.',
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            icon: LucideIcons.shieldCheck,
            title: 'Sicurezza Biometrica Avanzata',
            description: 'Proteggi i tuoi dati più sensibili con FaceID o TouchID.',
          ),
          
          const SizedBox(height: 40),
          
          // CTA Button
          GestureDetector(
            onTap: () {
              ref.hapticMedium();
              Navigator.pop(context);
              // Future: In-app purchase logic
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
                color: AppColors.mutedForeground,
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
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
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
                  color: AppColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  color: AppColors.mutedForeground,
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
}
