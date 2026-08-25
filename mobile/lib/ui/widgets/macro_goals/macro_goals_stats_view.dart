import 'package:flutter/material.dart';
import '../../kit/evolve_async_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math' as math;

import '../../../core/theme.dart';
import '../../../core/haptics.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/macro_goals_provider.dart';
import '../../../providers/macro_goals_stats_provider.dart';
import '../../../providers/macro_goal_categories_provider.dart';
import '../pro_features_modal.dart';
import '../../kit/evolve_sheet.dart';
import '../../../i18n/translations.g.dart';

class MacroGoalsStatsView extends ConsumerStatefulWidget {
  const MacroGoalsStatsView({super.key});

  @override
  ConsumerState<MacroGoalsStatsView> createState() =>
      _MacroGoalsStatsViewState();
}

class _MacroGoalsStatsViewState extends ConsumerState<MacroGoalsStatsView> {
  String _selectedYear = 'all';

  String _goalTypeLabel(String type) {
    switch (type) {
      case 'lifetime':
        return context.t.macroGoals.types.lifetime;
      case 'annual':
        return context.t.macroGoals.types.annual;
      case 'quarterly':
        return context.t.macroGoals.types.quarterly;
      case 'monthly':
        return context.t.macroGoals.types.monthly;
      case 'weekly':
        return context.t.macroGoals.types.weekly;
      default:
        return 'N/A';
    }
  }

  String _monthLabel(int month, {bool abbreviated = false}) {
    if (month < 1 || month > 12) return '';
    final formatter = abbreviated
        ? DateFormat.MMM(LocaleSettings.currentLocale.languageCode)
        : DateFormat.MMMM(LocaleSettings.currentLocale.languageCode);
    return formatter.format(DateTime(2000, month));
  }

