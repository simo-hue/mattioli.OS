import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';
import '../../../models/goal.dart';
import '../../../providers/goal_provider.dart';

class GlobalTrendTabWidget extends ConsumerStatefulWidget {
  const GlobalTrendTabWidget({super.key});

  @override
  ConsumerState<GlobalTrendTabWidget> createState() => _GlobalTrendTabWidgetState();
}

class _GlobalTrendTabWidgetState extends ConsumerState<GlobalTrendTabWidget> {
  String _chartTimeframe = 'timeframe_week_short';
  List<Map<String, dynamic>>? _lastValidData;

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    final trendAsync = ref.watch(globalTrendProvider(_chartTimeframe));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        trendAsync.when(
          data: (trendData) {
            _lastValidData = trendData;
            return _buildTrendChartSection(goals, trendData);
          },
          loading: () {
            if (_lastValidData != null) {
              return _buildTrendChartSection(goals, _lastValidData!);
            }
            return Container(
              height: 300,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            );
          },
          error: (err, stack) => Container(
            height: 300,
            alignment: Alignment.center,
            child: Text('${context.l10n.translate('Errore')}: $err', style: TextStyle(color: context.appColors.mutedForeground)),
          ),
        ),
        const SizedBox(height: 24),
        _AbitudiniCriticheSection(goals: goals, logs: logs),
        const SizedBox(height: 24),
        _MiglioriAbitudiniSection(goals: goals, logs: logs, timeframe: _chartTimeframe),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTrendChartSection(List<Goal> goals, List<Map<String, dynamic>> trendData) {
    final List<FlSpot> spots = [];
    final List<String> dates = [];
    final double maxX;
    final String title;
    final String percentage;
    final String delta;
    final bool isPositive;

    if (trendData.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_chartTimeframe == 'timeframe_all') {
      for (int i = 0; i < trendData.length; i++) {
        final item = trendData[i];
        final rate = (item['rate'] as num?)?.toDouble() ?? 100.0;
        spots.add(FlSpot(i.toDouble(), rate));
        final date = DateTime.parse(item['date'] as String);
        dates.add('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}');
      }
      maxX = spots.isNotEmpty ? (spots.length - 1).toDouble() : 0;
      title = 'Totale';
      percentage = spots.isNotEmpty 
          ? '${(spots.map((e) => e.y).reduce((a, b) => a + b) / spots.length).toStringAsFixed(1)}%' 
          : '100%';
      delta = 'N/A';
      isPositive = true;
    } else {
      final halfLength = trendData.length ~/ 2;
      final previous = trendData.sublist(0, halfLength);
      final current = trendData.sublist(halfLength);

      final currentAvg = current.isEmpty ? 100.0 : current.map((e) => (e['rate'] as num?)?.toDouble() ?? 100.0).reduce((a, b) => a + b) / current.length;
      final prevAvg = previous.isEmpty ? 100.0 : previous.map((e) => (e['rate'] as num?)?.toDouble() ?? 100.0).reduce((a, b) => a + b) / previous.length;
      
      final deltaValue = currentAvg - prevAvg;
      delta = '${deltaValue >= 0 ? '+' : ''}${deltaValue.toStringAsFixed(1)}%';
      isPositive = deltaValue >= 0;
      percentage = '${currentAvg.toStringAsFixed(1)}%';

      if (_chartTimeframe == 'timeframe_year_short') {
        final now = DateTime.now();
        final List<double> rates = List.filled(12, 100.0);
        final List<String> monthLabels = [];
        final monthsIT = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
        
        for (int i = 11; i >= 0; i--) {
          final date = DateTime(now.year, now.month - i, 1);
          monthLabels.add(monthsIT[date.month - 1]);
        }
        
        for (final item in trendData) {
          final date = DateTime.parse(item['date'] as String);
          final rate = (item['rate'] as num?)?.toDouble() ?? 100.0;
          
          final diffMonths = (now.year - date.year) * 12 + (now.month - date.month);
          if (diffMonths >= 0 && diffMonths < 12) {
            final index = 11 - diffMonths;
            rates[index] = rate;
          }
        }
        
        for (int i = 0; i < 12; i++) {
          spots.add(FlSpot(i.toDouble(), rates[i]));
          dates.add(monthLabels[i]);
        }
        maxX = 11;
      } else {
        final displayData = current;

        for (int i = 0; i < displayData.length; i++) {
          final item = displayData[i];
          final rate = (item['rate'] as num?)?.toDouble() ?? 100.0;
          spots.add(FlSpot(i.toDouble(), rate));
          
          final date = DateTime.parse(item['date'] as String);
          if (_chartTimeframe == 'timeframe_week_short') {
            final weekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
            dates.add(weekDays[date.weekday - 1]);
          } else {
            dates.add('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}');
          }
        }

        maxX = displayData.isNotEmpty ? (displayData.length - 1).toDouble() : 0;
      }
      title = _chartTimeframe == 'timeframe_week_short' ? 'Settimanale' : _chartTimeframe == 'timeframe_month_short' ? 'Mensile' : 'Annuale';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassPanelDecoration(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.translate('Performance Evolution'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: context.appColors.foreground,
                  letterSpacing: -0.8,
                ),
              ),
              Text(
                '${context.l10n.translate('Trend')} $title',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: context.appColors.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPremiumSelector(),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                percentage,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: context.appColors.foreground,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              if (_chartTimeframe != 'timeframe_all') ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                          size: 14,
                          color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          delta,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.appColors.border.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              color: context.appColors.mutedForeground,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: _chartTimeframe == 'timeframe_week_short' ? 1 : _chartTimeframe == 'timeframe_month_short' ? 6 : 3,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < dates.length && value.toInt() >= 0) {
                          final String label = _chartTimeframe == 'timeframe_week_short' 
                              ? context.l10n.translate(dates[value.toInt()]).toLowerCase()
                              : dates[value.toInt()];
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: context.appColors.mutedForeground,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: _chartTimeframe == 'timeframe_week_short',
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => context.appColors.card.withValues(alpha: 0.9),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          '${barSpot.y.toStringAsFixed(1)}%',
                          TextStyle(color: context.appColors.foreground, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 350),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildPremiumSelector() {
    final options = ['week', 'month', 'year', 'all'];
    final selectedKey = _chartTimeframe == 'timeframe_week_short' ? 'week' : _chartTimeframe == 'timeframe_month_short' ? 'month' : _chartTimeframe == 'timeframe_year_short' ? 'year' : 'all';

    final Map<String, String> italianLabels = {
      'week': 'Settimana',
      'month': 'Mese',
      'year': 'Anno',
      'all': 'Tutto',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = selectedKey == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    if (opt == 'week') {
                      _chartTimeframe = 'timeframe_week_short';
                    } else if (opt == 'month') {
                      _chartTimeframe = 'timeframe_month_short';
                    } else if (opt == 'year') {
                      _chartTimeframe = 'timeframe_year_short';
                    } else {
                      _chartTimeframe = 'timeframe_all';
                    }
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected 
                      ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))] 
                      : null,
                ),
                child: Text(
                  italianLabels[opt] ?? opt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? context.appColors.background : context.appColors.mutedForeground,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MiglioriAbitudiniSection extends ConsumerStatefulWidget {
  final List<Goal> goals;
  final Map<String, Map<String, String>> logs;
  final String timeframe;
  const _MiglioriAbitudiniSection({required this.goals, required this.logs, required this.timeframe});

  @override
  ConsumerState<_MiglioriAbitudiniSection> createState() => _MiglioriAbitudiniSectionState();
}

class _MiglioriAbitudiniSectionState extends ConsumerState<_MiglioriAbitudiniSection> {
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
    final bestHabitsAsync = ref.watch(bestHabitsProvider(widget.timeframe));

    return bestHabitsAsync.when(
      data: (data) {
        final List<Map<String, dynamic>> bestHabits = [];
        for (final item in data) {
          final goalId = item['goal_id'] as String;
          if (widget.goals.any((g) => g.id == goalId)) {
            final habit = widget.goals.firstWhere((g) => g.id == goalId);
            bestHabits.add({
              'habit': habit,
              'rate': (item['rate'] as num?)?.toDouble() ?? 0.0,
              'streak': (item['streak'] as num?)?.toInt() ?? 0,
            });
          }
        }

        final List<Widget> cards = bestHabits.isEmpty
            ? [
                _MiglioreCard(
                  title: context.l10n.translate('Tutto alla grande!'),
                  rate: '100%',
                  color: Color(0xFF10B981),
                  streak: '0 giorni',
                  desc: 'Tutte le tue abitudini stanno mantenendo o migliorando il loro trend! Continua così!',
                )
              ]
            : bestHabits.take(3).map((item) {
                final habit = item['habit'] as Goal;
                final rate = item['rate'] as double;
                
                return _MiglioreCard(
                  title: habit.title,
                  rate: '${(rate * 100).toStringAsFixed(0)}%',
                  color: const Color(0xFF10B981),
                  streak: '${item['streak']} giorni',
                  desc: 'Hai completato questa abitudine il ${(rate * 100).toStringAsFixed(0)}% delle volte nel periodo selezionato.',
                );
              }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.trophy, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(
                  'Abitudini Migliori',
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
              'Le abitudini in cui sei più costante.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: context.appColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              height: 180,
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
                          ? const Color(0xFF10B981)
                          : context.appColors.mutedForeground.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => SizedBox(
        height: 200,
        child: Center(child: Text('${context.l10n.translate('Errore')}: $err', style: TextStyle(color: context.appColors.mutedForeground))),
      ),
    );
  }
}

class _MiglioreCard extends StatelessWidget {
  final String title;
  final String rate;
  final Color color;
  final String streak;
  final String desc;

  const _MiglioreCard({
    required this.title,
    required this.rate,
    required this.color,
    required this.streak,
    required this.desc,
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
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: context.appColors.foreground)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.trendingUp, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(rate, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: context.appColors.mutedForeground, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.flame, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text('${context.l10n.translate('Serie Attuale')}: ', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: context.appColors.mutedForeground)),
              Text(streak, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AbitudiniCriticheSection extends ConsumerStatefulWidget {
  final List<Goal> goals;
  final Map<String, Map<String, String>> logs;
  const _AbitudiniCriticheSection({required this.goals, required this.logs});

  @override
  ConsumerState<_AbitudiniCriticheSection> createState() => _AbitudiniCriticheSectionState();
}

class _AbitudiniCriticheSectionState extends ConsumerState<_AbitudiniCriticheSection> {
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
    final criticalHabitsAsync = ref.watch(criticalHabitsProvider);

    return criticalHabitsAsync.when(
      data: (data) {
        final List<Map<String, dynamic>> criticalHabits = [];
        for (final item in data) {
          final goalId = item['goal_id'] as String;
          if (widget.goals.any((g) => g.id == goalId)) {
            final habit = widget.goals.firstWhere((g) => g.id == goalId);
            criticalHabits.add({
              'habit': habit,
              'drop': (item['drop'] as num?)?.toDouble() ?? 0.0,
              'negStreak': (item['neg_streak'] as num?)?.toInt() ?? 0,
            });
          }
        }

        final List<Widget> cards = criticalHabits.isEmpty
            ? [
                _CriticaCard(
                  title: context.l10n.translate('Tutto alla grande!'),
                  drop: '0%',
                  trend: 'trending_up',
                  color: Color(0xFF10B981),
                  streak: '0 giorni',
                  desc: 'Tutte le tue abitudini stanno mantenendo o migliorando il loro trend! Continua così!',
                )
              ]
            : criticalHabits.take(3).map((item) {
                final habit = item['habit'] as Goal;
                final drop = item['drop'] as double;
                final negStreak = item['negStreak'] as int;
                
                return _CriticaCard(
                  title: habit.title,
                  drop: '-${drop.toStringAsFixed(0)}%',
                  trend: 'trending_down',
                  color: drop > 30 ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                  streak: '$negStreak giorni',
                  desc: 'Questa abitudine ha perso il ${drop.toStringAsFixed(0)}% di costanza nell\'ultima settimana rispetto alla precedente.',
                );
              }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.flame, size: 16, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Text(
                  context.l10n.translate('Abitudini Critiche'),
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
              'Le abitudini che stanno peggiorando di più.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: context.appColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              height: 180,
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
                          ? const Color(0xFFEF4444)
                          : context.appColors.mutedForeground.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => SizedBox(
        height: 200,
        child: Center(child: Text('${context.l10n.translate('Errore')}: $err', style: TextStyle(color: context.appColors.mutedForeground))),
      ),
    );
  }
}

class _CriticaCard extends StatelessWidget {
  final String title;
  final String drop;
  final String trend;
  final Color color;
  final String streak;
  final String desc;

  const _CriticaCard({
    required this.title,
    required this.drop,
    required this.trend,
    required this.color,
    required this.streak,
    required this.desc,
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
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: context.appColors.foreground)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.trendingDown, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(drop, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: context.appColors.mutedForeground, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.calendarX, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text('${context.l10n.translate('Streak Negativa')}: ', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: context.appColors.mutedForeground)),
              Text(streak, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
