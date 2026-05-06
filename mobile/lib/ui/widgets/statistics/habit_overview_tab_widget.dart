import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';

class HabitOverviewTabWidget extends StatelessWidget {
  final String goalId;

  const HabitOverviewTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopStatsGrid(),
        const SizedBox(height: 16),
        _TrendUltimi30Giorni(),
        const SizedBox(height: 16),
        _CorrelazioniSection(goalId: goalId),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _TopStatsGrid extends StatelessWidget {
  const _TopStatsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _StatCard(
          title: context.l10n.translate('SERIE ATTUALE'),
          value: '0',
          subtitle: context.l10n.translate('giorni'),
          valueColor: const Color(0xFFEF4444), // Red
        ),
        _StatCard(
          title: context.l10n.translate('RECORD'),
          value: '34',
          subtitle: context.l10n.translate('giorni'),
          valueColor: const Color(0xFFEAB308), // Yellow
        ),
        _StatCard(
          title: context.l10n.translate('COMPLETAMENTO'),
          value: '55%',
          subtitle: '67/122 ${context.l10n.translate('gg')}',
          valueColor: AppColors.foreground,
        ),
        _StatCard(
          title: context.l10n.translate('MANCATI'),
          value: '40',
          subtitle: context.l10n.translate('giorni'),
          valueColor: const Color(0xFFEF4444), // Red
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color valueColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendUltimi30Giorni extends StatelessWidget {
  const _TrendUltimi30Giorni();

  @override
  Widget build(BuildContext context) {
    // Mocking the 30 days grid as seen in the screenshot
    // 3 rows, 10 columns
    // Red: Missed, Green: Completed, Dark: Empty/Future
    final List<int> statuses = [
      0, 0, 1, 0, 2, 0, 1, 1, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 2,
      1, 1, 1, 1, 2, 0, 0, 0, 0, 2,
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.translate('Trend Ultimi 30 Giorni'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: 30,
            itemBuilder: (context, index) {
              final status = statuses[index];
              Color color;
              if (status == 1) {
                color = Theme.of(context).colorScheme.primary; 
              } else if (status == 0) {
                color = const Color(0xFFFF0000); // Red
              } else {
                color = const Color(0xFF18181B); // Dark Grey
              }

              return Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(context.l10n.translate('Completato'), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.mutedForeground)),
              const SizedBox(width: 16),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF18181B), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(context.l10n.translate('Non completato'), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.mutedForeground)),
            ],
          )
        ],
      ),
    );
  }
}

class _CorrelazioniSection extends StatelessWidget {
  final String goalId;
  const _CorrelazioniSection({required this.goalId});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.l10n.translate('Correlazioni con')} "20 Flessioni 1"', // Mock title for now
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.translate('Come questa abitudine si relaziona con le altre'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          
          // Positive Correlations
          Row(
            children: [
              const Icon(LucideIcons.trendingUp, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                context.l10n.translate('Correlazioni Positive'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CorrelazioneCard(
            habitName: '20 Flessioni 2',
            habitColor: const Color(0xFFEF4444),
            strengthText: 'Forte (+0.92)',
            strengthColor: const Color(0xFF10B981),
            subtitle: '94% ${context.l10n.translate('together')}',
            description: 'Quando completi "20 Flessioni 1", hai una probabilità del 94% di completare anche "20 Flessioni 2". Considera di farle insieme come routine consolidata.',
            borderColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 8),
          _CorrelazioneCard(
            habitName: '20 Flessioni 3',
            habitColor: const Color(0xFFEF4444),
            strengthText: 'Forte (+0.77)',
            strengthColor: const Color(0xFF10B981),
            subtitle: '81% insieme',
            description: 'Quando completi "20 Flessioni 1", hai una probabilità del 81% di completare anche "20 Flessioni 3". Considera di farle insieme come routine consolidata.',
            borderColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 8),
          _CorrelazioneCard(
            habitName: '20 Flessioni 4',
            habitColor: const Color(0xFFEF4444),
            strengthText: 'Forte (+0.62)',
            strengthColor: const Color(0xFF10B981),
            subtitle: '53% insieme',
            description: 'Quando completi "20 Flessioni 1", hai una probabilità del 53% di completare anche "20 Flessioni 4". Considera di farle insieme come routine consolidata.',
            borderColor: const Color(0xFF10B981),
          ),
          
          const SizedBox(height: 24),
          
          // Negative Correlations
          Row(
            children: [
              const Icon(LucideIcons.trendingDown, size: 14, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Text(
                context.l10n.translate('Correlazioni Negative'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CorrelazioneCard(
            habitName: '1 YT-Video',
            habitColor: const Color(0xFFEF4444),
            strengthText: 'Moderata (-0.30)',
            strengthColor: const Color(0xFFEF4444),
            subtitle: '93 giorni',
            description: '"20 Flessioni 1" e "1 YT-Video" raramente vengono completate lo stesso giorno. Potrebbero competere per tempo/energia - considera di pianificarle in giorni diversi.',
            borderColor: const Color(0xFFEF4444),
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.info, size: 16, color: Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.translate('Info Correlazioni'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _CorrelazioneCard extends StatelessWidget {
  final String habitName;
  final Color habitColor;
  final String strengthText;
  final Color strengthColor;
  final String subtitle;
  final String description;
  final Color borderColor;

  const _CorrelazioneCard({
    required this.habitName,
    required this.habitColor,
    required this.strengthText,
    required this.strengthColor,
    required this.subtitle,
    required this.description,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: habitColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(
                habitName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 18),
              Text(
                strengthText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: strengthColor,
                ),
              ),
              const SizedBox(width: 6),
              const Text('•', style: TextStyle(color: AppColors.mutedForeground, fontSize: 11)),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppColors.mutedForeground,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
