/// Pure, deterministic streak computation shared by cloud (Supabase) and
/// Private Mode (SQLCipher). Kept in lock-step with the mobile copy
/// (`mobile/lib/core/streak_utils.dart`) so the two Flutter clients stay at
/// parity; it **intentionally diverges** from the web app's
/// `src/lib/streakUtils.ts`, which has no day-of-week scheduling.
///
/// The returned value is a *signed* integer:
///   - `> 0`  → length of the consecutive `'done'` run ending on (or, for a
///              pending day, just before) [date] — the 🔥 positive streak.
///   - `< 0`  → negated length of the consecutive `'missed'` run — the 💔
///              negative streak.
///   - `0`    → no active streak, or [date] is before [startDate].
///
/// Semantics:
///   - Walk calendar days backwards, but honor [frequencyDays] (ISO weekdays
///     1=Mon…7=Sun; `null`/empty ⇒ every day): days the habit is **not**
///     scheduled on are *transparent* — they neither count toward nor break the
///     streak, the walk simply steps over them. Among scheduled days, any
///     unlogged ("pending") day still breaks the streak.
///   - A direction (positive/negative) is set by the status on the most recent
///     scheduled day at/before [date]; the run only counts scheduled days of
///     that same status and stops at the first scheduled day that differs
///     (including pending/unlogged and the sign flip).
///   - If that day is pending, look back to the previous scheduled day so an
///     ongoing streak can still be displayed as "continuing".
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
  List<int>? frequencyDays,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final start = DateTime(startDate.year, startDate.month, startDate.day);

  if (day.isBefore(start)) return 0;

  // An empty list is treated the same as null (every day): a habit scheduled on
  // no days would otherwise spin the scheduled-day search forever.
  final freq = (frequencyDays == null || frequencyDays.isEmpty)
      ? null
      : frequencyDays;
  bool scheduled(DateTime d) => freq == null || freq.contains(d.weekday);
  String? statusAt(DateTime d) => logs[_dateKey(d)]?[habitId];

  // Anchor on the most recent *scheduled* day at or before [date]; off-days at
  // the tail are stepped over so they don't hide an ongoing streak.
  DateTime anchor = day;
  while (!anchor.isBefore(start) && !scheduled(anchor)) {
    anchor = _shiftDays(anchor, -1);
  }
  if (anchor.isBefore(start)) return 0;

  // Direction of the streak: true = positive ('done'), false = negative
  // ('missed'). Null until we find a status to anchor on.
  bool? positive;
  int count = 0;
  DateTime checkDate = anchor;

  final status = statusAt(anchor);
  if (status == 'done') {
    positive = true;
    count = 1;
  } else if (status == 'missed') {
    positive = false;
    count = 1;
  } else {
    // The anchor (today, most likely) is pending: look back to the previous
    // scheduled day so an ongoing streak still shows.
    DateTime prev = _shiftDays(anchor, -1);
    while (!prev.isBefore(start) && !scheduled(prev)) {
      prev = _shiftDays(prev, -1);
    }
    if (prev.isBefore(start)) return 0;
    final pStatus = statusAt(prev);
    if (pStatus == 'done') {
      positive = true;
      checkDate = prev;
      count = 1;
    } else if (pStatus == 'missed') {
      positive = false;
      checkDate = prev;
      count = 1;
    } else {
      return 0;
    }
  }

  var cursor = checkDate;
  var guard = 0;
  while (true) {
    cursor = _shiftDays(cursor, -1);
    if (cursor.isBefore(start)) break;
    if (++guard > 365 * 10) break; // safety: never spin forever
    if (!scheduled(cursor)) continue; // off-day: transparent to the streak

    final pastStatus = statusAt(cursor);
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
  }

  return positive ? count : -count;
}
