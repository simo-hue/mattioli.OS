import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart'
    show MoodCorrelation, kIsoDowTokens;
import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/coach_tutorial.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum _AnalyticsScope { global, habit }

enum _GlobalTab { info, trend, alerts, habits, mood }

enum _HabitTab { overview, calendar, performance, improvement, mood }

/// UI timeframe options for the Global Trend chart. Each maps to the cloud/local
/// `timeframe_*` vocabulary consumed by [globalTrendRpcProvider] and
/// [bestHabitsRpcProvider].
enum _TrendTimeframe {
  week('timeframe_week_short'),
  month('timeframe_month_short'),
  year('timeframe_year_short'),
  all('timeframe_all');

  const _TrendTimeframe(this.token);
  final String token;
}

String _trendTimeframeLabel(_TrendTimeframe value) => switch (value) {
  _TrendTimeframe.week => t.stats.timeframeWeek,
  _TrendTimeframe.month => t.stats.timeframeMonth,
  _TrendTimeframe.year => t.stats.timeframeYear,
  _TrendTimeframe.all => t.stats.timeframeAll,
};

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  _AnalyticsScope _scope = _AnalyticsScope.global;
  _GlobalTab _globalTab = _GlobalTab.info;
  _HabitTab _habitTab = _HabitTab.overview;
  _TrendTimeframe _trendTimeframe = _TrendTimeframe.week;
  String? _habitId;

  // First-run coach-mark tour (wires the previously-dead statsTutorialProvider).
  bool _showTour = false;
  bool _didFinishTour = false;
  int _tourIndex = 0;
  final _filterKey = GlobalKey();
  final _tabsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didFinishTour) return;
      if (!ref.read(statsTutorialProvider)) {
        setState(() {
          _tourIndex = 0;
          _showTour = true;
        });
      }
    });
  }

  List<CoachStep> _statsTourSteps() => [
    CoachStep(
      targetKey: _filterKey,
      title: t.tutorial.filterByHabit,
      description: t.tutorial.filterHabitDesc,
    ),
    CoachStep(
      targetKey: _tabsKey,
      title: t.tutorial.statisticsSections,
      description: t.tutorial.statsSectionsDesc,
    ),
  ];

  void _finishStatsTour() {
    if (!mounted || _didFinishTour) return;
    setState(() {
      _didFinishTour = true;
      _showTour = false;
    });
    ref.read(statsTutorialProvider.notifier).setTutorialSeen(true);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(dashboardControllerProvider);
    final selectedHabit = snapshot.habits.isEmpty
        ? null
        : snapshot.habits.firstWhere(
            (habit) => habit.id == (_habitId ?? snapshot.habits.first.id),
            orElse: () => snapshot.habits.first,
          );

    final page = DesktopPage(
      title: t.stats.title,
      subtitle: t.stats.pageSubtitle,
      trailing: StatusPill(
        label: t.stats.last30Days,
        icon: LucideIcons.calendarClock,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: _filterKey,
            child: _AnalyticsToolbar(
              scope: _scope,
              habits: snapshot.habits,
              selectedHabit: selectedHabit,
              onScopeChanged: (scope) => setState(() => _scope = scope),
              onHabitChanged: (id) => setState(() => _habitId = id),
            ),
          ),
          const SizedBox(height: 12),
          if (_scope == _AnalyticsScope.global) ...[
            KeyedSubtree(
              key: _tabsKey,
              child: _TabSelector<_GlobalTab>(
                selected: _globalTab,
                values: _GlobalTab.values,
                labelFor: _globalTabLabel,
                onChanged: (tab) => setState(() => _globalTab = tab),
              ),
            ),
            const SizedBox(height: 18),
            _globalContent(snapshot),
          ] else ...[
            KeyedSubtree(
              key: _tabsKey,
              child: _TabSelector<_HabitTab>(
                selected: _habitTab,
                values: _HabitTab.values,
                labelFor: _habitTabLabel,
                onChanged: (tab) => setState(() => _habitTab = tab),
              ),
            ),
            const SizedBox(height: 18),
            if (selectedHabit == null)
              const _EmptyHabitAnalytics()
            else
              _habitContent(selectedHabit, snapshot),
          ],
        ],
      ),
    );

    return Stack(
      children: [
        page,
        if (_showTour && !_didFinishTour)
          CoachTutorialOverlay(
            steps: _statsTourSteps(),
            index: _tourIndex,
            onIndexChanged: (i) => setState(() => _tourIndex = i),
            onFinish: _finishStatsTour,
            backLabel: t.tutorial.back,
            nextLabel: t.tutorial.next,
            finishLabel: t.tutorial.finish,
          ),
      ],
    );
  }

  Widget _globalContent(DashboardSnapshot snapshot) => switch (_globalTab) {
    _GlobalTab.info => _GlobalInfo(snapshot: snapshot),
    _GlobalTab.trend => _GlobalTrend(
      snapshot: snapshot,
      timeframe: _trendTimeframe,
      onTimeframeChanged: (value) => setState(() => _trendTimeframe = value),
    ),
    _GlobalTab.alerts => _GlobalAlerts(snapshot: snapshot),
    _GlobalTab.habits => _GlobalHabits(snapshot: snapshot),
    _GlobalTab.mood => _GlobalMood(snapshot: snapshot),
  };

  Widget _habitContent(DashboardHabit habit, DashboardSnapshot snapshot) =>
      switch (_habitTab) {
        _HabitTab.overview => _HabitOverview(habit: habit, snapshot: snapshot),
        _HabitTab.calendar => _HabitCalendar(habit: habit, snapshot: snapshot),
        _HabitTab.performance => _HabitPerformance(
          habit: habit,
          snapshot: snapshot,
        ),
        _HabitTab.improvement => _HabitImprovement(
          habit: habit,
          snapshot: snapshot,
        ),
        _HabitTab.mood => _HabitMood(habit: habit, snapshot: snapshot),
      };
}

class _AnalyticsToolbar extends StatelessWidget {
  const _AnalyticsToolbar({
    required this.scope,
    required this.habits,
    required this.selectedHabit,
    required this.onScopeChanged,
    required this.onHabitChanged,
  });

