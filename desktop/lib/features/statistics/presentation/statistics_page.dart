import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _AnalyticsScope { global, habit }

enum _GlobalTab { info, trend, alerts, habits, mood }

enum _HabitTab { overview, calendar, performance, improvement, mood }

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  _AnalyticsScope _scope = _AnalyticsScope.global;
  _GlobalTab _globalTab = _GlobalTab.info;
  _HabitTab _habitTab = _HabitTab.overview;
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
      title: 'Statistiche',
      subtitle:
          'Identifica i pattern che sostengono la crescita e intervieni sulle aree critiche.',
      trailing: const StatusPill(
        label: 'Ultimi 30 giorni',
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
    _GlobalTab.trend => _GlobalTrend(snapshot: snapshot),
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
            segments: const [
              ButtonSegment(
                value: _AnalyticsScope.global,
                icon: Icon(Icons.public_outlined),
                label: Text('Globale'),
              ),
              ButtonSegment(
                value: _AnalyticsScope.habit,
                icon: Icon(Icons.track_changes_outlined),
                label: Text('Singola abitudine'),
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
              const Text('Nessuna abitudine')
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
                label: 'Completamento oggi',
                value: '${(snapshot.completionRate * 100).round()}%',
                detail:
                    '${snapshot.completedHabits}/${snapshot.totalHabits} azioni',
                color: context.evolveAccent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: 'Serie migliore',
                value: '${snapshot.bestStreak} gg',
                detail: _bestHabit(snapshot),
                color: EvolveColors.amber,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: 'Giorno critico',
                value: criticalDay,
                detail: 'Completa prima le priorita',
                color: EvolveColors.rose,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final heatmap = _HeatmapPanel(
              title: 'Attivita recente',
              subtitle: 'Intensita di completamento negli ultimi 90 giorni',
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
  const _GlobalTrend({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rpcTrend = ref
        .watch(globalTrendRpcProvider('timeframe_week_short'))
        .value;
    final trend = _rpcTrendPoints(rpcTrend ?? const [], snapshot.trend);
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'Trend globale',
            subtitle: 'Confronto temporale del protocollo',
            trailing: StatusPill(
              label:
                  '${(_trendDelta(trend) * 100).round()}% vs giorno precedente',
              icon: Icons.trending_up_rounded,
            ),
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
                                heightFactor: point.value,
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
                  title: 'Abitudine migliore',
                  value: _bestHabit(snapshot),
                  color: context.evolveAccent,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _InlineInsight(
                  title: 'Area critica',
                  value: _criticalHabit(snapshot),
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

class _GlobalAlerts extends StatelessWidget {
  const _GlobalAlerts({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final criticalHabit = _criticalHabit(snapshot);
    final activeGoal = snapshot.goals
        .where((goal) => goal.state == GoalState.active)
        .firstOrNull;
    return Column(
      children: [
        _AlertCard(
          title: 'Serie a rischio',
          detail: '$criticalHabit richiede attenzione nei prossimi check-in.',
          color: EvolveColors.rose,
          icon: Icons.warning_amber_rounded,
        ),
        SizedBox(height: 12),
        _AlertCard(
          title: 'Pattern da consolidare',
          detail:
              'Controlla i giorni con umore basso e mantieni il protocollo essenziale.',
          color: EvolveColors.violet,
          icon: Icons.auto_awesome_outlined,
        ),
        SizedBox(height: 12),
        _AlertCard(
          title: 'Obiettivo in scadenza',
          detail: activeGoal == null
              ? 'Nessun obiettivo attivo richiede un intervento.'
              : '${activeGoal.title}: ${activeGoal.dueLabel}.',
          color: EvolveColors.amber,
          icon: Icons.flag_outlined,
        ),
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
          const SectionHeading(
            title: 'Performance per abitudine',
            subtitle:
                'Classifica calcolata dai log sincronizzati per consistenza settimanale',
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
                label: 'Umore medio',
                value: '${averageMood.toStringAsFixed(1)}/10',
                detail: '${moods.length} check-in disponibili',
                color: EvolveColors.violet,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: 'Energia media',
                value: '${averageEnergy.toStringAsFixed(1)}/10',
                detail: '${moods.length} check-in disponibili',
                color: EvolveColors.amber,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: 'Abitudine resiliente',
                value: _bestHabit(snapshot),
                detail: 'Completata anche nei giorni difficili',
                color: context.evolveAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _HeatmapPanel(
          title: 'Umore ed energia',
          subtitle: 'Media dei check-in disponibili negli ultimi 90 giorni',
          color: EvolveColors.violet,
          values: _moodValues(snapshot, 90),
        ),
      ],
    );
  }
}

class _HabitOverview extends StatelessWidget {
  const _HabitOverview({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final completion = _habitCompletion(snapshot, habit.id);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Completamento',
                value: '${(completion * 100).round()}%',
                detail: 'Settimana corrente',
                color: habit.color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: 'Serie corrente',
                value: '${habit.streak} gg',
                detail: 'Serie sincronizzata dai log disponibili',
                color: EvolveColors.amber,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: 'Trend 30 giorni',
                value: '${(completion * 100).round()}%',
                detail: 'Completamento negli ultimi 30 giorni',
                color: context.evolveAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _CorrelationPanel(snapshot: snapshot),
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
      title: 'Calendario annuale',
      subtitle: 'Distribuzione dei completamenti di ${habit.title}',
      color: habit.color,
      values: yearlyGrid == null || yearlyGrid.isEmpty
          ? _habitActivityValues(snapshot, habit.id, 280)
          : yearlyGrid.map((status) => status == 1 ? 1.0 : 0.0).toList(),
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
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Performance per giorno',
            subtitle: 'Giorni forti e giorni deboli della settimana',
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
    );
  }
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
    return Column(
      children: [
        _AlertCard(
          title: 'Proteggi la serie di ${habit.streak} giorni',
          detail: worstNegativeDays == 0
              ? 'Mantieni la stessa fascia oraria per ridurre la frizione nei giorni piu intensi.'
              : 'La peggiore sequenza negativa e durata $worstNegativeDays giorni.',
          color: EvolveColors.amber,
          icon: Icons.local_fire_department_outlined,
        ),
        const SizedBox(height: 12),
        _AlertCard(
          title: 'Leva positiva rilevata',
          detail:
              '${_bestHabit(snapshot)} mantiene la migliore regolarita recente.',
          color: context.evolveAccent,
          icon: Icons.trending_up_rounded,
        ),
      ],
    );
  }
}

class _HabitMood extends StatelessWidget {
  const _HabitMood({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Sensibilita all\'umore',
                value:
                    '${(_habitLowMoodCompletion(snapshot, habit.id) * 100).round()}%',
                detail: '${habit.title} risente dei giorni difficili',
                color: EvolveColors.violet,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Metric(
                label: 'Resilienza',
                value:
                    '${(_habitLowEnergyCompletion(snapshot, habit.id) * 100).round()}%',
                detail: 'Completamento con energia bassa',
                color: context.evolveAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _HeatmapPanel(
          title: 'Correlazione umore-output',
          subtitle: 'Completamenti disponibili nei giorni con check-in',
          color: EvolveColors.violet,
          values: _habitMoodValues(snapshot, habit.id, 90),
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

class _CorrelationPanel extends StatelessWidget {
  const _CorrelationPanel({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final correlations = _habitCorrelations(snapshot);
    return EvolvePanel(
      color: const Color(0xFF151522),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hub_outlined, color: EvolveColors.violet),
          const SizedBox(height: 13),
          const SectionHeading(
            title: 'Correlazioni chiave',
            subtitle: 'Pattern che influenzano maggiormente il protocollo',
          ),
          const SizedBox(height: 16),
          if (correlations.isEmpty)
            const Text('Servono piu log per calcolare correlazioni utili.')
          else
            for (final correlation in correlations.take(2)) ...[
              _InlineInsight(
                title: correlation.label,
                value: '${(correlation.value * 100).round()}%',
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
  });

  final String title;
  final String detail;
  final Color color;
  final IconData icon;

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
        SizedBox(width: 72, child: Text('${habit.streak} gg')),
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
        'Crea almeno un\'abitudine per visualizzare l\'analisi granulare.',
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

List<double> _habitMoodValues(
  DashboardSnapshot snapshot,
  String habitId,
  int count,
) {
  return [
    for (final date in _lastDays(count))
      if (snapshot.moods.containsKey(dashboardDateKey(date)))
        snapshot.habitStatusFor(habitId, date) == 'done' ? 1 : 0
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
) {
  if (rows.isEmpty) return fallback;
  return [
    for (final row in rows.take(14))
      TrendPoint(
        label: _trendLabel(row['date'] as String?),
        value: ((row['rate'] as num?)?.toDouble() ?? 0).clamp(0, 100) / 100,
      ),
  ];
}

String _trendLabel(String? rawDate) {
  final date = DateTime.tryParse(rawDate ?? '');
  return date == null ? '-' : '${date.day}/${date.month}';
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

double _habitLowMoodCompletion(DashboardSnapshot snapshot, String habitId) {
  return _habitCheckInCompletion(
    snapshot,
    habitId,
    (checkIn) => (checkIn.mood ?? 10) <= 4,
  );
}

double _habitLowEnergyCompletion(DashboardSnapshot snapshot, String habitId) {
  return _habitCheckInCompletion(
    snapshot,
    habitId,
    (checkIn) => (checkIn.energy ?? 10) <= 4,
  );
}

double _habitCheckInCompletion(
  DashboardSnapshot snapshot,
  String habitId,
  bool Function(DailyCheckIn checkIn) include,
) {
  final dates = snapshot.moods.entries
      .where((entry) => include(entry.value))
      .map((entry) => entry.key)
      .toList();
  if (dates.isEmpty) return 0;
  final completed = dates
      .where((date) => snapshot.habitLogs[date]?[habitId] == 'done')
      .length;
  return completed / dates.length;
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
  if (snapshot.habits.isEmpty) return 'Nessun dato';
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
  if (snapshot.habits.isEmpty) return 'Nessun dato';
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
  if (snapshot.trend.isEmpty) return 'Nessun dato';
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

List<_HabitCorrelation> _habitCorrelations(DashboardSnapshot snapshot) {
  final correlations = <_HabitCorrelation>[];
  for (final source in snapshot.habits) {
    for (final target in snapshot.habits) {
      if (source.id == target.id) continue;
      var sourceDone = 0;
      var bothDone = 0;
      for (final logs in snapshot.habitLogs.values) {
        if (logs[source.id] != 'done') continue;
        sourceDone++;
        if (logs[target.id] == 'done') bothDone++;
      }
      if (sourceDone > 0) {
        correlations.add(
          _HabitCorrelation(
            label: '${source.title} -> ${target.title}',
            value: bothDone / sourceDone,
          ),
        );
      }
    }
  }
  correlations.sort((a, b) => b.value.compareTo(a.value));
  return correlations;
}

class _HabitCorrelation {
  const _HabitCorrelation({required this.label, required this.value});

  final String label;
  final double value;
}

String _globalTabLabel(_GlobalTab tab) => switch (tab) {
  _GlobalTab.info => 'Info',
  _GlobalTab.trend => 'Trend',
  _GlobalTab.alerts => 'Alert',
  _GlobalTab.habits => 'Abitudini',
  _GlobalTab.mood => 'Umore',
};

String _habitTabLabel(_HabitTab tab) => switch (tab) {
  _HabitTab.overview => 'Overview',
  _HabitTab.calendar => 'Calendario',
  _HabitTab.performance => 'Performance',
  _HabitTab.improvement => 'Miglioramento',
  _HabitTab.mood => 'Umore',
};
