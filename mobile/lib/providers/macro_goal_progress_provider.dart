import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data_mode.dart';
import '../core/macro_goal_progress_resolver.dart';
import '../core/private_local_database.dart';
import '../core/supabase_macro_goal_progress.dart';
import 'auth_provider.dart';
import 'goal_provider.dart';
import 'macro_goals_provider.dart';

/// Resolved CURRENT progress amount for every NUMERIC macro goal, keyed by
/// macro-goal id.
///
/// This is the read path the progress bar reads: a macro goal's displayed
/// progress is NOT a single column. A manual goal resolves from its stored
/// `progress_amount`; a LINKED goal sums the linked habit's `goal_progress`
/// over the goal's period — a per-goal DB read (local DB in private mode,
/// Supabase in account mode). The fraction/label are then computed by feeding
/// this amount + the target into `evaluateMacroGoalProgress` at the widget.
///
/// Recomputes whenever the macro goals or the data mode change. `autoDispose`
/// so the per-goal reads stop when no numeric-goal surface is mounted.
final macroGoalProgressProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final goals = ref
      .watch(macroGoalsProvider)
      .goals
      .where((g) => g.hasNumericTarget)
      .toList();
  if (goals.isEmpty) return const <String, double>{};

  // Re-derive when the user logs habit progress, so a LINKED goal's bar tracks
  // its habit live (parity with desktop, which reads the live snapshot). Watched
  // purely as an invalidation signal — the actual sum is (re)read below.
  ref.watch(habitProgressProvider);

  final isPrivate = ref.watch(activeDataModeProvider) == AppDataMode.private;

  LinkedHabitProgressSum fetchLinkedSum;
  if (isPrivate) {
    final store = ref.read(privateLocalDatabaseProvider);
    fetchLinkedSum = store.linkedHabitProgressSum;
  } else {
    final user = supabase.auth.currentUser;
    if (user == null) {
      // Signed out: linked goals can't resolve their derived total; manual
      // goals still read their stored value (the fetcher is never called).
      fetchLinkedSum = (_, _) async => 0;
    } else {
      fetchLinkedSum = (habitId, range) =>
          sumCloudLinkedHabitProgress(supabase, user.id, habitId, range);
    }
  }

  final result = <String, double>{};
  for (final g in goals) {
    result[g.id] = await resolveMacroGoalProgress(
      typeWireName: g.type.name,
      year: g.year,
      quarter: g.quarter,
      month: g.month,
      weekNumber: g.weekNumber,
      linkedGoalId: g.linkedGoalId,
      storedAmount: g.progressAmount,
      fetchLinkedSum: fetchLinkedSum,
    );
  }
  return result;
});
