// Verifies the Goals board's period date-range line: the exact span of days a
// weekly / quarterly / monthly plan covers, rendered under the period title.
//
// Two layers, deliberately:
//  1. Real templates — the actual en/ar strings from lib/i18n, so a broken
//     translation or a placeholder typo fails here rather than on device.
//  2. Sentinel templates — echo lambdas that name the branch and each slot, so
//     a start/end swap (which reads plausibly in English) cannot hide.
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/core/macro_goal_range_label.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The label exactly as the Goals page builds it, for the period fields the
  /// page holds — going through [macroGoalPeriodRange] so these tests cover the
  /// same window the progress ring is computed from, not a hand-built range.
  String label({
    required String type,
    required Translations tr,
    int? year,
    int? quarter,
    int? month,
    int? week,
  }) {
    final range = macroGoalPeriodRange(
      type: type,
      year: year,
      quarter: quarter,
      month: month,
      week: week,
    );
    return macroGoalRangeLabel(
      range!,
      monthNames: tr.common.months,
      sameMonth: tr.goalsPage.rangeSameMonth,
      sameYear: tr.goalsPage.rangeSameYear,
      crossYear: tr.goalsPage.rangeCrossYear,
    );
  }

  final en = AppLocale.en.buildSync();

  group('weekly range (English)', () {
    test('names the month once when the week sits inside one month', () {
      expect(
        label(type: 'weekly', tr: en, year: 2026, month: 8, week: 2),
        '8 – 14 August 2026',
      );
    });

    test('covers the first seven days for week 1', () {
      expect(
        label(type: 'weekly', tr: en, year: 2026, month: 8, week: 1),
        '1 – 7 August 2026',
      );
    });

    // The final logical week of a month is a full seven days that spills into
    // the next month, and those spilled days really are summed into the goal
    // (see macroGoalPeriodRange). The label must show that, not a tidier window
    // the app does not actually use.
    test('spells out both months when the final week spills over', () {
      expect(
        label(type: 'weekly', tr: en, year: 2026, month: 8, week: 5),
        '29 August – 4 September 2026',
      );
    });

    test('spells out both years when the final week spills into January', () {
      expect(
        label(type: 'weekly', tr: en, year: 2025, month: 12, week: 5),
        '29 December 2025 – 4 January 2026',
      );
    });

    test('clamps a week number past the end of a short month', () {
      // February 2026 has 4 logical weeks; asking for a 5th yields the 4th.
      expect(
        label(type: 'weekly', tr: en, year: 2026, month: 2, week: 9),
        label(type: 'weekly', tr: en, year: 2026, month: 2, week: 4),
      );
    });
  });

  group('quarterly range (English)', () {
    test('covers each quarter end to end', () {
      expect(
        label(type: 'quarterly', tr: en, year: 2026, quarter: 1),
        '1 January – 31 March 2026',
      );
      expect(
        label(type: 'quarterly', tr: en, year: 2026, quarter: 2),
        '1 April – 30 June 2026',
      );
      expect(
        label(type: 'quarterly', tr: en, year: 2026, quarter: 3),
        '1 July – 30 September 2026',
      );
      expect(
        label(type: 'quarterly', tr: en, year: 2026, quarter: 4),
        '1 October – 31 December 2026',
      );
    });
  });

  group('monthly range (English)', () {
    test('covers the month, whatever its length', () {
      expect(
        label(type: 'monthly', tr: en, year: 2026, month: 8),
        '1 – 31 August 2026',
      );
      expect(
        label(type: 'monthly', tr: en, year: 2026, month: 4),
        '1 – 30 April 2026',
      );
    });

    test('shows February its true length in common and leap years', () {
      expect(
        label(type: 'monthly', tr: en, year: 2026, month: 2),
        '1 – 28 February 2026',
      );
      expect(
        label(type: 'monthly', tr: en, year: 2024, month: 2),
        '1 – 29 February 2024',
      );
    });

    test('does not run past December for month 12', () {
      expect(
        label(type: 'monthly', tr: en, year: 2026, month: 12),
        '1 – 31 December 2026',
      );
    });
  });

  // Every locale but the base one is generated behind a deferred import, so
  // these must go through the async `build()` that loads it — `buildSync`
  // throws "Deferred library not loaded" for anything except en.
  group('localisation', () {
    test('uses each locale template and its own month spelling', () async {
      // Italian and German are day-first like English; Spanish inserts "de";
      // German writes an ordinal dot after the day.
      expect(
        label(
          type: 'weekly',
          tr: await AppLocale.it.build(),
          year: 2026,
          month: 8,
          week: 2,
        ),
        '8 – 14 Agosto 2026',
      );
      expect(
        label(
          type: 'weekly',
          tr: await AppLocale.es.build(),
          year: 2026,
          month: 8,
          week: 2,
        ),
        '8 – 14 de Agosto de 2026',
      );
      expect(
        label(
          type: 'weekly',
          tr: await AppLocale.de.build(),
          year: 2026,
          month: 8,
          week: 2,
        ),
        '8. – 14. August 2026',
      );
    });

    test('honours the Arabic templates and month names', () async {
      final ar = await AppLocale.ar.build();
      // Spelled out rather than built from ar.common.months[7]: an expectation
      // assembled out of the same bundle it is checking also passes when that
      // month name is blank or wrong.
      expect(
        label(type: 'weekly', tr: ar, year: 2026, month: 8, week: 2),
        '8 – 14 أغسطس 2026',
      );
    });

    // rangeSameYear is the template EVERY quarterly header uses (a quarter always
    // spans three months of one year), so leaving it pinned in English only left
    // the most-seen string in four shipping locales unverified. A translator's
    // realistic mistake is reordering placeholders, not dropping one: dropping
    // changes the slang-generated signature and `flutter analyze` catches it,
    // whereas a reorder compiles clean and ships.
    test('pins rangeSameYear in every locale (a quarter)', () async {
      Future<String> quarter(AppLocale locale) async => label(
        type: 'quarterly',
        tr: await locale.build(),
        year: 2026,
        quarter: 3,
      );

      expect(await quarter(AppLocale.en), '1 July – 30 September 2026');
      expect(await quarter(AppLocale.it), '1 Luglio – 30 Settembre 2026');
      expect(
        await quarter(AppLocale.es),
        '1 de Julio – 30 de Septiembre de 2026',
      );
      expect(await quarter(AppLocale.de), '1. Juli – 30. September 2026');
      expect(await quarter(AppLocale.ar), '1 يوليو – 30 سبتمبر 2026');
    });

    test('pins rangeCrossYear in every locale (December week 5)', () async {
      Future<String> crossYear(AppLocale locale) async => label(
        type: 'weekly',
        tr: await locale.build(),
        year: 2025,
        month: 12,
        week: 5,
      );

      expect(
        await crossYear(AppLocale.en),
        '29 December 2025 – 4 January 2026',
      );
      expect(
        await crossYear(AppLocale.it),
        '29 Dicembre 2025 – 4 Gennaio 2026',
      );
      expect(
        await crossYear(AppLocale.es),
        '29 de Diciembre de 2025 – 4 de Enero de 2026',
      );
      expect(
        await crossYear(AppLocale.de),
        '29. Dezember 2025 – 4. Januar 2026',
      );
      expect(await crossYear(AppLocale.ar), '29 ديسمبر 2025 – 4 يناير 2026');
    });
  });

  group('template selection and slot mapping', () {
    // Echo templates: each names its branch and tags every slot, so a swapped
    // start/end or a month pulled from the wrong endpoint is unmistakable —
    // unlike with real prose, where "14 – 8 August" still reads like a date.
    String run(MacroGoalDateRange range, {List<String>? monthNames}) {
      return macroGoalRangeLabel(
        range,
        monthNames:
            monthNames ??
            const [
              'M1',
              'M2',
              'M3',
              'M4',
              'M5',
              'M6',
              'M7',
              'M8',
              'M9',
              'M10',
              'M11',
              'M12',
            ],
        sameMonth:
            ({
              required startDay,
              required endDay,
              required month,
              required year,
            }) => 'SAME_MONTH sd=$startDay ed=$endDay m=$month y=$year',
        sameYear:
            ({
              required startDay,
              required startMonth,
              required endDay,
              required endMonth,
              required year,
            }) =>
                'SAME_YEAR sd=$startDay sm=$startMonth ed=$endDay em=$endMonth y=$year',
        crossYear:
            ({
              required startDay,
              required startMonth,
              required startYear,
              required endDay,
              required endMonth,
              required endYear,
            }) =>
                'CROSS_YEAR sd=$startDay sm=$startMonth sy=$startYear ed=$endDay em=$endMonth ey=$endYear',
      );
    }

    test('picks sameMonth and fills every slot from the right endpoint', () {
      expect(
        run(logicalWeekRange(2026, 8, 2)),
        'SAME_MONTH sd=8 ed=14 m=M8 y=2026',
      );
    });

    test('picks sameYear across a month boundary', () {
      expect(
        run(logicalWeekRange(2026, 8, 5)),
        'SAME_YEAR sd=29 sm=M8 ed=4 em=M9 y=2026',
      );
    });

    test('picks crossYear across a year boundary', () {
      expect(
        run(logicalWeekRange(2025, 12, 5)),
        'CROSS_YEAR sd=29 sm=M12 sy=2025 ed=4 em=M1 ey=2026',
      );
    });

    test(
      'falls back to an empty month rather than throwing on a short list',
      () {
        // Defensive: a truncated month list must soften the label, never crash
        // the page mid-render.
        expect(
          run(logicalWeekRange(2026, 8, 2), monthNames: const ['M1']),
          'SAME_MONTH sd=8 ed=14 m= y=2026',
        );
      },
    );

    // macroGoalPeriodRange hands back UTC midnights, and this formatter must
    // read their fields as-is. A stray toLocal() would move the printed date a
    // day off the window progress is actually summed over.
    //
    // Both cases are needed, and neither alone is worth anything. A UTC-midnight
    // endpoint only shifts in NEGATIVE-offset zones, so the obvious version of
    // this test cannot fail under CI (TZ=Europe/Rome, .github/workflows) or
    // under UTC — it was in fact green against a deliberately toLocal()'d build.
    // The 23:30 case shifts in POSITIVE-offset zones instead. Together they kill
    // the mutation in every zone except exactly UTC, where no conversion can
    // change anything and there is nothing to catch.
    test('a UTC midnight endpoint is not shifted (bites at negative offsets)', () {
      final range = MacroGoalDateRange(
        start: DateTime.utc(2026, 8, 8),
        end: DateTime.utc(2026, 8, 14),
      );
      expect(run(range), 'SAME_MONTH sd=8 ed=14 m=M8 y=2026');
    });

    test('a late-evening UTC endpoint is not shifted (bites at positive offsets)', () {
      // 23:30 UTC on the 7th is already the 8th in Rome (UTC+2 in August) and in
      // every other positive-offset zone, so a toLocal() here prints day 8.
      final range = MacroGoalDateRange(
        start: DateTime.utc(2026, 8, 7, 23, 30),
        end: DateTime.utc(2026, 8, 14, 23, 30),
      );
      expect(run(range), 'SAME_MONTH sd=7 ed=14 m=M8 y=2026');
    });
  });
}
