import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';
import '../../../providers/goal_provider.dart';
import '../../../models/goal.dart';

class MiglioramentoData {
  final String title;
  final String successRate;
  final String day;
  final String dayCompletion;
  final Color color;

  MiglioramentoData({
    required this.title,
    required this.successRate,
    required this.day,
    required this.dayCompletion,
    required this.color,
  });
}

class FallimentiData {
  final String title;
  final String worstStreak;
  final String frequency;
  final Color color;

  FallimentiData({
    required this.title,
    required this.worstStreak,
    required this.frequency,
    required this.color,
  });
}

class RecuperoSectionData {
  final String avgGlobalRecovery;
  final List<RecuperoData> items;

  RecuperoSectionData({
    required this.avgGlobalRecovery,
    required this.items,
  });
}

class RecuperoData {
  final String title;
  final String time;
  final Color color;
  final double progress;

  RecuperoData({
    required this.title,
    required this.time,
    required this.color,
    required this.progress,
  });
}

class ConfrontoData {
  final String title;
  final double gap;
  final int best;
  final int worst;

  ConfrontoData({
    required this.title,
    required this.gap,
    required this.best,
    required this.worst,
  });
}

class GlobalAlertsTabWidget extends ConsumerWidget {
  const GlobalAlertsTabWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(habitStatsProvider);
    final analyticsAsync = ref.watch(habitAnalyticsProvider);
    final goals = ref.watch(goalsProvider);

    return statsAsync.when(
      data: (stats) {
        return analyticsAsync.when(
          data: (analytics) {
            final miglioramentoData = _calculateMiglioramentoData(stats, goals, analytics, context);
            final fallimentiData = _calculateFallimentiData(stats, goals);
            final recuperoData = _calculateRecuperoData(stats, goals, analytics, context);
            final confrontoData = _calculateConfrontoData(stats, goals);

            if (miglioramentoData.isEmpty && fallimentiData.isEmpty && recuperoData.items.isEmpty && confrontoData.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    context.l10n.translate('Nessun dato sufficiente per generare alert.'),
                    style: TextStyle(color: context.appColors.mutedForeground),
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (miglioramentoData.isNotEmpty) ...[
                  _AreeMiglioramentoSection(data: miglioramentoData),
                  const SizedBox(height: 24),
                ],
                if (fallimentiData.isNotEmpty) ...[
                  _AnalisiFallimentiSection(data: fallimentiData),
                  const SizedBox(height: 24),
                ],
                if (recuperoData.items.isNotEmpty) ...[
                  _PatternRecuperoSection(data: recuperoData),
                  const SizedBox(height: 24),
                ],
                if (confrontoData.isNotEmpty) ...[
                  _ConfrontoPerformanceSection(data: confrontoData),
                  const SizedBox(height: 40),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: context.appColors.mutedForeground))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: context.appColors.mutedForeground))),
    );
  }

  List<MiglioramentoData> _calculateMiglioramentoData(List<Map<String, dynamic>> stats, List<Goal> goals, Map<String, Map<String, dynamic>> analytics, BuildContext context) {
    final sortedStats = List<Map<String, dynamic>>.from(stats)
      ..sort((a, b) => (a['rate'] as num? ?? 0).compareTo(b['rate'] as num? ?? 0));
    
    final worstStats = sortedStats.take(3).toList();
    final List<MiglioramentoData> result = [];

    for (final stat in worstStats) {
      final goalId = stat['goal_id'] as String;
      final goal = goals.where((g) => g.id == goalId).firstOrNull;
      if (goal == null) continue;

      final analytic = analytics[goalId];
      final worstDow = analytic?['worst_dow'] as int? ?? 1;
      final dayName = _getDayName(worstDow, context);

      result.add(MiglioramentoData(
        title: goal.title,
        successRate: '${(stat['rate'] as num? ?? 0).round()}%',
        day: dayName,
        dayCompletion: '', // Not returned by RPC for simplicity
        color: goal.color,
      ));
    }
    return result;
  }

  String _getDayName(int dow, BuildContext context) {
    switch (dow) {
      case 1: return context.l10n.translate('Lunedì');
      case 2: return context.l10n.translate('Martedì');
      case 3: return context.l10n.translate('Mercoledì');
      case 4: return context.l10n.translate('Giovedì');
      case 5: return context.l10n.translate('Venerdì');
      case 6: return context.l10n.translate('Sabato');
      case 7: return context.l10n.translate('Domenica');
      default: return '';
    }
  }

  List<FallimentiData> _calculateFallimentiData(List<Map<String, dynamic>> stats, List<Goal> goals) {
    final sortedStats = List<Map<String, dynamic>>.from(stats)
      ..sort((a, b) => (b['worst_streak'] as int? ?? 0).compareTo(a['worst_streak'] as int? ?? 0));
    
    final worstStats = sortedStats.take(3).toList();
    final List<FallimentiData> result = [];

    for (final stat in worstStats) {
      final goalId = stat['goal_id'] as String;
      final goal = goals.where((g) => g.id == goalId).firstOrNull;
      if (goal == null) continue;

      final missedDays = stat['missed_days'] as int? ?? 0;
      final totalDays = stat['total_active_days'] as int? ?? 1;
      final freq = totalDays > 0 ? (missedDays / totalDays * 30).round() : 0;

      result.add(FallimentiData(
        title: goal.title,
        worstStreak: '${stat['worst_streak'] ?? 0} gg',
        frequency: '~$freq/mese',
        color: goal.color,
      ));
    }
    return result;
  }

  RecuperoSectionData _calculateRecuperoData(List<Map<String, dynamic>> stats, List<Goal> goals, Map<String, Map<String, dynamic>> analytics, BuildContext context) {
    final List<RecuperoData> items = [];
    num totalGlobalRecovery = 0;
    int globalCount = 0;

    for (final goal in goals) {
      final analytic = analytics[goal.id];
      final avgRecovery = analytic?['avg_recovery_days'] as num? ?? 0;
      totalGlobalRecovery += avgRecovery;
      globalCount++;

      final progress = avgRecovery > 0 ? 1.0 / avgRecovery : 1.0;

      items.add(RecuperoData(
        title: goal.title,
        time: '${avgRecovery.round()} gg',
        color: goal.color,
        progress: progress.clamp(0.0, 1.0),
      ));
    }

    items.sort((a, b) => a.time.compareTo(b.time));

    final avgGlobal = globalCount > 0 ? (totalGlobalRecovery / globalCount).round() : 0;

    return RecuperoSectionData(
      avgGlobalRecovery: '$avgGlobal ${context.l10n.translate('giorni')}',
      items: items.take(3).toList(),
    );
  }



  List<ConfrontoData> _calculateConfrontoData(List<Map<String, dynamic>> stats, List<Goal> goals) {
    final List<ConfrontoData> result = [];

    for (final stat in stats) {
      final goalId = stat['goal_id'] as String;
      final goal = goals.where((g) => g.id == goalId).firstOrNull;
      if (goal == null) continue;

      final best = stat['best_streak'] as int? ?? 0;
      final worst = stat['worst_streak'] as int? ?? 0;
      final gap = best > 0 ? (best - worst) / best : 0.0;

      result.add(ConfrontoData(
        title: goal.title,
        gap: gap.clamp(0.0, 1.0),
        best: best,
        worst: worst,
      ));
    }

    result.sort((a, b) => b.gap.compareTo(a.gap));

    return result.take(3).toList();
  }
}

