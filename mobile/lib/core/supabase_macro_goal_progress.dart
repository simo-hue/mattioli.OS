import 'package:supabase_flutter/supabase_flutter.dart';

import 'macro_goal_calendar.dart';

/// `yyyy-MM-dd` key for a `goal_progress.date` comparison — the same format the
/// rows are stored in, which sorts lexicographically so a string BETWEEN is
/// exact. Mirrors the local `sumLinkedHabitProgress` date key.
String macroGoalProgressDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Total of the `amount` column across [rows]. Pure, so the summing that feeds
/// both the display path and the delete-time snapshot is unit-testable without
/// a live Supabase client.
double sumProgressRows(Iterable<Map<String, dynamic>> rows) {
  var total = 0.0;
  for (final row in rows) {
    total += (row['amount'] as num?)?.toDouble() ?? 0;
  }
  return total;
}

/// Page size for the windowed read below. A single unbounded PostgREST select
/// is capped by the project's `db-max-rows` (1000 by default) and truncates
/// SILENTLY — which would undercount a long-history linked goal, and the
/// delete-time snapshot would then freeze that undercount permanently. Mirrors
/// `kGoalLogsSyncPageSize` / `kImportPageSize`.
const int kMacroGoalProgressPageSize = 1000;

/// Sum of habit [habitId]'s `goal_progress.amount` over [range] (null ⇒ all
/// history) from Supabase — the ACCOUNT-mode counterpart of the local
/// `sumLinkedHabitProgress`. This is the per-goal DB read a LINKED cumulative
/// macro goal's current progress is derived from.
Future<double> sumCloudLinkedHabitProgress(
  SupabaseClient client,
  String userId,
  String habitId,
  MacroGoalDateRange? range,
) async {
  final rows = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    // The filter is rebuilt each pass on purpose: `.order()`/`.range()` return a
    // transform builder, so the windowing cannot be re-applied to a hoisted
    // filter builder. The (date, id) sort makes the order total across pages —
    // `id` is the text PK — so no row is served twice or skipped.
    var query = client
        .from('goal_progress')
        .select('amount')
        .eq('user_id', userId)
        .eq('goal_id', habitId);
    if (range != null) {
      query = query
          .gte('date', macroGoalProgressDateKey(range.start))
          .lte('date', macroGoalProgressDateKey(range.end));
    }
    final page = await query
        .order('date', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + kMacroGoalProgressPageSize - 1);
    rows.addAll(page.cast<Map<String, dynamic>>());
    if (page.length < kMacroGoalProgressPageSize) break;
    offset += kMacroGoalProgressPageSize;
  }
  return sumProgressRows(rows);
}

/// Snapshots the derived total into every macro goal LINKED to [habitId]
/// (writes `progress_amount`, nulls `linked_goal_id`), over Supabase — the
/// ACCOUNT-mode counterpart of `snapshotLinkedMacroGoals`.
///
/// MUST run BEFORE the habit row is deleted (while its `goal_progress` still
/// exists): deleting the habit cascades its progress away and the
/// `ON DELETE SET NULL` FK un-links the macro goal automatically, so without
/// this a "500 km" goal that reached 320 would collapse to 0. Best-effort — the
/// caller proceeds with the delete even if this throws.
Future<void> snapshotCloudLinkedMacroGoals(
  SupabaseClient client,
  String userId,
  String habitId,
) async {
  final linked = await client
      .from('long_term_goals')
      .select('id, type, year, quarter, month, week_number')
      .eq('user_id', userId)
      .eq('linked_goal_id', habitId);
  for (final row in linked.cast<Map<String, dynamic>>()) {
    final range = macroGoalPeriodRange(
      type: row['type'] as String? ?? 'lifetime',
      year: (row['year'] as num?)?.toInt(),
      quarter: (row['quarter'] as num?)?.toInt(),
      month: (row['month'] as num?)?.toInt(),
      week: (row['week_number'] as num?)?.toInt(),
    );
    final total = await sumCloudLinkedHabitProgress(
      client,
      userId,
      habitId,
      range,
    );
    await client
        .from('long_term_goals')
        .update({'progress_amount': total, 'linked_goal_id': null})
        .eq('id', row['id'] as Object);
  }
}
