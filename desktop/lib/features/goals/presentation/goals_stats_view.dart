import 'dart:async';
import 'dart:math' as math;

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  /// Localized month name from the slang `t.common.months` array; the
  /// abbreviated variant keeps the first three characters ("Gen", "Feb", …)
  /// to match the short axis labels previously produced via `DateFormat.MMM`.
  String _monthLabel(int month, {bool abbreviated = false}) {
    if (month < 1 || month > 12) return '';
    final label = t.common.months[month - 1];
    if (!abbreviated || label.length <= 3) return label;
    return label.substring(0, 3);
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
        return LayoutBuilder(
          builder: (context, constraints) {
            // Same breakpoints as the dashboard: metric grids collapse from 4
            // to 2 columns below 1080, chart pairs stack below 1120. Fluid
            // guardrails: KPI tiles cap near 470px while charts absorb the
            // extra width — heights scale with the content and chart rows go
            // 3-up on ultra-wide content (>= 1760).
            final wide = constraints.maxWidth >= 1120;
            final ultra = constraints.maxWidth >= 1760;
            final columns = constraints.maxWidth >= 1080 ? 4 : 2;
            const spacing = 14.0;
            final cardWidth = math.min(
              (constraints.maxWidth - spacing * (columns - 1)) / columns,
              470.0,
            );
            final chartHeight = (constraints.maxWidth * 0.18).clamp(
              240.0,
              320.0,
            );

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header & Year Selector
                  SectionHeading(
                    title: t.stats.tabPerformance,
                    trailing: _buildYearSelector(years),
                  ),
                  const SizedBox(height: 20),

                  if (_selectedYear == 'all')
                    ..._buildGlobalContent(
                      stats,
                      wide: wide,
                      cardWidth: cardWidth,
                      chartHeight: chartHeight,
                    )
                  else
                    ..._buildSingleYearContent(
                      stats,
                      wide: wide,
                      ultra: ultra,
                      cardWidth: cardWidth,
                      chartHeight: chartHeight,
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () =>
          const SizedBox(height: 300, child: Center(child: EvolveSpinner())),
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

  /// Pairs two chart cards side by side on wide desktop layouts, stacking
  /// them on narrow ones (mirrors the dashboard two-column composition).
  Widget _chartPair(bool wide, Widget first, Widget second) {
    if (!wide) {
      return Column(children: [first, const SizedBox(height: 16), second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 18),
        Expanded(child: second),
      ],
    );
  }

  /// Ultra-wide (>= 1760) variant of [_chartPair]: three chart cards share
  /// one row so the fluid width is absorbed by charts instead of whitespace.
  Widget _chartTriple(Widget first, Widget second, Widget third) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 18),
        Expanded(child: second),
        const SizedBox(width: 18),
        Expanded(child: third),
      ],
    );
  }

  List<Widget> _buildSingleYearContent(
    Map<String, dynamic> stats, {
    required bool wide,
    required bool ultra,
    required double cardWidth,
    required double chartHeight,
  }) {
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
      // KPI + highlight cards in a single dashboard-style metric grid.
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          SizedBox(
            width: cardWidth,
            child: _buildKpiCard(
              t.common.total,
              '$totalGoals',
              LucideIcons.target,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _buildKpiCard(
              t.common.completed,
              '$completedGoals',
              LucideIcons.circleCheck,
              color: EvolveColors.success,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _buildKpiCard(
              t.macroGoals.success2,
              '$successRate%',
              LucideIcons.trophy,
              color: const Color(0xFFFBBF24),
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _buildKpiCard(
              t.stats.tabTrend,
              (trendPositive ? t.statistics.growth : t.statistics.decline),
              trendPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              color: const Color(0xFF60A5FA),
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _buildHighlightCard(
              title: t.macroGoals.strength,
              value: bestCategory,
              subtitle: '$bestCatRate% ${t.statistics.ofCompletion}',
              icon: LucideIcons.zap,
              color: const Color(0xFFA855F7),
            ),
          ),
          SizedBox(
            width: cardWidth,
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
          SizedBox(
            width: cardWidth,
            child: _buildHighlightCard(
              title: t.macroGoals.effectiveType,
              value: bestTypeLabel,
              subtitle: '$bestTypeRate% ${t.macroGoals.successRate2}',
              icon: LucideIcons.brainCircuit,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      // Chart composition: pairs on wide, and on ultra-wide content the first
      // row goes 3-up (cumulative + monthly + radar) so the remaining pair
      // (pie + quarterly) fills the second row.
      ...() {
        final cumulative = _buildAreaChartCard(
          stats['cumulative_monthly'] as List<dynamic>? ?? [],
          height: chartHeight,
        );
        final monthly = _buildMonthlyComposedCard(
          stats['monthly_composed'] as List<dynamic>? ?? [],
          height: chartHeight,
        );
        final radar = _buildCategoryRadarCard(
          stats['category_rates'] as List<dynamic>? ?? [],
          height: chartHeight,
        );
        final pie = _buildCategoryPieCard(
          stats['category_distribution'] as List<dynamic>? ?? [],
          categories,
          height: chartHeight,
        );
        final quarterly = _buildQuarterlyBarCard(
          stats['quarterly_activity'] as List<dynamic>? ?? [],
          height: chartHeight,
        );
        if (ultra) {
          return [
            _chartTriple(cumulative, monthly, radar),
            const SizedBox(height: 16),
            _chartPair(true, pie, quarterly),
          ];
        }
        return [
          _chartPair(wide, cumulative, monthly),
          const SizedBox(height: 16),
          _chartPair(wide, radar, pie),
          const SizedBox(height: 16),
          quarterly,
        ];
      }(),
      const SizedBox(height: 48),
    ];
  }

  List<Widget> _buildGlobalContent(
    Map<String, dynamic> stats, {
    required bool wide,
    required double cardWidth,
    required double chartHeight,
  }) {
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
      // Highlight cards in a single dashboard-style metric grid.
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          SizedBox(
            width: cardWidth,
            child: _buildHighlightCard(
              title: t.macroGoals.historicalTotal,
              value: '$total',
              subtitle:
                  '${t.macroGoals.from_} ${sortedYears.isNotEmpty ? sortedYears.first : '-'}',
              icon: LucideIcons.target,
              color: const Color(0xFF6366F1),
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _buildHighlightCard(
              title: t.macroGoals.globalSuccess,
              value: '$succ%',
              subtitle: '$comp ${t.macroGoals.completedGoals}',
              icon: LucideIcons.trophy,
              color: EvolveColors.success,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _buildHighlightCard(
              title: t.macroGoals.bestYear,
              value: bestYear != null ? '$bestYear' : 'N/A',
              subtitle: '$bestYearRate% completamento',
              icon: LucideIcons.calendar,
              color: const Color(0xFFD97706),
            ),
          ),
          SizedBox(
            width: cardWidth,
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

      _chartPair(
        wide,
        _buildGlobalYearProgressionCard(yearProgression, height: chartHeight),
        _buildGlobalMonthlyHistCard(
          stats['monthly_history'] as List<dynamic>? ?? [],
          height: chartHeight,
        ),
      ),
      const SizedBox(height: 16),
      _chartPair(
        wide,
        _buildCategoryRadarCard(
          stats['category_performance'] as List<dynamic>? ?? [],
          height: chartHeight,
        ),
        _buildQuarterSeasonalityCard(
          stats['seasonality'] as List<dynamic>? ?? [],
          height: chartHeight,
        ),
      ),
      const SizedBox(height: 16),
      _buildGlobalTypeDistCard(
        stats['type_distribution'] as Map<String, dynamic>? ?? {},
      ),
      const SizedBox(height: 16),
      _buildGlobalInterestEvolutionCard(
        stats['interest_evolution'] as List<dynamic>? ?? [],
        categories,
        height: chartHeight,
      ),
      const SizedBox(height: 48),
    ];
  }

  // ─── Component Builders ───────────────────────────────────────────────────

  Widget _buildYearSelector(List<int> years) {
    final String displayLabel = _selectedYear == 'all'
        ? t.macroGoals.allYears
        : _selectedYear;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showYearPicker(years),
        child: Container(
          height: 34,
          padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
          decoration: BoxDecoration(
            color: context.evolveColors.panel.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.evolveColors.border.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.calendar,
                size: 14,
                color: context.evolveColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                displayLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: context.evolveColors.foreground,
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                LucideIcons.chevronsUpDown,
                size: 13,
                color: context.evolveColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showYearPicker(List<int> years) {
    final isPro = ref.read(desktopIsProProvider);
    // Captured before the dialog builder shadows `context`; the locked-year tap
    // pops the dialog, so its own context is deactivated and can't host the
    // follow-up Pro dialog.
    final pageContext = context;

    showEvolveDialog<void>(
      context: context,
      builder: (dialogContext) => EvolveDialog(
        maxWidth: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EvolveDialogHeader(
              title: Text(t.macroGoals.selectYearHeader),
              icon: LucideIcons.calendarRange,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _YearOption(
                      label: t.macroGoals.allYears,
                      icon: LucideIcons.calendarRange,
                      selected: _selectedYear == 'all',
                      onTap: () {
                        setState(() => _selectedYear = 'all');
                        Navigator.pop(dialogContext);
                      },
                    ),
                    for (final y in years)
                      _YearOption(
                        label: '$y',
                        icon: isPro ? LucideIcons.calendar : LucideIcons.lock,
                        selected: _selectedYear == '$y',
                        locked: !isPro,
                        onTap: () {
                          if (!isPro) {
                            Navigator.pop(dialogContext);
                            if (mounted) {
                              setState(() => _selectedYear = 'all');
                              unawaited(
                                showProFeaturesDialog(pageContext, ref),
                              );
                            }
                          } else {
                            setState(() => _selectedYear = '$y');
                            Navigator.pop(dialogContext);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.02)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              EvolveIconChip(icon: icon, color: color, size: 28, iconSize: 14),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 27,
              color: context.evolveColors.foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
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
    return EvolvePanel(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
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
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.evolveColors.muted.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 13, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 27,
              color: context.evolveColors.foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
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
    return SizedBox(
      width: double.infinity,
      child: EvolvePanel(
        radius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: context.evolveColors.foreground,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.evolveColors.muted.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
            child,
          ],
        ),
      ),
    );
  }

  // ─── Chart Widgets ────────────────────────────────────────────────────────

  Widget _buildAreaChartCard(List<dynamic> stats, {required double height}) {
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
        height: height,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (value) => FlLine(
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
                color: context.evolveColors.foreground,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.evolveColors.foreground.withValues(alpha: 0.12),
                      context.evolveColors.foreground.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              LineChartBarData(
                spots: compSpots,
                isCurved: true,
                color: EvolveColors.success,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      EvolveColors.success.withValues(alpha: 0.12),
                      EvolveColors.success.withValues(alpha: 0.0),
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

  Widget _buildCategoryRadarCard(
    List<dynamic> stats, {
    required double height,
  }) {
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
        height: height,
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
            radarBorderData: BorderSide(
              color: context.evolveColors.border.withValues(alpha: 0.5),
            ),
            tickBorderData: BorderSide(
              color: context.evolveColors.border.withValues(alpha: 0.5),
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
              fontSize: 10,
              color: context.evolveColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuarterlyBarCard(List<dynamic> stats, {required double height}) {
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
              borderRadius: BorderRadius.circular(3),
            ),
            BarChartRodData(
              toY: comp,
              color: EvolveColors.success,
              width: 10,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }

    return _buildCardBase(
      title: '',
      subtitle: '',
      child: SizedBox(
        height: height,
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

  Widget _buildMonthlyComposedCard(
    List<dynamic> stats, {
    required double height,
  }) {
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
        height: height,
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
                      color: context.evolveColors.foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: '$tot\n',
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontSize: 10,
                        ),
                      ),
                      TextSpan(
                        text: '$comp',
                        style: TextStyle(
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
                color: context.evolveColors.border.withValues(alpha: 0.5),
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
    List<DesktopGoalCategory> categories, {
    required double height,
  }) {
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
              EvolveColors.subtle;
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
            // Keeps the historical 20px trim relative to the sibling charts.
            height: height - 20,
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
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: context.evolveColors.foreground,
                      ),
                    ),
                    Text(
                      'obiettivi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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
                    EvolveColors.subtle;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$perc%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

  Widget _buildGlobalYearProgressionCard(
    List<dynamic> stats, {
    required double height,
  }) {
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
                      EvolveColors.cyan,
                    ), // Attivi - Blue
                  if (fail > 0)
                    BarChartRodStackItem(
                      act,
                      act + fail,
                      EvolveColors.destructive,
                    ), // Falliti - Red
                  if (comp > 0)
                    BarChartRodStackItem(
                      act + fail,
                      act + fail + comp,
                      EvolveColors.success,
                    ), // Completati - Green
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
            height: height,
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
                          color: context.evolveColors.foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: '$act\n',
                            style: const TextStyle(
                              color: EvolveColors.cyan,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '$fail\n',
                            style: const TextStyle(
                              color: EvolveColors.destructive,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '$comp',
                            style: const TextStyle(
                              color: EvolveColors.success,
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
                    color: context.evolveColors.border.withValues(alpha: 0.5),
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
            _LegendItem(t.goalsStats.active, EvolveColors.cyan),
            _LegendItem(t.goalsStats.failed, EvolveColors.destructive),
            _LegendItem(t.common.completed, EvolveColors.success),
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
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: i.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  i.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 85,
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.evolveColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Stack(
                          children: [
                            Container(
                              height: 7,
                              color: context.evolveColors.panelSoft,
                            ),
                            FractionallySizedBox(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: maxV == 0 ? 0 : e.value / maxV,
                              child: Container(
                                height: 7,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${e.value}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.evolveColors.foreground,
                          fontWeight: FontWeight.w800,
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

  Widget _buildQuarterSeasonalityCard(
    List<dynamic> stats, {
    required double height,
  }) {
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
                if (act > 0) BarChartRodStackItem(0, act, EvolveColors.cyan),
                if (fail > 0)
                  BarChartRodStackItem(
                    act,
                    act + fail,
                    EvolveColors.destructive,
                  ),
                if (comp > 0)
                  BarChartRodStackItem(
                    act + fail,
                    act + fail + comp,
                    EvolveColors.success,
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
            height: height,
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
                          color: context.evolveColors.foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: '$act\n',
                            style: const TextStyle(
                              color: EvolveColors.cyan,
                              fontSize: 10,
                            ),
                          ),
                          TextSpan(
                            text: '$fail\n',
                            style: const TextStyle(
                              color: EvolveColors.destructive,
                              fontSize: 10,
                            ),
                          ),
                          TextSpan(
                            text: '$comp',
                            style: const TextStyle(
                              color: EvolveColors.success,
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
                    color: context.evolveColors.border.withValues(alpha: 0.5),
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
            _LegendItem(t.goalsStats.active, EvolveColors.cyan),
            _LegendItem(t.goalsStats.failed, EvolveColors.destructive),
            _LegendItem(t.goalsStats.complAbbr, EvolveColors.success),
          ]),
        ],
      ),
    );
  }

  Widget _buildGlobalMonthlyHistCard(
    List<dynamic> stats, {
    required double height,
  }) {
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
        height: height,
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
                        color: context.evolveColors.muted,
                        fontSize: 10,
                      ),
                      children: [
                        TextSpan(
                          text: '${s.y.round()}%',
                          style: const TextStyle(
                            color: EvolveColors.success,
                            fontWeight: FontWeight.w700,
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
                color: context.evolveColors.border.withValues(alpha: 0.5),
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
                color: EvolveColors.success,
                barWidth: 3,
                isCurved: true,
                curveSmoothness: 0.35,
                preventCurveOverShooting: true,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      EvolveColors.success.withValues(alpha: 0.12),
                      EvolveColors.success.withValues(alpha: 0.0),
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
    List<DesktopGoalCategory> categories, {
    required double height,
  }) {
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
            // Historically the tallest chart; never shrink below its 260px.
            height: math.max(260.0, height),
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
                    color: context.evolveColors.border.withValues(alpha: 0.5),
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

/// One selectable row of the desktop year-picker dialog: hover highlight, a
/// leading icon, the year label, and a trailing check (selected) or lock
/// (Pro-gated). Mirrors the kit's menu-item density.
class _YearOption extends StatefulWidget {
  const _YearOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  State<_YearOption> createState() => _YearOptionState();
}

class _YearOptionState extends State<_YearOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final accent = context.evolveAccent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? colors.foreground.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.selected
                    ? accent
                    : colors.muted.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    letterSpacing: -0.1,
                    color: widget.selected ? colors.foreground : colors.muted,
                  ),
                ),
              ),
              if (widget.locked)
                Icon(LucideIcons.lock, size: 14, color: colors.muted)
              else if (widget.selected)
                Icon(LucideIcons.check, size: 18, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
