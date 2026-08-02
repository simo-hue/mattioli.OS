/// Calendar-day arithmetic for the UI's date grids. Mirror of the desktop
/// client's `core/calendar_days.dart`, kept at parity for the same reason the
/// two `streak_utils.dart` copies are.
///
/// A `Duration` of 24 hours is NOT a calendar day. Across a DST transition a
/// local day is 23 or 25 hours long, so `add`/`subtract` of `Duration(days: n)`
/// drifts an hour each time it crosses one — and once the drift takes a
/// timestamp past midnight, the DATE it denotes is wrong:
///
///  * stepping **forward** out of a 25-hour fall-back day lands at 23:00 of the
///    SAME date, so a day is emitted twice;
///  * stepping **backward** out of a 23-hour spring-forward day lands at 23:00
///    of the PREVIOUS date, so a day is skipped entirely.
///
/// It bit hardest where the steps ACCUMULATE — the weekly view's ‹ › paging kept
/// a running `DateTime` and added `Duration(days: 7)` per press, so the drift was
/// permanent: measured from a 23:30 start, week 11 of 2026 landed on 03-31
/// instead of 03-30 and every subsequent week stayed a day off, leaving the grid
/// labelled Mon–Sun over Tue–Mon dates and opening the wrong day's details.
library;

/// [d] shifted by [n] calendar days, at midnight. [n] may be negative.
DateTime shiftDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Midnight on the Monday of the week containing [date].
DateTime startOfWeek(DateTime date) => shiftDays(date, -(date.weekday - 1));

/// The seven days of the Monday-start week containing [anchor], each at
/// midnight, in order.
List<DateTime> weekDaysFor(DateTime anchor) {
  final monday = startOfWeek(anchor);
  return [for (var i = 0; i < 7; i++) shiftDays(monday, i)];
}
