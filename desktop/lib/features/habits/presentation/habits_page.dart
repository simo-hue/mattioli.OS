import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/calendar_view_preference.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/performance_color.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/rtl.dart';
import 'package:evolve_desktop/shared/widgets/coach_tutorial.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/verified_habit_badge.dart';
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

  // Habits segment of the continuous product tour. The central
  // [tourControllerProvider] owns whether this segment is active; this page owns
  // the step index within the segment and the spotlight target keys.
  int _tourIndex = 0;
  final _addKey = GlobalKey();
  final _checkoffKey = GlobalKey();
  final _streakKey = GlobalKey();
  final _surfaceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final value = ref
        .read(sharedPreferencesProvider)
        ?.getString('pref_default_calendar_view');
    // Normalize first: the pref now stores the canonical code, but older
    // builds stored the display label — and 'mese'/'month' previously had no
    // arm here at all, so a Month default wrongly opened the week view.
    _calendarView = switch (normalizeCalendarViewCode(value)) {
      kCalendarViewMonth => CalendarViewMode.month,
      kCalendarViewYear => CalendarViewMode.year,
      kCalendarViewLife => CalendarViewMode.life,
      _ => CalendarViewMode.week,
    };
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(dashboardControllerProvider);
    final showTour = ref
        .watch(tourControllerProvider)
        .isSegmentActive(TourSegment.habits);

    // During the Habits tour, when the user has no real habits yet, inject a
    // single view-only demo row so the check-off (step 3) and streak (step 4)
    // coach-marks have a target to spotlight. It is never persisted — it is
    // built at the widget layer only and the tour scrim blocks interaction.
    final demoHabits = showTour && snapshot.habits.isEmpty
        ? <DashboardHabit>[_tutorialDemoHabit()]
        : null;

    // App-like workspace: the page is pinned to the viewport. Fixed chrome
    // (metrics + the Protocollo/Calendario switch) sits on top and the active
    // view fills the remaining height, scrolling internally where needed.
    final page = DesktopPage(
      pinned: true,
      title: t.common.habits,
      subtitle: t.habitsPage.subtitle,
      trailing: KeyedSubtree(
        key: _addKey,
        child: PageActionButton(
          label: t.habitsPage.newHabit,
          icon: LucideIcons.plus,
          primary: true,
          onPressed: () => _openHabitEditor(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Summary(snapshot: snapshot),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: _surfaceKey,
            child: EvolveSegmentedControl<_HabitSurface>(
              height: 44,
              segments: {
                _HabitSurface.protocol: t.habitsPage.tabProtocol,
                _HabitSurface.calendar: t.habitsPage.tabCalendar,
              },
              selected: _surface,
              onSelected: (surface) => setState(() => _surface = surface),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              layoutBuilder: _expandedSwitcherLayout,
              child: KeyedSubtree(
                key: ValueKey(_surface),
                child: _surface == _HabitSurface.protocol
                    ? _protocolSurface(snapshot, demoHabits)
                    : _calendarSurface(snapshot),
              ),
            ),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        page,
        if (showTour)
          CoachTutorialOverlay(
            steps: _habitsTourSteps(),
            index: _tourIndex,
            onIndexChanged: (i) => setState(() => _tourIndex = i),
            // Last Habits step advances the tour to the Insights segment.
            onFinish: () => ref.read(tourControllerProvider.notifier).advance(),
            backLabel: t.tour.back,
            nextLabel: t.tour.next,
            finishLabel: t.tour.continueLabel,
          ),
      ],
    );
  }

  List<CoachStep> _habitsTourSteps() => [
    // Orientation-first: a centered card (no spotlight) announcing the page.
    CoachStep(
      title: t.tour.habitsOrientationTitle,
      description: t.tour.habitsOrientationDesc,
    ),
    CoachStep(
      targetKey: _addKey,
      title: t.tour.habitsAddTitle,
      description: t.tour.habitsAddDesc,
    ),
    CoachStep(
      targetKey: _checkoffKey,
      title: t.tour.habitsCheckoffTitle,
      description: t.tour.habitsCheckoffDesc,
    ),
    CoachStep(
      targetKey: _streakKey,
      title: t.tour.habitsStreakTitle,
      description: t.tour.habitsStreakDesc,
    ),
    CoachStep(
      targetKey: _surfaceKey,
      title: t.tour.habitsCalendarTitle,
      description: t.tour.habitsCalendarDesc,
    ),
  ];

  Widget _protocolSurface(
    DashboardSnapshot snapshot,
    List<DashboardHabit>? demoHabits,
  ) {
    return _ProtocolPanel(
      snapshot: snapshot,
      habitsOverride: demoHabits,
      checkoffKey: _checkoffKey,
      streakKey: _streakKey,
      onToggle: (id) =>
          ref.read(dashboardControllerProvider.notifier).toggleHabit(id),
      onAdd: () => _openHabitEditor(),
      onEdit: _openHabitEditor,
      onDelete: _deleteHabit,
      onReorder: (oldIndex, newIndex) => ref
          .read(dashboardControllerProvider.notifier)
          .reorderHabits(oldIndex, newIndex),
    );
  }

  Widget _calendarSurface(DashboardSnapshot snapshot) {
    return _CalendarPanel(
      snapshot: snapshot,
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
      final added = await controller.addHabit(
        title: draft.title,
        color: draft.color,
        reminderTime: draft.reminderTime,
      );
      if (!added && mounted) {
        // Free-tier 5-habit cap reached → present the paywall (mobile parity).
        await showProFeaturesDialog(context, ref);
      }
    } else {
      await controller.updateHabit(
        id: habit.id,
        title: draft.title,
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

/// AnimatedSwitcher layout that keeps both the incoming and the outgoing view
/// sized to the full pinned content area (the default Stack lets them
/// shrink-wrap during the cross-fade).
Widget _expandedSwitcherLayout(
  Widget? currentChild,
  List<Widget> previousChildren,
) {
  return Stack(
    fit: StackFit.expand,
    children: [...previousChildren, ?currentChild],
  );
}

/// A single view-only habit injected into the Protocol table during the Habits
/// tour when the user has no real habits yet, so the check-off (step 3) and the
/// streak/heatmap (step 4) coach-marks have a row to spotlight. It is never
/// written to the controller — [_ProtocolPanel] renders it and the tour scrim
/// blocks interaction, so its callbacks can't fire.
DashboardHabit _tutorialDemoHabit() => DashboardHabit(
  id: 'tutorial_fake_habit',
  title: t.habitsPage.catMindfulness,
  color: EvolveColors.cyan,
  streak: 5,
  weeklyProgress: const [true, true, false, true, true, false, false],
  state: HabitState.completed,
);

/// Compact metric strip: the three summary cards share one row of fixed
/// chrome. They are secondary info, so they stay ~72px tall and stop growing
/// at 470px per card (aligned to the start on very wide windows).
class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        label: t.habitsPage.activeProtocol,
        value: '${snapshot.totalHabits}',
        icon: LucideIcons.listTodo,
        color: context.evolveAccent,
      ),
      _SummaryCard(
        label: t.habitsPage.completedToday,
        value: '${snapshot.completedHabits}',
        icon: LucideIcons.check,
        color: EvolveColors.cyan,
      ),
      _SummaryCard(
        label: t.stats.bestStreakLabel,
        value: t.dashboard.streakDaysShort(n: snapshot.bestStreak),
        icon: LucideIcons.flame,
        color: EvolveColors.streakColor(snapshot.bestStreak),
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          if (index > 0) const SizedBox(width: 14),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: cards[index],
              ),
            ),
          ),
        ],
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
      radius: 20,
      glowColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          EvolveIconChip(icon: icon, color: color, size: 38, iconSize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.evolveColors.foreground,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-height protocol surface: one panel hosting the heading, the fixed
/// column-label row and the internally scrolling habit table.
class _ProtocolPanel extends StatefulWidget {
  const _ProtocolPanel({
    required this.snapshot,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
    this.habitsOverride,
    this.checkoffKey,
    this.streakKey,
  });

  final DashboardSnapshot snapshot;
  final ValueChanged<String> onToggle;
  final ValueChanged<DashboardHabit> onEdit;
  final ValueChanged<DashboardHabit> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Quick-add action shown next to the status pill.
  final VoidCallback onAdd;

  /// Tour-only replacement for the real habit list: when non-null it is
  /// rendered instead of `snapshot.habits` so the coach-marks have a row to
  /// point at. Never written back to the controller.
  final List<DashboardHabit>? habitsOverride;

  /// Spotlight targets threaded to the FIRST habit row (check-off square /
  /// streak cluster) for the Habits tour. Null on non-tour renders.
  final GlobalKey? checkoffKey;
  final GlobalKey? streakKey;

  @override
  State<_ProtocolPanel> createState() => _ProtocolPanelState();
}

class _ProtocolPanelState extends State<_ProtocolPanel> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habits = widget.habitsOverride ?? widget.snapshot.habits;
    const metrics = _HabitRowMetrics.comfortable();
    return EvolvePanel(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(
            title: t.habitsPage.dailyProtocol,
            subtitle: t.habitsPage.protocolSubtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusPill(
                  label: t.stats.currentWeek,
                  icon: LucideIcons.calendarClock,
                ),
                const SizedBox(width: 8),
                EvolveSquareIconButton(
                  icon: LucideIcons.plus,
                  tooltip: t.habitsPage.newHabit,
                  onTap: widget.onAdd,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _HabitHeader(metrics: metrics),
          const SizedBox(height: 8),
          Expanded(
            child: habits.isEmpty
                ? _EmptyProtocol(onAdd: widget.onAdd)
                : Scrollbar(
                    controller: _scroll,
                    child: ReorderableListView.builder(
                      scrollController: _scroll,
                      padding: const EdgeInsets.only(bottom: 4),
                      buildDefaultDragHandles: false,
                      itemCount: habits.length,
                      onReorderItem: widget.onReorder,
                      itemBuilder: (context, index) {
                        final habit = habits[index];
                        // Only the first row carries the tour spotlight keys.
                        final isFirst = index == 0;
                        return _HabitRow(
                          key: ValueKey(habit.id),
                          habit: habit,
                          metrics: metrics,
                          checkoffKey: isFirst ? widget.checkoffKey : null,
                          streakKey: isFirst ? widget.streakKey : null,
                          onToggle: () => widget.onToggle(habit.id),
                          onEdit: () => widget.onEdit(habit),
                          onDelete: () => widget.onDelete(habit),
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
                  ),
          ),
        ],
      ),
    );
  }
}

/// Empty state (LAYOUT_SPEC recipe): centered icon chip + existing copy +
/// the new-habit CTA. The scroll view is a guard for very short windows.
class _EmptyProtocol extends StatelessWidget {
  const _EmptyProtocol({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EvolveIconChip(
                icon: LucideIcons.listTodo,
                color: context.evolveAccent,
                size: 44,
                iconSize: 20,
              ),
              const SizedBox(height: 12),
              Text(
                t.stats.noHabit,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t.dashboard.emptyHabits,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: Text(t.habitsPage.newHabit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Column sizing for the full-width protocol table: one comfortable desktop
/// preset (the title/category column absorbs the remaining width).
class _HabitRowMetrics {
  const _HabitRowMetrics.comfortable()
    : streakWidth = 110,
      weekWidth = 210,
      reminderWidth = 120,
      actionsWidth = 90,
      daySquareSize = 18,
      daySquareGap = 8,
      actionButtonSize = 36,
      actionIconSize = 17,
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
    this.checkoffKey,
    this.streakKey,
    super.key,
  });

  final DashboardHabit habit;
  final _HabitRowMetrics metrics;
  final Widget? dragHandle;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Habits-tour spotlight targets: the check-off square and the streak/heatmap
  /// stat cluster. Non-null only on the first row while the tour is active.
  final GlobalKey? checkoffKey;
  final GlobalKey? streakKey;

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
                child: KeyedSubtree(
                  key: widget.checkoffKey,
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
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
                            ),
                            // Read-only marker for iPhone-verified habits
                            // (mobile parity).
                            if (habit.verificationRule != null) ...[
                              const SizedBox(width: 6),
                              const VerifiedHabitBadge(),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            KeyedSubtree(
              key: widget.streakKey,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: metrics.streakWidth,
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.flame,
                          size: 12,
                          color: EvolveColors.streakColor(habit.streak),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            t.habitsPage.streakDays(n: habit.streak),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: EvolveColors.streakColor(habit.streak),
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

/// Full-screen calendar surface: one panel with the period title on the left,
/// the Mese/Settimana/Anno/Vita switcher plus navigation on the right, and a
/// grid that flexes to fill all the remaining height.
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

    return EvolvePanel(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _PeriodTitle(anchor: anchor, view: view),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 380,
                child: EvolveSegmentedControl<CalendarViewMode>(
                  height: 44,
                  segments: {
                    for (final mode in CalendarViewMode.values)
                      mode: mode.label,
                  },
                  selected: view,
                  onSelected: onViewChanged,
                ),
              ),
              if (view != CalendarViewMode.life) ...[
                const SizedBox(width: 8),
                ..._navigationControls(context),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              layoutBuilder: _expandedSwitcherLayout,
              child: KeyedSubtree(key: ValueKey(view), child: body),
            ),
          ),
        ],
      ),
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
      return Text(
        _periodLabel(anchor, view),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.common.months[anchor.month - 1],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        Text(
          '${anchor.year}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
    final weeks = (leading + days + 6) ~/ 7;
    // The grid fills the viewport by construction: every week row is an
    // Expanded row of flexible day cells, so the month never scrolls.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var day = 0; day < 7; day++) ...[
              if (day > 0) const SizedBox(width: 6),
              Expanded(
                child: Center(
                  child: _WeekdayLabel(t.habitsPage.weekdayAbbrevUpper[day]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Column(
            children: [
              for (var week = 0; week < weeks; week++) ...[
                if (week > 0) const SizedBox(height: 6),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var day = 0; day < 7; day++) ...[
                        if (day > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _cellFor(week * 7 + day, leading, days),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _cellFor(int index, int leading, int days) {
    if (index < leading || index >= leading + days) {
      return const SizedBox.shrink();
    }
    final date = DateTime(anchor.year, anchor.month, index - leading + 1);
    return _DayCell(
      snapshot: snapshot,
      date: date,
      completion: _completionFor(snapshot, date),
      onTap: date.isAfter(DateTime.now()) ? null : () => onSelectDay(date),
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
    // Seven flexible day columns that fill the available height.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var day = 0; day < 7; day++) ...[
              if (day > 0) const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: _WeekdayLabel(t.habitsPage.weekdayAbbrevUpper[day]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    onTap:
                        monday
                            .add(Duration(days: index))
                            .isAfter(DateTime.now())
                        ? null
                        : () => onSelectDay(monday.add(Duration(days: index))),
                  ),
                ),
              ],
            ],
          ),
        ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Cells flex with the pinned viewport: short cells tighten their
            // padding, clip surplus dots and drop the completion caption; the
            // caption returns as soon as there is comfortable room (~90px).
            final compact = constraints.maxHeight < 64;
            final showCaption = constraints.maxHeight >= 72;
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 3 : 8,
              ),
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
                  SizedBox(height: compact ? 2 : 6),
                  Expanded(
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Wrap(
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
                      ),
                    ),
                  ),
                  if (showCaption) ...[
                    const SizedBox(height: 4),
                    Text(
                      indicators.isEmpty
                          ? t.stats.noHabit
                          : '${(completion * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.evolveColors.muted.withValues(
                          alpha: 0.8,
                        ),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
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
        // 4x3 month grid on wide surfaces, 3x4 when narrower — unless the
        // area is too short for four rows (compact pinned windows).
        final columns =
            constraints.maxWidth >= 1080 || constraints.maxHeight < 380 ? 4 : 3;
        final rows = (12 + columns - 1) ~/ columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: 11),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: 11),
                      Expanded(
                        child: _monthTile(context, row * columns + column + 1),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _monthTile(BuildContext context, int month) {
    final weeks = logicalWeeksInMonth(anchor.year, month);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.evolveColors.panel.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.evolveColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.common.months[month - 1],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.evolveColors.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          // The week bars distribute across whatever height the tile gets;
          // each bar keeps its 4px stroke and centers inside its slot.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var week = 0; week < weeks; week++)
                  Expanded(
                    child: Center(
                      child: LinearProgressIndicator(
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
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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

class _LifeCalendar extends ConsumerStatefulWidget {
  const _LifeCalendar();

  @override
  ConsumerState<_LifeCalendar> createState() => _LifeCalendarState();
}

class _LifeCalendarState extends ConsumerState<_LifeCalendar> {
  // The life grid is intrinsically tall, so it scrolls inside the panel.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    return Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        child: Column(
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
                  child: _LifeMetric(
                    label: t.habitsPage.currentAge,
                    value: '$age',
                  ),
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
        ),
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
            _DayHabitRow(
              title: habit.title,
              color: habit.color,
              streak: habit.streak,
              done: _habitStatus(snapshot, habit.id, date, habit) == 'done',
              statusLabel: _habitStatusLabel(snapshot, habit.id, date, habit),
              onToggle: _canEditDate(date)
                  ? () => ref
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

/// Day-detail habit completion row — the kit-native replacement for the old
/// Material `CheckboxListTile`. Mirrors the toggle square used by `_HabitRow`
/// (fills with the habit color + a check glyph when done) so completion reads
/// identically across the protocol table and the day-detail dialog, and adds
/// the title, status caption and streak badge.
class _DayHabitRow extends StatelessWidget {
  const _DayHabitRow({
    required this.title,
    required this.color,
    required this.streak,
    required this.done,
    required this.statusLabel,
    required this.onToggle,
  });

  final String title;
  final Color color;
  final int streak;
  final bool done;
  final String statusLabel;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final square = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: done ? color : Colors.transparent,
        border: Border.all(color: done ? color : colors.borderStrong),
        borderRadius: BorderRadius.circular(7),
      ),
      child: done
          ? const Icon(LucideIcons.check, color: Color(0xFF092113), size: 14)
          : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (onToggle == null)
            Opacity(opacity: 0.5, child: square)
          else
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: square,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            LucideIcons.flame,
            size: 13,
            color: EvolveColors.streakColor(streak),
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              color: EvolveColors.streakColor(streak),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
  late Color _color;
  var _usesDefaultColor = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.habit?.title);
    _reminder = TextEditingController(text: widget.habit?.reminderTime);
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
            EvolveFieldLabel(t.form.title),
            const SizedBox(height: 8),
            TextField(controller: _title, autofocus: true),
            const SizedBox(height: 16),
            EvolveFieldLabel(t.habitsPage.optionalReminder),
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
                final picked = await showEvolveTimePicker(
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
            EvolveFieldLabel(t.form.color),
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
    required this.color,
    this.reminderTime,
  });

  final String title;
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
    'done' => t.habitsPage.statusDone,
    'missed' => t.habitsPage.statusSkipped,
    _ => t.habitsPage.statusUnrecorded,
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

const _habitColors = [
  EvolveColors.primaryStrong,
  EvolveColors.cyan,
  EvolveColors.violet,
  EvolveColors.amber,
  EvolveColors.rose,
];