  final _AnalyticsScope scope;
  final List<DashboardHabit> habits;
  final DashboardHabit? selectedHabit;
  final ValueChanged<_AnalyticsScope> onScopeChanged;
  final ValueChanged<String> onHabitChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scopeControl = EvolveSegmentedControl<_AnalyticsScope>(
          height: 44,
          segments: {
            _AnalyticsScope.global: t.stats.global,
            _AnalyticsScope.habit: t.stats.singleHabit,
          },
          selected: scope,
          onSelected: onScopeChanged,
        );
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              _buildSelectorCard(context),
              const SizedBox(height: 10),
              scopeControl,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _buildSelectorCard(context)),
            const SizedBox(width: 12),
            SizedBox(width: 300, child: scopeControl),
          ],
        );
      },
    );
  }

  /// Mobile's "All Habits" selector card: translucent card with a target icon
  /// chip tinted by the selected habit color, a bold 15/w700 title and a muted
  /// disclosure chevron (provided by the embedded dropdown in habit scope).
  Widget _buildSelectorCard(BuildContext context) {
    final colors = context.evolveColors;
    final isHabitScope = scope == _AnalyticsScope.habit;
    final tint = isHabitScope && selectedHabit != null
        ? selectedHabit!.color
        : colors.foreground;
    final titleStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: colors.foreground,
    );

    return EvolvePanel(
      color: colors.panel.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          EvolveIconChip(
            icon: LucideIcons.target,
            color: tint,
            size: 34,
            iconSize: 16,
          ),
          const SizedBox(width: 12),
          if (!isHabitScope)
            Expanded(
              child: Text(
                t.stats.global,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            )
          else ...[
            Expanded(
              child: selectedHabit == null
                  ? Text(
                      t.stats.noHabit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle.copyWith(color: colors.muted),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedHabit!.id,
                        isExpanded: true,
                        isDense: true,
                        icon: Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: colors.muted,
                        ),
                        dropdownColor: colors.panelRaised,
                        borderRadius: BorderRadius.circular(14),
                        focusColor: Colors.transparent,
                        style: titleStyle,
                        items: [
                          for (final habit in habits)
                            DropdownMenuItem(
                              value: habit.id,
                              child: Text(
                                habit.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          if (id != null) onHabitChanged(id);
                        },
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            const StatusPill(
              label: 'Evolve Pro',
              color: EvolveColors.amber,
              icon: LucideIcons.sparkles,
            ),
          ],
        ],
      ),
    );
  }
}

