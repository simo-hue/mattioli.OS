import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _HabitSurface { protocol, calendar }

class HabitsPage extends ConsumerStatefulWidget {
  const HabitsPage({super.key});

  @override
  ConsumerState<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends ConsumerState<HabitsPage> {
  _HabitSurface _surface = _HabitSurface.protocol;
  CalendarViewMode _calendarView = CalendarViewMode.month;
  DateTime _anchor = DateTime.now();

  @override
  void initState() {
    super.initState();
    final value = ref
        .read(sharedPreferencesProvider)
        ?.getString('pref_default_calendar_view');
    _calendarView = switch (value?.toLowerCase()) {
      'settimana' || 'week' => CalendarViewMode.week,
      'anno' || 'year' => CalendarViewMode.year,
      'vita' || 'life' => CalendarViewMode.life,
      _ => CalendarViewMode.week,
    };
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(dashboardControllerProvider);

    return DesktopPage(
      title: 'Abitudini',
      subtitle:
          'Costruisci il protocollo quotidiano e osserva la consistenza nel tempo.',
      trailing: PageActionButton(
        label: 'Nuova abitudine',
        icon: Icons.add_rounded,
        primary: true,
        onPressed: () => _openHabitEditor(),
      ),
      child: Column(
        children: [
          _Summary(snapshot: snapshot),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<_HabitSurface>(
              segments: const [
                ButtonSegment(
                  value: _HabitSurface.protocol,
                  icon: Icon(Icons.fact_check_outlined),
                  label: Text('Protocollo'),
                ),
                ButtonSegment(
                  value: _HabitSurface.calendar,
                  icon: Icon(Icons.calendar_month_outlined),
                  label: Text('Calendario'),
                ),
              ],
              selected: {_surface},
              onSelectionChanged: (selection) {
                setState(() => _surface = selection.single);
              },
            ),
          ),
          const SizedBox(height: 14),
          if (_surface == _HabitSurface.protocol)
            _ProtocolPanel(
              snapshot: snapshot,
              onToggle: (id) => ref
                  .read(dashboardControllerProvider.notifier)
                  .toggleHabit(id),
              onEdit: _openHabitEditor,
              onDelete: _deleteHabit,
            )
          else
            _CalendarPanel(
              snapshot: snapshot,
              anchor: _anchor,
              view: _calendarView,
              onViewChanged: (view) => setState(() => _calendarView = view),
              onPrevious: () => setState(() => _anchor = _shiftAnchor(-1)),
              onNext: () => setState(() => _anchor = _shiftAnchor(1)),
              onToday: () => setState(() => _anchor = DateTime.now()),
              onSelectDay: _openDayDetails,
            ),
        ],
      ),
    );
  }

  DateTime _shiftAnchor(int direction) => switch (_calendarView) {
    CalendarViewMode.month => DateTime(
      _anchor.year,
      _anchor.month + direction,
      1,
    ),
    CalendarViewMode.week => _anchor.add(Duration(days: direction * 7)),
    CalendarViewMode.year => DateTime(_anchor.year + direction, 1, 1),
    CalendarViewMode.life => _anchor,
  };

  Future<void> _openHabitEditor([DashboardHabit? habit]) async {
    final draft = await showEvolveDialog<_HabitDraft>(
      context: context,
      builder: (context) => _HabitEditorDialog(habit: habit),
    );
    if (draft == null) return;

    final controller = ref.read(dashboardControllerProvider.notifier);
    if (habit == null) {
      await controller.addHabit(
        title: draft.title,
        category: draft.category,
        color: draft.color,
        reminderTime: draft.reminderTime,
      );
    } else {
      await controller.updateHabit(
        id: habit.id,
        title: draft.title,
        category: draft.category,
        color: draft.color,
        reminderTime: draft.reminderTime,
      );
    }
  }

