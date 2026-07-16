/// Pure, deterministic streak computation shared by cloud (Supabase) and
/// Private Mode (SQLCipher). This mirrors the web app's
/// `src/lib/streakUtils.ts` so the two clients stay at parity.
///
/// The returned value is a *signed* integer:
///   - `> 0`  → length of the consecutive `'done'` run ending on (or, for a
///              pending day, just before) [date] — the 🔥 positive streak.
///   - `< 0`  → negated length of the consecutive `'missed'` run — the 💔
///              negative streak.
///   - `0`    → no active streak, or [date] is before [startDate].
///
/// Semantics (confirmed with product, matching the web app):
///   - Walk strict *calendar* days backwards. Any unlogged ("pending") day
///     breaks the streak. `frequency_days` is intentionally **not** consulted.
///   - A direction (positive/negative) is set by the status on [date]; the run
///     only counts days of that same status and stops at the first day that
///     differs (including pending/unlogged and the sign flip).
///   - If [date] itself is pending, look back one day so an ongoing streak can
///     still be displayed as "continuing".
library;

/// Logs shaped as `{ 'yyyy-MM-dd': { habitId: status } }`, where `status` is
/// `'done'` or `'missed'`. Matches `HabitLogsMap` in `goal_provider.dart`.
typedef StreakLogs = Map<String, Map<String, String>>;

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Shifts [d] by [n] calendar days, mirroring `_shiftDays` in
/// `features/statistics/data/private_analytics.dart`. Replaces
/// `d.subtract(Duration(days: n))`, which is a fixed 24h multiple and so lands
/// on the wrong calendar day across a DST transition (a 23h day is skipped
/// entirely, a 25h day is visited twice).
DateTime _shiftDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

int computeStreak({
  required String habitId,
  required DateTime date,
  required StreakLogs logs,
  required DateTime startDate,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final start = DateTime(startDate.year, startDate.month, startDate.day);

  if (day.isBefore(start)) return 0;

  String? statusAt(DateTime d) => logs[_dateKey(d)]?[habitId];

  // Direction of the streak: true = positive ('done'), false = negative
  // ('missed'). Null until we find a status to anchor on.
  bool? positive;
  int count = 0;
  DateTime checkDate = day;

  final status = statusAt(day);
  if (status == 'done') {
    positive = true;
    count = 1;
  } else if (status == 'missed') {
    positive = false;
    count = 1;
  } else {
    // [date] is pending: look at yesterday so an ongoing streak still shows.
    final yesterday = _shiftDays(day, -1);
    if (yesterday.isBefore(start)) return 0;
    final yStatus = statusAt(yesterday);
    if (yStatus == 'done') {
      positive = true;
      checkDate = yesterday;
      count = 1;
    } else if (yStatus == 'missed') {
      positive = false;
      checkDate = yesterday;
      count = 1;
    } else {
      return 0;
    }
  }

  var daysBack = 1;
  while (true) {
    final pastDate = _shiftDays(checkDate, -daysBack);
    if (pastDate.isBefore(start)) break;

    final pastStatus = statusAt(pastDate);
    if (positive) {
      if (pastStatus == 'done') {
        count++;
      } else {
        break;
      }
    } else {
      if (pastStatus == 'missed') {
        count++;
      } else {
        break;
      }
    }

    daysBack++;
    if (daysBack > 365 * 10) break; // safety: never spin forever
  }

  return positive ? count : -count;
}