  @override
  Widget build(BuildContext context) {
    final allGoals = ref.watch(macroGoalsProvider).goals;

    final settings = ref.watch(settingsProvider);
    if (!settings.isPro && _selectedYear != 'all') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedYear = 'all');
        }
      });
    }

    // Distinct years for dropdown
    final years = allGoals.map((g) => g.year).whereType<int>().toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    if (!years.contains(DateTime.now().year)) {
      years.insert(0, DateTime.now().year);
    }

    final statsAsync = ref.watch(macroGoalsStatsProvider(_selectedYear));

    return statsAsync.when(
      data: (stats) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Year Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Performance',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.appColors.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _buildYearSelector(years),
                ],
              ),
              const SizedBox(height: 20),

              if (_selectedYear == 'all')
                ..._buildGlobalContent(stats)
              else
                ..._buildSingleYearContent(stats),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => SizedBox(
        height: 300,
        child: Center(
          child: EvolveAsyncError(
            error: err,
            stackTrace: stack,
            context: '[Stats] macro goals',
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSingleYearContent(Map<String, dynamic> stats) {
    final categories = ref.watch(macroGoalCategoriesProvider).value ?? [];
    final totalGoals = stats['total_goals'] as int? ?? 0;
    final completedGoals = stats['completed_goals'] as int? ?? 0;
    final successRate = stats['success_rate'] as int? ?? 0;
    final trendPositive = successRate > 50;

    final bestCategoryKey = stats['best_category'] as String?;
    String bestCategory = 'N/A';
    try {
      bestCategory = categories
          .firstWhere((c) => c.key == bestCategoryKey)
          .label;
    } catch (_) {
      bestCategory = categoryLabel(bestCategoryKey) ?? 'N/A';
    }
    final bestCatRate = stats['best_category_rate'] as int? ?? 0;

    final bestMonthIdx = stats['best_month'] as int?;
    final bestMonthRate = stats['best_month_rate'] as int? ?? 0;

    final bestTypeStr = stats['best_type'] as String?;
    String bestTypeLabel = 'N/A';
    if (bestTypeStr != null) {
      bestTypeLabel = _goalTypeLabel(bestTypeStr);
    }
    final bestTypeRate = stats['best_type_rate'] as int? ?? 0;

    return [
      Row(
        children: [
          Expanded(
            child: _buildHighlightCard(
              title: context.t.macroGoals.strength,
              value: bestCategory,
              subtitle: '$bestCatRate% ${context.t.common.ofCompletion}',
              icon: LucideIcons.zap,
              color: const Color(0xFFA855F7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildHighlightCard(
              title: context.t.macroGoals.bestMonth,
              value: (bestMonthIdx != null && bestMonthIdx > 0)
                  ? _monthLabel(bestMonthIdx, abbreviated: true)
                  : context.t.common.none,
              subtitle: '$bestMonthRate% ${context.t.macroGoals.successRate2}',
              icon: LucideIcons.trophy,
              color: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _buildHighlightCard(
        title: context.t.macroGoals.effectiveType,
        value: bestTypeLabel,
        subtitle: '$bestTypeRate% ${context.t.macroGoals.successRate2}',
        icon: LucideIcons.brainCircuit,
        color: Theme.of(context).colorScheme.primary,
        fullWidth: true,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              context.t.common.total,
              '$totalGoals',
              LucideIcons.target,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              context.t.common.completed,
              '$completedGoals',
              LucideIcons.circleCheck,
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              context.t.macroGoals.success2,
              '$successRate%',
              LucideIcons.trophy,
              color: const Color(0xFFFBBF24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              context.t.macroGoals.trend,
              (trendPositive
                  ? context.t.statistics.growth
                  : context.t.statistics.decline),
              trendPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              color: const Color(0xFF60A5FA),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _buildAreaChartCard(stats['cumulative_monthly'] as List<dynamic>? ?? []),
      const SizedBox(height: 16),
      _buildCategoryRadarCard(stats['category_rates'] as List<dynamic>? ?? []),
      const SizedBox(height: 16),
      _buildQuarterlyBarCard(
        stats['quarterly_activity'] as List<dynamic>? ?? [],
      ),
      const SizedBox(height: 16),
      _buildMonthlyComposedCard(
        stats['monthly_composed'] as List<dynamic>? ?? [],
      ),
      const SizedBox(height: 16),
      _buildCategoryPieCard(
        stats['category_distribution'] as List<dynamic>? ?? [],
        categories,
      ),
      const SizedBox(height: 48),
    ];
  }

  List<Widget> _buildGlobalContent(Map<String, dynamic> stats) {
    final categories = ref.watch(macroGoalCategoriesProvider).value ?? [];
    final total = stats['total_goals'] as int? ?? 0;
    final comp = stats['completed_goals'] as int? ?? 0;
    final succ = total > 0 ? (comp / total * 100).round() : 0;

    final bestYear = stats['best_year'] as int?;
    final bestYearRate = stats['best_year_rate'] as int? ?? 0;
    final mostProdYear = stats['most_productive_year'] as int?;
    final mostProdCount = stats['most_productive_count'] as int? ?? 0;

    final yearProgression = stats['year_progression'] as List<dynamic>? ?? [];
    final List<int> sortedYears = [];
    for (var item in yearProgression) {
      if (item is Map<String, dynamic>) {
        final y = item['year'] as int?;
        if (y != null) sortedYears.add(y);
      }
    }
    sortedYears.sort();

    return [
      Row(
        children: [
          Expanded(
            child: _buildHighlightCard(
              title: context.t.macroGoals.historicalTotal,
              value: '$total',
              subtitle:
                  '${context.t.macroGoals.from_} ${sortedYears.isNotEmpty ? sortedYears.first : '-'}',
              icon: LucideIcons.target,
              color: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildHighlightCard(
              title: context.t.macroGoals.globalSuccess,
              value: '$succ%',
              subtitle: '$comp ${context.t.macroGoals.completedGoals}',
              icon: LucideIcons.trophy,
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _buildHighlightCard(
              title: context.t.macroGoals.bestYear,
              value: bestYear != null ? '$bestYear' : 'N/A',
              subtitle: '$bestYearRate% ${context.t.macroGoals.completion}',
              icon: LucideIcons.calendar,
              color: const Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildHighlightCard(
              title: context.t.macroGoals.mostProductiveYear,
              value: mostProdYear != null ? '$mostProdYear' : 'N/A',
              subtitle: '$mostProdCount ${context.t.macroGoals.totalGoals}',
              icon: LucideIcons.activity,
              color: const Color(0xFF06B6D4),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),

      _buildGlobalYearProgressionCard(yearProgression),
      const SizedBox(height: 16),
      _buildCategoryRadarCard(
        stats['category_performance'] as List<dynamic>? ?? [],
      ),
      const SizedBox(height: 16),
      _buildGlobalTypeDistCard(
        stats['type_distribution'] as Map<String, dynamic>? ?? {},
      ),
      const SizedBox(height: 16),
      _buildQuarterSeasonalityCard(
        stats['seasonality'] as List<dynamic>? ?? [],
      ),
      const SizedBox(height: 16),
      _buildGlobalMonthlyHistCard(
        stats['monthly_history'] as List<dynamic>? ?? [],
      ),
      const SizedBox(height: 16),
      _buildGlobalInterestEvolutionCard(
        stats['interest_evolution'] as List<dynamic>? ?? [],
        categories,
      ),
      const SizedBox(height: 48),
    ];
  }

  // ─── Component Builders ───────────────────────────────────────────────────

  Widget _buildYearSelector(List<int> years) {
    final String displayLabel = _selectedYear == 'all'
        ? context.t.macroGoals.allYears
        : _selectedYear;

    return GestureDetector(
      onTap: () {
        ref.hapticLight();
        _showYearPicker(years);
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.appColors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.appColors.border.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendar,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              displayLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appColors.foreground,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: context.appColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  void _showYearPicker(List<int> years) {
    final settings = ref.read(settingsProvider);
    final isPro = settings.isPro;

    showEvolveSheet<void>(
      context: context,
      title: context.t.macroGoals.selectYearHeader,
      itemsBuilder: (sheetContext) => [
        EvolveListSection(
          children: [
            EvolveListRow(
              leading: EvolveIconTile(
                icon: LucideIcons.calendarRange,
                tint: context.appColors.mutedForeground,
              ),
              title: context.t.macroGoals.allYears,
              selected: _selectedYear == 'all',
              onTap: () {
                setState(() => _selectedYear = 'all');
                Navigator.pop(sheetContext);
              },
            ),
            ...years.map((y) {
              final isSel = _selectedYear == '$y';
              return EvolveListRow(
                leading: EvolveIconTile(
                  icon: LucideIcons.calendar,
                  tint: context.appColors.mutedForeground,
                ),
                title: '$y',
                titleColor: isPro ? null : context.appColors.mutedForeground,
                selected: isPro && isSel,
                trailing: isPro
                    ? null
                    : Icon(
                        LucideIcons.lock,
                        color: context.appColors.mutedForeground,
                        size: 14,
                      ),
                onTap: () {
                  if (!isPro) {
                    Navigator.pop(sheetContext);
                    ref.hapticHeavy();
                    ProFeaturesModal.show(context).then((_) {
                      if (mounted) {
                        setState(() => _selectedYear = 'all');
                      }
                    });
                  } else {
                    setState(() => _selectedYear = '$y');
                    Navigator.pop(sheetContext);
                  }
                },
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildHighlightCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.02)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              color: context.appColors.foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: context.appColors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    IconData icon, {
    Color color = AppColors.foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: context.appColors.mutedForeground,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 12, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              color: context.appColors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBase({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.appColors.card.withValues(alpha: 0.4),
            context.appColors.card.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              color: context.appColors.foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: context.appColors.mutedForeground,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  // ─── Chart Widgets ────────────────────────────────────────────────────────

  Widget _buildAreaChartCard(List<dynamic> stats) {
    final List<FlSpot> totalSpots = [];
    final List<FlSpot> compSpots = [];

    double maxTotal = 0;

    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final m = item['month'] as int?;
        final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
        final comp = (item['completed'] as num?)?.toDouble() ?? 0.0;

        if (m != null) {
          totalSpots.add(FlSpot(m.toDouble(), tot));
          compSpots.add(FlSpot(m.toDouble(), comp));
          if (tot > maxTotal) maxTotal = tot;
        }
      }
    }

    final double maxY = math.max(10.0, maxTotal * 1.2);

    return _buildCardBase(
      title: context.t.macroGoals.executionSpeedCumulative,
      subtitle: context.t.macroGoals.comparisonOfPlannedVsCompletedGoals,
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: maxY / 4,
              verticalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(
                color: context.appColors.border.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
              getDrawingVerticalLine: (value) => FlLine(
                color: context.appColors.border.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
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
                  interval: 1,
                  getTitlesWidget: (val, meta) {
                    if (val < 1 || val > 12) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _monthLabel(val.toInt(), abbreviated: true),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: maxY / 4,
                  reservedSize: 36,
                  getTitlesWidget: (val, meta) {
                    return Text(
                      val.toInt().toString(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: context.appColors.mutedForeground,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 1,
            maxX: 12,
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: totalSpots,
                isCurved: true,
                color: const Color(0xFF818CF8), // Indigo
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                ),
              ),
              LineChartBarData(
                spots: compSpots,
                isCurved: true,
                color: const Color(0xFF10B981),
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRadarCard(List<dynamic> stats) {
    final categories = ref.watch(macroGoalCategoriesProvider).value ?? [];
    if (stats.isEmpty) {
      return _buildCardBase(
        title: context.t.macroGoals.categoryPerformance,
        subtitle: context.t.macroGoals.successRate,
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              context.t.macroGoals.noData,
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
          ),
        ),
      );
    }

    if (stats.length < 3) {
      return _buildCardBase(
        title: context.t.macroGoals.categoryPerformance,
        subtitle: context.t.macroGoals.successRate,
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              context.t.macroGoals.insufficientDataAtLeast3Categories,
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
          ),
        ),
      );
    }

    final List<RadarEntry> entries = [];
    final List<String> labels = [];

    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final catKey = item['category'] as String?;
        final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
        String label = 'N/A';
        try {
          label = categories.firstWhere((c) => c.key == catKey).label;
        } catch (_) {
          label = categoryLabel(catKey) ?? 'N/A';
        }

        entries.add(RadarEntry(value: rate));
        labels.add(label);
      }
    }

    return _buildCardBase(
      title: context.t.macroGoals.categoryPerformance,
      subtitle: context.t.macroGoals.successRateByCategory,
      child: SizedBox(
        height: 240,
        child: RadarChart(
          RadarChartData(
            tickCount: 3,
            dataSets: [
              RadarDataSet(
                fillColor: const Color(
                  0xFF06B6D4,
                ).withValues(alpha: 0.2), // Cyan
                borderColor: const Color(0xFF06B6D4),
                entryRadius: 0,
                dataEntries: entries,
              ),
            ],
            radarBackgroundColor: Colors.transparent,
            borderData: FlBorderData(show: false),
            radarBorderData: BorderSide(color: context.appColors.border),
            tickBorderData: BorderSide(
              color: context.appColors.border,
              width: 0.5,
            ),
            ticksTextStyle: const TextStyle(color: Colors.transparent),
            getTitle: (index, angle) {
              if (index < labels.length) {
                return RadarChartTitle(
                  text: labels[index],
                  angle: 0,
                  positionPercentageOffset: 0.1,
                );
              }
              return const RadarChartTitle(text: '');
            },
            titleTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: context.appColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuarterlyBarCard(List<dynamic> stats) {
    if (stats.isEmpty) {
      return _buildCardBase(
        title: context.t.macroGoals.quarterlyActivity,
        subtitle: context.t.macroGoals.q1Q4,
        child: SizedBox(
          height: 150,
          child: Center(
            child: Text(
              context.t.macroGoals.noData,
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
          ),
        ),
      );
    }

    // Extract totals and completed per quarter
    final List<BarChartGroupData> groups = [];
    double maxY = 0;

    // Create a map for quick lookup
    final Map<int, Map<String, dynamic>> dataMap = {};
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final q = item['quarter'] as int?;
        if (q != null) {
          dataMap[q] = item;
          final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
          if (tot > maxY) maxY = tot;
        }
      }
    }

    for (int q = 1; q <= 4; q++) {
      final item = dataMap[q];
      final tot = (item?['total'] as num?)?.toDouble() ?? 0.0;
      final comp = (item?['completed'] as num?)?.toDouble() ?? 0.0;

      groups.add(
        BarChartGroupData(
          x: q,
          barRods: [
            BarChartRodData(
              toY: tot,
              color: const Color(0xFFD97706),
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: comp,
              color: const Color(0xFF10B981),
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    return _buildCardBase(
      title: context.t.macroGoals.quarterlyActivity,
      subtitle: context.t.macroGoals.inQ1Q4,
      child: SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) => Text(
                    'Q${val.toInt()}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            maxY: math.max(5.0, maxY * 1.2),
            barGroups: groups,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyComposedCard(List<dynamic> stats) {
    if (stats.isEmpty) {
      return _buildCardBase(
        title: context.t.macroGoals.monthlyActivity,
        subtitle: context.t.macroGoals.totalCompleted,
        child: const SizedBox(height: 150),
      );
    }

    final List<BarChartGroupData> barGroups = [];
    double maxY = 0;

    // Create a map for quick lookup
    final Map<int, Map<String, dynamic>> dataMap = {};
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final m = item['month'] as int?;
        if (m != null) {
          dataMap[m] = item;
          final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
          if (tot > maxY) maxY = tot;
        }
      }
    }

    for (int m = 1; m <= 12; m += 2) {
      // Show fewer columns to fit mobile
      final item = dataMap[m];
      final tot = (item?['total'] as num?)?.toDouble() ?? 0.0;
      final comp = (item?['completed'] as num?)?.toDouble() ?? 0.0;

      barGroups.add(
        BarChartGroupData(
          x: m,
          barRods: [
            BarChartRodData(
              toY: tot,
              color: Colors.transparent,
              width: 10,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: math.max(5.0, maxY * 1.2),
                color: context.appColors.border.withValues(alpha: 0.1),
              ),
              rodStackItems: [
                if (comp > 0)
                  BarChartRodStackItem(
                    0,
                    comp,
                    Theme.of(context).colorScheme.primary,
                  ),
                if (tot > comp)
                  BarChartRodStackItem(
                    comp,
                    tot,
                    const Color(0xFF6366F1).withValues(alpha: 0.6),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return _buildCardBase(
      title: context.t.macroGoals.completions,
      subtitle: context.t.macroGoals.monthly,
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => context.appColors.card,
                tooltipRoundedRadius: 12,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final m = group.x.toInt();
                  final item = dataMap[m];
                  final tot = (item?['total'] as num?)?.toInt() ?? 0;
                  final comp = (item?['completed'] as num?)?.toInt() ?? 0;
                  return BarTooltipItem(
                    '${_monthLabel(m)}\n',
                    TextStyle(
                      fontFamily: 'Inter',
                      color: context.appColors.foreground,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: '${context.t.macroGoals.total}$tot\n',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF6366F1),
                          fontSize: 10,
                        ),
                      ),
                      TextSpan(
                        text: '${context.t.macroGoals.completed2}$comp',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: math.max(1.0, maxY / 4),
              getDrawingHorizontalLine: (v) => FlLine(
                color: context.appColors.border.withValues(alpha: 0.2),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final index = val.toInt();
                    if (index < 1 || index > 12) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _monthLabel(index, abbreviated: true),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: context.appColors.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            maxY: math.max(5.0, maxY * 1.2),
            barGroups: barGroups,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPieCard(
    List<dynamic> stats,
    List<GoalCategory> categories,
  ) {
    if (stats.isEmpty) {
      return _buildCardBase(
        title: context.t.macroGoals.distribution,
        subtitle: '',
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              context.t.macroGoals.noData,
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
          ),
        ),
      );
    }

    final List<PieChartSectionData> sections = [];
    int totalCount = 0;

    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final count = (item['count'] as num?)?.toInt() ?? 0;
        totalCount += count;
      }
    }

    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final catKey = item['category'] as String?;
        final count = (item['count'] as num?)?.toDouble() ?? 0.0;

        Color? color;
        try {
          color = categories.firstWhere((c) => c.key == catKey).color;
        } catch (_) {
          color = categoryColor(catKey) ?? Colors.grey;
        }

        sections.add(
          PieChartSectionData(
            value: count,
            color: color,
            title: '',
            radius: 26,
            badgeWidget: null,
          ),
        );
      }
    }

    return _buildCardBase(
      title: context.t.macroGoals.categoryDistribution,
      subtitle: context.t.macroGoals.breakdownOfGoalsByFocusArea,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 65,
                    sectionsSpace: 4,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalCount',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: context.appColors.foreground,
                      ),
                    ),
                    Text(
                      context.t.macroGoals.goals,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: context.appColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Legend grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stats.map((item) {
              if (item is! Map<String, dynamic>) return const SizedBox.shrink();
              final catKey = item['category'] as String?;
              final count = (item['count'] as num?)?.toInt() ?? 0;
              Color? color;
              String label = 'N/A';
              try {
                final c = categories.firstWhere((c) => c.key == catKey);
                color = c.color;
                label = c.label;
              } catch (_) {
                color = categoryColor(catKey) ?? Colors.grey;
                label = categoryLabel(catKey) ?? 'N/A';
              }
              final perc = totalCount > 0
                  ? (count / totalCount * 100).round()
                  : 0;

              return Container(
                width: 150, // Fix width for grid likeness
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appColors.foreground,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    Text(
                      '$perc%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: context.appColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalYearProgressionCard(List<dynamic> stats) {
    if (stats.isEmpty) return const SizedBox();

    final List<BarChartGroupData> groups = [];
    double maxTot = 0;

    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
        if (tot > maxTot) maxTot = tot;
      }
    }

    for (int i = 0; i < stats.length; i++) {
      final item = stats[i];
      if (item is Map<String, dynamic>) {
        final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
        final act = (item['active'] as num?)?.toDouble() ?? 0.0;
        final fail = (item['failed'] as num?)?.toDouble() ?? 0.0;
        final comp = (item['completed'] as num?)?.toDouble() ?? 0.0;

        groups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: tot,
                color: Colors.transparent,
                width: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: math.max(10, maxTot * 1.2),
                  color: context.appColors.border.withValues(alpha: 0.1),
                ),
                rodStackItems: [
                  if (act > 0)
                    BarChartRodStackItem(
                      0,
                      act,
                      const Color(0xFF3B82F6),
                    ), // Attivi - Blue
                  if (fail > 0)
                    BarChartRodStackItem(
                      act,
                      act + fail,
                      const Color(0xFFEF4444),
                    ), // Falliti - Red
                  if (comp > 0)
                    BarChartRodStackItem(
                      act + fail,
                      act + fail + comp,
                      const Color(0xFF10B981),
                    ), // Completati - Dynamic Accent
                ],
              ),
            ],
          ),
        );
      }
    }

    return _buildCardBase(
      title: context.t.macroGoals.annualProgression,
      subtitle: context.t.macroGoals.yearOverYearComparisonOfGoals,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.appColors.card,
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final index = group.x.toInt();
                      if (index >= stats.length) return null;
                      final item = stats[index] as Map<String, dynamic>;
                      final y = item['year'] as int?;
                      final act = item['active'] as int? ?? 0;
                      final fail = item['failed'] as int? ?? 0;
                      final comp = item['completed'] as int? ?? 0;
                      return BarTooltipItem(
                        '$y\n',
                        TextStyle(
                          fontFamily: 'Inter',
                          color: context.appColors.foreground,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: '${context.t.macroGoals.active}$act\n',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF3B82F6),
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${context.t.macroGoals.failed2}$fail\n',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFEF4444),
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${context.t.macroGoals.completed2}$comp',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF10B981),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1.0, maxTot / 4),
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: context.appColors.border.withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          v.toInt().toString(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: context.appColors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final index = val.toInt();
                        if (index < 0 || index >= stats.length) {
                          return const SizedBox.shrink();
                        }
                        final item = stats[index] as Map<String, dynamic>;
                        final y = item['year'] as int?;
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            y?.toString() ?? '',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: context.appColors.mutedForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                maxY: math.max(10.0, maxTot * 1.2),
                barGroups: groups,
                alignment: BarChartAlignment.spaceAround,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend([
            _LegendItem('Attivi', const Color(0xFF3B82F6)),
            _LegendItem('Falliti', const Color(0xFFEF4444)),
            _LegendItem('Completati', const Color(0xFF10B981)),
          ]),
        ],
      ),
    );
  }

  Widget _buildLegend(List<_LegendItem> items) {
    return Wrap(
      spacing: 16,
      alignment: WrapAlignment.center,
      children: items
          .map(
            (i) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  i.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: context.appColors.mutedForeground,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _buildGlobalTypeDistCard(Map<String, dynamic> stats) {
    final Map<String, int> counts = {
      _goalTypeLabel('weekly'): (stats['weekly'] as num?)?.toInt() ?? 0,
      _goalTypeLabel('monthly'): (stats['monthly'] as num?)?.toInt() ?? 0,
      _goalTypeLabel('quarterly'): (stats['quarterly'] as num?)?.toInt() ?? 0,
      _goalTypeLabel('annual'): (stats['annual'] as num?)?.toInt() ?? 0,
      _goalTypeLabel('lifetime'): (stats['lifetime'] as num?)?.toInt() ?? 0,
    };
    final int maxV = counts.values.fold(0, (p, c) => math.max(p, c));
    return _buildCardBase(
      title: context.t.macroGoals.typeDistribution,
      subtitle: context.t.macroGoals.breakdownOfGoalsByTimeHorizon,
      child: Column(
        children: counts.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 85,
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: context.appColors.card,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: maxV == 0 ? 0 : e.value / maxV,
                            child: Container(
                              height: 18,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${e.value}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appColors.foreground,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildQuarterSeasonalityCard(List<dynamic> stats) {
    final List<BarChartGroupData> groups = [];
    double maxX = 0;

    // Create a map for quick lookup
    final Map<int, Map<String, dynamic>> dataMap = {};
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final q = item['quarter'] as int?;
        if (q != null) {
          dataMap[q] = item;
          final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
          if (tot > maxX) maxX = tot;
        }
      }
    }

    for (int q = 1; q <= 4; q++) {
      final item = dataMap[q];
      final tot = (item?['total'] as num?)?.toDouble() ?? 0.0;
      final act = (item?['active'] as num?)?.toDouble() ?? 0.0;
      final fail = (item?['failed'] as num?)?.toDouble() ?? 0.0;
      final comp = (item?['completed'] as num?)?.toDouble() ?? 0.0;

      groups.add(
        BarChartGroupData(
          x: q,
          barRods: [
            BarChartRodData(
              toY: tot,
              color: Colors.transparent,
              width: 14,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: math.max(5.0, maxX * 1.2),
                color: context.appColors.border.withValues(alpha: 0.1),
              ),
              rodStackItems: [
                if (act > 0)
                  BarChartRodStackItem(0, act, const Color(0xFF3B82F6)),
                if (fail > 0)
                  BarChartRodStackItem(
                    act,
                    act + fail,
                    const Color(0xFFD97706),
                  ),
                if (comp > 0)
                  BarChartRodStackItem(
                    act + fail,
                    act + fail + comp,
                    const Color(0xFF10B981),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return _buildCardBase(
      title: context.t.macroGoals.seasonality,
      subtitle: context.t.macroGoals.aggregatedQuarterlyPerformance,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.appColors.card,
                    tooltipRoundedRadius: 12,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final q = group.x.toInt();
                      final item = dataMap[q];
                      final act = (item?['active'] as num?)?.toInt() ?? 0;
                      final fail = (item?['failed'] as num?)?.toInt() ?? 0;
                      final comp = (item?['completed'] as num?)?.toInt() ?? 0;
                      return BarTooltipItem(
                        '${context.t.macroGoals.quarterNumber(quarter: q)}\n',
                        TextStyle(
                          fontFamily: 'Inter',
                          color: context.appColors.foreground,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: '${context.t.macroGoals.active}$act\n',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF3B82F6),
                              fontSize: 10,
                            ),
                          ),
                          TextSpan(
                            text: '${context.t.macroGoals.failed2}$fail\n',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFD97706),
                              fontSize: 10,
                            ),
                          ),
                          TextSpan(
                            text: '${context.t.macroGoals.completed2}$comp',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF10B981),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1.0, maxX / 4),
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: context.appColors.border.withValues(alpha: 0.2),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final index = v.toInt();
                        if (index < 1 || index > 4) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Q$index',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: context.appColors.mutedForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: groups,
                maxY: math.max(5.0, maxX * 1.2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLegend([
            _LegendItem('Attivi', const Color(0xFF3B82F6)),
            _LegendItem('Falliti', const Color(0xFFD97706)),
            _LegendItem('Compl.', const Color(0xFF10B981)),
          ]),
        ],
      ),
    );
  }

  Widget _buildGlobalMonthlyHistCard(List<dynamic> stats) {
    final List<FlSpot> spots = [];

    // Create a map for quick lookup
    final Map<int, double> dataMap = {};
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final m = item['month'] as int?;
        final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
        if (m != null) {
          dataMap[m] = rate;
        }
      }
    }

    for (int m = 1; m <= 12; m++) {
      final rate = dataMap[m] ?? 0.0;
      spots.add(FlSpot(m.toDouble(), rate));
    }

    return _buildCardBase(
      title: context.t.macroGoals.monthlyHistorical,
      subtitle: context.t.macroGoals.averageSuccessPerMonth,
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => context.appColors.card,
                tooltipRoundedRadius: 10,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((s) {
                    return LineTooltipItem(
                      '${_monthLabel(s.x.toInt())}\n',
                      TextStyle(
                        fontFamily: 'Inter',
                        color: context.appColors.mutedForeground,
                        fontSize: 10,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${s.y.round()}%${context.t.macroGoals.success}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(
                color: context.appColors.border.withValues(alpha: 0.2),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}%',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 3,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 1 || idx > 12) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _monthLabel(idx, abbreviated: true),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          color: context.appColors.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            minY: 0,
            maxY: 100,
            minX: 1,
            maxX: 12,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                color: const Color(0xFF10B981),
                barWidth: 3,
                isCurved: true,
                curveSmoothness: 0.35,
                preventCurveOverShooting: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF10B981),
                        strokeWidth: 2,
                        strokeColor: context.appColors.card,
                      ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalInterestEvolutionCard(
    List<dynamic> stats,
    List<GoalCategory> categories,
  ) {
    if (stats.isEmpty) return const SizedBox();
    final List<BarChartGroupData> groups = [];
    double maxY = 0;

    // Categories to show in evolution
    final limitedCategories = categories.take(6).toList();

    for (int i = 0; i < stats.length; i++) {
      final item = stats[i];
      if (item is! Map<String, dynamic>) continue;

      final cats = item['categories'] as Map<String, dynamic>? ?? {};

      double totalForYear = 0;
      final List<BarChartRodStackItem> stacks = [];
      double curr = 0;

      for (var c in limitedCategories) {
        final count = (cats[c.key] as num?)?.toDouble() ?? 0.0;
        totalForYear += count;
        if (count > 0) {
          stacks.add(BarChartRodStackItem(curr, curr + count, c.color));
          curr += count;
        }
      }

      if (totalForYear > maxY) maxY = totalForYear;

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: totalForYear,
              color: Colors.transparent,
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: math.max(5.0, maxY * 1.2),
                color: AppColors.borderHover.withValues(alpha: 0.1),
              ),
              rodStackItems: stacks,
            ),
          ],
        ),
      );
    }

    // Update backDrawRodData with the final maxY
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final rod = g.barRods.first;
      groups[i] = BarChartGroupData(
        x: g.x,
        barRods: [
          BarChartRodData(
            toY: rod.toY,
            color: rod.color,
            width: rod.width,
            borderRadius: rod.borderRadius,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: math.max(5.0, maxY * 1.2),
              color: AppColors.borderHover.withValues(alpha: 0.1),
            ),
            rodStackItems: rod.rodStackItems,
          ),
        ],
      );
    }

    return _buildCardBase(
      title: context.t.macroGoals.interestEvolution,
      subtitle: context.t.macroGoals.compositionOfFocusAreasOverThe,
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.appColors.card,
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.all(12),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final index = group.x.toInt();
                      if (index >= stats.length) return null;
                      final item = stats[index] as Map<String, dynamic>;
                      final y = item['year'] as int?;
                      final cats =
                          item['categories'] as Map<String, dynamic>? ?? {};

                      final List<TextSpan> categorySpans = [];
                      for (var c in limitedCategories) {
                        final count = (cats[c.key] as num?)?.toInt() ?? 0;
                        if (count > 0) {
                          categorySpans.add(
                            TextSpan(
                              text: '${c.label}: $count\n',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: c.color,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                      }

                      return BarTooltipItem(
                        '$y\n',
                        TextStyle(
                          fontFamily: 'Inter',
                          color: context.appColors.foreground,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        children: categorySpans,
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1.0, maxY / 4),
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: context.appColors.border.withValues(alpha: 0.2),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final index = v.toInt();
                        if (index < 0 || index >= stats.length) {
                          return const SizedBox.shrink();
                        }
                        final item = stats[index] as Map<String, dynamic>;
                        final y = item['year'] as int?;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            y?.toString() ?? '',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: context.appColors.mutedForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: groups,
                maxY: math.max(5.0, maxY * 1.2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(
            limitedCategories
                .map((c) => _LegendItem(c.label, c.color))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  _LegendItem(this.label, this.color);
}
