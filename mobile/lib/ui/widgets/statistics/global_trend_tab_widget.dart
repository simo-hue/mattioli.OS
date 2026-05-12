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
  String _comparisonTimeframe = 'timeframe_week_short';

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrendChartSection(goals, logs),
        const SizedBox(height: 24),
        _AbitudiniCriticheSection(goals: goals, logs: logs),
        const SizedBox(height: 24),
        _MiglioriAbitudiniSection(goals: goals, logs: logs),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTrendChartSection(List<Goal> goals, Map<String, Map<String, String>> logs) {
    final List<FlSpot> spots;
    final List<String> dates;
    final double maxX;
    final String title;
    final String percentage;
    final String delta;
    final bool isPositive;

    switch (_chartTimeframe) {
      case 'timeframe_month_short':
        spots = [];
        dates = [];
        final today = DateTime.now();
        double totalPercentage = 0;
        
        for (int i = 29; i >= 0; i--) {
          final date = today.subtract(Duration(days: i));
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final dayLogs = logs[dateKey] ?? {};
          
          int activeCount = 0;
          int doneCount = 0;
          
          for (final habit in goals) {
            if (habit.isActiveOn(date)) {
              activeCount++;
              if (dayLogs[habit.id] == 'done') {
                doneCount++;
              }
            }
          }
          
          final dayPercentage = activeCount > 0 ? (doneCount / activeCount) * 100 : 100.0;
          spots.add(FlSpot((29 - i).toDouble(), dayPercentage));
          dates.add('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}');
          totalPercentage += dayPercentage;
        }
        
        maxX = 29;
        title = 'Mensile';
        percentage = '${(totalPercentage / 30).toStringAsFixed(1)}%';
        
        // Calcola il delta con i 30 giorni precedenti
        double prevTotalPercentage = 0;
        for (int i = 59; i >= 30; i--) {
          final date = today.subtract(Duration(days: i));
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final dayLogs = logs[dateKey] ?? {};
          
          int activeCount = 0;
          int doneCount = 0;
          
          for (final habit in goals) {
            if (habit.isActiveOn(date)) {
              activeCount++;
              if (dayLogs[habit.id] == 'done') {
                doneCount++;
              }
            }
          }
          prevTotalPercentage += activeCount > 0 ? (doneCount / activeCount) * 100 : 100.0;
        }
        
        final currentAvg = totalPercentage / 30;
        final prevAvg = prevTotalPercentage / 30;
        final deltaValue = currentAvg - prevAvg;
        
        delta = '${deltaValue >= 0 ? '+' : ''}${deltaValue.toStringAsFixed(1)}%';
        isPositive = deltaValue >= 0;
        break;
      case 'timeframe_year_short':
        spots = [];
        dates = [];
        final today = DateTime.now();
        final monthsIT = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
        double totalPercentage = 0;
        
        for (int i = 11; i >= 0; i--) {
          final date = DateTime(today.year, today.month - i, 1);
          final monthIndex = (date.month - 1) % 12;
          
          final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
          double monthSum = 0;
          int daysCount = 0;
          
          for (int d = 1; d <= daysInMonth; d++) {
            final checkDate = DateTime(date.year, date.month, d);
            if (checkDate.isAfter(today)) break;
            
            final dateKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
            final dayLogs = logs[dateKey] ?? {};
            
            int activeCount = 0;
            int doneCount = 0;
            
            for (final habit in goals) {
              if (habit.isActiveOn(checkDate)) {
                activeCount++;
                if (dayLogs[habit.id] == 'done') {
                  doneCount++;
                }
              }
            }
            monthSum += activeCount > 0 ? (doneCount / activeCount) * 100 : 100.0;
            daysCount++;
          }
          
          final monthAvg = daysCount > 0 ? monthSum / daysCount : 100.0;
          spots.add(FlSpot((11 - i).toDouble(), monthAvg));
          dates.add(monthsIT[monthIndex]);
          totalPercentage += monthAvg;
        }
        
        maxX = 11;
        title = 'Annuale';
        percentage = '${(totalPercentage / 12).toStringAsFixed(1)}%';
        
        // Calcola il delta con i 12 mesi precedenti
        double prevTotalPercentage = 0;
        for (int i = 23; i >= 12; i--) {
          final date = DateTime(today.year, today.month - i, 1);
          final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
          double monthSum = 0;
          int daysCount = 0;
          
          for (int d = 1; d <= daysInMonth; d++) {
            final checkDate = DateTime(date.year, date.month, d);
            final dateKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
            final dayLogs = logs[dateKey] ?? {};
            
            int activeCount = 0;
            int doneCount = 0;
            
            for (final habit in goals) {
              if (habit.isActiveOn(checkDate)) {
                activeCount++;
                if (dayLogs[habit.id] == 'done') {
                  doneCount++;
                }
              }
            }
            monthSum += activeCount > 0 ? (doneCount / activeCount) * 100 : 100.0;
            daysCount++;
          }
          prevTotalPercentage += daysCount > 0 ? monthSum / daysCount : 100.0;
        }
        
        final currentAvg = totalPercentage / 12;
        final prevAvg = prevTotalPercentage / 12;
        final deltaValue = currentAvg - prevAvg;
        
        delta = '${deltaValue >= 0 ? '+' : ''}${deltaValue.toStringAsFixed(1)}%';
        isPositive = deltaValue >= 0;
        break;
      case 'timeframe_all':
        spots = [];
        dates = [];
        final today = DateTime.now();
        
        DateTime earliest = today;
        for (final habit in goals) {
          if (habit.startDate.isBefore(earliest)) {
            earliest = habit.startDate;
          }
        }
        
        final totalDays = today.difference(earliest).inDays;
        final interval = totalDays > 10 ? (totalDays / 10).ceil() : 1;
        final pointsCount = totalDays > 10 ? 10 : totalDays + 1;
        
        double totalPercentage = 0;
        
        for (int i = 0; i < pointsCount; i++) {
          final date = earliest.add(Duration(days: i * interval));
          if (date.isAfter(today)) break;
          
          double sum = 0;
          int count = 0;
          
          for (int d = 0; d < interval; d++) {
            final checkDate = date.add(Duration(days: d));
            if (checkDate.isAfter(today)) break;
            
            final dateKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
            final dayLogs = logs[dateKey] ?? {};
            
            int activeCount = 0;
            int doneCount = 0;
            
            for (final habit in goals) {
              if (habit.isActiveOn(checkDate)) {
                activeCount++;
                if (dayLogs[habit.id] == 'done') {
                  doneCount++;
                }
              }
            }
            sum += activeCount > 0 ? (doneCount / activeCount) * 100 : 100.0;
            count++;
          }
          
          final avg = count > 0 ? sum / count : 100.0;
          spots.add(FlSpot(i.toDouble(), avg));
          dates.add('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}');
          totalPercentage += avg;
        }
        
        maxX = spots.isNotEmpty ? (spots.length - 1).toDouble() : 0;
        title = 'Totale';
        percentage = spots.isNotEmpty ? '${(totalPercentage / spots.length).toStringAsFixed(1)}%' : '100%';
        delta = 'N/A';
        isPositive = true;
        break;
      case 'timeframe_week_short':
      default:
        spots = [];
        dates = [];
        final today = DateTime.now();
        final weekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
        double totalPercentage = 0;
        
        // Calcola i dati per gli ultimi 7 giorni
        for (int i = 6; i >= 0; i--) {
          final date = today.subtract(Duration(days: i));
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final dayLogs = logs[dateKey] ?? {};
          
          int activeCount = 0;
          int doneCount = 0;
          
          for (final habit in goals) {
            if (habit.isActiveOn(date)) {
              activeCount++;
              if (dayLogs[habit.id] == 'done') {
                doneCount++;
              }
            }
          }
          
          final dayPercentage = activeCount > 0 ? (doneCount / activeCount) * 100 : 100.0;
          spots.add(FlSpot((6 - i).toDouble(), dayPercentage));
          dates.add(weekDays[date.weekday - 1]);
          totalPercentage += dayPercentage;
        }
        
        maxX = 6;
        title = 'Settimanale';
        percentage = '${(totalPercentage / 7).toStringAsFixed(1)}%';
        
        // Calcola il delta con la settimana precedente (giorni da -13 a -7)
        double prevTotalPercentage = 0;
        for (int i = 13; i >= 7; i--) {
          final date = today.subtract(Duration(days: i));
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final dayLogs = logs[dateKey] ?? {};
          
          int activeCount = 0;
          int doneCount = 0;
          
          for (final habit in goals) {
            if (habit.isActiveOn(date)) {
              activeCount++;
              if (dayLogs[habit.id] == 'done') {
                doneCount++;
              }
            }
          }
          prevTotalPercentage += activeCount > 0 ? (doneCount / activeCount) * 100 : 100.0;
        }
        
        final currentAvg = totalPercentage / 7;
        final prevAvg = prevTotalPercentage / 7;
        final deltaValue = currentAvg - prevAvg;
        
        delta = '${deltaValue >= 0 ? '+' : ''}${deltaValue.toStringAsFixed(1)}%';
        isPositive = deltaValue >= 0;
        break;
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
                    if (opt == 'week') _chartTimeframe = 'timeframe_week_short';
                    else if (opt == 'month') _chartTimeframe = 'timeframe_month_short';
                    else if (opt == 'year') _chartTimeframe = 'timeframe_year_short';
                    else _chartTimeframe = 'timeframe_all';
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

class _MiglioriAbitudiniSection extends StatefulWidget {
  final List<Goal> goals;
  final Map<String, Map<String, String>> logs;
  const _MiglioriAbitudiniSection({required this.goals, required this.logs});

  @override
  State<_MiglioriAbitudiniSection> createState() => _MiglioriAbitudiniSectionState();
}

class _MiglioriAbitudiniSectionState extends State<_MiglioriAbitudiniSection> {
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
    final List<Map<String, dynamic>> bestHabits = [];
    final today = DateTime.now();
    
    for (final habit in widget.goals) {
      int activeCount = 0;
      int doneCount = 0;
      for (int i = 6; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        if (habit.isActiveOn(date)) {
          activeCount++;
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          if (widget.logs[dateKey]?[habit.id] == 'done') {
            doneCount++;
          }
        }
      }
      final rate = activeCount > 0 ? doneCount / activeCount : 0.0;
      
      int currentStreak = 0;
      DateTime checkDate = today;
      while (true) {
        final dateKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        if (widget.logs[dateKey]?[habit.id] == 'done') {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          if (checkDate == today) {
            checkDate = checkDate.subtract(const Duration(days: 1));
            continue;
          }
          break;
        }
      }

      if (rate > 0) {
        bestHabits.add({
          'habit': habit,
          'rate': rate,
          'streak': currentStreak,
        });
      }
    }
    
    bestHabits.sort((a, b) => b['rate'].compareTo(a['rate']));
    
    final List<Widget> cards = bestHabits.isEmpty
        ? [
            const _MiglioreCard(
              title: 'Tutto alla grande!',
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
              desc: 'Hai completato questa abitudine il ${(rate * 100).toStringAsFixed(0)}% delle volte nell\'ultima settimana.',
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

class _AbitudiniCriticheSection extends StatefulWidget {
  final List<Goal> goals;
  final Map<String, Map<String, String>> logs;
  const _AbitudiniCriticheSection({required this.goals, required this.logs});

  @override
  State<_AbitudiniCriticheSection> createState() => _AbitudiniCriticheSectionState();
}

class _AbitudiniCriticheSectionState extends State<_AbitudiniCriticheSection> {
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
    final List<Map<String, dynamic>> criticalHabits = [];
    final today = DateTime.now();
    
    for (final habit in widget.goals) {
      int currentActive = 0;
      int currentDone = 0;
      for (int i = 6; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        if (habit.isActiveOn(date)) {
          currentActive++;
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          if (widget.logs[dateKey]?[habit.id] == 'done') {
            currentDone++;
          }
        }
      }
      final currentRate = currentActive > 0 ? currentDone / currentActive : 1.0;
      
      int prevActive = 0;
      int prevDone = 0;
      for (int i = 13; i >= 7; i--) {
        final date = today.subtract(Duration(days: i));
        if (habit.isActiveOn(date)) {
          prevActive++;
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          if (widget.logs[dateKey]?[habit.id] == 'done') {
            prevDone++;
          }
        }
      }
      final prevRate = prevActive > 0 ? prevDone / prevActive : 1.0;
      
      final drop = currentRate - prevRate;
      
      if (drop < 0) {
        final dropPercentage = (drop * 100).abs();
        
        int negStreak = 0;
        DateTime checkDate = today;
        while (true) {
          final dk = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
          if (widget.logs[dk]?[habit.id] == 'missed') {
            negStreak++;
          } else if (widget.logs[dk]?[habit.id] == 'done') {
            break;
          }
          checkDate = checkDate.subtract(const Duration(days: 1));
          if (checkDate.isBefore(habit.startDate)) break;
        }
        
        criticalHabits.add({
          'habit': habit,
          'drop': dropPercentage,
          'negStreak': negStreak,
        });
      }
    }
    
    criticalHabits.sort((a, b) => b['drop'].compareTo(a['drop']));
    
    final List<Widget> cards = criticalHabits.isEmpty
        ? [
            const _CriticaCard(
              title: 'Tutto alla grande!',
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
          context.l10n.translate('Habit che stanno perdendo slancio e richiedono attenzione.'),
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
