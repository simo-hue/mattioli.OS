// Coverage for the ⌘K palette's natural-language period parser: it turns typed
// text ("week 2 march", "q2 2026", "march", "this week") into concrete Goals
// period jumps, and describes a period back as a label.
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/search/application/goal_nav_target.dart';
import 'package:evolve_desktop/features/search/application/period_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

void main() {
  // A fixed "now" so tests are deterministic (mid-August 2026).
  final now = DateTime(2026, 8, 12);

  List<GoalNavTarget> parse(String q) =>
      parsePeriodQuery(q, now: now, monthNames: _months);

  group('parsePeriodQuery', () {
    test('empty / unrecognised → no jumps', () {
      expect(parse(''), isEmpty);
      expect(parse('buy milk'), isEmpty);
    });

    test('"this week" → current week', () {
      final r = parse('this week');
      expect(r, hasLength(1));
      expect(r.first.type, GoalType.weekly);
      expect(r.first.year, 2026);
      expect(r.first.month, 8);
      expect(r.first.week, 2); // day 12 → week-of-month 2
    });

    test('a bare month name → that month of the current year', () {
      final r = parse('march');
      expect(r, hasLength(1));
      expect(r.first.type, GoalType.monthly);
      expect(r.first.month, 3);
      expect(r.first.year, 2026);
    });

    test('a 3-letter month prefix matches', () {
      expect(parse('mar').first.month, 3);
      expect(parse('sep').first.month, 9);
    });

    test('month + explicit year', () {
      final r = parse('march 2027');
      expect(r.first.type, GoalType.monthly);
      expect(r.first.month, 3);
      expect(r.first.year, 2027);
    });

    test('quarter forms', () {
      expect(parse('q2').first.type, GoalType.quarterly);
      expect(parse('q2').first.quarter, 2);
      expect(parse('quarter 3 2025').first.quarter, 3);
      expect(parse('quarter 3 2025').first.year, 2025);
    });

    test('week + month → weekly target', () {
      final r = parse('week 2 march');
      expect(r.first.type, GoalType.weekly);
      expect(r.first.month, 3);
      expect(r.first.week, 2);
      expect(r.first.year, 2026);
    });

    test('compact week form "wk3 sep"', () {
      final r = parse('wk3 sep');
      expect(r.first.type, GoalType.weekly);
      expect(r.first.month, 9);
      expect(r.first.week, 3);
    });

    test('a bare 4-digit year → annual', () {
      final r = parse('2027');
      expect(r.first.type, GoalType.annual);
      expect(r.first.year, 2027);
    });

    test('lifetime keyword', () {
      expect(parse('lifetime').first.type, GoalType.lifetime);
      expect(parse('life').first.type, GoalType.lifetime);
    });

    test('single stray letter does not match a month', () {
      expect(parse('m'), isEmpty);
    });
  });

  group('describePeriod', () {
    String describe(GoalNavTarget t) => describePeriod(
      t,
      monthNames: _months,
      weekWord: 'Week',
      lifetimeWord: 'Life',
    );

    test('formats each granularity', () {
      expect(
        describe(const GoalNavTarget(type: GoalType.annual, year: 2026)),
        '2026',
      );
      expect(
        describe(
          const GoalNavTarget(type: GoalType.quarterly, year: 2026, quarter: 2),
        ),
        'Q2 2026',
      );
      expect(
        describe(
          const GoalNavTarget(type: GoalType.monthly, year: 2026, month: 3),
        ),
        'March 2026',
      );
      expect(
        describe(
          const GoalNavTarget(
            type: GoalType.weekly,
            year: 2026,
            month: 3,
            week: 2,
          ),
        ),
        'Week 2, March 2026',
      );
      expect(
        describe(const GoalNavTarget(type: GoalType.lifetime)),
        'Life',
      );
    });
  });
}