class _AreeMiglioramentoSection extends StatefulWidget {
  final List<MiglioramentoData> data;
  const _AreeMiglioramentoSection({required this.data});

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
    final List<Widget> cards = widget.data.map((d) => _MiglioramentoCard(
      title: d.title,
      successRate: d.successRate,
      day: d.day,
      dayCompletion: d.dayCompletion,
      color: d.color,
    )).toList();

    if (cards.isEmpty) return const SizedBox.shrink();

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
                    if (dayCompletion.isNotEmpty) ...[
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
  final List<FallimentiData> data;
  const _AnalisiFallimentiSection({required this.data});

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
    final List<Widget> cards = widget.data.map((d) => _FailureDetailCard(
      title: d.title,
      worstStreak: d.worstStreak,
      frequency: d.frequency,
      color: d.color,
    )).toList();

    if (cards.isEmpty) return const SizedBox.shrink();

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
  final RecuperoSectionData data;
  const _PatternRecuperoSection({required this.data});

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
    final List<Widget> cards = widget.data.items.map((d) => _RecoveryDetailCard(
      title: d.title,
      time: d.time,
      color: d.color,
      progress: d.progress,
    )).toList();

    if (cards.isEmpty) return const SizedBox.shrink();

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
              Text(widget.data.avgGlobalRecovery, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w800, color: context.appColors.foreground)),
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
  final List<ConfrontoData> data;
  const _ConfrontoPerformanceSection({required this.data});

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
    final List<Widget> cards = widget.data.map((d) => _PerformanceComparisonCard(
      title: d.title,
      gap: d.gap,
      best: d.best,
      worst: d.worst,
    )).toList();

    if (cards.isEmpty) return const SizedBox.shrink();

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
