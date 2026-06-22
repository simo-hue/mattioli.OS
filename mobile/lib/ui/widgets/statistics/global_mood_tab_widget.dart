import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../../providers/mood_provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../models/goal.dart';
import '../../../i18n/translations.g.dart';

class MoodChartWindow {
  final DateTime startDate;
  final int dayCount;
  final double labelInterval;

  const MoodChartWindow({
    required this.startDate,
    required this.dayCount,
    required this.labelInterval,
  });

  double get minX => dayCount == 1 ? -1 : 0;

  double get maxX => (dayCount - 1).toDouble();

  DateTime dateAt(double x) {
    return startDate.add(Duration(days: x.toInt()));
  }

  static MoodChartWindow resolve({
    required DateTime now,
    required int selectedDays,
    required Iterable<String> moodDateKeys,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final defaultStartDate = today.subtract(Duration(days: selectedDays - 1));
    final moodDatesInRange =
        moodDateKeys
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .map((date) => DateTime(date.year, date.month, date.day))
            .where(
              (date) =>
                  !date.isBefore(defaultStartDate) && !date.isAfter(today),
            )
            .toList()
          ..sort();

    final startDate = moodDatesInRange.isEmpty
        ? defaultStartDate
        : moodDatesInRange.first;
    final dayCount = today.difference(startDate).inDays + 1;

    return MoodChartWindow(
      startDate: startDate,
      dayCount: dayCount,
      labelInterval: _labelIntervalFor(dayCount),
    );
  }

  static double _labelIntervalFor(int dayCount) {
    if (dayCount <= 7) return 1;
    if (dayCount <= 14) return 2;
    if (dayCount <= 30) return 5;
    return 15;
  }
}

class GlobalMoodTabWidget extends ConsumerStatefulWidget {
  const GlobalMoodTabWidget({super.key});

  @override
  ConsumerState<GlobalMoodTabWidget> createState() =>
      _GlobalMoodTabWidgetState();
}

class _GlobalMoodTabWidgetState extends ConsumerState<GlobalMoodTabWidget> {
  String _timeRange = 'time_range_14d';

  @override
  Widget build(BuildContext context) {
    final moods = ref.watch(dailyMoodsProvider);
    final correlations = ref.watch(moodCorrelationProvider);
    final goals = ref.watch(goalsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildMainChart(moods),
        const SizedBox(height: 24),
        _MoodSensitiveSection(correlations: correlations, goals: goals),
        const SizedBox(height: 24),
        _ResilientHabitsSection(correlations: correlations, goals: goals),
        const SizedBox(height: 24),
        _CorrelazioneMoodSection(correlations: correlations, goals: goals),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t.statistics.moodEnergy,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.appColors.foreground,
          ),
        ),
        Text(
          context.t.statistics.psychophysicalWellBeingAnalysis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: context.appColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    final options = [
      {'key': 'time_range_14d', 'label': '14D'},
      {'key': 'time_range_30d', 'label': '30D'},
      {'key': 'time_range_90d', 'label': '90D'},
    ];

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
          final isSelected = _timeRange == opt['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _timeRange = opt['key']!;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  opt['label']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? context.appColors.background
                        : context.appColors.mutedForeground,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainChart(DailyMoodsMap moods) {
    final List<FlSpot> moodSpots = [];
    final List<FlSpot> energySpots = [];

    final now = DateTime.now();
    final selectedDays = switch (_timeRange) {
      'time_range_30d' => 30,
      'time_range_90d' => 90,
      _ => 14,
    };

    final chartWindow = MoodChartWindow.resolve(
      now: now,
      selectedDays: selectedDays,
      moodDateKeys: moods.keys,
    );

    for (int i = 0; i < chartWindow.dayCount; i++) {
      final date = chartWindow.startDate.add(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      if (moods.containsKey(dateKey)) {
        final mood = moods[dateKey]!;
        moodSpots.add(FlSpot(i.toDouble(), mood.moodScore.toDouble()));
        energySpots.add(FlSpot(i.toDouble(), mood.energyScore.toDouble()));
      }
    }

    // If no data, add some empty spots to avoid crash
    final hasMoodData = moodSpots.isNotEmpty;

    if (!hasMoodData) moodSpots.add(const FlSpot(0, 0));
    if (energySpots.isEmpty) energySpots.add(const FlSpot(0, 0));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassPanelDecoration(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeRangeSelector(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildChartLegendItem(
                context.t.statistics.mood,
                const Color(0xFFFBBF24),
              ),
              _buildChartLegendItem(
                context.t.statistics.energy,
                const Color(0xFF06B6D4),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Semantics(
              label: context.t.a11y.chartLabel,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: context.appColors.border.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: chartWindow.labelInterval,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 ||
                              value > (chartWindow.dayCount - 1).toDouble()) {
                            return const SizedBox.shrink();
                          }
                          final date = chartWindow.dateAt(value);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${date.day}/${date.month}',
                              style: TextStyle(
                                color: context.appColors.mutedForeground,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              color: context.appColors.mutedForeground,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: chartWindow.minX,
                  maxX: chartWindow.maxX,
                  minY: 0,
                  maxY: 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: moodSpots,
                      isCurved: true,
                      color: const Color(0xFFFBBF24),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: hasMoodData && moodSpots.length <= 7,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.05),
                      ),
                    ),
                    LineChartBarData(
                      spots: energySpots,
                      isCurved: true,
                      color: const Color(0xFF06B6D4),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: hasMoodData && energySpots.length <= 7,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.05),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) =>
                          context.appColors.card.withValues(alpha: 0.9),
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final isMood = barSpot.barIndex == 0;
                          return LineTooltipItem(
                            '${isMood ? context.t.statistics.mood : context.t.statistics.energy}: ${barSpot.y.toInt()}',
                            TextStyle(
                              color: isMood
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFF06B6D4),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 350),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.appColors.foreground,
          ),
        ),
      ],
    );
  }
}

