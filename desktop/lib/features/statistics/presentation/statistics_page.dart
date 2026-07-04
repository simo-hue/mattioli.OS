import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart'
    show MoodCorrelation, kIsoDowTokens;
import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(dashboardControllerProvider);
    final selectedHabit = snapshot.habits.isEmpty
        ? null
        : snapshot.habits.firstWhere(
            (habit) => habit.id == (_habitId ?? snapshot.habits.first.id),
            orElse: () => snapshot.habits.first,
          );

    return DesktopPage(
      title: t.stats.title,
      subtitle: t.stats.pageSubtitle,
      trailing: StatusPill(
        label: t.stats.last30Days,
        icon: Icons.date_range_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsToolbar(
            scope: _scope,
            habits: snapshot.habits,
            selectedHabit: selectedHabit,
            onScopeChanged: (scope) => setState(() => _scope = scope),
            onHabitChanged: (id) => setState(() => _habitId = id),
          ),
          const SizedBox(height: 14),
          if (_scope == _AnalyticsScope.global) ...[
            _TabSelector<_GlobalTab>(
              selected: _globalTab,
              values: _GlobalTab.values,
              labelFor: _globalTabLabel,
              onChanged: (tab) => setState(() => _globalTab = tab),
            ),
            const SizedBox(height: 14),
            _globalContent(snapshot),
          ] else ...[
            _TabSelector<_HabitTab>(
              selected: _habitTab,
              values: _HabitTab.values,
              labelFor: _habitTabLabel,
              onChanged: (tab) => setState(() => _habitTab = tab),
            ),
            const SizedBox(height: 14),
            if (selectedHabit == null)
              const _EmptyHabitAnalytics()
            else
              _habitContent(selectedHabit, snapshot),
          ],
        ],
      ),
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
    return EvolvePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SegmentedButton<_AnalyticsScope>(
            segments: [
              ButtonSegment(
                value: _AnalyticsScope.global,
                icon: const Icon(Icons.public_outlined),
                label: Text(t.stats.global),
              ),
              ButtonSegment(
                value: _AnalyticsScope.habit,
                icon: const Icon(Icons.track_changes_outlined),
                label: Text(t.stats.singleHabit),
              ),
            ],
            selected: {scope},
            onSelectionChanged: (value) => onScopeChanged(value.single),
          ),
          const Spacer(),
          if (scope == _AnalyticsScope.habit) ...[
            const StatusPill(
              label: 'Evolve Pro',
              color: EvolveColors.amber,
              icon: Icons.auto_awesome_outlined,
            ),
            const SizedBox(width: 10),
            if (selectedHabit == null)
              Text(t.stats.noHabit)
            else
              DropdownButton<String>(
                value: selectedHabit!.id,
                items: [
                  for (final habit in habits)
                    DropdownMenuItem(value: habit.id, child: Text(habit.title)),
                ],
                onChanged: (id) {
                  if (id != null) onHabitChanged(id);
                },
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(labelFor(value)),
            selected: value == selected,
            onSelected: (_) => onChanged(value),
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
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: t.stats.completionToday,
                value: '${(snapshot.completionRate * 100).round()}%',
                detail: t.stats.actionsFraction(
                  done: snapshot.completedHabits,
                  total: snapshot.totalHabits,
                ),
                color: context.evolveAccent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: t.stats.bestStreakLabel,
                value: t.dashboard.streakDaysShort(n: snapshot.bestStreak),
                detail: _bestHabit(snapshot),
                color: EvolveColors.amber,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: t.stats.criticalDay,
                value: _criticalDayLabel(criticalDay),
                detail: t.stats.completePrioritiesFirst,
                color: EvolveColors.rose,
              ),
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
            if (constraints.maxWidth < 980) {
              return Column(
                children: [heatmap, const SizedBox(height: 18), correlations],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: heatmap),
                const SizedBox(width: 18),
                Expanded(flex: 4, child: correlations),
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
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.trendGlobal,
            subtitle: t.stats.trendGlobalSubtitle,
            trailing: StatusPill(
              label: t.stats.vsPrevDay(
                value: (_trendDelta(trend) * 100).round(),
              ),
              icon: Icons.trending_up_rounded,
            ),
          ),
          const SizedBox(height: 16),
          _TrendTimeframeSelector(
            selected: timeframe,
            onChanged: onTimeframeChanged,
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 230,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in trend)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${(point.value * 100).round()}%'),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: point.value.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: context.evolveAccent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(point.label),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InlineInsight(
                  title: t.stats.bestHabit,
                  value: _resolveHabitTitle(
                    snapshot,
                    best?.firstOrNull?['goal_id'] as String?,
                    fallback: _bestHabit(snapshot),
                  ),
                  color: context.evolveAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InlineInsight(
                  title: t.stats.criticalArea,
                  value: _resolveHabitTitle(
                    snapshot,
                    critical?.firstOrNull?['goal_id'] as String?,
                    fallback: _criticalHabit(snapshot),
                  ),
                  color: EvolveColors.rose,
                ),
              ),
            ],
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in _TrendTimeframe.values)
          ChoiceChip(
            label: Text(_trendTimeframeLabel(value)),
            selected: value == selected,
            onSelected: (_) => onChanged(value),
          ),
      ],
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
        child: Text(
          t.statistics.noDataForAlerts,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (improvement.isNotEmpty) ...[
          _AlertsSection(
            icon: Icons.track_changes_outlined,
            title: t.statistics.improvementAreas,
            subtitle: t.statistics.habitsRequiringMoreAttention,
            children: [
              for (final area in improvement)
                _AlertCard(
                  title: area.title,
                  detail: t.stats.blackDayDetail(day: area.day),
                  color: EvolveColors.rose,
                  icon: Icons.error_outline,
                  trailing: t.stats.successRate(rate: area.rate),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (failures.isNotEmpty) ...[
          _AlertsSection(
            icon: Icons.bar_chart_outlined,
            title: t.statistics.failureAnalysis,
            subtitle: t.statistics.missedDaysPattern,
            children: [
              for (final failure in failures)
                _AlertCard(
                  title: failure.title,
                  detail: t.stats.failureDetail(
                    streak: failure.worstStreak,
                    frequency: failure.frequency,
                  ),
                  color: EvolveColors.amber,
                  icon: Icons.trending_down_rounded,
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (recovery.isNotEmpty)
          _AlertsSection(
            icon: Icons.calendar_month_outlined,
            title: t.statistics.recoveryPatterns,
            subtitle: t.statistics.recoverySpeed,
            children: [
              for (final item in recovery)
                _AlertCard(
                  title: item.title,
                  detail: t.stats.recoveryDetail(days: item.days),
                  color: context.evolveAccent,
                  icon: Icons.schedule_outlined,
                ),
            ],
          ),
      ],
    );
  }
}

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: context.evolveColors.muted),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final child in children) ...[child, const SizedBox(height: 10)],
      ],
    );
  }
}

