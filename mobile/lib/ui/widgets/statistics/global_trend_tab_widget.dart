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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrendChartSection(),
        const SizedBox(height: 24),
        const _AbitudiniCriticheSection(),
        const SizedBox(height: 24),
        _buildComparisonSection(goals),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTrendChartSection() {
    final List<FlSpot> spots;
    final List<String> dates;
    final double maxX;
    final String title;
    final String percentage;
    final String delta;
    final bool isPositive;

    switch (_chartTimeframe) {
      case 'timeframe_month_short':
        spots = List.generate(30, (i) => FlSpot(i.toDouble(), 60 + (i % 7).toDouble() * 5));
        dates = List.generate(30, (i) => '${(i + 1).toString().padLeft(2, '0')}/04');
        maxX = 29;
        title = 'Mensile';
        percentage = '68.5%';
        delta = '+2.1%';
        isPositive = true;
        break;
      case 'timeframe_year_short':
        spots = List.generate(12, (i) => FlSpot(i.toDouble(), 50 + (i % 4).toDouble() * 10));
        dates = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        maxX = 11;
        title = 'Annuale';
        percentage = '71.2%';
        delta = '+8.4%';
        isPositive = true;
        break;
      case 'timeframe_all':
        spots = List.generate(24, (i) => FlSpot(i.toDouble(), 40 + (i % 6).toDouble() * 8));
        dates = List.generate(24, (i) => 'M$i');
        maxX = 23;
        title = 'Totale';
        percentage = '74.2%';
        delta = '+5.4%';
        isPositive = true;
        break;
      case 'timeframe_week_short':
      default:
        spots = const [FlSpot(0, 40), FlSpot(1, 65), FlSpot(2, 50), FlSpot(3, 85), FlSpot(4, 75), FlSpot(5, 80), FlSpot(6, 95)];
        dates = ['gio', 'ven', 'sab', 'dom', 'lun', 'mar', 'mer'];
        maxX = 6;
        title = 'Settimanale';
        percentage = '74.2%';
        delta = '+5.4%';
        isPositive = true;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassPanelDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.translate('Performance Evolution'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.foreground,
                  letterSpacing: -0.8,
                ),
              ),
              Text(
                '${context.l10n.translate('Trend')} $title',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.mutedForeground,
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
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.foreground,
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
                    color: AppColors.border.withValues(alpha: 0.1),
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
                            style: const TextStyle(
                              color: AppColors.mutedForeground,
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
                              style: const TextStyle(
                                color: AppColors.mutedForeground,
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
                    getTooltipColor: (touchedSpot) => AppColors.card.withValues(alpha: 0.9),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          '${barSpot.y.toStringAsFixed(1)}%',
                          const TextStyle(color: AppColors.foreground, fontWeight: FontWeight.bold, fontSize: 12),
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

  Widget _buildComparisonSection(List<Goal> goals) {
    return _ComparisonCarouselSection(goals: goals, timeframe: _comparisonTimeframe);
  }

  Widget _buildPremiumSelector() {
    final options = ['week', 'month', 'year', 'all'];
    final selectedKey = _chartTimeframe == 'timeframe_week_short' ? 'week' : _chartTimeframe == 'timeframe_month_short' ? 'month' : _chartTimeframe == 'timeframe_year_short' ? 'year' : 'all';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
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
                  context.l10n.translate(opt),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.background : AppColors.mutedForeground,
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

class _ComparisonCarouselSection extends StatefulWidget {
  final List<Goal> goals;
  final String timeframe;

  const _ComparisonCarouselSection({required this.goals, required this.timeframe});

  @override
  State<_ComparisonCarouselSection> createState() => _ComparisonCarouselSectionState();
}

class _ComparisonCarouselSectionState extends State<_ComparisonCarouselSection> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.trendingUp, size: 16, color: AppColors.foreground),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Confronto Temporale'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Analizza come stai andando rispetto al passato.'),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.goals.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final goal = widget.goals[index];
              // Mock data based on goal ID
              final int current = 50 + (goal.id.hashCode % 45);
              final int previous = 40 + (goal.id.hashCode % 35);
              final int delta = current - previous;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _ComparisonCard(goal: goal, current: current, previous: previous, delta: delta),
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.goals.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive 
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.mutedForeground.withValues(alpha: 0.3),
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

class _ComparisonCard extends StatelessWidget {
  final Goal goal;
  final int current;
  final int previous;
  final int delta;

  const _ComparisonCard({
    required this.goal,
    required this.current,
    required this.previous,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPositive = delta >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
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
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: goal.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(goal.title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.foreground)),
                ],
              ),
              Container(
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
                      size: 12,
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}$delta%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ATTUALE', style: TextStyle(fontFamily: 'Inter', fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5)),
                  Text('$current%', style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.foreground)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('PRECEDENTE', style: TextStyle(fontFamily: 'Inter', fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.mutedForeground, letterSpacing: 0.5)),
                  Text('$previous%', style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.mutedForeground)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AbitudiniCriticheSection extends StatefulWidget {
  const _AbitudiniCriticheSection();

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
    final List<Widget> cards = [
      const _CriticaCard(
        title: '20 Flessioni 4',
        drop: '-45%',
        trend: 'trending_down',
        color: Color(0xFFEF4444),
        streak: '30 giorni',
        desc: 'Questa abitudine ha perso il 45% di costanza nell\'ultima settimana. La tua serie negativa più lunga mai registrata.',
      ),
      const _CriticaCard(
        title: '20 Flessioni 3',
        drop: '-28%',
        trend: 'trending_down',
        color: Color(0xFFF97316),
        streak: '17 giorni',
        desc: 'Il trend è in calo costante. Hai saltato 5 delle ultime 7 sessioni programmate.',
      ),
      const _CriticaCard(
        title: 'Journaling',
        drop: '-15%',
        trend: 'trending_down',
        color: Color(0xFFEAB308),
        streak: '8 giorni',
        desc: 'Attenzione al calo di motivazione. Stai perdendo la costanza che avevi costruito nel mese scorso.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.flame, size: 16, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Abitudini Critiche'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Habit che stanno perdendo slancio e richiedono attenzione.'),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: AppColors.mutedForeground,
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
                      : AppColors.mutedForeground.withValues(alpha: 0.3),
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
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
                  Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.foreground)),
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
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.mutedForeground, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.calendarX, size: 14, color: AppColors.mutedForeground),
              const SizedBox(width: 6),
              Text('${context.l10n.translate('Streak Negativa')}: ', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.mutedForeground)),
              Text(streak, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
