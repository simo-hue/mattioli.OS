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
        _AnalisiFallimentiSection(),
        SizedBox(height: 24),
        _PatternRecuperoSection(),
        SizedBox(height: 24),
        _ConfrontoPerformanceSection(),
        SizedBox(height: 40),
      ],
    );
  }
}

class _AreeMiglioramentoSection extends StatefulWidget {
  const _AreeMiglioramentoSection();

  @override
  State<_AreeMiglioramentoSection> createState() => _AreeMiglioramentoSectionState();
}

class _AreeMiglioramentoSectionState extends State<_AreeMiglioramentoSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _MiglioramentoCard(
        title: 'Lettura',
        successRate: '10%',
        day: context.l10n.translate('Mercoledì'),
        dayCompletion: '15%',
        color: const Color(0xFF10B981),
      ),
      _MiglioramentoCard(
        title: '20 Flessioni 4',
        successRate: '13%',
        day: context.l10n.translate('Domenica'),
        dayCompletion: '15%',
        color: const Color(0xFFEF4444),
      ),
      _MiglioramentoCard(
        title: '20 Flessioni 2',
        successRate: '20%',
        day: context.l10n.translate('Domenica'),
        dayCompletion: '31%',
        color: const Color(0xFFEF4444),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.target, size: 16, color: context.appColors.foreground),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Aree di Miglioramento'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Abitudini che richiedono più attenzione.'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        
        // Carousel
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cards[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Pagination Dots
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive 
                      ? Theme.of(context).colorScheme.primary 
                      : context.appColors.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
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
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
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
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.foreground,
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
                style: TextStyle(
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
              Icon(LucideIcons.circleAlert, size: 14, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.translate('GIORNO NERO'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      day,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: context.appColors.mutedForeground),
                        children: [
                          TextSpan(text: '${context.l10n.translate('Solo')} '),
                          TextSpan(text: dayCompletion, style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
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


class _AnalisiFallimentiSection extends StatefulWidget {
  const _AnalisiFallimentiSection();

  @override
  State<_AnalisiFallimentiSection> createState() => _AnalisiFallimentiSectionState();
}

class _AnalisiFallimentiSectionState extends State<_AnalisiFallimentiSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _FailureDetailCard(
        title: '20 Flessioni 4',
        worstStreak: '30 giorni',
        frequency: '~26/mese',
        color: const Color(0xFFEF4444),
      ),
      _FailureDetailCard(
        title: '20 Flessioni 3',
        worstStreak: '17 giorni',
        frequency: '~24/mese',
        color: const Color(0xFFF97316),
      ),
      _FailureDetailCard(
        title: '20 Flessioni 1',
        worstStreak: '11 giorni',
        frequency: '~22/mese',
        color: const Color(0xFFEAB308),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.chartBar, size: 16, color: Color(0xFFF97316)),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Analisi Fallimenti'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Frequenza e pattern dei tuoi giorni mancati.'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cards[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive 
                      ? const Color(0xFFF97316)
                      : context.appColors.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _FailureDetailCard extends StatelessWidget {
  final String title;
  final String worstStreak;
  final String frequency;
  final Color color;

  const _FailureDetailCard({
    required this.title,
    required this.worstStreak,
    required this.frequency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: context.appColors.foreground)),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatMiniItem(label: 'WORST STREAK', value: worstStreak, color: const Color(0xFFEF4444)),
              _StatMiniItem(label: 'FREQUENZA', value: frequency, color: const Color(0xFFF97316)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatternRecuperoSection extends StatefulWidget {
  const _PatternRecuperoSection();

  @override
  State<_PatternRecuperoSection> createState() => _PatternRecuperoSectionState();
}

class _PatternRecuperoSectionState extends State<_PatternRecuperoSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _RecoveryDetailCard(title: 'Fitness', time: '1 gg', color: Theme.of(context).colorScheme.primary, progress: 0.9),
      const _RecoveryDetailCard(title: 'Journaling', time: '1 gg', color: Color(0xFFEAB308), progress: 0.85),
      const _RecoveryDetailCard(title: 'No Fap', time: '1 gg', color: Color(0xFF06B6D4), progress: 0.8),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.calendarClock, size: 16, color: context.appColors.foreground),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Pattern di Recupero'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Quanto velocemente torni in carreggiata dopo un errore.'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),

        // Global recovery stat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appColors.border, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.translate('Tempo Medio Recupero'), style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: context.appColors.mutedForeground)),
              Text('6 ${context.l10n.translate('giorni')}', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w800, color: context.appColors.foreground)),
            ],
          ),
        ),
        
        const SizedBox(height: 16),

        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cards[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive 
                      ? Theme.of(context).colorScheme.primary
                      : context.appColors.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _RecoveryDetailCard extends StatelessWidget {
  final String title;
  final String time;
  final Color color;
  final double progress;

  const _RecoveryDetailCard({
    required this.title,
    required this.time,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: context.appColors.foreground)),
                ],
              ),
              Text(time, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.muted,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMiniItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatMiniItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 8, fontWeight: FontWeight.w800, color: context.appColors.mutedForeground, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

class _ConfrontoPerformanceSection extends StatefulWidget {
  const _ConfrontoPerformanceSection();

  @override
  State<_ConfrontoPerformanceSection> createState() => _ConfrontoPerformanceSectionState();
}

class _ConfrontoPerformanceSectionState extends State<_ConfrontoPerformanceSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _PerformanceComparisonCard(title: '20 Flessioni 4', gap: 0.13, best: 4, worst: 30),
      _PerformanceComparisonCard(title: 'Alimentazione', gap: 0.36, best: 4, worst: 11),
      _PerformanceComparisonCard(title: 'Lettura', gap: 0.60, best: 6, worst: 10),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.trendingUp, size: 16, color: context.appColors.foreground),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Confronto Performance'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Compara le tue migliori performance con le peggiori.'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cards[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive 
                      ? Theme.of(context).colorScheme.primary 
                      : context.appColors.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _PerformanceComparisonCard extends StatelessWidget {
  final String title;
  final double gap;
  final int best;
  final int worst;

  const _PerformanceComparisonCard({
    required this.title,
    required this.gap,
    required this.best,
    required this.worst,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: context.appColors.foreground)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF97316).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(context.l10n.translate('Attenzione'), style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFF97316))),
              ),
            ],
          ),
          const Spacer(),
          _PerformanceBar(label: 'BEST', value: '$best gg', progress: 0.3, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          _PerformanceBar(label: 'WORST', value: '$worst gg', progress: 0.9, color: const Color(0xFFEF4444)),
          const Spacer(),
          RichText(
            text: TextSpan(
              style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: context.appColors.mutedForeground),
              children: [
                const TextSpan(text: 'Gap: '),
                TextSpan(text: '${(gap * 100).toInt()}%', style: TextStyle(color: context.appColors.foreground, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceBar extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _PerformanceBar({required this.label, required this.value, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w800, color: context.appColors.mutedForeground, letterSpacing: 0.5)),
            Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: AppColors.muted,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