class _GlobalHabits extends StatelessWidget {
  const _GlobalHabits({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.performancePerHabit,
            subtitle: t.stats.performancePerHabitSubtitle,
          ),
          const SizedBox(height: 15),
          for (final habit in snapshot.habits) ...[
            _HabitPerformanceRow(habit: habit),
            if (habit != snapshot.habits.last) const Divider(height: 22),
          ],
        ],
      ),
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
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: t.stats.avgMood,
                value: '${averageMood.toStringAsFixed(1)}/10',
                detail: t.stats.checkInsAvailable(count: moods.length),
                color: EvolveColors.violet,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: t.stats.avgEnergy,
                value: '${averageEnergy.toStringAsFixed(1)}/10',
                detail: t.stats.checkInsAvailable(count: moods.length),
                color: EvolveColors.amber,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: t.stats.resilientHabit,
                value: _bestHabit(snapshot),
                detail: t.stats.completedEvenHardDays,
                color: context.evolveAccent,
              ),
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
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: t.stats.completion,
                value: '$completionRate%',
                detail: t.stats.actionsFraction(
                  done: totalCompletions,
                  total: totalActiveDays,
                ),
                color: habit.color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: t.stats.currentStreak,
                value: t.dashboard.streakDaysShort(n: currentStreak),
                detail: t.stats.currentStreakDetail,
                color: EvolveColors.amber,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: t.statistics.missed,
                value: '$missedDays',
                detail: t.stats.trend30Detail,
                color: EvolveColors.rose,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Last30DaysGrid(statuses: last30),
        const SizedBox(height: 18),
        _HabitCorrelationsPanel(habit: habit, snapshot: snapshot),
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

