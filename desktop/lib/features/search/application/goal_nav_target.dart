import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A one-shot instruction to open the Goals page on a *specific* period
/// (and optionally spotlight one goal), instead of its default "today's week".
///
/// The command palette drops one of these via [goalNavTargetProvider] and then
/// navigates to the Goals section. `GoalsPage.initState` consumes it exactly
/// once — seeding its local period state from the target — then clears it, so
/// ordinary opens (sidebar, ⌘4) still land on the current week. See the design
/// note "Desktop ⌘K command palette design".
class GoalNavTarget {
  const GoalNavTarget({
    required this.type,
    this.year,
    this.quarter,
    this.month,
    this.week,
    this.highlightGoalId,
    this.openEditor = false,
  });

  /// The period fields mirror `_GoalsPageState`'s selection exactly, so seeding
  /// is a direct copy. Which sub-fields matter depends on [type]
  /// (see [GoalType]): weekly uses year+month+week, monthly year+month,
  /// quarterly year+quarter, annual year, lifetime none.
  final GoalType type;
  final int? year;
  final int? quarter;
  final int? month;
  final int? week;

  /// When set, the Goals board briefly glows this goal's row and scrolls it
  /// into view after landing. Null for a plain "jump to this period" with no
  /// particular goal to spotlight.
  final String? highlightGoalId;

  /// When true, the Goals page opens the goal editor for [highlightGoalId] right
  /// after landing — the palette's "Edit" row action, which reuses the page's
  /// own editor (with all its category context) instead of duplicating it.
  final bool openEditor;

  /// Build a target that lands on [goal]'s own period and spotlights it.
  factory GoalNavTarget.forGoal(DashboardGoal goal, {bool openEditor = false}) =>
      GoalNavTarget(
        type: goal.type,
        year: goal.year,
        quarter: goal.quarter,
        month: goal.month,
        week: goal.weekNumber,
        highlightGoalId: goal.id,
        openEditor: openEditor,
      );
}

/// Holds the pending [GoalNavTarget], or null when there is nothing queued.
///
/// Deliberately a consume-once channel: [set] queues a jump, [consume] reads and
/// atomically clears it. Reading via [consume] (rather than watching) keeps the
/// jump a true one-shot — a later rebuild of the Goals page won't re-apply a
/// stale target.
class GoalNavTargetNotifier extends Notifier<GoalNavTarget?> {
  @override
  GoalNavTarget? build() => null;

  void set(GoalNavTarget target) => state = target;

  /// Returns the queued target (if any) and clears it in the same step.
  GoalNavTarget? consume() {
    final current = state;
    state = null;
    return current;
  }
}

final goalNavTargetProvider =
    NotifierProvider<GoalNavTargetNotifier, GoalNavTarget?>(
      GoalNavTargetNotifier.new,
    );
