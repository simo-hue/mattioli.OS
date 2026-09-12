// Parity with mobile's `life_months_lived_test.dart`.
//
// The Life View shows MONTHS LIVED, CURRENT AGE and MONTHS REMAINING on both
// clients from the same expression, and both counted month BOUNDARIES rather
// than months completed: neither `birthDate.day` nor `now.day` appeared in the
// arithmetic. DOB 1990-09-15 read on 2026-09-02 gave 432 months and age 36, for
// someone who is 35. Age is `livedMonths ~/ 12`, so the birthday arrived up to a
// month early.
//
// Fixing one client alone would have left the two disagreeing by a month for the
// same user, which is why this file exists next to the mobile one.
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the birth month is not credited before the birthday', () {
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 9, 2)), 431);
    expect(
      lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 9, 2)) ~/ 12,
      35,
    );
  });

  test('the month is credited on the birthday and after', () {
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 9, 15)), 432);
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 9, 16)), 432);
  });

  test('a mid-year reading is unaffected', () {
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 12, 20)), 435);
    expect(lifeMonthsLived(DateTime(1990, 9, 15), DateTime(2026, 3, 20)), 426);
  });

  test('a day-of-month that the current month does not have', () {
    expect(lifeMonthsLived(DateTime(2000, 1, 31), DateTime(2026, 2, 28)), 312);
    expect(lifeMonthsLived(DateTime(2000, 1, 31), DateTime(2026, 3, 1)), 313);
  });

  test('the same day is zero months, not one', () {
    expect(lifeMonthsLived(DateTime(2026, 9, 15), DateTime(2026, 9, 15)), 0);
  });

  test('it never goes negative', () {
    expect(lifeMonthsLived(DateTime(2026, 9, 15), DateTime(2026, 9, 1)), 0);
  });
}
