// `dashboardGoalDueLabel` names the period a goal is filed under, and it is
// recomputed from the STORED fields on every deserialize
// (`DashboardGoal.fromRemoteJson`) rather than read back from the row. So a
// legacy `week_number = 5` goal would render "Week 5, 8/2026" while the board
// files it under September week 1 — the label has to canonicalise too.
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

  test('renames a legacy week 5 to the bucket that contains it', () {
    expect(weekly(year: 2026, month: 8, week: 5), 'Week 1, 9/2026');
    // Identical to the canonical spelling of the same bucket.
    expect(weekly(year: 2026, month: 8, week: 5), weekly(year: 2026, month: 9, week: 1));
  });

  test('carries a legacy December week 5 into the next year', () {
    expect(weekly(year: 2026, month: 12, week: 5), 'Week 1, 1/2027');
  });

  test('falls back rather than throwing when the address is incomplete', () {
    // Both are reachable: week_number, year and month are all nullable in the
    // cloud and private schemas alike.
    expect(weekly(year: 2026, month: 8), 'Week');
    expect(weekly(week: 3), 'Week 3, /');
  });
}
