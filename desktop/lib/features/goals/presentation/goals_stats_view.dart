import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fl_chart/fl_chart.dart';

import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math' as math;

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:flutter/services.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';

class GoalsStatsView extends ConsumerStatefulWidget {
  const GoalsStatsView({super.key});

  @override
  ConsumerState<GoalsStatsView> createState() => _GoalsStatsViewState();
}

class _GoalsStatsViewState extends ConsumerState<GoalsStatsView> {
  String _selectedYear = 'all';

  String _goalTypeLabel(String type) {
    switch (type) {
      case 'lifetime':
        return 'Lifetime';
      case 'annual':
        return 'Annuale';
      case 'quarterly':
        return 'Trimestrale';
      case 'monthly':
        return 'Mensile';
      case 'weekly':
        return 'Settimanale';
      default:
        return 'N/A';
    }
  }

  String _monthLabel(int month, {bool abbreviated = false}) {
    if (month < 1 || month > 12) return '';
    final formatter = abbreviated
        ? DateFormat.MMM('it')
        : DateFormat.MMMM('it');
    return formatter.format(DateTime(2000, month));
  }

  @override
  Widget build(BuildContext context) {
    final allGoals = ref.watch(dashboardControllerProvider).goals;

    final isPro = ref.watch(desktopIsProProvider);
    if (!isPro && _selectedYear != 'all') {
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

    final statsAsync = ref.watch(macroGoalsStatsRpcProvider(_selectedYear));

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
                    t.stats.tabPerformance,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.evolveColors.foreground,
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
          child: Text(
            '${t.common.status.error}: $err',
            style: TextStyle(color: context.evolveColors.muted),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSingleYearContent(Map<String, dynamic> stats) {
    final List<DesktopGoalCategory> categories =
        ref.watch(desktopGoalCategoriesControllerProvider).value ?? [];
    final totalGoals = stats['total_goals'] as int? ?? 0;
    final completedGoals = stats['completed_goals'] as int? ?? 0;
    final successRate = stats['success_rate'] as int? ?? 0;
    final trendPositive = successRate > 50;

    final bestCategoryKey = stats['best_category'] as String?;
    String bestCategory = 'N/A';
    try {
      bestCategory = categories
          .firstWhere((c) => c.id == bestCategoryKey)
          .label;
    } catch (_) {
      bestCategory =
          categories.where((c) => c.id == bestCategoryKey).firstOrNull?.label ??
          'N/A';
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
              title: t.macroGoals.strength,
              value: bestCategory,
              subtitle: '$bestCatRate% ${t.statistics.ofCompletion}',
              icon: LucideIcons.zap,
              color: const Color(0xFFA855F7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildHighlightCard(
              title: t.macroGoals.bestMonth,
              value: (bestMonthIdx != null && bestMonthIdx > 0)
                  ? _monthLabel(bestMonthIdx, abbreviated: true)
                  : t.common.none,
              subtitle: '$bestMonthRate% ${t.macroGoals.successRate2}',
              icon: LucideIcons.trophy,
              color: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _buildHighlightCard(
        title: t.macroGoals.effectiveType,
        value: bestTypeLabel,
        subtitle: '$bestTypeRate% ${t.macroGoals.successRate2}',
        icon: LucideIcons.brainCircuit,
        color: Theme.of(context).colorScheme.primary,
        fullWidth: true,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              t.common.total,
              '$totalGoals',
              LucideIcons.target,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              t.common.completed,
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
              t.macroGoals.success2,
              '$successRate%',
              LucideIcons.trophy,
              color: const Color(0xFFFBBF24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              t.stats.tabTrend,
              (trendPositive ? t.statistics.growth : t.statistics.decline),
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
    final List<DesktopGoalCategory> categories =
        ref.watch(desktopGoalCategoriesControllerProvider).value ?? [];
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
              title: t.macroGoals.historicalTotal,
              value: '$total',
              subtitle:
                  '${t.macroGoals.from_} ${sortedYears.isNotEmpty ? sortedYears.first : '-'}',
              icon: LucideIcons.target,
              color: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildHighlightCard(
              title: t.macroGoals.globalSuccess,
              value: '$succ%',
              subtitle: '$comp ${t.macroGoals.completedGoals}',
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
              title: t.macroGoals.bestYear,
              value: bestYear != null ? '$bestYear' : 'N/A',
              subtitle: '$bestYearRate% ${'completamento'}',
              icon: LucideIcons.calendar,
              color: const Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildHighlightCard(
              title: t.macroGoals.mostProductiveYear,
              value: mostProdYear != null ? '$mostProdYear' : 'N/A',
              subtitle: '$mostProdCount ${t.macroGoals.totalGoals}',
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
        ? t.macroGoals.allYears
        : _selectedYear;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showYearPicker(years);
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.evolveColors.panel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.evolveColors.border.withValues(alpha: 0.5),
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
                color: context.evolveColors.foreground,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: context.evolveColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  void _showYearPicker(List<int> years) {
    final isPro = ref.read(desktopIsProProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.evolveColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.evolveColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  t.macroGoals.selectYearHeader,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    color: context.evolveColors.muted,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                LucideIcons.calendarRange,
                size: 20,
                color: _selectedYear == 'all'
                    ? primaryColor
                    : context.evolveColors.muted.withValues(alpha: 0.6),
              ),
              title: Text(
                t.macroGoals.allYears,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: _selectedYear == 'all'
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: _selectedYear == 'all'
                      ? context.evolveColors.foreground
                      : context.evolveColors.muted,
                ),
              ),
              trailing: _selectedYear == 'all'
                  ? Icon(LucideIcons.check, color: primaryColor, size: 20)
                  : null,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedYear = 'all');
                Navigator.pop(context);
              },
            ),
            ...years.map((y) {
              final isSel = _selectedYear == '$y';
              return ListTile(
                leading: Icon(
                  isPro ? LucideIcons.calendar : LucideIcons.lock,
                  size: 20,
                  color: isSel
                      ? primaryColor
                      : context.evolveColors.muted.withValues(alpha: 0.6),
                ),
                title: Text(
                  '$y',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isPro
                        ? (isSel
                              ? context.evolveColors.foreground
                              : context.evolveColors.muted)
                        : context.evolveColors.muted,
                  ),
                ),
                trailing: isPro
                    ? (isSel
                          ? Icon(
                              LucideIcons.check,
                              color: primaryColor,
                              size: 20,
                            )
                          : null)
                    : Icon(
                        LucideIcons.lock,
                        color: context.evolveColors.muted,
                        size: 14,
                      ),
                onTap: () {
                  if (!isPro) {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.goalsStats.proRequired)),
                    );
                    if (mounted) {
                      setState(() => _selectedYear = 'all');
                    }
                  } else {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedYear = '$y');
                    Navigator.pop(context);
                  }
                },
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
              color: context.evolveColors.foreground,
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
              color: context.evolveColors.muted,
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
    Color color = EvolveColors.foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: context.evolveColors.panel.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.evolveColors.border),
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
                    color: context.evolveColors.muted,
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
              color: context.evolveColors.foreground,
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
        color: context.evolveColors.panel.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.evolveColors.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.evolveColors.panel.withValues(alpha: 0.4),
            context.evolveColors.panel.withValues(alpha: 0.2),
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
              color: context.evolveColors.foreground,
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
              color: context.evolveColors.muted,
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
      title: '',
      subtitle: '',
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
                color: context.evolveColors.border.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
              getDrawingVerticalLine: (value) => FlLine(
                color: context.evolveColors.border.withValues(alpha: 0.5),
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
                          color: context.evolveColors.muted,
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
                        color: context.evolveColors.muted,
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
    final List<DesktopGoalCategory> categories =
        ref.watch(desktopGoalCategoriesControllerProvider).value ?? [];
    if (stats.isEmpty) {
      return _buildCardBase(
        title: '',
        subtitle: '',
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              '',
              style: TextStyle(color: context.evolveColors.muted),
            ),
          ),
        ),
      );
    }

    if (stats.length < 3) {
      return _buildCardBase(
        title: '',
        subtitle: '',
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              '',
              style: TextStyle(color: context.evolveColors.muted),
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
          label = categories.firstWhere((c) => c.id == catKey).label;
        } catch (_) {
          label =
              categories.where((c) => c.id == catKey).firstOrNull?.label ??
              'N/A';
        }

        entries.add(RadarEntry(value: rate));
        labels.add(label);
      }
    }

    return _buildCardBase(
      title: '',
      subtitle: '',
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
            radarBorderData: BorderSide(color: context.evolveColors.border),
            tickBorderData: BorderSide(
              color: context.evolveColors.border,
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
              color: context.evolveColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuarterlyBarCard(List<dynamic> stats) {
    if (stats.isEmpty) {
      return _buildCardBase(
        title: '',
        subtitle: '',
        child: SizedBox(
          height: 150,
          child: Center(
            child: Text(
              '',
              style: TextStyle(color: context.evolveColors.muted),
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
      title: '',
      subtitle: '',
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
                      color: context.evolveColors.muted,
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
        title: '',
        subtitle: '',
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
                color: context.evolveColors.border.withValues(alpha: 0.1),
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
      title: t.macroGoals.completions,
      subtitle: '',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => context.evolveColors.panel,

                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final m = group.x.toInt();
                  final item = dataMap[m];
                  final tot = (item?['total'] as num?)?.toInt() ?? 0;
                  final comp = (item?['completed'] as num?)?.toInt() ?? 0;
                  return BarTooltipItem(
                    '${_monthLabel(m)}\n',
                    TextStyle(
                      fontFamily: 'Inter',
                      color: context.evolveColors.foreground,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: '${''}$tot\n',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: const Color(0xFF6366F1),
                          fontSize: 10,
                        ),
                      ),
                      TextSpan(
                        text: '${''}$comp',
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
                color: context.evolveColors.border.withValues(alpha: 0.2),
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
                      color: context.evolveColors.muted,
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
                          color: context.evolveColors.muted,
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
    List<DesktopGoalCategory> categories,
  ) {
    if (stats.isEmpty) {
      return _buildCardBase(
        title: '',
        subtitle: '',
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              '',
              style: TextStyle(color: context.evolveColors.muted),
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
          color = categories.firstWhere((c) => c.id == catKey).color;
        } catch (_) {
          color =
              categories.where((c) => c.id == catKey).firstOrNull?.color ??
              Colors.grey ??
              Colors.grey;
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
      title: '',
      subtitle: '',
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
                        color: context.evolveColors.foreground,
                      ),
                    ),
                    Text(
                      'obiettivi',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: context.evolveColors.muted,
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
                final c = categories.firstWhere((c) => c.id == catKey);
                color = c.color;
                label = c.label;
              } catch (_) {
                color =
                    categories
                        .where((c) => c.id == catKey)
                        .firstOrNull
                        ?.color ??
                    Colors.grey ??
                    Colors.grey;
                label =
                    categories
                        .where((c) => c.id == catKey)
                        .firstOrNull
                        ?.label ??
                    'N/A';
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
                  color: context.evolveColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.evolveColors.border),
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
                          color: context.evolveColors.foreground,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    Text(
                      '$perc%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: context.evolveColors.muted,
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
                  color: context.evolveColors.border.withValues(alpha: 0.1),
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
      title: '',
      subtitle: '',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.evolveColors.panel,

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
                          color: context.evolveColors.foreground,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: '${''}$act\n',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: const Color(0xFF3B82F6),
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${''}$fail\n',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: const Color(0xFFEF4444),
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${''}$comp',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: const Color(0xFF10B981),
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
                    color: context.evolveColors.border.withValues(alpha: 0.3),
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
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Text(
                          v.toInt().toString(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: context.evolveColors.muted,
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
                              color: context.evolveColors.muted,
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
            _LegendItem(t.goalsStats.active, const Color(0xFF3B82F6)),
            _LegendItem(t.goalsStats.failed, const Color(0xFFEF4444)),
            _LegendItem(t.common.completed, const Color(0xFF10B981)),
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
                    color: context.evolveColors.muted,
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
      title: '',
      subtitle: '',
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
                          color: context.evolveColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: context.evolveColors.panel,
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
                          color: context.evolveColors.foreground,
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
                color: context.evolveColors.border.withValues(alpha: 0.1),
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
      title: t.goalsStats.seasonality,
      subtitle: '',
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.evolveColors.panel,

                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final q = group.x.toInt();
                      final item = dataMap[q];
                      final act = (item?['active'] as num?)?.toInt() ?? 0;
                      final fail = (item?['failed'] as num?)?.toInt() ?? 0;
                      final comp = (item?['completed'] as num?)?.toInt() ?? 0;
                      return BarTooltipItem(
                        'Q$q\n',
                        TextStyle(
                          fontFamily: 'Inter',
                          color: context.evolveColors.foreground,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: '${''}$act\n',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: const Color(0xFF3B82F6),
                              fontSize: 10,
                            ),
                          ),
                          TextSpan(
                            text: '${''}$fail\n',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: const Color(0xFFD97706),
                              fontSize: 10,
                            ),
                          ),
                          TextSpan(
                            text: '${''}$comp',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: const Color(0xFF10B981),
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
                    color: context.evolveColors.border.withValues(alpha: 0.2),
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
                              color: context.evolveColors.muted,
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
            _LegendItem(t.goalsStats.active, const Color(0xFF3B82F6)),
            _LegendItem(t.goalsStats.failed, const Color(0xFFD97706)),
            _LegendItem(t.goalsStats.complAbbr, const Color(0xFF10B981)),
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
      title: '',
      subtitle: '',
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => context.evolveColors.panel,

                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((s) {
                    return LineTooltipItem(
                      '${_monthLabel(s.x.toInt())}\n',
                      TextStyle(
                        fontFamily: 'Inter',
                        color: context.evolveColors.muted,
                        fontSize: 10,
                      ),
                      children: [
                        TextSpan(
                          text: '${s.y.round()}%${''}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: const Color(0xFF10B981),
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
                color: context.evolveColors.border.withValues(alpha: 0.2),
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
                      color: context.evolveColors.muted,
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
                          color: context.evolveColors.muted,
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
                        strokeColor: context.evolveColors.panel,
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
    List<DesktopGoalCategory> categories,
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
        final count = (cats[c.id] as num?)?.toDouble() ?? 0.0;
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
                color: EvolveColors.border.withValues(alpha: 0.1),
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
              color: EvolveColors.border.withValues(alpha: 0.1),
            ),
            rodStackItems: rod.rodStackItems,
          ),
        ],
      );
    }

    return _buildCardBase(
      title: t.goalsStats.interestEvolution,
      subtitle: '',
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.evolveColors.panel,

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
                        final count = (cats[c.id] as num?)?.toInt() ?? 0;
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
                          color: context.evolveColors.foreground,
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
                    color: context.evolveColors.border.withValues(alpha: 0.2),
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
                          color: context.evolveColors.muted,
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
                              color: context.evolveColors.muted,
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
