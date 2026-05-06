import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';

class HabitMiglioramentoTabWidget extends StatelessWidget {
  final String goalId;

  const HabitMiglioramentoTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SerieNegativaCard(),
        const SizedBox(height: 16),
        _StreakInterrottiCard(),
        const SizedBox(height: 16),
        _SuggerimentiCard(),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SerieNegativaCard extends StatelessWidget {
  const _SerieNegativaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trendingDown, size: 20, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Text(
                context.l10n.translate('Serie Negativa Peggiore'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '12',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                  height: 1,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.translate('giorni consecutivi mancati'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${context.l10n.translate('Iniziata il')} 1 ${context.l10n.translate('Aprile')} 2026',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakInterrottiCard extends StatelessWidget {
  const _StreakInterrottiCard();

  @override
  Widget build(BuildContext context) {
    final streaks = [
      {'days': 4, 'date': '17 aprile 2026'},
      {'days': 6, 'date': '6 marzo 2026'},
      {'days': 7, 'date': '8 febbraio 2026'},
      {'days': 34, 'date': '31 gennaio 2026'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.translate('Streak Interrotti'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 16),
          ...streaks.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildStreakItem(context, s['days'] as int, s['date'] as String),
              )),
        ],
      ),
    );
  }

  Widget _buildStreakItem(BuildContext context, int days, String date) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Inner card background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$days',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.translate('Streak di count giorni interrotto').replaceFirst('count', days.toString()),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggerimentiCard extends StatelessWidget {
  const _SuggerimentiCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 ${context.l10n.translate('Suggerimenti')}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 16),
          _buildBulletPoint(context.l10n.translate('Concentrati sul Dom - è il tuo giorno più debole')),
          _buildBulletPoint(context.l10n.translate('Evita pause prolungate - la tua serie negativa più lunga è stata di 12 giorni')),
          _buildBulletPoint(context.l10n.translate('Obiettivo: raggiungi almeno il 70% di completamento per consolidare l\'abitudine')),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                  height: 1.4,
                ),
                children: _parseBoldText(text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simple parser to make Dom, 12 giorni, and 70% bold slightly if wanted,
  // but let's just make the text standard or we can just hardcode the styling if really needed.
  // Using rich text explicitly based on the snapshot
  List<TextSpan> _parseBoldText(String text) {
    // Actually the user screenshot doesn't show strong bold, it's just regular text.
    // I'll return a single text span.
    return [TextSpan(text: text, style: const TextStyle(color: AppColors.mutedForeground))];
  }
}
