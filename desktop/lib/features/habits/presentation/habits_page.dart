import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/performance_color.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/rtl.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      title: t.common.habits,
      subtitle: t.habitsPage.subtitle,
      trailing: PageActionButton(
        label: t.habitsPage.newHabit,
        icon: LucideIcons.plus,
        primary: true,
        onPressed: () => _openHabitEditor(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Summary(snapshot: snapshot),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumns = constraints.maxWidth >= 1120;
              if (useColumns) {
                // Desktop-first composition (mirrors the dashboard): protocol
                // and calendar are visible side by side, no surface switcher.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _protocolSurface(snapshot, wide: true),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 5,
                      child: _calendarSurface(snapshot, wide: true),
                    ),
                  ],
                );
              }
              // Narrow windows keep the segmented Protocol/Calendar switcher.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EvolveSegmentedControl<_HabitSurface>(
                    height: 44,
                    segments: {
                      _HabitSurface.protocol: t.habitsPage.tabProtocol,
                      _HabitSurface.calendar: t.habitsPage.tabCalendar,
                    },
                    selected: _surface,
                    onSelected: (surface) => setState(() => _surface = surface),
                  ),
                  const SizedBox(height: 14),
                  if (_surface == _HabitSurface.protocol)
                    _protocolSurface(snapshot, wide: false)
                  else
                    _calendarSurface(snapshot, wide: false),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _protocolSurface(DashboardSnapshot snapshot, {required bool wide}) {
    return _ProtocolPanel(
      snapshot: snapshot,
      wide: wide,
      onToggle: (id) =>
          ref.read(dashboardControllerProvider.notifier).toggleHabit(id),
      onAdd: wide ? () => _openHabitEditor() : null,
      onEdit: _openHabitEditor,
      onDelete: _deleteHabit,
      onReorder: (oldIndex, newIndex) => ref
          .read(dashboardControllerProvider.notifier)
          .reorderHabits(oldIndex, newIndex),
    );
  }

  Widget _calendarSurface(DashboardSnapshot snapshot, {required bool wide}) {
    return _CalendarPanel(
      snapshot: snapshot,
      wide: wide,
      anchor: _anchor,
      view: _calendarView,
      onViewChanged: (view) => setState(() => _calendarView = view),
      onPrevious: () => setState(() => _anchor = _shiftAnchor(-1)),
      onNext: () => setState(() => _anchor = _shiftAnchor(1)),
      onToday: () => setState(() => _anchor = DateTime.now()),
      onSelectDay: _openDayDetails,
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
        icon: LucideIcons.trash2,
        iconColor: EvolveColors.destructive,
        title: Text(t.habitsPage.deleteHabitTitle),
        content: Text(t.habitsPage.deleteHabitConfirm(title: habit.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.actions.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.actions.delete),
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

/// Dashboard-style metric grid (Wrap, 4 columns on wide surfaces, else 2)
/// mirroring the Overview page's metric cards.
class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080 ? 4 : 2;
        const spacing = 14.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _SummaryCard(
              width: cardWidth,
              label: t.habitsPage.activeProtocol,
              value: '${snapshot.totalHabits}',
              icon: LucideIcons.listTodo,
              color: context.evolveAccent,
            ),
            _SummaryCard(
              width: cardWidth,
              label: t.habitsPage.completedToday,
              value: '${snapshot.completedHabits}',
              icon: LucideIcons.check,
              color: EvolveColors.cyan,
            ),
            _SummaryCard(
              width: cardWidth,
              label: t.stats.bestStreakLabel,
              value: t.dashboard.streakDaysShort(n: snapshot.bestStreak),
              icon: LucideIcons.flame,
              color: EvolveColors.amber,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: EvolvePanel(
        radius: 20,
        glowColor: color,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: context.evolveColors.foreground,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
            EvolveIconChip(icon: icon, color: color, size: 42, iconSize: 19),
          ],
        ),
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
    required this.onReorder,
    this.onAdd,
    this.wide = false,
  });

  final DashboardSnapshot snapshot;
  final ValueChanged<String> onToggle;
  final ValueChanged<DashboardHabit> onEdit;
  final ValueChanged<DashboardHabit> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Optional quick-add action shown next to the status pill (wide mode).
  final VoidCallback? onAdd;

  /// Two-column composition: the section takes the protocol tab label as its
  /// title and the rows compact themselves to the narrower column.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final habits = snapshot.habits;
    final pill = StatusPill(
      label: t.stats.currentWeek,
      icon: LucideIcons.calendarClock,
    );
    // Mobile habit-manager look: floating heading + one translucent outlined
    // card per habit row instead of a single table panel.
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = wide && constraints.maxWidth < 700
            ? const _HabitRowMetrics.dense()
            : const _HabitRowMetrics.regular();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 2, end: 2),
              child: SectionHeading(
                title: wide
                    ? t.habitsPage.tabProtocol
                    : t.habitsPage.dailyProtocol,
                subtitle: t.habitsPage.protocolSubtitle,
                trailing: onAdd == null
                    ? pill
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          pill,
                          const SizedBox(width: 8),
                          EvolveSquareIconButton(
                            icon: LucideIcons.plus,
                            tooltip: t.habitsPage.newHabit,
                            onTap: onAdd,
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            _HabitHeader(metrics: metrics),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: habits.length,
              onReorderItem: onReorder,
              itemBuilder: (context, index) {
                final habit = habits[index];
                return _HabitRow(
                  key: ValueKey(habit.id),
                  habit: habit,
                  metrics: metrics,
                  onToggle: () => onToggle(habit.id),
                  onEdit: () => onEdit(habit),
                  onDelete: () => onDelete(habit),
                  dragHandle: ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      LucideIcons.gripVertical,
                      size: 16,
                      color: context.evolveColors.muted,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Column sizing for the protocol table: regular for full-width surfaces,
/// dense when the protocol shares the main row with the calendar panel.
class _HabitRowMetrics {
  const _HabitRowMetrics.regular()
    : streakWidth = 100,
      weekWidth = 200,
      reminderWidth = 105,
      actionsWidth = 84,
      daySquareSize = 18,
      daySquareGap = 8,
      actionButtonSize = 36,
      actionIconSize = 17,
      verticalPadding = 12;

  const _HabitRowMetrics.dense()
    : streakWidth = 78,
      weekWidth = 136,
      reminderWidth = 68,
      actionsWidth = 64,
      daySquareSize = 14,
      daySquareGap = 5,
      actionButtonSize = 30,
      actionIconSize = 15,
      verticalPadding = 10;

  final double streakWidth;
  final double weekWidth;
  final double reminderWidth;
  final double actionsWidth;
  final double daySquareSize;
  final double daySquareGap;
  final double actionButtonSize;
  final double actionIconSize;
  final double verticalPadding;
}

class _HabitHeader extends StatelessWidget {
  const _HabitHeader({required this.metrics});

  final _HabitRowMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          const SizedBox(width: 24),
          const SizedBox(width: 32),
          Expanded(child: _ColumnLabel(t.habitsPage.colHabit)),
          SizedBox(
            width: metrics.streakWidth,
            child: _ColumnLabel(t.habitsPage.colStreak),
          ),
          SizedBox(
            width: metrics.weekWidth,
            child: _ColumnLabel(t.habitsPage.colLast7Days),
          ),
          SizedBox(
            width: metrics.reminderWidth,
            child: _ColumnLabel(t.habitsPage.colReminder),
          ),
          SizedBox(width: metrics.actionsWidth),
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
        color: context.evolveColors.muted.withValues(alpha: 0.8),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Calendar weekday header label (mobile: 9px w600 uppercase muted, ls .5).
class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: context.evolveColors.muted,
        fontSize: 9,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _HabitRow extends StatefulWidget {
  const _HabitRow({
    required this.habit,
    required this.metrics,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.dragHandle,
    super.key,
  });

  final DashboardHabit habit;
  final _HabitRowMetrics metrics;
  final Widget? dragHandle;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_HabitRow> createState() => _HabitRowState();
}

class _HabitRowState extends State<_HabitRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final metrics = widget.metrics;
    final completed = habit.state == HabitState.completed;
    // Desktop affordance: the row card brightens slightly under the pointer.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: metrics.verticalPadding,
        ),
        decoration: BoxDecoration(
          color: context.evolveColors.panel.withValues(
            alpha: _hovered ? 0.55 : 0.4,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.evolveColors.border.withValues(
              alpha: _hovered ? 0.9 : 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: widget.dragHandle == null
                  ? null
                  : MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: widget.dragHandle,
                    ),
            ),
            SizedBox(
              width: 32,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: InkWell(
                  onTap: widget.onToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: completed ? habit.color : Colors.transparent,
                      border: Border.all(
                        color: completed
                            ? habit.color
                            : context.evolveColors.borderStrong,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: completed
                        ? const Icon(
                            LucideIcons.check,
                            color: Color(0xFF092113),
                            size: 14,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: habit.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: habit.color.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.evolveColors.foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          habit.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.evolveColors.muted.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: metrics.streakWidth,
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.flame,
                    size: 12,
                    color: EvolveColors.amber,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      t.habitsPage.streakDays(n: habit.streak),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: EvolveColors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: metrics.weekWidth,
              child: Row(
                children: [
                  for (final done in habit.weeklyProgress)
                    Container(
                      width: metrics.daySquareSize,
                      height: metrics.daySquareSize,
                      margin: EdgeInsetsDirectional.only(
                        end: metrics.daySquareGap,
                      ),
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
              width: metrics.reminderWidth,
              child: Text(
                habit.reminderTime ?? t.common.none,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: metrics.actionsWidth,
              child: Row(
                children: [
                  _RowIconButton(
                    icon: LucideIcons.pencil,
                    tooltip: t.common.actions.edit,
                    size: metrics.actionButtonSize,
                    iconSize: metrics.actionIconSize,
                    onPressed: widget.onEdit,
                  ),
                  _RowIconButton(
                    icon: LucideIcons.trash2,
                    tooltip: t.common.actions.delete,
                    size: metrics.actionButtonSize,
                    iconSize: metrics.actionIconSize,
                    color: EvolveColors.destructive,
                    hoverColor: EvolveColors.destructive,
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact 36x36 row action icon: muted by default, foreground on hover
/// (destructive actions keep their red tint).
class _RowIconButton extends StatefulWidget {
  const _RowIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 36,
    this.iconSize = 17,
    this.color,
    this.hoverColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? hoverColor;

  @override
  State<_RowIconButton> createState() => _RowIconButtonState();
}

class _RowIconButtonState extends State<_RowIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.evolveColors.muted;
    final hoverColor = widget.hoverColor ?? context.evolveColors.foreground;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: IconButton(
        tooltip: widget.tooltip,
        visualDensity: VisualDensity.compact,
        constraints: BoxConstraints.tightFor(
          width: widget.size,
          height: widget.size,
        ),
        padding: EdgeInsets.zero,
        onPressed: widget.onPressed,
        icon: Icon(
          widget.icon,
          size: widget.iconSize,
          color: _hovered ? hoverColor : color,
        ),
      ),
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
    this.wide = false,
  });

  final DashboardSnapshot snapshot;
  final DateTime anchor;
  final CalendarViewMode view;
  final ValueChanged<CalendarViewMode> onViewChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectDay;

  /// Two-column composition: heading, view switcher and navigation live in
  /// the panel header zone and the month grid is width-capped.
  final bool wide;

  /// Keeps month day cells in a pleasant size range when the calendar column
  /// grows on large windows ((540 - 6 gaps) / 7 = 72px cells at most).
  static const _wideMonthMaxWidth = 540.0;

  @override
  Widget build(BuildContext context) {
    final switcher = EvolveSegmentedControl<CalendarViewMode>(
      height: 44,
      segments: {for (final mode in CalendarViewMode.values) mode: mode.label},
      selected: view,
      onSelected: onViewChanged,
    );
    final body = switch (view) {
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
    };

    if (wide) {
      return EvolvePanel(
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(
              title: t.habitsPage.tabCalendar,
              trailing: view == CalendarViewMode.life
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _navigationControls(context),
                    ),
            ),
            const SizedBox(height: 14),
            switcher,
            const SizedBox(height: 16),
            _PeriodTitle(anchor: anchor, view: view),
            const SizedBox(height: 16),
            if (view == CalendarViewMode.month)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _wideMonthMaxWidth,
                  ),
                  child: body,
                ),
              )
            else
              body,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switcher,
        const SizedBox(height: 14),
        EvolvePanel(
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PeriodTitle(anchor: anchor, view: view),
                  ),
                  if (view != CalendarViewMode.life)
                    ..._navigationControls(context),
                ],
              ),
              const SizedBox(height: 16),
              body,
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _navigationControls(BuildContext context) {
    return [
      SizedBox(
        height: 36,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onToday,
          child: Text(t.habitsPage.today),
        ),
      ),
      const SizedBox(width: 8),
      EvolveSquareIconButton(
        icon: directionalIcon(
          context,
          LucideIcons.chevronLeft,
          LucideIcons.chevronRight,
        ),
        tooltip: t.habitsPage.prevPeriod,
        onTap: onPrevious,
      ),
      const SizedBox(width: 4),
      EvolveSquareIconButton(
        icon: directionalIcon(
          context,
          LucideIcons.chevronRight,
          LucideIcons.chevronLeft,
        ),
        tooltip: t.habitsPage.nextPeriod,
        onTap: onNext,
      ),
    ];
  }
}

/// Mobile calendar header: 22px w800 period title with, on the month view,
/// the year as a muted subtitle underneath.
class _PeriodTitle extends StatelessWidget {
  const _PeriodTitle({required this.anchor, required this.view});

  final DateTime anchor;
  final CalendarViewMode view;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: context.evolveColors.foreground,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
    );
    if (view != CalendarViewMode.month) {
      return Text(_periodLabel(anchor, view), style: titleStyle);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.common.months[anchor.month - 1], style: titleStyle),
        Text(
          '${anchor.year}',
          style: TextStyle(
            color: context.evolveColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
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
            for (final day in t.habitsPage.weekdayAbbrevUpper)
              Expanded(child: Center(child: _WeekdayLabel(day))),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.85,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
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
    final isEditable = _canEditDate(date);
    final hasActivity = indicators.any(
      (habit) => _habitStatus(snapshot, habit.id, date, habit) != null,
    );

    // Mobile day-cell recipe: red→green performance tint for recorded days,
    // accent hairline for today / still-editable days, faded future days.
    Color? background;
    var borderColor = Colors.transparent;
    if (hasActivity) {
      background = performanceColor(
        completion,
        saturation: 0.7,
        lightness: 0.1,
        alpha: 0.3,
      );
      borderColor = performanceColor(
        completion,
        saturation: 0.8,
        lightness: 0.4,
        alpha: 0.5,
      );
    } else if (isEditable) {
      background = context.evolveAccent.withValues(alpha: 0.04);
      borderColor = context.evolveAccent.withValues(alpha: 0.25);
    }
    if (isToday && !hasActivity) {
      background = context.evolveColors.foreground.withValues(alpha: 0.04);
      borderColor = context.evolveAccent.withValues(alpha: 0.4);
    }
    if (isFuture) {
      background = null;
      borderColor = Colors.transparent;
    }

    return Opacity(
      opacity: isFuture ? 0.28 : 1,
      child: InkWell(
        onTap: onTap,
        mouseCursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: expanded ? 155 : null,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
            boxShadow: hasActivity && completion == 1.0
                ? [
                    BoxShadow(
                      color: performanceColor(
                        1,
                        saturation: 0.8,
                        lightness: 0.4,
                        alpha: 0.15,
                      ),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: isToday
                      ? context.evolveAccent
                      : hasActivity
                      ? context.evolveColors.foreground
                      : context.evolveColors.muted,
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (final habit in indicators.take(indicatorLimit))
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: switch (snapshot.habitStatusFor(
                          habit.id,
                          date,
                        )) {
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
                      style: TextStyle(
                        color: context.evolveColors.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                indicators.isEmpty
                    ? t.stats.noHabit
                    : '${(completion * 100).round()}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.evolveColors.muted.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.evolveColors.panel.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.evolveColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.common.months[month - 1],
                        style: TextStyle(
                          color: context.evolveColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
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
                          color: performanceColor(
                            _weekCompletion(month, week),
                            saturation: 0.8,
                            lightness: 0.4,
                          ),
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
    // Private mode has no Supabase user; read the date of birth from the
    // encrypted private profile instead of defaulting everyone to 2003.
    final isPrivate = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final String? dobString;
    if (isPrivate) {
      dobString = ref.watch(privateProfileProvider).value?.dateOfBirth;
    } else {
      final metadata = ref
          .watch(desktopAuthControllerProvider)
          .user
          ?.userMetadata;
      dobString = metadata?['date_of_birth'] as String?;
    }
    final birthDate = DateTime.tryParse(dobString ?? '') ?? DateTime(2003);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: t.habitsPage.lifeView,
          subtitle: t.habitsPage.lifeViewSubtitle,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _LifeMetric(
                label: t.habitsPage.monthsLived,
                value: '$livedMonths',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LifeMetric(label: t.habitsPage.currentAge, value: '$age'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LifeMetric(
                label: t.habitsPage.monthsRemaining,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.evolveColors.panel.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.evolveColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: context.evolveColors.foreground,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: context.evolveColors.muted.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
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
      icon: LucideIcons.calendarClock,
      title: Text(
        t.habitsPage.dayDetail(
          day: date.day,
          month: t.common.months[date.month - 1],
        ),
      ),
      subtitle: t.habitsPage.dayDetailSubtitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_canEditDate(date))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.lock,
                    size: 14,
                    color: context.evolveColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.habitsPage.editableHint,
                      style: TextStyle(
                        color: context.evolveColors.muted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final habit in snapshot.habitsFor(date))
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.flame,
                    size: 13,
                    color: EvolveColors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${habit.streak}',
                    style: const TextStyle(
                      color: EvolveColors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
          child: Text(t.habitsPage.close),
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
      icon: widget.habit == null ? LucideIcons.plus : LucideIcons.pencil,
      title: Text(
        widget.habit == null ? t.habitsPage.newHabit : t.habitsPage.editHabit,
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(t.form.title),
            const SizedBox(height: 8),
            TextField(controller: _title, autofocus: true),
            const SizedBox(height: 16),
            _FieldLabel(t.form.category),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [
                for (final value in _habitCategories)
                  DropdownMenuItem(
                    value: value,
                    child: Text(_localizedHabitCategory(value)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 16),
            _FieldLabel(t.habitsPage.optionalReminder),
            const SizedBox(height: 8),
            TextField(
              controller: _reminder,
              readOnly: true,
              decoration: InputDecoration(
                hintText: t.habitsPage.reminderHint,
                suffixIcon: _reminder.text.trim().isEmpty
                    ? Icon(
                        LucideIcons.bell,
                        size: 16,
                        color: context.evolveColors.muted,
                      )
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        color: context.evolveColors.muted,
                        onPressed: () => setState(() => _reminder.clear()),
                      ),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime:
                      _parseReminderTime(_reminder.text) ?? TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() => _reminder.text = _formatReminderTime(picked));
                }
              },
            ),
            const SizedBox(height: 20),
            _FieldLabel(t.form.color),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in _habitColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == color
                                ? (color.computeLuminance() > 0.7
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : Colors.white)
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: _color == color
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
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
          child: Text(t.common.actions.cancel),
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
          child: Text(t.common.actions.save),
        ),
      ],
    );
  }
}

/// Uppercase micro-label above a form field ("HABIT NAME" on mobile).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: context.evolveColors.muted,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Parses a stored `HH:mm` reminder string into a [TimeOfDay] (null if empty
/// or malformed), so the time picker can open on the current value.
TimeOfDay? _parseReminderTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Formats a [TimeOfDay] as a normalized 24-hour `HH:mm` string — the format
/// the notification scheduler ([_nextInstance]) expects, independent of the
/// picker's 12/24h display.
String _formatReminderTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

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
    'done' => t.habitsPage.statusDone(category: habit.category),
    'missed' => t.habitsPage.statusSkipped(category: habit.category),
    _ => t.habitsPage.statusUnrecorded(category: habit.category),
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
  CalendarViewMode.month =>
    '${t.common.months[anchor.month - 1]} ${anchor.year}',
  CalendarViewMode.week => t.habitsPage.weekOf(
    day: anchor.day,
    month: t.common.months[anchor.month - 1],
  ),
  CalendarViewMode.year => '${anchor.year}',
  CalendarViewMode.life => t.habitsPage.lifeWeeks,
};

// Preset category identifiers are kept stable (Italian) so they remain the
// values stored in the DB and match existing rows; only the displayed label is
// localized via [_localizedHabitCategory].
const _habitCategories = [
  'Benessere',
  'Produttivita',
  'Formazione',
  'Salute',
  'Mindfulness',
];

String _localizedHabitCategory(String value) => switch (value) {
  'Benessere' => t.habitsPage.catWellness,
  'Produttivita' => t.habitsPage.catProductivity,
  'Formazione' => t.habitsPage.catEducation,
  'Salute' => t.habitsPage.catHealth,
  'Mindfulness' => t.habitsPage.catMindfulness,
  _ => value,
};

const _habitColors = [
  EvolveColors.primaryStrong,
  EvolveColors.cyan,
  EvolveColors.violet,
  EvolveColors.amber,
  EvolveColors.rose,
];
