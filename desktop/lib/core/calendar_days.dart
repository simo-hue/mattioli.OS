/// Calendar-day arithmetic for the UI's date grids.
///
/// A `Duration` of 24 hours is NOT a calendar day. Across a DST transition a
/// local day is 23 or 25 hours long, so `add`/`subtract` of `Duration(days: n)`
/// drifts by an hour each time it crosses one — and once the drift takes a
/// timestamp past midnight, the DATE it denotes is wrong:
///
///  * stepping **forward** out of a 25-hour fall-back day lands at 23:00 of the
///    SAME date, so a day is emitted twice;
///  * stepping **backward** out of a 23-hour spring-forward day lands at 23:00
///    of the PREVIOUS date, so a day is skipped entirely.
///
/// Both were live in the Habits week calendar. Constructing the date instead —
/// `DateTime(y, m, d + n)` — asks the calendar for "n days later", which is what
/// every one of these call sites means, and normalises to midnight as a bonus.
///
/// The same idiom, for the same reason, is `_shiftDays` in `core/streak_utils.dart`
/// and in `evolve_targets`' `target_reconcile.dart`, where the backward form had
/// silently dropped one calendar day per year from the end-of-day sweep.
library;

/// [d] shifted by [n] calendar days, at midnight. [n] may be negative.
DateTime shiftDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// The seven days of the Monday-start week containing [anchor], each at
/// midnight, in order.
///
/// [anchor]'s time-of-day is deliberately discarded: these are calendar cells,
/// and carrying a wall-clock time through them is what let the drift above reach
/// the dates in the first place. It also fixes a smaller bug — the week view
/// disabled a day cell when its date `isAfter(DateTime.now())`, so with the
/// anchor's own time attached, TODAY's cell was disabled for the rest of the day
/// whenever the anchor had been set later than the current moment.
List<DateTime> weekDaysFor(DateTime anchor) {
  final monday = shiftDays(anchor, -(anchor.weekday - 1));
  return [for (var i = 0; i < 7; i++) shiftDays(monday, i)];
}
