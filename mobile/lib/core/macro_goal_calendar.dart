class MacroGoalDateRange {
  final DateTime start;
  final DateTime end;

  const MacroGoalDateRange({required this.start, required this.end});
}

/// The number of *addressable* weeks in any month. Constant by construction:
/// days 1–28 of every month fill weeks 1–4, and the 1–3 day tail a longer month
/// leaves over is not a week of its own — it is the head of the NEXT month's
/// week 1 (see [weekBucketRange]).
///
/// This replaces the older `logicalWeeksInMonth`, which returned 5 for any month
/// past 28 days and let that fifth week run a full 7 days past the month end.
/// August week 5 therefore spanned 29 August – 4 September while September
/// week 1 spanned 1 – 7 September: the two overlapped on four days, so a linked
/// habit's progress on 1–4 September was summed into BOTH goals.
const int macroGoalWeeksInMonth = 4;

/// A canonical macro-goal week address: the identity a weekly goal is filed
/// under, and the unit the Goals board navigates by.
///
/// Canonical means [week] is always in `1..macroGoalWeeksInMonth`. Storage is
/// deliberately laxer than this — clients shipped before the merge wrote
/// `week_number = 5`, and `schema.sql` still permits 1–53 — so an address read
/// out of the database must pass through [canonicalWeekBucket] before it is
/// compared, ranged or advanced.
class WeekBucket {
  /// Asserts the canonical range rather than clamping, so a caller that builds
  /// an address by hand finds out in debug instead of silently comparing
  /// unequal to the same bucket spelled canonically. Release builds strip the
  /// assert, which is why [nextWeekBucket] and [prevWeekBucket] still
  /// canonicalise defensively — a bad address must never page the board to a
  /// week that does not exist.
  const WeekBucket({
    required this.year,
    required this.month,
    required this.week,
  }) : assert(
         week >= 1 && week <= macroGoalWeeksInMonth,
         'a WeekBucket week must be canonical; pass a stored address through '
         'canonicalWeekBucket first',
       );

  final int year;
  final int month;
  final int week;

  @override
  bool operator ==(Object other) =>
      other is WeekBucket &&
      other.year == year &&
      other.month == month &&
      other.week == week;

  @override
  int get hashCode => Object.hash(year, month, week);

  @override
  String toString() => 'WeekBucket($year-$month w$week)';
}

/// Days in [month] of [year]. Day 0 of the following month is the last day of
/// this one, which also normalises a month index of 13 for free.
int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// The canonical bucket a stored `(year, month, week)` triple denotes.
///
/// A stored week 5 is NOT a week of its own month — it is the head of the next
/// month's week 1, which is the whole point of the merge: `(2026, 8, 5)` and
/// `(2026, 9, 1)` are two spellings of the same ten-day bucket, 29 August –
/// 7 September. Canonicalising on read is what lets legacy rows keep working
/// with no migration and lets an older client go on writing week 5 harmlessly.
///
/// Out-of-range input is absorbed rather than rejected: [month] is normalised
/// through [DateTime] (so month 13 rolls the year), a [week] below 1 becomes 1,
/// and any [week] at or above 5 merges FORWARD. A goal address is never worth
/// throwing over. A 1..53 value from the schema is read as a week-of-month
/// index, never as an ISO week-of-year.
///
/// Note the deliberate asymmetry with the pickers, which CLAMP an out-of-range
/// week back to [macroGoalWeeksInMonth] rather than merging it forward. They
/// answer different questions: a picked week is an *intent* inside the month
/// the user is looking at, so it saturates there; a stored week is an
/// *address*, and week 5 is the legacy spelling of a bucket in the next month.
WeekBucket canonicalWeekBucket(int year, int month, int week) {
  final normalised = DateTime.utc(year, month, 1);
  if (week <= macroGoalWeeksInMonth) {
    return WeekBucket(
      year: normalised.year,
      month: normalised.month,
      week: week < 1 ? 1 : week,
    );
  }
  final merged = DateTime.utc(normalised.year, normalised.month + 1, 1);
  return WeekBucket(year: merged.year, month: merged.month, week: 1);
}

/// The bucket containing [date] — the "current week" for every default landing
/// state, `"this week"` search and rollover fallback.
///
/// Days 29–31 belong to the NEXT month's week 1, so on 30 August 2026 this
/// returns September week 1, and on 30 December 2026 it returns January 2027
/// week 1. That forward jump is intended: the week containing those days really
/// does run into the next month, and landing on the previous month's week 4
/// would open the app on a week that has already ended.
WeekBucket weekBucketOf(DateTime date) =>
    canonicalWeekBucket(date.year, date.month, ((date.day - 1) ~/ 7) + 1);

/// The bucket after [bucket]. Weeks 1–3 advance within the month; week 4 rolls
/// to the next month's week 1.
///
/// The input is canonicalised first (see [canonicalWeekBucket]), which is what
/// stops a legacy week-5 goal from "advancing" into the very bucket it already
/// occupies.
WeekBucket nextWeekBucket(WeekBucket bucket) {
  final b = canonicalWeekBucket(bucket.year, bucket.month, bucket.week);
  if (b.week < macroGoalWeeksInMonth) {
    return WeekBucket(year: b.year, month: b.month, week: b.week + 1);
  }
  final next = DateTime.utc(b.year, b.month + 1, 1);
  return WeekBucket(year: next.year, month: next.month, week: 1);
}

