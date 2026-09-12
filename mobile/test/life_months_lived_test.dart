// The Life View was a month ahead of itself for part of every year.
//
// `(now.year - birth.year) * 12 + now.month - birth.month` counts month
// BOUNDARIES crossed, not months completed. Neither `birthDate.day` nor
// `now.day` appeared anywhere in the file's arithmetic, so between the 1st of
// the birth month and the birthday itself the screen credited a month that had
// not happened yet.
//
// DOB 1990-09-15 read on 2026-09-02: MONTHS LIVED 432 and CURRENT AGE 36, for
// someone who is 35 and has lived 431 months and 18 days. Age is
// `livedMonths ~/ 12`, so the off-by-one month lands on the birthday itself —
// the app told people they were a year older, up to two weeks early. The
// highlighted "you are here" dot in the 1032-dot grid is fed the same number and
// sat a month in the future too.
//
// Tested as a function of two dates rather than through a pump: the widget reads
// `DateTime.now()`, and the case only exists when today's day-of-month is
// smaller than the birth day-of-month — unreachable on the 31st, so a
// now-relative widget test would be green seven days a year for the wrong
// reason.
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/ui/widgets/life_view_widget.dart';

void main() {
  test('the birth month is not credited before the birthday', () {
    // The reported case, exactly.
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 9, 2)), 431);
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 9, 2)) ~/ 12,
        35);
  });

  test('the month is credited on the birthday and after', () {
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 9, 15)), 432);
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 9, 16)), 432);
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 9, 15)) ~/ 12,
        36);
  });

  test('a mid-year reading is unaffected', () {
    // The day-of-month rule must only ever remove a month that has not
    // completed, never one that has.
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 12, 20)), 435);
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 3, 20)), 426);
  });

  test('a day-of-month that the current month does not have', () {
    // Born on the 31st, read in February. The 31st never arrives, so the month
    // is incomplete until the next month starts — which is what the comparison
    // says, and it is the honest answer rather than a special case.
    expect(lifeMonthsLived(DateTime(2000, 1, 31), DateTime(2026, 2, 28)), 312);
    expect(lifeMonthsLived(DateTime(2000, 1, 31), DateTime(2026, 3, 1)), 313);
  });

  test('the same day is zero months, not one', () {
    expect(lifeMonthsLived(DateTime(2026, 9, 15), DateTime(2026, 9, 15)), 0);
  });

  test('it never goes negative', () {
    // The widget already refuses a future date of birth, and the desktop mirror
    // clamps — but the raw count is the thing every caller multiplies, so pin
    // that it does not hand back a negative to clamp away.
    expect(lifeMonthsLived(DateTime(2026, 9, 15), DateTime(2026, 9, 1)), 0);
  });
}