class _MoodSensitiveSection extends StatelessWidget {
  final List<MoodCorrelation> correlations;
  final List<Goal> goals;

  const _MoodSensitiveSection({
    required this.correlations,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final sensitiveHabits =
        correlations.where((c) => c.sensitivity > 10).toList()
          ..sort((a, b) => b.sensitivity.compareTo(a.sensitivity));

    final topSensitive = sensitiveHabits.take(3).toList();
    final colors = [
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF3B82F6),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t.statistics.moodSensitiveHabits,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.appColors.foreground,
          ),
        ),
        const SizedBox(height: 12),
        if (topSensitive.isEmpty)
          Text(
            context.t.statistics.notEnoughDataToCalculateSensitivity,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: context.appColors.mutedForeground,
            ),
          )
        else
          ...List.generate(topSensitive.length, (i) {
            final c = topSensitive[i];
            final goal = goals.firstWhere(
              (g) => g.id == c.goalId,
              orElse: () => Goal(
                id: c.goalId,
                title: context.t.statistics.unknownHabit,
                color: Colors.grey,
                startDate: DateTime.now(),
              ),
            );
            return _buildSensitiveItem(
              context,
              goal.title,
              c.sensitivity,
              colors[i % colors.length],
            );
          }),
      ],
    );
  }

  Widget _buildSensitiveItem(
    BuildContext context,
    String name,
    int sensitivity,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${context.t.statistics.sensitivity}: ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                      Text(
                        '$sensitivity%',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: context.appColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResilientHabitsSection extends StatelessWidget {
  final List<MoodCorrelation> correlations;
  final List<Goal> goals;

  const _ResilientHabitsSection({
    required this.correlations,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    // Resilient habits are those with high completion rate in low mood
    final resilientHabits =
        correlations.where((c) => c.resilience > 50).toList()
          ..sort((a, b) => b.resilience.compareTo(a.resilience));

    final topResilient = resilientHabits.take(2).toList();
    final colors = [const Color(0xFF10B981), const Color(0xFFF59E0B)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t.statistics.resilientHabits,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.appColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.t.statistics.habitsYouKeepEvenWhenYour,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        if (topResilient.isEmpty)
          Text(
            context.t.statistics.notEnoughDataToCalculateResilience,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: context.appColors.mutedForeground,
            ),
          )
        else
          Row(
            children: List.generate(topResilient.length, (i) {
              final c = topResilient[i];
              final goal = goals.firstWhere(
                (g) => g.id == c.goalId,
                orElse: () => Goal(
                  id: c.goalId,
                  title: context.t.statistics.unknownHabit,
                  color: Colors.grey,
                  startDate: DateTime.now(),
                ),
              );
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < topResilient.length - 1 ? 12.0 : 0.0,
                  ),
                  child: _buildResilientCard(
                    context,
                    goal.title,
                    c.resilience,
                    colors[i % colors.length],
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildResilientCard(
    BuildContext context,
    String name,
    int resilience,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$resilience%',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            context.t.statistics.resilience,
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

class _CorrelazioneMoodSection extends StatelessWidget {
  final List<MoodCorrelation> correlations;
  final List<Goal> goals;

  const _CorrelazioneMoodSection({
    required this.correlations,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final topCorrelations = correlations.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.statistics.correlationAnalysis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 20),
          if (topCorrelations.isEmpty)
            Text(
              context.t.statistics.notEnoughDataForCorrelationAnalysis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: context.appColors.mutedForeground,
              ),
            )
          else
            ...topCorrelations.map((c) {
              final goal = goals.firstWhere(
                (g) => g.id == c.goalId,
                orElse: () => Goal(
                  id: c.goalId,
                  title: context.t.statistics.unknownHabit,
                  color: Colors.grey,
                  startDate: DateTime.now(),
                ),
              );
              return _buildCorrelationRow(
                context,
                goal.title,
                c.lowMoodPct,
                c.highMoodPct,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCorrelationRow(
    BuildContext context,
    String name,
    int lowVal,
    int highVal,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.foreground,
                ),
              ),
              Row(
                children: [
                  _MoodStatMini(
                    label: context.t.statistics.lowMood,
                    value: '$lowVal%',
                    icon: LucideIcons.frown,
                    small: true,
                  ),
                  const SizedBox(width: 12),
                  _MoodStatMini(
                    label: context.t.statistics.highMood,
                    value: '$highVal%',
                    icon: LucideIcons.smile,
                    small: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: context.appColors.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: highVal / 100,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodStatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool small;

  const _MoodStatMini({
    required this.label,
    required this.value,
    required this.icon,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: small ? 7 : 8,
            fontWeight: FontWeight.w800,
            color: context.appColors.mutedForeground,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              icon,
              size: small ? 10 : 12,
              color: context.appColors.mutedForeground,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: small ? 12 : 14,
                fontWeight: FontWeight.w900,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