/// The bucket before [bucket]. Week 1 steps back to the previous month's
/// week 4 — never to a week 5, which no longer exists as an address.
WeekBucket prevWeekBucket(WeekBucket bucket) {
  final b = canonicalWeekBucket(bucket.year, bucket.month, bucket.week);
  if (b.week > 1) {
    return WeekBucket(year: b.year, month: b.month, week: b.week - 1);
  }
  final prev = DateTime.utc(b.year, b.month - 1, 1);
  return WeekBucket(
    year: prev.year,
    month: prev.month,
    week: macroGoalWeeksInMonth,
  );
}

/// Re-anchors a shared `(year, month)` period selection when the Goals board
/// switches between the weekly plan and the calendar-shaped ones (monthly,
/// quarterly, annual).
///
/// The board keeps ONE year and ONE month across every plan, but on the 29th to
/// 31st the plans disagree about what "today" is: the current week bucket is
/// next month's week 1 (30 August 2026 → September week 1) while the current
/// month is still August. Seeding both from one value leaves whichever plan you
/// switch to showing the wrong period — and in the create-goal dialog it files a
/// monthly goal under the wrong month.
///
/// Only a selection still parked on today's period is moved; once the user has
/// navigated elsewhere their position is theirs and comes back untouched. On
/// days 1-28 both anchors coincide and this is a no-op.
({int year, int month}) reanchorPeriod({
  required DateTime now,
  required bool toWeekly,
  required int year,
  required int month,
}) {
  final bucket = weekBucketOf(now);
  if (toWeekly) {
    if (year == now.year && month == now.month) {
      return (year: bucket.year, month: bucket.month);
    }
  } else if (year == bucket.year && month == bucket.month) {
    return (year: now.year, month: now.month);
  }
  return (year: year, month: month);
}

/// The inclusive, UTC, day-granular `[start, end]` range a week bucket covers.
///
/// Weeks 2–4 are always exactly seven days — 8–14, 15–21, 22–28. Week 1 absorbs
/// the previous month's tail when that month ran past 28 days, so it is 8–10
/// days long: September 2026 week 1 is 29 August – 7 September. After a 28-day
/// February there is no tail to absorb and week 1 is an ordinary 1–7.
///
/// Together with [weekBucketOf] this is an exact partition of the calendar:
/// every day falls in exactly one bucket, with no overlap and no gap. That is
/// what makes a linked habit's daily progress countable — `macroGoalPeriodRange`
/// sums over this range, so a day that appeared in two ranges was summed twice.
MacroGoalDateRange weekBucketRange(int year, int month, int week) {
  final b = canonicalWeekBucket(year, month, week);

  if (b.week == 1) {
    final prev = DateTime.utc(b.year, b.month - 1, 1);
    // A 28-day month ends exactly on its week 4, leaving no tail to merge.
    final start = _daysInMonth(prev.year, prev.month) > 28
        ? DateTime.utc(prev.year, prev.month, 29)
        : DateTime.utc(b.year, b.month, 1);
    return MacroGoalDateRange(
      start: start,
      end: DateTime.utc(b.year, b.month, 7),
    );
  }

  final start = DateTime.utc(b.year, b.month, (b.week - 1) * 7 + 1);
  return MacroGoalDateRange(
    start: start,
    end: start.add(const Duration(days: 6)),
  );
}

/// The `[start, end]` calendar range (inclusive, UTC, day-granular) a cumulative
/// macro goal of [type] covers, from its period fields — the window a linked
/// habit's daily progress is summed over. Returns **null** for a lifetime goal
/// (all history, no bound) and for any period missing the fields it needs (a
/// safe "sum everything" fallback rather than a throw).
///
/// [type] is a `GoalType`/`long_term_goal_type` wire name
/// (lifetime/annual/quarterly/monthly/weekly). Weekly reuses [weekBucketRange]
/// so the boundary matches the app's week-of-month calendar exactly — including
/// the canonicalisation of a legacy stored week 5.
MacroGoalDateRange? macroGoalPeriodRange({
  required String type,
  int? year,
  int? quarter,
  int? month,
  int? week,
}) {
  switch (type) {
    case 'annual':
      if (year == null) return null;
      return MacroGoalDateRange(
        start: DateTime.utc(year, 1, 1),
        end: DateTime.utc(year, 12, 31),
      );
    case 'quarterly':
      if (year == null || quarter == null) return null;
      final startMonth = (quarter - 1) * 3 + 1;
      return MacroGoalDateRange(
        start: DateTime.utc(year, startMonth, 1),
        // Day 0 of the month after the quarter's last month = that last day.
        end: DateTime.utc(year, startMonth + 3, 0),
      );
    case 'monthly':
      if (year == null || month == null) return null;
      return MacroGoalDateRange(
        start: DateTime.utc(year, month, 1),
        end: DateTime.utc(year, month + 1, 0),
      );
    case 'weekly':
      if (year == null || month == null || week == null) return null;
      return weekBucketRange(year, month, week);
    case 'lifetime':
    default:
      return null;
  }
}
