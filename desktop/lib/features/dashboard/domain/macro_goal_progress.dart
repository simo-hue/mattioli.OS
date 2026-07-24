import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_targets/evolve_targets.dart';

/// `yyyy-MM-dd` key — the format both `goal_progress.date` and the snapshot's
/// `habitProgress` map are keyed by, so a lexicographic compare is an exact
/// day-range test.
String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Sum of habit [habitId]'s daily progress within [range] (null ⇒ all history)
/// read from the snapshot's in-memory `dateKey -> habitId -> amount` map.
///
/// The dashboard snapshot already loads EVERY `goal_progress` row (both the
/// cloud and private repos select the whole table), so a LINKED macro goal's
/// derived total is a pure reduction over what is already in memory — no extra
/// per-goal query in either data mode. Pure + unit-testable.
double sumHabitProgressInRange(
  Map<String, Map<String, double>> habitProgress,
  String habitId,
  MacroGoalDateRange? range,
) {
  final startKey = range == null ? null : _dateKey(range.start);
  final endKey = range == null ? null : _dateKey(range.end);
  var total = 0.0;
  habitProgress.forEach((dateKey, byHabit) {
    final amount = byHabit[habitId];
    if (amount == null) return;
    if (startKey != null && dateKey.compareTo(startKey) < 0) return;
    if (endKey != null && dateKey.compareTo(endKey) > 0) return;
    total += amount;
  });
  return total;
}

/// The CURRENT effective progress amount for a numeric macro goal, resolved
/// against the snapshot's in-memory progress map: a MANUAL goal reads its stored
/// `progressAmount`; a LINKED goal sums the linked habit's progress over the
/// goal's period. The clamp/floor is delegated to [resolveMacroProgressAmount]
/// (evolve_targets) so this and mobile's resolver behave identically.
double resolveMacroGoalProgressAmount(
  DashboardGoal goal,
  Map<String, Map<String, double>> habitProgress,
) {
  final linkedId = goal.linkedGoalId;
  if (linkedId == null) {
    return resolveMacroProgressAmount(
      isLinked: false,
      storedAmount: goal.progressAmount,
    );
  }
  final range = macroGoalPeriodRange(
    type: goal.type.name,
    year: goal.year,
    quarter: goal.quarter,
    month: goal.month,
    week: goal.weekNumber,
  );
  final sum = sumHabitProgressInRange(habitProgress, linkedId, range);
  return resolveMacroProgressAmount(isLinked: true, linkedSum: sum);
}

/// The derived total to freeze into a macro goal that a habit feeds, before the
/// habit is deleted.
class LinkedMacroGoalSnapshot {
  const LinkedMacroGoalSnapshot({required this.goalId, required this.total});

  final String goalId;
  final double total;
}

/// The `(macroGoalId, derivedTotal)` snapshot for every macro goal LINKED to
/// [habitId] — the value each keeps as a now-manual `progress_amount` once the
/// habit (and its `goal_progress`) is deleted and the FK un-links it.
///
/// Pure over the already in-memory [goals] + [habitProgress], so the delete-time
/// snapshot both repos run is unit-testable without a database or client.
List<LinkedMacroGoalSnapshot> linkedMacroGoalSnapshots({
  required Iterable<DashboardGoal> goals,
  required Map<String, Map<String, double>> habitProgress,
  required String habitId,
}) {
  final result = <LinkedMacroGoalSnapshot>[];
  for (final goal in goals) {
    if (goal.linkedGoalId != habitId) continue;
    final range = macroGoalPeriodRange(
      type: goal.type.name,
      year: goal.year,
      quarter: goal.quarter,
      month: goal.month,
      week: goal.weekNumber,
    );
    result.add(
      LinkedMacroGoalSnapshot(
        goalId: goal.id,
        total: sumHabitProgressInRange(habitProgress, habitId, range),
      ),
    );
  }
  return result;
}

/// Convenience: the full [MacroGoalProgress] (fraction, label numbers, complete
/// flag) for [goal] against [habitProgress], or null when [goal] has no numeric
/// target (an ordinary boolean macro goal — render it exactly as today).
MacroGoalProgress? macroGoalProgressFor(
  DashboardGoal goal,
  Map<String, Map<String, double>> habitProgress,
) {
  if (!goal.hasNumericTarget) return null;
  final amount = resolveMacroGoalProgressAmount(goal, habitProgress);
  return evaluateMacroGoalProgress(
    targetAmount: goal.targetAmount,
    unit: TargetUnit.fromWire(goal.targetUnit),
    isLinked: goal.isLinked,
    // `amount` is already the resolved effective value, so pass it as the stored
    // side with isLinked:false to avoid re-deriving — evaluate only needs the
    // final number here.
    storedAmount: amount,
    linkedSum: amount,
  );
}