class _TabSelector<T> extends StatelessWidget {
  const _TabSelector({
    required this.selected,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final T selected;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return EvolveSegmentedControl<T>(
      height: 44,
      segments: {for (final value in values) value: labelFor(value)},
      selected: selected,
      onSelected: onChanged,
    );
  }
}

/// 22/w800 card heading with a muted subtitle, matching mobile's feature-card
/// headings ("Performance Evolution").
class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.evolveColors.muted.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _GlobalInfo extends ConsumerWidget {
  const _GlobalInfo({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final criticalDay =
        ref.watch(globalCriticalDayRpcProvider).value ?? _criticalDay(snapshot);
    return Column(
      children: [
        _MetricGrid(
          tiles: [
            _Metric(
              label: t.stats.completionToday,
              value: '${(snapshot.completionRate * 100).round()}%',
              detail: t.stats.actionsFraction(
                done: snapshot.completedHabits,
                total: snapshot.totalHabits,
              ),
              color: context.evolveAccent,
              icon: LucideIcons.activity,
            ),
            _Metric(
              label: t.stats.bestStreakLabel,
              value: t.dashboard.streakDaysShort(n: snapshot.bestStreak),
              detail: _bestHabit(snapshot),
              color: EvolveColors.amber,
              icon: LucideIcons.flame,
            ),
            _Metric(
              label: t.stats.criticalDay,
              value: _criticalDayLabel(criticalDay),
              detail: t.stats.completePrioritiesFirst,
              color: EvolveColors.rose,
              icon: LucideIcons.circleAlert,
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final heatmap = _HeatmapPanel(
              title: t.stats.recentActivity,
              subtitle: t.stats.recentActivitySubtitle,
              values: _activityValues(snapshot, 90),
            );
            final correlations = _CorrelationPanel(snapshot: snapshot);
            if (constraints.maxWidth < 1120) {
              return Column(
                children: [heatmap, const SizedBox(height: 18), correlations],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: heatmap),
                const SizedBox(width: 18),
                SizedBox(width: 350, child: correlations),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GlobalTrend extends ConsumerWidget {
  const _GlobalTrend({
    required this.snapshot,
    required this.timeframe,
    required this.onTimeframeChanged,
  });

  final DashboardSnapshot snapshot;
  final _TrendTimeframe timeframe;
  final ValueChanged<_TrendTimeframe> onTimeframeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rpcTrend = ref.watch(globalTrendRpcProvider(timeframe.token)).value;
    final trend = _rpcTrendPoints(
      rpcTrend ?? const [],
      snapshot.trend,
      timeframe,
    );
    final best = ref.watch(bestHabitsRpcProvider(timeframe.token)).value;
    final critical = ref.watch(criticalHabitsRpcProvider).value;
    final delta = _trendDelta(trend);
    final average = trend.isEmpty
        ? 0.0
        : trend.fold<double>(0, (sum, point) => sum + point.value) /
              trend.length;
    final bestValue = _resolveHabitTitle(
      snapshot,
      best?.firstOrNull?['goal_id'] as String?,
      fallback: _bestHabit(snapshot),
    );
    final criticalValue = _resolveHabitTitle(
      snapshot,
      critical?.firstOrNull?['goal_id'] as String?,
      fallback: _criticalHabit(snapshot),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumns = constraints.maxWidth >= 1120;
        final hero = _TrendHeroCard(
          trend: trend,
          average: average,
          delta: delta,
          timeframe: timeframe,
          onTimeframeChanged: onTimeframeChanged,
          chartHeight: useColumns ? 280 : 240,
          footer: useColumns
              ? null
              : Row(
                  children: [
                    Expanded(
                      child: _InlineInsight(
                        title: t.stats.bestHabit,
                        value: bestValue,
                        color: context.evolveAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InlineInsight(
                        title: t.stats.criticalArea,
                        value: criticalValue,
                        color: EvolveColors.rose,
                      ),
                    ),
                  ],
                ),
        );
        if (!useColumns) return hero;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: hero),
            const SizedBox(width: 18),
            SizedBox(
              width: 350,
              child: Column(
                children: [
                  _TrendInsightCard(
                    icon: LucideIcons.trophy,
                    color: context.evolveAccent,
                    label: t.stats.bestHabit,
                    value: bestValue,
                  ),
                  const SizedBox(height: 14),
                  _TrendInsightCard(
                    icon: LucideIcons.circleAlert,
                    color: EvolveColors.rose,
                    label: t.stats.criticalArea,
                    value: criticalValue,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The Performance-Evolution hero card: 22/w800 heading with the timeframe
/// segmented control in the header row (own line on narrow cards), the big
/// w900 average with its trend pill and the white fl_chart line underneath.
class _TrendHeroCard extends StatelessWidget {
  const _TrendHeroCard({
    required this.trend,
    required this.average,
    required this.delta,
    required this.timeframe,
    required this.onTimeframeChanged,
    required this.chartHeight,
    this.footer,
  });

  final List<TrendPoint> trend;
  final double average;
  final double delta;
  final _TrendTimeframe timeframe;
  final ValueChanged<_TrendTimeframe> onTimeframeChanged;
  final double chartHeight;

  /// Extra content below the chart (the inline-insight row on stacked
  /// layouts); wide layouts move the insights to the right rail instead.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final heading = _CardHeading(
      title: t.stats.trendGlobal,
      subtitle: t.stats.trendGlobalSubtitle,
    );
    final selector = _TrendTimeframeSelector(
      selected: timeframe,
      onChanged: onTimeframeChanged,
    );
    return EvolvePanel(
      radius: 20,
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inlineSelector = constraints.maxWidth >= 620;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inlineSelector)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 14),
                    SizedBox(width: 300, child: selector),
                  ],
                )
              else ...[
                heading,
                const SizedBox(height: 18),
                selector,
              ],
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(average * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1,
                      color: context.evolveColors.foreground,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: StatusPill(
                      label: t.stats.vsPrevDay(value: (delta * 100).round()),
                      color: delta >= 0
                          ? EvolveColors.success
                          : EvolveColors.destructive,
                      icon: delta >= 0
                          ? LucideIcons.trendingUp
                          : LucideIcons.trendingDown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: chartHeight,
                child: trend.isEmpty
                    ? const SizedBox.shrink()
                    : _TrendLineChart(points: trend),
              ),
              if (footer != null) ...[const SizedBox(height: 20), footer!],
            ],
          );
        },
      ),
    );
  }
}

/// Right-rail counterpart of [_InlineInsight]: a small panel with an icon
/// chip, uppercase micro-label and the w800 insight value.
class _TrendInsightCard extends StatelessWidget {
  const _TrendInsightCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Row(
        children: [
          EvolveIconChip(icon: icon, color: color, size: 38, iconSize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: context.evolveColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile's Performance Evolution chart: white ~3px curved line, no point
/// dots, faint foreground area gradient, muted 10px axis labels and 0.5-alpha
/// horizontal gridlines.
class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final line = colors.foreground;
    final axisStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: colors.muted,
    );
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].value.clamp(0.0, 1.0) * 100),
    ];
    final maxX = points.length < 2 ? 1.0 : (points.length - 1).toDouble();
    final labelInterval = ((points.length + 6) ~/ 7).clamp(1, 1000).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colors.border.withValues(alpha: 0.5),
            strokeWidth: 1,
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
              reservedSize: 38,
              interval: 25,
              getTitlesWidget: (value, meta) =>
                  Text('${value.toInt()}%', style: axisStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: labelInterval,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(points[index].label, style: axisStyle),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => colors.panelRaised,
            getTooltipItems: (touchedSpots) => [
              for (final spot in touchedSpots)
                LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)}%',
                  TextStyle(
                    color: colors.foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: line,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  line.withValues(alpha: 0.12),
                  line.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendTimeframeSelector extends StatelessWidget {
  const _TrendTimeframeSelector({
    required this.selected,
    required this.onChanged,
  });

  final _TrendTimeframe selected;
  final ValueChanged<_TrendTimeframe> onChanged;

  @override
  Widget build(BuildContext context) {
    return EvolveSegmentedControl<_TrendTimeframe>(
      height: 40,
      segments: {
        for (final value in _TrendTimeframe.values)
          value: _trendTimeframeLabel(value),
      },
      selected: selected,
      onSelected: onChanged,
    );
  }
}

class _GlobalAlerts extends ConsumerWidget {
  const _GlobalAlerts({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(habitStatsRpcProvider).value ?? const [];
    final analytics =
        ref.watch(habitAnalyticsRpcProvider).value ??
        const <String, Map<String, dynamic>>{};

    final improvement = _improvementAreas(snapshot, stats, analytics);
    final failures = _failureAnalysis(snapshot, stats);
    final recovery = _recoveryPatterns(snapshot, analytics);

    if (improvement.isEmpty && failures.isEmpty && recovery.isEmpty) {
      return EvolvePanel(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Center(
          child: Text(
            t.statistics.noDataForAlerts,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final sections = <Widget>[
      if (improvement.isNotEmpty)
        _AlertsSection(
          icon: LucideIcons.target,
          iconColor: context.evolveColors.foreground,
          title: t.statistics.improvementAreas,
          subtitle: t.statistics.habitsRequiringMoreAttention,
          children: [
            for (final area in improvement) _ImprovementCard(area: area),
          ],
        ),
      if (failures.isNotEmpty)
        _AlertsSection(
          icon: LucideIcons.chartBar,
          iconColor: EvolveColors.amber,
          title: t.statistics.failureAnalysis,
          subtitle: t.statistics.missedDaysPattern,
          children: [
            for (final failure in failures) _FailureCard(failure: failure),
          ],
        ),
      if (recovery.isNotEmpty)
        _AlertsSection(
          icon: LucideIcons.calendarClock,
          iconColor: context.evolveColors.foreground,
          title: t.statistics.recoveryPatterns,
          subtitle: t.statistics.recoverySpeed,
          children: [for (final item in recovery) _RecoveryCard(item: item)],
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide: all section cards in one 18px-gapped row of equal columns.
        if (constraints.maxWidth >= 1120) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(width: 18),
                Expanded(child: sections[i]),
              ],
            ],
          );
        }
        // Mid: 2-up rows with the remainder full-width below.
        if (constraints.maxWidth >= 760) {
          return Column(
            children: [
              for (var i = 0; i < sections.length; i += 2) ...[
                if (i > 0) const SizedBox(height: 18),
                if (i + 1 < sections.length)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: sections[i]),
                      const SizedBox(width: 18),
                      Expanded(child: sections[i + 1]),
                    ],
                  )
                else
                  sections[i],
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              sections[i],
            ],
          ],
        );
      },
    );
  }
}

/// Alert-tab section card: icon chip + 16/w700 title and a muted 13px
/// subtitle in the panel header, then the item cards — stacked when the
/// panel is a narrow column, side by side when it spans the full page width
/// (mobile shows them as a swipe carousel).
class _AlertsSection extends StatelessWidget {
  const _AlertsSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EvolveIconChip(
                icon: icon,
                color: iconColor,
                size: 34,
                iconSize: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.evolveColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.evolveColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700 || children.length == 1) {
                return Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      children[i],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(child: children[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Raised inner card for items nested inside a section panel — same recipe
/// as [_InlineInsight] (panelRaised fill, radius 12, half-alpha border).
class _RaisedCard extends StatelessWidget {
  const _RaisedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.evolveColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}

/// Small colored habit dot used as the leading marker of alert cards.
class _HabitDot extends StatelessWidget {
  const _HabitDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Uppercase 10px micro-label above a bold semantic-colored value
/// ("WORST STREAK" / "FREQUENCY" on mobile's alert cards).
class _MicroStat extends StatelessWidget {
  const _MicroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: context.evolveColors.muted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Mobile's improvement-area card: habit dot + title, red success rate at the
/// trailing edge and the "BLACK DAY" micro-stat underneath.
class _ImprovementCard extends StatelessWidget {
  const _ImprovementCard({required this.area});

  final _ImprovementArea area;

  @override
  Widget build(BuildContext context) {
    return _RaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HabitDot(color: area.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  area.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.evolveColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.stats.successRate(rate: area.rate),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: EvolveColors.destructive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.circleAlert,
                size: 14,
                color: EvolveColors.destructive,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.statistics.blackDay,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: EvolveColors.destructive,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      area.day,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.evolveColors.foreground,
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

/// Mobile's failure-analysis card: habit dot + title with the WORST STREAK /
/// FREQUENCY micro-stats row underneath.
class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure});

  final _FailureItem failure;

  @override
  Widget build(BuildContext context) {
    return _RaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HabitDot(color: failure.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  failure.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.evolveColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MicroStat(
                label: t.statistics.worstStreak,
                value: '${failure.worstStreak} ${t.statistics.daysShortUnit}',
                color: EvolveColors.destructive,
              ),
              _MicroStat(
                label: t.statistics.frequency,
                value: '~${failure.frequency}/${t.statistics.perMonthUnit}',
                color: EvolveColors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.item});

  final _RecoveryItem item;

  @override
  Widget build(BuildContext context) {
    return _RaisedCard(
      child: Row(
        children: [
          _HabitDot(color: item.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.evolveColors.foreground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t.stats.recoveryDetail(days: item.days),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.evolveColors.muted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _HabitSort { rate, streak, name }

class _GlobalHabits extends ConsumerStatefulWidget {
  const _GlobalHabits({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  ConsumerState<_GlobalHabits> createState() => _GlobalHabitsState();
}

class _GlobalHabitsState extends ConsumerState<_GlobalHabits> {
  _HabitSort _sort = _HabitSort.rate;

  String _sortLabel(_HabitSort s) => switch (s) {
    _HabitSort.rate => t.stats.sortRate,
    _HabitSort.streak => t.stats.sortStreak,
    _HabitSort.name => t.stats.sortName,
  };

  int _compare(Map<String, dynamic> a, Map<String, dynamic> b) =>
      switch (_sort) {
        _HabitSort.rate => ((b['rate'] as num?) ?? 0).compareTo(
          (a['rate'] as num?) ?? 0,
        ),
        _HabitSort.streak => ((b['best_streak'] as num?) ?? 0).compareTo(
          (a['best_streak'] as num?) ?? 0,
        ),
        _HabitSort.name =>
          ((a['title'] as String?) ?? '').toLowerCase().compareTo(
            ((b['title'] as String?) ?? '').toLowerCase(),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(habitStatsRpcProvider);
    final habitsById = {for (final h in widget.snapshot.habits) h.id: h};

    return EvolvePanel(
      radius: 20,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = _CardHeading(
                title: t.stats.performancePerHabit,
                subtitle: t.stats.performancePerHabitSubtitle,
              );
              final sortControl = EvolveSegmentedControl<_HabitSort>(
                segments: {for (final s in _HabitSort.values) s: _sortLabel(s)},
                selected: _sort,
                onSelected: (s) => setState(() => _sort = s),
              );
              if (constraints.maxWidth < 640) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: sortControl,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 14),
                  SizedBox(width: 340, child: sortControl),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          statsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(
              t.stats.createHabitForAnalysis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Text(
                  t.stats.createHabitForAnalysis,
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }
              final sorted = [...rows]..sort(_compare);
              return Column(
                children: [
                  for (final row in sorted) ...[
                    _HabitStatsRow(
                      row: row,
                      color:
                          habitsById[row['goal_id']]?.color ??
                          context.evolveAccent,
                    ),
                    if (row != sorted.last)
                      Divider(
                        height: 8,
                        color: context.evolveColors.border.withValues(
                          alpha: 0.5,
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HabitStatsRow extends StatefulWidget {
  const _HabitStatsRow({required this.row, required this.color});

  final Map<String, dynamic> row;
  final Color color;

  @override
  State<_HabitStatsRow> createState() => _HabitStatsRowState();
}

class _HabitStatsRowState extends State<_HabitStatsRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final rate = ((widget.row['rate'] as num?) ?? 0).toDouble();
    final best = ((widget.row['best_streak'] as num?) ?? 0).toInt();
    final worst = ((widget.row['worst_streak'] as num?) ?? 0).toInt();
    final title = (widget.row['title'] as String?) ?? '';
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered
              ? context.evolveColors.panelRaised
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _HabitDot(color: widget.color),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: context.evolveColors.foreground,
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: LinearProgressIndicator(
                value: (rate / 100).clamp(0, 1),
                minHeight: 6,
                color: widget.color,
                backgroundColor: context.evolveColors.panelSoft,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 42,
              child: Text(
                '${rate.round()}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.evolveColors.foreground,
                ),
              ),
            ),
            const SizedBox(width: 16),
            _StatBadge(
              label: t.stats.bestStreakLabel,
              value: '$best',
              color: EvolveColors.amber,
            ),
            const SizedBox(width: 12),
            _StatBadge(
              label: t.stats.worstStreakLabel,
              value: '$worst',
              color: EvolveColors.rose,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: context.evolveColors.muted.withValues(alpha: 0.8),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _GlobalMood extends StatelessWidget {
  const _GlobalMood({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final moods = snapshot.moods.values.toList();
    final averageMood = _averageCheckIn(moods, (mood) => mood.mood);
    final averageEnergy = _averageCheckIn(moods, (mood) => mood.energy);
    return Column(
      children: [
        _MetricGrid(
          tiles: [
            _Metric(
              label: t.stats.avgMood,
              value: '${averageMood.toStringAsFixed(1)}/10',
              detail: t.stats.checkInsAvailable(count: moods.length),
              color: EvolveColors.violet,
              icon: LucideIcons.smile,
            ),
            _Metric(
              label: t.stats.avgEnergy,
              value: '${averageEnergy.toStringAsFixed(1)}/10',
              detail: t.stats.checkInsAvailable(count: moods.length),
              color: EvolveColors.amber,
              icon: LucideIcons.zap,
            ),
            _Metric(
              label: t.stats.resilientHabit,
              value: _bestHabit(snapshot),
              detail: t.stats.completedEvenHardDays,
              color: context.evolveAccent,
              icon: LucideIcons.heartPulse,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _HeatmapPanel(
          title: t.stats.moodEnergy,
          subtitle: t.stats.moodEnergySubtitle,
          color: EvolveColors.violet,
          values: _moodValues(snapshot, 90),
        ),
      ],
    );
  }
}

class _HabitOverview extends ConsumerWidget {
  const _HabitOverview({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(habitStatsRpcProvider).value ?? const [];
    final stat = stats.where((s) => s['goal_id'] == habit.id).firstOrNull ?? {};
    final grid = ref.watch(habitYearlyGridRpcProvider(habit.id)).value;
    final last30 = grid == null
        ? const <int>[]
        : (grid.length >= 30 ? grid.sublist(grid.length - 30) : grid);

    final completionRate = (stat['rate'] as num?)?.round() ?? 0;
    final currentStreak =
        (stat['current_streak'] as num?)?.toInt() ?? habit.streak;
    final totalCompletions = (stat['total_completions'] as num?)?.toInt() ?? 0;
    final totalActiveDays = (stat['total_active_days'] as num?)?.toInt() ?? 1;
    final missedDays = (stat['missed_days'] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        _MetricGrid(
          tiles: [
            _Metric(
              label: t.stats.completion,
              value: '$completionRate%',
              detail: t.stats.actionsFraction(
                done: totalCompletions,
                total: totalActiveDays,
              ),
              color: habit.color,
              icon: LucideIcons.target,
            ),
            _Metric(
              label: t.stats.currentStreak,
              value: t.dashboard.streakDaysShort(n: currentStreak),
              detail: t.stats.currentStreakDetail,
              color: EvolveColors.amber,
              icon: LucideIcons.flame,
            ),
            _Metric(
              label: t.statistics.missed,
              value: '$missedDays',
              detail: t.stats.trend30Detail,
              color: EvolveColors.rose,
              icon: LucideIcons.circleAlert,
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final grid = _Last30DaysGrid(statuses: last30);
            final correlations = _HabitCorrelationsPanel(
              habit: habit,
              snapshot: snapshot,
            );
            if (constraints.maxWidth < 1120) {
              return Column(
                children: [grid, const SizedBox(height: 18), correlations],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: grid),
                const SizedBox(width: 18),
                SizedBox(width: 350, child: correlations),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The last-30-day pass/fail grid (done=green, missed=red, other=grey),
/// mirroring mobile's `_TrendUltimi30Giorni`. Fed from the yearly-grid slice.
class _Last30DaysGrid extends StatelessWidget {
  const _Last30DaysGrid({required this.statuses});

  final List<int> statuses;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.last30DaysTrend,
            subtitle: t.stats.trend30Detail,
          ),
          const SizedBox(height: 16),
          if (statuses.isEmpty)
            Text(
              t.stats.moreLogsNeeded,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final status in statuses)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: switch (status) {
                        1 => const Color(0xFF10B981),
                        2 => EvolveColors.rose,
                        _ => context.evolveColors.panelSoft,
                      },
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _GridLegend(
                  color: const Color(0xFF10B981),
                  label: t.statistics.completed2,
                ),
                _GridLegend(
                  color: EvolveColors.rose,
                  label: t.statistics.notCompleted,
                ),
                _GridLegend(
                  color: context.evolveColors.panelSoft,
                  label: t.statistics.skipped,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GridLegend extends StatelessWidget {
  const _GridLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Yearly per-day statuses for a habit (1=done, 2=missed, 0=untracked) over the
/// last 365 days — the same encoding as `computeYearlyGrid`, derived from the
/// snapshot when the RPC/local grid isn't available.
List<int> _habitYearlyStatuses(DashboardSnapshot snapshot, String habitId) {
  final today = DateTime.now();
  final start = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(const Duration(days: 364));
  return [
    for (var i = 0; i < 365; i++)
      switch (snapshot.habitStatusFor(habitId, start.add(Duration(days: i)))) {
        'done' => 1,
        'missed' => 2,
        _ => 0,
      },
  ];
}

class _HabitCalendar extends ConsumerWidget {
  const _HabitCalendar({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearlyGrid = ref.watch(habitYearlyGridRpcProvider(habit.id)).value;
    final statuses = (yearlyGrid == null || yearlyGrid.isEmpty)
        ? _habitYearlyStatuses(snapshot, habit.id)
        : yearlyGrid;
    return _YearlyHabitHeatmap(
      title: t.stats.yearlyCalendar,
      subtitle: t.stats.yearlyCalendarSubtitle(habit: habit.title),
      color: habit.color,
      statuses: statuses,
    );
  }
}

/// Yearly heatmap that distinguishes **completed** (habit color), **missed**
/// (rose) and **untracked** (faint), with a completed/missed/rate summary —
/// mirrors mobile's calendar tab (the old panel collapsed missed into untracked
/// and lost the red-miss + summary).
class _YearlyHabitHeatmap extends StatelessWidget {
  const _YearlyHabitHeatmap({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.statuses,
  });

  final String title;
  final String subtitle;
  final Color color;
  final List<int> statuses;

  @override
  Widget build(BuildContext context) {
    final completed = statuses.where((s) => s == 1).length;
    final missed = statuses.where((s) => s == 2).length;
    final tracked = completed + missed;
    final rate = tracked == 0 ? 0 : (completed * 100 / tracked).round();

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: title, subtitle: subtitle),
          const SizedBox(height: 14),
          Row(
            children: [
              _CalendarSummaryStat(
                value: '$completed',
                label: t.statistics.completed2,
                color: color,
              ),
              const SizedBox(width: 24),
              _CalendarSummaryStat(
                value: '$missed',
                label: t.statistics.notCompleted,
                color: EvolveColors.rose,
              ),
              const Spacer(),
              StatusPill(label: t.stats.successRate(rate: rate)),
            ],
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final s in statuses)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: switch (s) {
                      1 => color,
                      2 => EvolveColors.rose.withValues(alpha: 0.85),
                      _ => context.evolveColors.panelSoft,
                    },
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarSummaryStat extends StatelessWidget {
  const _CalendarSummaryStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: context.evolveColors.muted.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Real per-habit co-completion correlations from [habitCorrelationsRpcProvider]
/// (mirrors mobile's `_CorrelazioniSection`): positive (>= 50%) and negative
/// (< 50%) partners, each resolved to its habit title.
class _HabitCorrelationsPanel extends ConsumerWidget {
  const _HabitCorrelationsPanel({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows =
        ref.watch(habitCorrelationsRpcProvider(habit.id)).value ?? const [];
    final resolved = <({String title, int percentage})>[];
    for (final row in rows) {
      final otherId = row['goal_id'] as String?;
      if (otherId == null) continue;
      final title = _habitTitleFor(snapshot, otherId);
      if (title == null) continue;
      resolved.add((
        title: title,
        percentage: (row['percentage'] as num?)?.toInt() ?? 0,
      ));
    }
    final positives = resolved.where((c) => c.percentage >= 50).toList()
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
    final negatives = resolved.where((c) => c.percentage < 50).toList()
      ..sort((a, b) => a.percentage.compareTo(b.percentage));

    return EvolvePanel(
      glowColor: EvolveColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EvolveIconChip(
            icon: LucideIcons.brain,
            color: EvolveColors.violet,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(height: 13),
          SectionHeading(
            title: t.statistics.correlationsWith,
            subtitle: t.statistics.howThisHabitRelatesToOthers,
          ),
          const SizedBox(height: 16),
          if (resolved.isEmpty)
            Text(
              t.stats.moreLogsNeeded,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else ...[
            Text(
              t.statistics.positiveCorrelations,
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 10),
            if (positives.isEmpty)
              Text(
                t.statistics.noSignificantPositiveCorrelation,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (final c in positives.take(3)) ...[
                _InlineInsight(
                  title: c.title,
                  value: t.stats.togetherProbability(percentage: c.percentage),
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 14),
            Text(
              t.statistics.negativeCorrelations,
              style: const TextStyle(
                color: EvolveColors.rose,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 10),
            if (negatives.isEmpty)
              Text(
                t.statistics.noSignificantNegativeCorrelation,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (final c in negatives.take(3)) ...[
                _InlineInsight(
                  title: c.title,
                  value: t.stats.togetherProbability(percentage: c.percentage),
                  color: EvolveColors.rose,
                ),
                const SizedBox(height: 8),
              ],
          ],
        ],
      ),
    );
  }
}

class _HabitPerformance extends ConsumerWidget {
  const _HabitPerformance({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const labels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    final rpc =
        ref.watch(habitPerformanceRpcProvider(habit.id)).value ?? const [];
    final extremes = _weekdayExtremes(rpc);

    final bars = EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.performancePerDay,
            subtitle: t.stats.performancePerDaySubtitle,
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < labels.length; index++) ...[
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.evolveColors.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: _rpcWeekdayCompletion(
                      rpc,
                      index + 1,
                      fallback: _habitWeekdayCompletion(
                        snapshot,
                        habit.id,
                        index + 1,
                      ),
                    ),
                    minHeight: 7,
                    color: habit.color,
                    backgroundColor: context.evolveColors.panelSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(_rpcWeekdayCompletion(rpc, index + 1, fallback: _habitWeekdayCompletion(snapshot, habit.id, index + 1)) * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.evolveColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            if (index < labels.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
    final highlights = <Widget>[
      if (extremes.strongest != null)
        _AlertCard(
          title:
              '${t.statistics.strongestDay}: ${_weekdayName(extremes.strongest!.dow)}',
          detail: t.stats.strongestDayDetail(
            pct: extremes.strongest!.pct,
            done: extremes.strongest!.done,
            total: extremes.strongest!.total,
          ),
          color: context.evolveAccent,
          icon: LucideIcons.trophy,
        ),
      if (extremes.weakest != null)
        _AlertCard(
          title:
              '${t.statistics.weakestDay}: ${_weekdayName(extremes.weakest!.dow)}',
          detail: t.stats.weakestDayDetail(
            pct: extremes.weakest!.pct,
            done: extremes.weakest!.done,
            total: extremes.weakest!.total,
          ),
          color: EvolveColors.rose,
          icon: LucideIcons.circleAlert,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1120 || highlights.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bars,
              for (final card in highlights) ...[
                const SizedBox(height: 12),
                card,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: bars),
            const SizedBox(width: 18),
            SizedBox(
              width: 350,
              child: Column(
                children: [
                  for (var i = 0; i < highlights.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    highlights[i],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

typedef _DayPerf = ({int dow, int pct, int done, int total});

/// Strongest/weakest weekday from performance-by-day rows. Mirrors mobile's
/// `HabitPerformanceTabWidget` (strongest = highest pct, weakest = lowest;
/// weakest suppressed when it ties the strongest).
({_DayPerf? strongest, _DayPerf? weakest}) _weekdayExtremes(
  List<Map<String, dynamic>> rows,
) {
  final active = <_DayPerf>[];
  for (final row in rows) {
    final total = (row['total_count'] as num?)?.toInt() ?? 0;
    if (total <= 0) continue;
    final done = (row['done_count'] as num?)?.toInt() ?? 0;
    active.add((
      dow: (row['day_index'] as num?)?.toInt() ?? 1,
      pct: (done / total * 100).round(),
      done: done,
      total: total,
    ));
  }
  if (active.isEmpty) return (strongest: null, weakest: null);
  final strongest = active.reduce((a, b) => a.pct >= b.pct ? a : b);
  final weakest = active.reduce((a, b) => a.pct <= b.pct ? a : b);
  return (
    strongest: strongest,
    weakest: strongest.pct == weakest.pct ? null : weakest,
  );
}

class _HabitImprovement extends ConsumerWidget {
  const _HabitImprovement({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(habitAlertsRpcProvider(habit.id)).value ?? const {};
    final worstNegativeDays =
        (alert['worst_negative_days'] as num?)?.toInt() ?? 0;
    final worstStart = DateTime.tryParse(
      alert['worst_negative_start'] as String? ?? '',
    );
    final broken = <({int days, DateTime date})>[];
    for (final raw in (alert['broken_streaks'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final date = DateTime.tryParse(raw['date'] as String? ?? '');
      if (date == null) continue;
      broken.add((days: (raw['days'] as num?)?.toInt() ?? 0, date: date));
    }

    final worstPanel = EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EvolveIconChip(
                icon: LucideIcons.trendingDown,
                color: EvolveColors.destructive,
                size: 36,
                iconSize: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.statistics.worstNegativeStreak,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$worstNegativeDays',
                style: const TextStyle(
                  color: EvolveColors.destructive,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.statistics.missedConsecutiveDays,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (worstStart != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${t.statistics.startedOn} ${_shortDate(worstStart)}',
                        style: Theme.of(context).textTheme.bodySmall,
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
    final brokenPanel = EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.statistics.brokenStreaks,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          if (broken.isEmpty)
            Text(
              t.statistics.noBrokenStreaks,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final b in broken) ...[
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: EvolveColors.destructive.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${b.days}',
                      style: const TextStyle(
                        color: EvolveColors.destructive,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.stats.brokenStreakItem(days: b.days),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: context.evolveColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _shortDate(b.date),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1120) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [worstPanel, const SizedBox(height: 16), brokenPanel],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: worstPanel),
            const SizedBox(width: 18),
            Expanded(child: brokenPanel),
          ],
        );
      },
    );
  }
}

String _shortDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _HabitMood extends ConsumerWidget {
  const _HabitMood({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correlations =
        ref.watch(moodCorrelationsRpcProvider).value ?? const [];
    final correlation = correlations
        .where((c) => c.goalId == habit.id)
        .firstOrNull;

    if (correlation == null) {
      return EvolvePanel(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Center(
          child: Text(
            t.stats.moreLogsNeeded,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricGrid(
          tiles: [
            _Metric(
              label: t.statistics.moodCorrelation,
              value: '${correlation.sensitivity}%',
              detail: correlation.sensitivity > 10
                  ? t.statistics.positive
                  : t.statistics.neutral,
              color: EvolveColors.violet,
              icon: LucideIcons.heartPulse,
            ),
            _Metric(
              label: t.stats.resilience,
              value: '${correlation.resilience}%',
              detail: correlation.resilience > 50
                  ? t.statistics.high
                  : t.statistics.low,
              color: context.evolveAccent,
              icon: LucideIcons.zap,
            ),
            _Metric(
              label: t.statistics.avgMood,
              value: correlation.avgMoodDone.toStringAsFixed(1),
              detail: t.statistics.onCompletedDays,
              color: correlation.avgMoodDone < 4
                  ? EvolveColors.rose
                  : context.evolveAccent,
              icon: LucideIcons.smile,
            ),
            _Metric(
              label: t.statistics.avgEnergy,
              value: correlation.avgEnergyDone.toStringAsFixed(1),
              detail: t.statistics.onCompletedDays,
              color: correlation.avgEnergyDone < 4
                  ? EvolveColors.rose
                  : EvolveColors.amber,
              icon: LucideIcons.zap,
            ),
          ],
        ),
        if (correlation.resilience > 50) ...[
          const SizedBox(height: 12),
          StatusPill(
            label: t.statistics.resilient,
            color: EvolveColors.violet,
            icon: LucideIcons.zap,
          ),
        ],
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final completedVsMissed = _CompletedVsMissedPanel(
              correlation: correlation,
            );
            final perLevel = _PerformancePerLevelPanel(
              correlation: correlation,
            );
            if (constraints.maxWidth < 1120) {
              return Column(
                children: [
                  completedVsMissed,
                  const SizedBox(height: 16),
                  perLevel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: completedVsMissed),
                const SizedBox(width: 18),
                Expanded(child: perLevel),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            t.statistics.moodEnergyAnalysis,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Completed-vs-missed average mood/energy bars (0–10 scale), mirroring mobile's
/// `_CompletatoVsMancatoCard`.
class _CompletedVsMissedPanel extends StatelessWidget {
  const _CompletedVsMissedPanel({required this.correlation});

  final MoodCorrelation correlation;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.statistics.completedVsMissed,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _MoodBarGroup(
                    label: t.statistics.completed2,
                    mood: correlation.avgMoodDone,
                    energy: correlation.avgEnergyDone,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MoodBarGroup(
                    label: t.statistics.missed2,
                    mood: correlation.avgMoodMissed,
                    energy: correlation.avgEnergyMissed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GridLegend(
                color: const Color(0xFF10B981),
                label: t.statistics.mood2,
              ),
              const SizedBox(width: 16),
              _GridLegend(
                color: EvolveColors.amber,
                label: t.statistics.energy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodBarGroup extends StatelessWidget {
  const _MoodBarGroup({
    required this.label,
    required this.mood,
    required this.energy,
  });

  final String label;
  final double mood;
  final double energy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FractionallySizedBox(
                  heightFactor: (mood / 10).clamp(0.0, 1.0),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FractionallySizedBox(
                  heightFactor: (energy / 10).clamp(0.0, 1.0),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: EvolveColors.amber,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Completion % with high vs low mood, mirroring mobile's
/// `_PerformancePerLivelloCard`.
class _PerformancePerLevelPanel extends StatelessWidget {
  const _PerformancePerLevelPanel({required this.correlation});

  final MoodCorrelation correlation;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.statistics.performancePerLevel,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          _LevelBar(
            label: t.statistics.withHighMood,
            percentage: correlation.highMoodPct,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          _LevelBar(
            label: t.statistics.withLowMood,
            percentage: correlation.lowMoodPct,
            color: EvolveColors.rose,
          ),
        ],
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({
    required this.label,
    required this.percentage,
    required this.color,
  });

  final String label;
  final int percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '$percentage%',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: context.evolveColors.panelSoft,
          ),
        ),
      ],
    );
  }
}

/// Dashboard-style metric grid: 14px-gapped Wrap that lays the [_Metric]
/// tiles 4-up on wide layouts (>=1080) and 2-up below, capped at the tile
/// count so a 3-tile row still fills the full width.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxColumns = constraints.maxWidth >= 1080 ? 4 : 2;
        final columns = tiles.length < maxColumns ? tiles.length : maxColumns;
        const spacing = 14.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: cardWidth, child: tile),
          ],
        );
      },
    );
  }
}

/// Metric tile: uppercase micro-label + tinted icon chip on the first row and
/// a big w800 figure underneath (mobile stat-card recipe).
class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: context.evolveColors.muted.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 10),
                EvolveIconChip(
                  icon: icon!,
                  color: color,
                  size: 30,
                  iconSize: 15,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HeatmapPanel extends StatelessWidget {
  const _HeatmapPanel({
    required this.title,
    required this.subtitle,
    required this.values,
    this.color,
  });

  final String title;
  final String subtitle;
  final Color? color;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: title, subtitle: subtitle),
          const SizedBox(height: 17),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var index = 0; index < values.length; index++)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: (color ?? context.evolveAccent).withValues(
                      alpha: _alphaFor(index),
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  double _alphaFor(int index) {
    final value = values[index];
    if (value <= 0) return 0.1;
    return 0.18 + value.clamp(0, 1) * 0.72;
  }
}

class _CorrelationPanel extends ConsumerWidget {
  const _CorrelationPanel({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(allHabitCorrelationsRpcProvider).value ?? const [];
    // Resolve goal ids to titles and keep the strongest co-completion pairs.
    final correlations = <({String label, int percentage})>[];
    for (final row in rows) {
      final sourceId = row['goal_id'] as String?;
      final otherId = row['other_goal_id'] as String?;
      if (sourceId == null || otherId == null) continue;
      final source = _habitTitleFor(snapshot, sourceId);
      final other = _habitTitleFor(snapshot, otherId);
      if (source == null || other == null) continue;
      correlations.add((
        label: '$source -> $other',
        percentage: (row['percentage'] as num?)?.toInt() ?? 0,
      ));
    }
    correlations.sort((a, b) => b.percentage.compareTo(a.percentage));

    return EvolvePanel(
      glowColor: EvolveColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EvolveIconChip(
            icon: LucideIcons.brain,
            color: EvolveColors.violet,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(height: 13),
          SectionHeading(
            title: t.stats.keyCorrelations,
            subtitle: t.stats.keyCorrelationsSubtitle,
          ),
          const SizedBox(height: 16),
          if (correlations.isEmpty)
            Text(
              t.stats.moreLogsNeeded,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final correlation in correlations.take(2)) ...[
              _InlineInsight(
                title: correlation.label,
                value: '${correlation.percentage}%',
                color: context.evolveAccent,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _InlineInsight extends StatelessWidget {
  const _InlineInsight({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.evolveColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.evolveColors.muted.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.title,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String title;
  final String detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          EvolveIconChip(icon: icon, color: color, size: 38, iconSize: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.evolveColors.foreground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.evolveColors.muted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHabitAnalytics extends StatelessWidget {
  const _EmptyHabitAnalytics();

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Center(
        child: Text(
          t.stats.createHabitForAnalysis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

List<double> _activityValues(DashboardSnapshot snapshot, int count) {
  return [for (final date in _lastDays(count)) snapshot.completionFor(date)];
}

List<double> _moodValues(DashboardSnapshot snapshot, int count) {
  return [
    for (final date in _lastDays(count))
      if (snapshot.moods[dashboardDateKey(date)] case final checkIn?)
        ((checkIn.mood ?? 0) + (checkIn.energy ?? 0)) / 20
      else
        0,
  ];
}

Iterable<DateTime> _lastDays(int count) sync* {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  for (var offset = count - 1; offset >= 0; offset--) {
    yield today.subtract(Duration(days: offset));
  }
}

double _habitCompletion(DashboardSnapshot snapshot, String habitId) {
  final statuses = [
    for (final date in _lastDays(30)) snapshot.habitStatusFor(habitId, date),
  ].whereType<String>().toList();
  if (statuses.isEmpty) {
    final habit = snapshot.habits.firstWhere((habit) => habit.id == habitId);
    return habit.weeklyProgress.where((done) => done).length / 7;
  }
  return statuses.where((status) => status == 'done').length / statuses.length;
}

List<TrendPoint> _rpcTrendPoints(
  List<Map<String, dynamic>> rows,
  List<TrendPoint> fallback,
  _TrendTimeframe timeframe,
) {
  if (rows.isEmpty) return fallback;
  // The engine returns denser series for month/year/all; keep the last N points
  // so the line chart stays readable (weekly = 7, otherwise ~14 buckets).
  final maxBars = switch (timeframe) {
    _TrendTimeframe.week => 7,
    _ => 14,
  };
  final visible = rows.length > maxBars
      ? rows.sublist(rows.length - maxBars)
      : rows;
  return [
    for (final row in visible)
      TrendPoint(
        label: _trendLabel(row['date'] as String?, timeframe),
        value: ((row['rate'] as num?)?.toDouble() ?? 0).clamp(0, 100) / 100,
      ),
  ];
}

const List<String> _trendWeekdayTokens = [
  'Lun',
  'Mar',
  'Mer',
  'Gio',
  'Ven',
  'Sab',
  'Dom',
];

String _trendLabel(String? rawDate, _TrendTimeframe timeframe) {
  final date = DateTime.tryParse(rawDate ?? '');
  if (date == null) return '-';
  if (timeframe == _TrendTimeframe.week) {
    return _trendWeekdayTokens[date.weekday - 1];
  }
  return '${date.day}/${date.month}';
}

/// Resolves a goal_id from an RPC row to a habit title, falling back to a
/// precomputed string when the id is unknown (e.g. an archived habit).
String _resolveHabitTitle(
  DashboardSnapshot snapshot,
  String? goalId, {
  required String fallback,
}) {
  if (goalId == null) return fallback;
  final habit = snapshot.habits.where((h) => h.id == goalId).firstOrNull;
  return habit?.title ?? fallback;
}

String? _habitTitleFor(DashboardSnapshot snapshot, String goalId) =>
    snapshot.habits.where((h) => h.id == goalId).firstOrNull?.title;

String _weekdayName(int dow) {
  if (dow < 1 || dow > 7) return '';
  return t.common.weekdaysLong[dow - 1];
}

/// Localizes the critical-day value: `computeGlobalCriticalDay` (and the cloud
/// RPC) return a 3-letter ISO-dow token (`mon`…`sun`); map it to a localized
/// weekday name. Any other value (the trend-label fallback) passes through.
String _criticalDayLabel(String value) {
  final index = kIsoDowTokens.indexOf(value);
  return index >= 0 ? _weekdayName(index + 1) : value;
}

// ─── Global Alerts derivations (mirror mobile global_alerts_tab_widget) ──────

class _ImprovementArea {
  const _ImprovementArea({
    required this.title,
    required this.rate,
    required this.day,
    required this.color,
  });
  final String title;
  final int rate;
  final String day;
  final Color color;
}

class _FailureItem {
  const _FailureItem({
    required this.title,
    required this.worstStreak,
    required this.frequency,
    required this.color,
  });
  final String title;
  final int worstStreak;
  final int frequency;
  final Color color;
}

class _RecoveryItem {
  const _RecoveryItem({
    required this.title,
    required this.days,
    required this.color,
  });
  final String title;
  final int days;
  final Color color;
}

/// Lowest-rate habits and their worst weekday. Mirrors mobile's
/// `_calculateMiglioramentoData` (bottom-3 by `rate`, worst_dow from analytics).
List<_ImprovementArea> _improvementAreas(
  DashboardSnapshot snapshot,
  List<Map<String, dynamic>> stats,
  Map<String, Map<String, dynamic>> analytics,
) {
  final sorted = [
    ...stats,
  ]..sort((a, b) => (a['rate'] as num? ?? 0).compareTo(b['rate'] as num? ?? 0));
  final result = <_ImprovementArea>[];
  for (final stat in sorted.take(3)) {
    final goalId = stat['goal_id'] as String?;
    if (goalId == null) continue;
    final habit = snapshot.habits.where((h) => h.id == goalId).firstOrNull;
    if (habit == null) continue;
    final worstDow = (analytics[goalId]?['worst_dow'] as num?)?.toInt() ?? 1;
    result.add(
      _ImprovementArea(
        title: habit.title,
        rate: (stat['rate'] as num? ?? 0).round(),
        day: _weekdayName(worstDow),
        color: habit.color,
      ),
    );
  }
  return result;
}

/// Habits with the worst missed streaks. Mirrors mobile's
/// `_calculateFallimentiData` (top-3 by `worst_streak`, monthly miss frequency).
List<_FailureItem> _failureAnalysis(
  DashboardSnapshot snapshot,
  List<Map<String, dynamic>> stats,
) {
  final sorted = [...stats]
    ..sort(
      (a, b) => (b['worst_streak'] as num? ?? 0).compareTo(
        a['worst_streak'] as num? ?? 0,
      ),
    );
  final result = <_FailureItem>[];
  for (final stat in sorted.take(3)) {
    final goalId = stat['goal_id'] as String?;
    if (goalId == null) continue;
    final habit = snapshot.habits.where((h) => h.id == goalId).firstOrNull;
    if (habit == null) continue;
    final missed = (stat['missed_days'] as num? ?? 0).toInt();
    final totalDays = (stat['total_active_days'] as num? ?? 1).toInt();
    final freq = totalDays > 0 ? (missed / totalDays * 30).round() : 0;
    final worst = (stat['worst_streak'] as num? ?? 0).toInt();
    if (worst <= 0) continue;
    result.add(
      _FailureItem(
        title: habit.title,
        worstStreak: worst,
        frequency: freq,
        color: habit.color,
      ),
    );
  }
  return result;
}

/// Average recovery time per habit. Mirrors mobile's `_calculateRecuperoData`
/// (fastest 3 by `avg_recovery_days` from analytics).
List<_RecoveryItem> _recoveryPatterns(
  DashboardSnapshot snapshot,
  Map<String, Map<String, dynamic>> analytics,
) {
  final result = <_RecoveryItem>[];
  for (final habit in snapshot.habits) {
    final recovery =
        (analytics[habit.id]?['avg_recovery_days'] as num?)?.round() ?? 0;
    if (recovery <= 0) continue;
    result.add(
      _RecoveryItem(title: habit.title, days: recovery, color: habit.color),
    );
  }
  result.sort((a, b) => a.days.compareTo(b.days));
  return result.take(3).toList();
}

double _rpcWeekdayCompletion(
  List<Map<String, dynamic>> rows,
  int weekday, {
  required double fallback,
}) {
  final row = rows
      .where((item) => (item['day_index'] as num?)?.toInt() == weekday)
      .firstOrNull;
  if (row == null) return fallback;
  final total = (row['total_count'] as num?)?.toInt() ?? 0;
  final done = (row['done_count'] as num?)?.toInt() ?? 0;
  return total == 0 ? fallback : done / total;
}

double _habitWeekdayCompletion(
  DashboardSnapshot snapshot,
  String habitId,
  int weekday,
) {
  final statuses = snapshot.habitLogs.entries
      .where((entry) => DateTime.parse(entry.key).weekday == weekday)
      .map((entry) => entry.value[habitId])
      .whereType<String>()
      .toList();
  if (statuses.isEmpty) {
    final habit = snapshot.habits.firstWhere((habit) => habit.id == habitId);
    return habit.weeklyProgress[weekday - 1] ? 1 : 0;
  }
  return statuses.where((status) => status == 'done').length / statuses.length;
}

double _averageCheckIn(
  List<DailyCheckIn> moods,
  int? Function(DailyCheckIn mood) read,
) {
  final values = moods.map(read).whereType<int>().toList();
  if (values.isEmpty) return 0;
  return values.fold<int>(0, (sum, value) => sum + value) / values.length;
}

String _bestHabit(DashboardSnapshot snapshot) {
  if (snapshot.habits.isEmpty) return t.stats.noData;
  final habits = [...snapshot.habits]
    ..sort(
      (a, b) => _habitCompletion(
        snapshot,
        b.id,
      ).compareTo(_habitCompletion(snapshot, a.id)),
    );
  return habits.first.title;
}

String _criticalHabit(DashboardSnapshot snapshot) {
  if (snapshot.habits.isEmpty) return t.stats.noData;
  final habits = [...snapshot.habits]
    ..sort(
      (a, b) => _habitCompletion(
        snapshot,
        a.id,
      ).compareTo(_habitCompletion(snapshot, b.id)),
    );
  return habits.first.title;
}

String _criticalDay(DashboardSnapshot snapshot) {
  if (snapshot.trend.isEmpty) return t.stats.noData;
  final points = [...snapshot.trend]
    ..sort((a, b) => a.value.compareTo(b.value));
  return points.first.label;
}

double _trendDelta(List<TrendPoint> trend) {
  if (trend.length < 2) return 0;
  final current = trend.last.value;
  final previous = trend[trend.length - 2].value;
  return current - previous;
}

String _globalTabLabel(_GlobalTab tab) => switch (tab) {
  _GlobalTab.info => t.stats.tabInfo,
  _GlobalTab.trend => t.stats.tabTrend,
  _GlobalTab.alerts => t.stats.tabAlerts,
  _GlobalTab.habits => t.stats.tabHabits,
  _GlobalTab.mood => t.stats.tabMood,
};

String _habitTabLabel(_HabitTab tab) => switch (tab) {
  _HabitTab.overview => t.stats.tabOverview,
  _HabitTab.calendar => t.stats.tabCalendar,
  _HabitTab.performance => t.stats.tabPerformance,
  _HabitTab.improvement => t.stats.tabImprovement,
  _HabitTab.mood => t.stats.tabMood,
};
