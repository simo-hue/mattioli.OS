import 'package:sqflite_sqlcipher/sqflite.dart';

import 'macro_goal_calendar.dart';

/// Sum of habit [habitId]'s `goal_progress.amount` over [range] — the window a
/// linked cumulative macro goal accumulates over. A null [range] means "all
/// history" (a lifetime goal). Dates are stored as `yyyy-MM-dd` strings, which
/// sort lexicographically, so a string BETWEEN is exact.
///
/// Pure over the database (no app state), so both the delete-time snapshot and
/// the display path can derive the same number, and it is unit-testable against
/// a plain in-memory database.
Future<double> sumLinkedHabitProgress(
  DatabaseExecutor db,
  String habitId,
  MacroGoalDateRange? range,
) async {
  final where = StringBuffer('goal_id = ?');
  final args = <Object?>[habitId];
  if (range != null) {
    where.write(' AND date >= ? AND date <= ?');
    args.add(_dateKey(range.start));
    args.add(_dateKey(range.end));
  }
  final rows = await db.rawQuery(
    'SELECT COALESCE(SUM(amount), 0) AS total FROM goal_progress WHERE $where',
    args,
  );
  return (rows.first['total'] as num?)?.toDouble() ?? 0;
}

/// Before a habit is deleted, snapshot the derived total into every macro goal
/// it feeds: sum the habit's `goal_progress` over each goal's period, write it
/// into `progress_amount`, and null `linked_goal_id`.
///
/// Turning a derived goal into an equivalent manual one in ONE write (a single
/// sync record) matters because deleting the habit cascades its `goal_progress`
/// away — without this, a "500 km" goal that reached 320 would collapse to 0 the
/// instant the link's data vanished. The `ON DELETE SET NULL` FK would un-link
/// it anyway; this is purely about preserving the accumulated number.
///
/// Must run BEFORE the habit row is deleted (while its progress still exists),
/// ideally in the same transaction as the delete.
Future<void> snapshotLinkedMacroGoals(
  DatabaseExecutor db,
  String habitId, {
  required String now,
}) async {
  final linked = await db.query(
    'long_term_goals',
    columns: ['id', 'type', 'year', 'quarter', 'month', 'week_number'],
    where: 'linked_goal_id = ?',
    whereArgs: [habitId],
  );
  if (linked.isEmpty) return;
  for (final m in linked) {
    final total = await sumLinkedHabitProgress(
      db,
      habitId,
      macroGoalPeriodRange(
        type: m['type'] as String? ?? 'lifetime',
        year: (m['year'] as num?)?.toInt(),
        quarter: (m['quarter'] as num?)?.toInt(),
        month: (m['month'] as num?)?.toInt(),
        week: (m['week_number'] as num?)?.toInt(),
      ),
    );
    await db.update(
      'long_term_goals',
      {'progress_amount': total, 'linked_goal_id': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [m['id']],
    );
  }
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