  Future<void> _deleteHabit(DashboardHabit habit) async {
    final confirmed = await showEvolveDialog<bool>(
      context: context,
      builder: (context) => EvolveAlertDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: EvolveColors.rose,
        title: const Text('Elimina abitudine'),
        content: Text('Vuoi rimuovere "${habit.title}" dal protocollo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(dashboardControllerProvider.notifier).deleteHabit(habit.id);
  }

  Future<void> _openDayDetails(DateTime date) async {
    await showEvolveDialog<void>(
      context: context,
      builder: (context) => _DayDetailsDialog(date: date),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Protocollo attivo',
            value: '${snapshot.totalHabits}',
            icon: Icons.event_available_outlined,
            color: context.evolveAccent,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SummaryCard(
            label: 'Completate oggi',
            value: '${snapshot.completedHabits}',
            icon: Icons.check_circle_outline_rounded,
            color: EvolveColors.cyan,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SummaryCard(
            label: 'Serie migliore',
            value: '${snapshot.bestStreak} gg',
            icon: Icons.local_fire_department_outlined,
            color: EvolveColors.amber,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: context.evolveColors.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProtocolPanel extends StatelessWidget {
  const _ProtocolPanel({
    required this.snapshot,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final DashboardSnapshot snapshot;
  final ValueChanged<String> onToggle;
  final ValueChanged<DashboardHabit> onEdit;
  final ValueChanged<DashboardHabit> onDelete;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: SectionHeading(
              title: 'Protocollo quotidiano',
              subtitle: 'Panoramica settimanale, reminder e azioni rapide',
              trailing: StatusPill(
                label: 'Settimana corrente',
                icon: Icons.calendar_today_outlined,
              ),
            ),
          ),
          const Divider(height: 1),
          const _HabitHeader(),
          for (final habit in snapshot.habits)
            _HabitRow(
              habit: habit,
              onToggle: () => onToggle(habit.id),
              onEdit: () => onEdit(habit),
              onDelete: () => onDelete(habit),
            ),
        ],
      ),
    );
  }
}

class _HabitHeader extends StatelessWidget {
  const _HabitHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          SizedBox(width: 32),
          Expanded(child: _ColumnLabel('ABITUDINE')),
          SizedBox(width: 100, child: _ColumnLabel('SERIE')),
          SizedBox(width: 200, child: _ColumnLabel('ULTIMI 7 GIORNI')),
          SizedBox(width: 105, child: _ColumnLabel('REMINDER')),
          SizedBox(width: 84),
        ],
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: context.evolveColors.subtle,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.9,
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final DashboardHabit habit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final completed = habit.state == HabitState.completed;
    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: onToggle,
                  icon: Icon(
                    completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: completed
                        ? habit.color
                        : context.evolveColors.subtle,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      habit.category,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  '${habit.streak} giorni',
                  style: const TextStyle(
                    color: EvolveColors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: Row(
                  children: [
                    for (final done in habit.weeklyProgress)
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: done
                              ? habit.color.withValues(alpha: 0.86)
                              : context.evolveColors.panelSoft,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 105,
                child: Text(
                  habit.reminderTime ?? 'Nessuno',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: 84,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Modifica',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                    ),
                    IconButton(
                      tooltip: 'Elimina',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.snapshot,
    required this.anchor,
    required this.view,
    required this.onViewChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onSelectDay,
  });

  final DashboardSnapshot snapshot;
  final DateTime anchor;
  final CalendarViewMode view;
  final ValueChanged<CalendarViewMode> onViewChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<CalendarViewMode>(
                  segments: [
                    for (final mode in CalendarViewMode.values)
                      ButtonSegment(value: mode, label: Text(mode.label)),
                  ],
                  selected: {view},
                  onSelectionChanged: (selection) {
                    onViewChanged(selection.single);
                  },
                ),
              ),
              if (view != CalendarViewMode.life) ...[
                OutlinedButton(onPressed: onToday, child: const Text('Oggi')),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Periodo precedente',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'Periodo successivo',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _periodLabel(anchor, view),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          switch (view) {
            CalendarViewMode.month => _MonthCalendar(
              snapshot: snapshot,
              anchor: anchor,
              onSelectDay: onSelectDay,
            ),
            CalendarViewMode.week => _WeekCalendar(
              snapshot: snapshot,
              anchor: anchor,
              onSelectDay: onSelectDay,
            ),
            CalendarViewMode.year => _YearCalendar(
              snapshot: snapshot,
              anchor: anchor,
            ),
            CalendarViewMode.life => const _LifeCalendar(),
          },
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.snapshot,
    required this.anchor,
    required this.onSelectDay,
  });

  final DashboardSnapshot snapshot;
  final DateTime anchor;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(anchor.year, anchor.month);
    final days = DateUtils.getDaysInMonth(anchor.year, anchor.month);
    final leading = first.weekday - 1;
    return Column(
      children: [
        Row(
          children: [
            for (final day in ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'])
              Expanded(child: Center(child: _ColumnLabel(day))),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.34,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
          ),
          itemCount: leading + days,
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final date = DateTime(
              anchor.year,
              anchor.month,
              index - leading + 1,
            );
            return _DayCell(
              snapshot: snapshot,
              date: date,
              completion: _completionFor(snapshot, date),
              onTap: date.isAfter(DateTime.now())
                  ? null
                  : () => onSelectDay(date),
            );
          },
        ),
      ],
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({
    required this.snapshot,
    required this.anchor,
    required this.onSelectDay,
  });

  final DashboardSnapshot snapshot;
  final DateTime anchor;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < 7; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _DayCell(
              snapshot: snapshot,
              date: monday.add(Duration(days: index)),
              completion: _completionFor(
                snapshot,
                monday.add(Duration(days: index)),
              ),
              expanded: true,
              onTap: monday.add(Duration(days: index)).isAfter(DateTime.now())
                  ? null
                  : () => onSelectDay(monday.add(Duration(days: index))),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.snapshot,
    required this.date,
    required this.completion,
    required this.onTap,
    this.expanded = false,
  });

  final DashboardSnapshot snapshot;
  final DateTime date;
  final double completion;
  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final indicators = snapshot.habitsFor(date);
    final indicatorLimit = expanded ? 28 : 14;
    final hiddenIndicators = indicators.length - indicatorLimit;
    final isFuture = date.isAfter(DateTime.now());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: expanded ? 155 : null,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isToday
              ? context.evolveAccent.withValues(alpha: 0.08)
              : isFuture
              ? context.evolveColors.panelSoft.withValues(alpha: 0.5)
              : context.evolveColors.panelRaised,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isToday ? context.evolveAccent : context.evolveColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: isToday
                    ? context.evolveAccent
                    : context.evolveColors.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final habit in indicators.take(indicatorLimit))
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: switch (snapshot.habitStatusFor(habit.id, date)) {
                        'done' => habit.color,
                        'missed' => EvolveColors.rose,
                        _ => habit.color.withValues(alpha: 0.22),
                      },
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hiddenIndicators > 0)
                  Text(
                    '+$hiddenIndicators',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              indicators.isEmpty
                  ? 'Nessuna abitudine'
                  : '${(completion * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _YearCalendar extends StatelessWidget {
  const _YearCalendar({required this.snapshot, required this.anchor});

  final DashboardSnapshot snapshot;
  final DateTime anchor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 33) / 4;
        return Wrap(
          spacing: 11,
          runSpacing: 11,
          children: [
            for (var month = 1; month <= 12; month++)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.evolveColors.panelRaised,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: context.evolveColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _months[month - 1],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      for (
                        var week = 0;
                        week < logicalWeeksInMonth(anchor.year, month);
                        week++
                      ) ...[
                        LinearProgressIndicator(
                          value: _weekCompletion(month, week),
                          minHeight: 4,
                          color: context.evolveAccent,
                          backgroundColor: context.evolveColors.panelSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        if (week < logicalWeeksInMonth(anchor.year, month) - 1)
                          const SizedBox(height: 5),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _weekCompletion(int month, int week) {
    final first = DateTime(anchor.year, month, 1 + week * 7);
    final days = [
      for (var day = 0; day < 7; day++) first.add(Duration(days: day)),
    ].where((date) => date.month == month).toList();
    if (days.isEmpty) return 0;
    return days
            .map(snapshot.completionFor)
            .fold<double>(0, (sum, value) => sum + value) /
        days.length;
  }
}

class _LifeCalendar extends ConsumerWidget {
  const _LifeCalendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref
        .watch(desktopAuthControllerProvider)
        .user
        ?.userMetadata;
    final birthDate =
        DateTime.tryParse(metadata?['date_of_birth'] as String? ?? '') ??
        DateTime(2003);
    final now = DateTime.now();
    const years = 85;
    final totalMonths = years * 12;
    final livedMonths =
        ((now.year - birthDate.year) * 12 + now.month - birthDate.month).clamp(
          0,
          totalMonths,
        );
    final remainingMonths = totalMonths - livedMonths;
    final age = livedMonths ~/ 12;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Vista vita',
            subtitle:
                'Una cella rappresenta un mese del percorso fino a 85 anni.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LifeMetric(
                  label: 'Mesi vissuti',
                  value: '$livedMonths',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LifeMetric(label: 'Eta attuale', value: '$age'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LifeMetric(
                  label: 'Mesi rimanenti',
                  value: '$remainingMonths',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var index = 0; index < totalMonths; index++)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: index == livedMonths - 1
                        ? EvolveColors.amber
                        : index < livedMonths
                        ? context.evolveAccent.withValues(alpha: 0.52)
                        : context.evolveColors.panelSoft,
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

class _LifeMetric extends StatelessWidget {
  const _LifeMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.evolveColors.panelSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DayDetailsDialog extends ConsumerWidget {
  const _DayDetailsDialog({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardControllerProvider);
    return EvolveAlertDialog(
      maxWidth: 560,
      icon: Icons.calendar_today_outlined,
      title: Text('Dettaglio ${date.day} ${_months[date.month - 1]}'),
      subtitle: 'Aggiorna lo stato delle abitudini per questo giorno.',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final habit in snapshot.habitsFor(date))
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(habit.title),
              subtitle: Text(
                _habitStatusLabel(snapshot, habit.id, date, habit),
              ),
              activeColor: habit.color,
              value: _habitStatus(snapshot, habit.id, date, habit) == 'done',
              onChanged: _canEditDate(date)
                  ? (_) => ref
                        .read(dashboardControllerProvider.notifier)
                        .toggleHabitForDay(habit.id, date)
                  : null,
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }
}

class _HabitEditorDialog extends StatefulWidget {
  const _HabitEditorDialog({this.habit});

  final DashboardHabit? habit;

  @override
  State<_HabitEditorDialog> createState() => _HabitEditorDialogState();
}

class _HabitEditorDialogState extends State<_HabitEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _reminder;
  late String _category;
  late Color _color;
  var _usesDefaultColor = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.habit?.title);
    _reminder = TextEditingController(text: widget.habit?.reminderTime);
    _category = widget.habit?.category ?? 'Benessere';
    _usesDefaultColor = widget.habit == null;
    _color = widget.habit?.color ?? EvolveColors.primaryStrong;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_usesDefaultColor) {
      _color = context.evolveAccent;
      _usesDefaultColor = false;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _reminder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      icon: Icons.event_repeat_rounded,
      title: Text(
        widget.habit == null ? 'Nuova abitudine' : 'Modifica abitudine',
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Titolo'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                for (final value in _habitCategories)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reminder,
              decoration: const InputDecoration(
                labelText: 'Promemoria opzionale',
                hintText: 'es. 08:30',
              ),
            ),
            const SizedBox(height: 16),
            Text('Colore', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 9,
              children: [
                for (final color in _habitColors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == color
                              ? context.evolveColors.foreground
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(
              context,
              _HabitDraft(
                title: title,
                category: _category,
                color: _color,
                reminderTime: _reminder.text.trim().isEmpty
                    ? null
                    : _reminder.text.trim(),
              ),
            );
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

class _HabitDraft {
  const _HabitDraft({
    required this.title,
    required this.category,
    required this.color,
    this.reminderTime,
  });

  final String title;
  final String category;
  final Color color;
  final String? reminderTime;
}

double _completionFor(DashboardSnapshot snapshot, DateTime date) {
  return snapshot.completionFor(date);
}

bool _isCurrentWeek(DateTime date) {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final sunday = monday.add(const Duration(days: 6));
  final normalized = DateTime(date.year, date.month, date.day);
  return !normalized.isBefore(
        DateTime(monday.year, monday.month, monday.day),
      ) &&
      !normalized.isAfter(DateTime(sunday.year, sunday.month, sunday.day));
}

String? _habitStatus(
  DashboardSnapshot snapshot,
  String habitId,
  DateTime date,
  DashboardHabit habit,
) {
  return snapshot.habitStatusFor(habitId, date) ??
      (_isCurrentWeek(date) && habit.weeklyProgress[date.weekday - 1]
          ? 'done'
          : null);
}

String _habitStatusLabel(
  DashboardSnapshot snapshot,
  String habitId,
  DateTime date,
  DashboardHabit habit,
) {
  return switch (_habitStatus(snapshot, habitId, date, habit)) {
    'done' => '${habit.category} · Completata',
    'missed' => '${habit.category} · Saltata',
    _ => '${habit.category} · Non registrata',
  };
}

bool _canEditDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized == today ||
      normalized == today.subtract(const Duration(days: 1));
}

String _periodLabel(DateTime anchor, CalendarViewMode view) => switch (view) {
  CalendarViewMode.month => '${_months[anchor.month - 1]} ${anchor.year}',
  CalendarViewMode.week =>
    'Settimana del ${anchor.day} ${_months[anchor.month - 1]}',
  CalendarViewMode.year => '${anchor.year}',
  CalendarViewMode.life => 'Settimane del tuo percorso',
};

const _months = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

const _habitCategories = [
  'Benessere',
  'Produttivita',
  'Formazione',
  'Salute',
  'Mindfulness',
];

const _habitColors = [
  EvolveColors.primaryStrong,
  EvolveColors.cyan,
  EvolveColors.violet,
  EvolveColors.amber,
  EvolveColors.rose,
];