class _HabitCalendar extends ConsumerWidget {
  const _HabitCalendar({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearlyGrid = ref.watch(habitYearlyGridRpcProvider(habit.id)).value;
    return _HeatmapPanel(
      title: t.stats.yearlyCalendar,
      subtitle: t.stats.yearlyCalendarSubtitle(habit: habit.title),
      color: habit.color,
      values: yearlyGrid == null || yearlyGrid.isEmpty
          ? _habitActivityValues(snapshot, habit.id, 280)
          : yearlyGrid.map((status) => status == 1 ? 1.0 : 0.0).toList(),
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
      color: const Color(0xFF151522),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hub_outlined, color: EvolveColors.violet),
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
                fontWeight: FontWeight.w700,
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
                fontWeight: FontWeight.w700,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EvolvePanel(
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
                    SizedBox(width: 44, child: Text(labels[index])),
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
                      ),
                    ),
                  ],
                ),
                if (index < labels.length - 1) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        if (extremes.strongest != null) ...[
          const SizedBox(height: 12),
          _AlertCard(
            title:
                '${t.statistics.strongestDay}: ${_weekdayName(extremes.strongest!.dow)}',
            detail: t.stats.strongestDayDetail(
              pct: extremes.strongest!.pct,
              done: extremes.strongest!.done,
              total: extremes.strongest!.total,
            ),
            color: context.evolveAccent,
            icon: Icons.emoji_events_outlined,
          ),
        ],
        if (extremes.weakest != null) ...[
          const SizedBox(height: 12),
          _AlertCard(
            title:
                '${t.statistics.weakestDay}: ${_weekdayName(extremes.weakest!.dow)}',
            detail: t.stats.weakestDayDetail(
              pct: extremes.weakest!.pct,
              done: extremes.weakest!.done,
              total: extremes.weakest!.total,
            ),
            color: EvolveColors.rose,
            icon: Icons.warning_amber_rounded,
          ),
        ],
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EvolvePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.trending_down_rounded,
                    color: EvolveColors.rose,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.statistics.worstNegativeStreak,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '$worstNegativeDays',
                    style: const TextStyle(
                      color: EvolveColors.rose,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
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
        ),
        const SizedBox(height: 16),
        EvolvePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.statistics.brokenStreaks,
                style: Theme.of(context).textTheme.titleMedium,
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
                          color: EvolveColors.rose.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${b.days}',
                          style: const TextStyle(
                            color: EvolveColors.rose,
                            fontWeight: FontWeight.w700,
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
                              style: Theme.of(context).textTheme.bodyMedium,
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
        ),
      ],
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
        child: Text(
          t.stats.moreLogsNeeded,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: t.statistics.moodCorrelation,
                value: '${correlation.sensitivity}%',
                detail: correlation.sensitivity > 10
                    ? t.statistics.positive
                    : t.statistics.neutral,
                color: EvolveColors.violet,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: t.stats.resilience,
                value: '${correlation.resilience}%',
                detail: correlation.resilience > 50
                    ? t.statistics.high
                    : t.statistics.low,
                color: context.evolveAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: t.statistics.avgMood,
                value: correlation.avgMoodDone.toStringAsFixed(1),
                detail: t.statistics.onCompletedDays,
                color: correlation.avgMoodDone < 4
                    ? EvolveColors.rose
                    : context.evolveAccent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: t.statistics.avgEnergy,
                value: correlation.avgEnergyDone.toStringAsFixed(1),
                detail: t.statistics.onCompletedDays,
                color: correlation.avgEnergyDone < 4
                    ? EvolveColors.rose
                    : EvolveColors.amber,
              ),
            ),
          ],
        ),
        if (correlation.resilience > 50) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.bolt_outlined,
                size: 16,
                color: EvolveColors.violet,
              ),
              const SizedBox(width: 6),
              Text(
                t.statistics.resilient,
                style: const TextStyle(
                  color: EvolveColors.violet,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _CompletedVsMissedPanel(correlation: correlation),
        const SizedBox(height: 16),
        _PerformancePerLevelPanel(correlation: correlation),
        const SizedBox(height: 16),
        Text(
          t.statistics.moodEnergyAnalysis,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
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
            style: Theme.of(context).textTheme.titleMedium,
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
            style: Theme.of(context).textTheme.titleMedium,
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
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
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

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
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
      color: const Color(0xFF151522),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hub_outlined, color: EvolveColors.violet),
          const SizedBox(height: 13),
          SectionHeading(
            title: t.stats.keyCorrelations,
            subtitle: t.stats.keyCorrelationsSubtitle,
          ),
          const SizedBox(height: 16),
          if (correlations.isEmpty)
            Text(t.stats.moreLogsNeeded)
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
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
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
    this.trailing,
  });

  final String title;
  final String detail;
  final Color color;
  final IconData icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Text(
              trailing!,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}

