// `dashboardGoalDueLabel` names the normalized calendar period a goal belongs
// to. Overflow addresses must resolve to the same month/year as the board.
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  String weekly({int? year, int? month, int? week}) => dashboardGoalDueLabel(
    type: GoalType.weekly,
    year: year,
    month: month,
    weekNumber: week,
  );

  test('names a canonical week by its own address', () {
    expect(weekly(year: 2026, month: 9, week: 2), 'Week 2, 9/2026');
  });

  test('normalizes a fifth week in a month that owns only four', () {
    expect(weekly(year: 2026, month: 8, week: 5), 'Week 1, 9/2026');
    // Identical to the canonical spelling of the same bucket.
    expect(weekly(year: 2026, month: 8, week: 5), weekly(year: 2026, month: 9, week: 1));
  });

  test('keeps a real fifth week in December when it owns Thursday', () {
    expect(weekly(year: 2026, month: 12, week: 5), 'Week 5, 12/2026');
  });

  test('falls back rather than throwing when the address is incomplete', () {
    // Both are reachable: week_number, year and month are all nullable in the
    // cloud and private schemas alike.
    expect(weekly(year: 2026, month: 8), 'Week');
    expect(weekly(week: 3), 'Week 3, /');
  });
}
