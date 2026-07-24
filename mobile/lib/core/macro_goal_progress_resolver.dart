import 'package:evolve_targets/evolve_targets.dart';

import 'macro_goal_calendar.dart';

/// Sums a linked habit's `goal_progress.amount` over [range] (null ⇒ all
/// history). Injected so the resolution below stays pure and unit-testable — in
/// ACCOUNT mode this reads Supabase, in PRIVATE mode the local SQLCipher DB.
typedef LinkedHabitProgressSum =
    Future<double> Function(String habitId, MacroGoalDateRange? range);

/// The CURRENT effective progress amount for a numeric macro goal — the ONE
/// place the "linked ⇒ sum the habit over its period, manual ⇒ read the stored
/// number" rule is joined to a real data source.
///
/// A manual goal ([linkedGoalId] == null) reads its [storedAmount] with no
/// query. A linked goal maps its period to a date range ([macroGoalPeriodRange])
/// and sums the linked habit's progress over it via [fetchLinkedSum]. The final
/// clamp/floor is delegated to [resolveMacroProgressAmount] (evolve_targets) so
/// the display path and the delete-time snapshot can never disagree about which
/// source wins or how a stray negative is handled.
Future<double> resolveMacroGoalProgress({
  required String typeWireName,
  int? year,
  int? quarter,
  int? month,
  int? weekNumber,
  String? linkedGoalId,
  double? storedAmount,
  required LinkedHabitProgressSum fetchLinkedSum,
}) async {
  if (linkedGoalId == null) {
    return resolveMacroProgressAmount(
      isLinked: false,
      storedAmount: storedAmount,
    );
  }
  final range = macroGoalPeriodRange(
    type: typeWireName,
    year: year,
    quarter: quarter,
    month: month,
    week: weekNumber,
  );
  final sum = await fetchLinkedSum(linkedGoalId, range);
  return resolveMacroProgressAmount(isLinked: true, linkedSum: sum);
}
