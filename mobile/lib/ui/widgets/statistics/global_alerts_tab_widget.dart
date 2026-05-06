import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';

class GlobalAlertsTabWidget extends StatelessWidget {
  const GlobalAlertsTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AreeMiglioramentoSection(),
        SizedBox(height: 24),
        _AnalisiWorstStreaksSection(),
        SizedBox(height: 24),
        _AnalisiFallimentiSection(),
        SizedBox(height: 24),
        _ConfrontoPerformanceSection(),
        SizedBox(height: 24),
        _SuggerimentiPraticiSection(),
        SizedBox(height: 40),
      ],
    );
  }
}

class _AreeMiglioramentoSection extends StatelessWidget {
  const _AreeMiglioramentoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.target, size: 20, color: AppColors.foreground),
            const SizedBox(width: 10),
            Text(
              context.l10n.translate('Aree di Miglioramento'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Abitudini che richiedono più attenzione.'),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _MiglioramentoCard(
                title: 'Lettura',
                successRate: '10%',
                day: context.l10n.translate('Mercoledì'),
                dayCompletion: '15%',
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 12),
              _MiglioramentoCard(
                title: '20 Flessioni 4',
                successRate: '13%',
                day: context.l10n.translate('Domenica'),
                dayCompletion: '15%',
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(width: 12),
              _MiglioramentoCard(
                title: '20 Flessioni 2',
                successRate: '20%',
                day: context.l10n.translate('Domenica'),
                dayCompletion: '31%',
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiglioramentoCard extends StatelessWidget {
  final String title;
  final String successRate;
  final String day;
  final String dayCompletion;
  final Color color;

  const _MiglioramentoCard({
    required this.title,
    required this.successRate,
    required this.day,
    required this.dayCompletion,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '$successRate ${context.l10n.translate('succ.')}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.circleAlert, size: 14, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.translate('GIORNO NERO'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      day,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.mutedForeground),
                        children: [
                          TextSpan(text: '${context.l10n.translate('Solo')} '),
                          TextSpan(text: dayCompletion, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                          TextSpan(text: ' ${context.l10n.translate('di completamento')}'),
                        ],
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

class _AnalisiWorstStreaksSection extends StatelessWidget {
  const _AnalisiWorstStreaksSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.trendingDown, size: 18, color: Color(0xFFEF4444)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.translate('Analisi Worst Streaks'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      context.l10n.translate('Analisi serie negative per identificare pattern.'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🎯 ${context.l10n.translate('Abitudini Critiche')}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                  Text(
                    context.l10n.translate('Top 3 Worst Streaks'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: _WorstStreakCard(
                      title: '20 Flessioni 4',
                      streak: '30',
                      rank: '1',
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: _WorstStreakCard(
                      title: '20 Flessioni 3',
                      streak: '17',
                      rank: '2',
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: _WorstStreakCard(
                      title: '20 Flessioni 1',
                      streak: '11',
                      rank: '3',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorstStreakCard extends StatelessWidget {
  final String title;
  final String streak;
  final String rank;

  const _WorstStreakCard({
    required this.title,
    required this.streak,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderHover, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title.length > 12 ? '${title.substring(0, 10)}...' : title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                child: Text(
                  rank,
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.mutedForeground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'WORST STREAK',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            streak,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEF4444),
            ),
          ),
          Text(
            context.l10n.translate('giorni consecutivi'),
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

class _AnalisiFallimentiSection extends StatelessWidget {
  const _AnalisiFallimentiSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.chartBar, size: 16, color: Color(0xFFF97316)),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.translate('Analisi Fallimenti'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFailureRow('20 Flessioni 4', '30 giorni', '~26/mese'),
                const SizedBox(height: 12),
                _buildFailureRow('20 Flessioni 3', '17 giorni', '~24/mese'),
                const SizedBox(height: 12),
                _buildFailureRow('20 Flessioni 1', '11 giorni', '~22/mese'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 16, color: AppColors.foreground),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.translate('Pattern di Recupero'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.l10n.translate('Tempo Medio Recupero'), style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                    Text('6 ${context.l10n.translate('giorni')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.foreground)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.7,
                    minHeight: 6,
                    backgroundColor: AppColors.muted,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text('👍 ${context.l10n.translate('Buono')}', style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                const SizedBox(height: 16),
                Text(
                  '🔥 ${context.l10n.translate('RECUPERATORI VELOCI')}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 12),
                _buildRecoveryRow('Fitness', '1 gg', Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                _buildRecoveryRow('Journaling', '1 gg', Color(0xFFEAB308)),
                const SizedBox(height: 8),
                _buildRecoveryRow('No Fap', '1 gg', Color(0xFF06B6D4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailureRow(String title, String worst, String freq) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Worst Streak', style: TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                Text(worst, style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Freq. Fallimenti', style: TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                Text(freq, style: const TextStyle(fontSize: 11, color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecoveryRow(String title, String time, Color dotColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          ],
        ),
        Text(time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: dotColor)),
      ],
    );
  }
}

class _ConfrontoPerformanceSection extends StatelessWidget {
  const _ConfrontoPerformanceSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trendingUp, size: 18, color: AppColors.foreground),
              const SizedBox(width: 10),
              Text(
                context.l10n.translate('Confronto Performance'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPerformanceItem(context, '20 Flessioni 4', 0.13, 4, 30),
          const SizedBox(height: 20),
          _buildPerformanceItem(context, 'Alimentazione', 0.36, 4, 11),
          const SizedBox(height: 20),
          _buildPerformanceItem(context, 'Lettura', 0.60, 6, 10),
        ],
      ),
    );
  }

  Widget _buildPerformanceItem(BuildContext context, String title, double gap, int best, int worst) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF97316).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(context.l10n.translate('Attenzione'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF97316))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Best', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
            Text('$best gg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: 0.3,
            minHeight: 4,
            backgroundColor: AppColors.muted,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Worst', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
            Text('$worst gg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: 0.9,
            minHeight: 4,
            backgroundColor: AppColors.muted,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
            children: [
              const TextSpan(text: 'Gap: '),
              TextSpan(text: '${(gap * 100).toInt()}%', style: const TextStyle(color: AppColors.foreground, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggerimentiPraticiSection extends StatelessWidget {
  const _SuggerimentiPraticiSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.lightbulb, size: 18, color: Color(0xFFEAB308)),
              const SizedBox(width: 10),
              Text(
                context.l10n.translate('Suggerimenti Pratici'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSuggerimento(
            icon: LucideIcons.target,
            color: Color(0xFFEF4444),
            title: 'Focus su "20 Flessioni 4"',
            desc: 'Hai passato 30 giorni consecutivi senza completare questa abitudine',
            action: 'Considera di ridurre la difficoltà o impostare promemoria extra',
          ),
          const SizedBox(height: 12),
          _buildSuggerimento(
            icon: LucideIcons.chartBar,
            color: Color(0xFF3B82F6),
            title: 'Tasso di Completamento Basso',
            desc: '"20 Flessioni 4" ha solo 13% di successo',
            action: 'Prova a semplificare l\'abitudine o renderla più piccola',
          ),
          const SizedBox(height: 12),
          _buildSuggerimento(
            icon: LucideIcons.armchair, // Using similar icon as LucideIcons.armchair for recovery if armchair not available
            color: Color(0xFFF97316),
            title: 'Ottima Capacità di Recupero',
            desc: 'Recuperi velocemente dopo i fallimenti (media 6 giorni)',
            action: 'Continua così - usa la stessa strategia per altre abitudini!',
          ),
          const SizedBox(height: 12),
          _buildSuggerimento(
            icon: LucideIcons.calendar,
            color: Color(0xFF6B7280),
            title: 'Pattern Generale',
            desc: 'In media fallisci ~24 volte al mese',
            action: 'Identifica i trigger comuni e crea strategie preventive',
          ),
        ],
      ),
    );
  }

  Widget _buildSuggerimento({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required String action,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.foreground)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.arrowRight, size: 10, color: AppColors.mutedForeground),
                    const SizedBox(width: 4),
                    Expanded(child: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.foreground))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


