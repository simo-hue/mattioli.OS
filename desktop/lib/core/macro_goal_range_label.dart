import 'package:evolve_desktop/core/macro_goal_calendar.dart';

/// Human-readable date range for a macro goal period — "8 – 14 August 2026",
/// "29 August – 4 September 2026", "29 December 2025 – 4 January 2026".
///
/// The Goals board header states *which* period you are looking at ("Week 2",
/// "Quarter 3", "August"); those labels are opaque on their own, so the line
/// underneath spells out the exact days the period covers. The range always
/// comes from [macroGoalPeriodRange], which is the same window a linked habit's
/// daily progress is summed over — so the header can never disagree with the
/// completion ring beside it. Notably that means the final logical week of a
/// month prints its true cross-month window (August week 5 → 29 August –
/// 4 September): those four days genuinely count toward the goal, and clamping
/// the label to the month end would show a window the app does not use.
///
/// Every locale-visible fragment is injected, following the `describePeriod`
/// recipe in `features/search/application/period_parser.dart`: month names come
/// from `t.common.months` (so a month is spelled the same here as in the shell
/// header) and the three sentence shapes come from `t.goalsPage.range*`, so a
/// translator — Arabic especially — controls word order, punctuation and the
/// dash. That also keeps this function pure and testable with no slang setup.
/// The mobile client carries a twin at the same path; keep the two in step, as
/// is already the convention for `macro_goal_calendar.dart`.
///
/// [range] endpoints are read field-wise and are expected to be the UTC,
/// day-granular values [macroGoalPeriodRange] produces. They are deliberately
/// **not** converted to local time: `toLocal()` on a UTC midnight moves the
/// date backwards a day in every negative-offset zone, which would print a
/// range one day short of the one the progress math uses.
String macroGoalRangeLabel(
  MacroGoalDateRange range, {
  required List<String> monthNames,
  required MacroGoalRangeSameMonthTemplate sameMonth,
  required MacroGoalRangeSameYearTemplate sameYear,
  required MacroGoalRangeCrossYearTemplate crossYear,
}) {
  final start = range.start;
  final end = range.end;

  if (start.year != end.year) {
    return crossYear(
      startDay: start.day,
      startMonth: _monthName(monthNames, start.month),
      startYear: start.year,
      endDay: end.day,
      endMonth: _monthName(monthNames, end.month),
      endYear: end.year,
    );
  }

  // Same year: name the month once when both endpoints share it.
  if (start.month == end.month) {
    return sameMonth(
      startDay: start.day,
      endDay: end.day,
      month: _monthName(monthNames, end.month),
      year: end.year,
    );
  }

  return sameYear(
    startDay: start.day,
    startMonth: _monthName(monthNames, start.month),
    endDay: end.day,
    endMonth: _monthName(monthNames, end.month),
    year: end.year,
  );
}

/// Month name for a 1-based [month], or an empty string if the index is out of
/// range or the caller passed a short list. A defensive fallback rather than a
/// throw: a header is never worth crashing a page over, and the surrounding
/// title still names the period.
String _monthName(List<String> monthNames, int month) {
  if (month < 1 || month > monthNames.length) return '';
  return monthNames[month - 1];
}

/// Signatures of the three slang-generated `t.goalsPage.range*` templates.
/// Declared here so [macroGoalRangeLabel] stays independent of the generated
/// translation classes (and so tests can pass plain lambdas).
typedef MacroGoalRangeSameMonthTemplate =
    String Function({
      required Object startDay,
      required Object endDay,
      required Object month,
      required Object year,
    });

typedef MacroGoalRangeSameYearTemplate =
    String Function({
      required Object startDay,
      required Object startMonth,
      required Object endDay,
      required Object endMonth,
      required Object year,
    });

typedef MacroGoalRangeCrossYearTemplate =
    String Function({
      required Object startDay,
      required Object startMonth,
      required Object startYear,
      required Object endDay,
      required Object endMonth,
      required Object endYear,
    });