class _HabitPerformanceRow extends StatelessWidget {
  const _HabitPerformanceRow({required this.habit});

  final DashboardHabit habit;

  @override
  Widget build(BuildContext context) {
    final done = habit.weeklyProgress.where((value) => value).length;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: habit.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 11),
        Expanded(child: Text(habit.title)),
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            value: done / 7,
            minHeight: 6,
            color: habit.color,
            backgroundColor: context.evolveColors.panelSoft,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 34, child: Text('$done/7')),
        SizedBox(
          width: 72,
          child: Text(t.dashboard.streakDaysShort(n: habit.streak)),
        ),
      ],
    );
  }
}

class _EmptyHabitAnalytics extends StatelessWidget {
  const _EmptyHabitAnalytics();

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Text(
        t.stats.createHabitForAnalysis,
        style: Theme.of(context).textTheme.bodyMedium,
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

List<double> _habitActivityValues(
  DashboardSnapshot snapshot,
  String habitId,
  int count,
) {
  return [
    for (final date in _lastDays(count))
      snapshot.habitStatusFor(habitId, date) == 'done' ? 1 : 0,
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
  // so the bar chart stays readable (weekly = 7, otherwise ~14 buckets).
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
  });
  final String title;
  final int rate;
  final String day;
}

class _FailureItem {
  const _FailureItem({
    required this.title,
    required this.worstStreak,
    required this.frequency,
  });
  final String title;
  final int worstStreak;
  final int frequency;
}

class _RecoveryItem {
  const _RecoveryItem({required this.title, required this.days});
  final String title;
  final int days;
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
    final title = _habitTitleFor(snapshot, goalId);
    if (title == null) continue;
    final worstDow = (analytics[goalId]?['worst_dow'] as num?)?.toInt() ?? 1;
    result.add(
      _ImprovementArea(
        title: title,
        rate: (stat['rate'] as num? ?? 0).round(),
        day: _weekdayName(worstDow),
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
    final title = _habitTitleFor(snapshot, goalId);
    if (title == null) continue;
    final missed = (stat['missed_days'] as num? ?? 0).toInt();
    final totalDays = (stat['total_active_days'] as num? ?? 1).toInt();
    final freq = totalDays > 0 ? (missed / totalDays * 30).round() : 0;
    final worst = (stat['worst_streak'] as num? ?? 0).toInt();
    if (worst <= 0) continue;
    result.add(_FailureItem(title: title, worstStreak: worst, frequency: freq));
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
    result.add(_RecoveryItem(title: habit.title, days: recovery));
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
