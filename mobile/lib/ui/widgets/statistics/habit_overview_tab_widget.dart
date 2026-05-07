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
        const _TopStatsGrid(),
        const SizedBox(height: 16),
        const _TrendUltimi30Giorni(),
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
          valueColor: context.appColors.foreground,
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
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.appColors.mutedForeground,
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
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: context.appColors.mutedForeground,
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
    final List<int> statuses = [
      0, 0, 1, 0, 2, 0, 1, 1, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 2,
      1, 1, 1, 1, 2, 0, 0, 0, 0, 2,
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.translate('Trend Ultimi 30 Giorni'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
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
                color = context.appColors.muted.withValues(alpha: 0.3); // Dynamic Grey
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
              Text(context.l10n.translate('Completato'), style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: context.appColors.mutedForeground)),
              const SizedBox(width: 16),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: context.appColors.muted.withValues(alpha: 0.3), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(context.l10n.translate('Non completato'), style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: context.appColors.mutedForeground)),
            ],
          )
        ],
      ),
    );
  }
}

class _CorrelazioniSection extends StatefulWidget {
  final String goalId;
  const _CorrelazioniSection({required this.goalId});

  @override
  State<_CorrelazioniSection> createState() => _CorrelazioniSectionState();
}

class _CorrelazioniSectionState extends State<_CorrelazioniSection> {
  late PageController _positiveController;
  late PageController _negativeController;
  int _positiveIndex = 0;
  int _negativeIndex = 0;

  @override
  void initState() {
    super.initState();
    _positiveController = PageController(viewportFraction: 0.9);
    _negativeController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _positiveController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.l10n.translate('Correlazioni con')} "20 Flessioni 1"',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.appColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Come questa abitudine si relaziona con le altre'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 24),

        // POSITIVE CORRELATIONS
        Row(
          children: [
            const Icon(LucideIcons.trendingUp, size: 16, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Correlazioni Positive'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: PageView(
            controller: _positiveController,
            onPageChanged: (i) => setState(() => _positiveIndex = i),
            children: [
              _buildPaddedCard(
                _CorrelazioneCard(
                  habitName: '20 Flessioni 2',
                  habitColor: const Color(0xFFEF4444),
                  strengthText: 'Forte (+0.92)',
                  strengthColor: const Color(0xFF10B981),
                  subtitle: '94% insieme',
                  description: 'Quando completi "20 Flessioni 1", hai una probabilità del 94% di completare anche "20 Flessioni 2".',
                  borderColor: const Color(0xFF10B981),
                ),
              ),
              _buildPaddedCard(
                _CorrelazioneCard(
                  habitName: '20 Flessioni 3',
                  habitColor: const Color(0xFFEF4444),
                  strengthText: 'Forte (+0.77)',
                  strengthColor: const Color(0xFF10B981),
                  subtitle: '81% insieme',
                  description: 'Quando completi "20 Flessioni 1", hai una probabilità del 81% di completare anche "20 Flessioni 3".',
                  borderColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildDots(2, _positiveIndex, const Color(0xFF10B981)),

        const SizedBox(height: 32),

        // NEGATIVE CORRELATIONS
        Row(
          children: [
            const Icon(LucideIcons.trendingDown, size: 16, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Correlazioni Negative'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: PageView(
            controller: _negativeController,
            onPageChanged: (i) => setState(() => _negativeIndex = i),
            children: [
              _buildPaddedCard(
                _CorrelazioneCard(
                  habitName: '1 YT-Video',
                  habitColor: const Color(0xFFEF4444),
                  strengthText: 'Moderata (-0.30)',
                  strengthColor: const Color(0xFFEF4444),
                  subtitle: '93 giorni',
                  description: '"20 Flessioni 1" e "1 YT-Video" raramente vengono completate lo stesso giorno.',
                  borderColor: const Color(0xFFEF4444),
                ),
              ),
              _buildPaddedCard(
                _CorrelazioneCard(
                  habitName: 'Caviglia',
                  habitColor: const Color(0xFF64748B),
                  strengthText: 'Moderata (-0.25)',
                  strengthColor: const Color(0xFFEF4444),
                  subtitle: '102 giorni',
                  description: 'Queste due abitudini sembrano competere per la tua attenzione serale.',
                  borderColor: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildDots(2, _negativeIndex, const Color(0xFFEF4444)),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPaddedCard(Widget card) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: card,
    );
  }

  Widget _buildDots(int count, int current, Color color) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = current == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? color : context.appColors.mutedForeground.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: habitColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  habitName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                strengthText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: strengthColor,
                ),
              ),
              const SizedBox(width: 6),
              Text('•', style: TextStyle(color: context.appColors.mutedForeground, fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: context.appColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: context.appColors.mutedForeground,
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
