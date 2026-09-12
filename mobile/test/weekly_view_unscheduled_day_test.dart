// A day with nothing scheduled is not a day you failed.
//
// `_calculateDailyCompletion` already has an exclusion sentinel — `-1.0` for
// days in the future, which the `>= 0` gate downstream skips — but the
// `activeCount == 0` branch wrote `0.0` instead. So a Mon–Fri habit, done every
// single session, read "Best: mon 100% · Avg 71% · Worst: sat 0%" on Sunday: the
// two days the user had deliberately scheduled nothing on were counted as two
// perfect failures, and dragged the weekly average down by 29 points.
//
// The same two days read 100% on the trend chart — `private_analytics.dart`
// returns 100.0 when no goal is active on a date, and its SQL counterpart
// records that treating empty days the other way was itself a bug worth a
// migration. Weekday scheduling (5eba2d9) only changed the counting line and
// left this branch alone.
//
// Also hits the days before a new user's `startDate`, and every week after the
// last habit's `endDate`.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/calendar_days.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/ui/widgets/weekly_view_widget.dart';

/// The Monday of the week BEFORE the current one.
///
/// The widget anchors on `DateTime.now()`, which a widget test cannot move, so
/// the assertion is made one page back: every day of last week is in the past
/// whatever today happens to be, which removes the future-day sentinel from the
/// picture and leaves only the branch under test.
final DateTime _lastMonday = shiftDays(startOfWeek(DateTime.now()), -7);

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _WeekdayHabit extends GoalsNotifier {
  @override
  List<Goal> build() => [
        Goal(
          id: 'h1',
          title: 'Gym',
          color: Colors.blue,
          // Mon–Fri only. Saturday and Sunday have activeCount == 0.
          frequencyDays: const [1, 2, 3, 4, 5],
          startDate: shiftDays(_lastMonday, -30),
        ),
      ];
}

class _AllDoneLogs extends HabitLogsNotifier {
  @override
  HabitLogsMap build() => {
        for (var i = 0; i < 5; i++)
          _key(shiftDays(_lastMonday, i)): const {'h1': 'done'},
      };
}

/// The summary line, flattened out of its RichText spans.
///
/// Picked by content, not position: the header's date range is a RichText too,
/// and it is the one that comes first.
String _summary(WidgetTester tester) {
  final lines = tester
      .widgetList<RichText>(find.descendant(
        of: find.byType(WeeklyViewWidget),
        matching: find.byType(RichText),
      ))
      .map((r) => r.text.toPlainText())
      .where((s) => s.contains(t.weeklyView.avg))
      .toList();
  expect(lines, hasLength(1), reason: 'the Best/Avg/Worst summary line');
  return lines.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        goalsProvider.overrideWith(_WeekdayHabit.new),
        habitLogsProvider.overrideWith(_AllDoneLogs.new),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          locale: const Locale('en'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          home: const Scaffold(
            body: SizedBox(height: 800, child: WeeklyViewWidget()),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Page back to the fully-past week the logs were written for.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
  }

  testWidgets('a perfect Mon-Fri week reads 100%, not 71% with a 0% Saturday',
      (tester) async {
    await pump(tester);

    final summary = _summary(tester);

    expect(summary, contains('${t.weeklyView.avg}: 100%'),
        reason: 'the two unscheduled days were averaged in as zeros');
    // The worst day of a perfect week is a perfect day. Naming the percentage
    // as well as the label, because "WORST: sat" alone would also be satisfied
    // by a Saturday that legitimately scored.
    expect(summary, contains('${t.weeklyView.worst}: mon 100%'));
    expect(summary, contains('${t.weeklyView.best}: mon 100%'));
  });

  testWidgets('an unscheduled day is excluded, not floored at zero',
      (tester) async {
    // Pinned separately from the summary wording: the sentinel is the mechanism,
    // and the radar already maps a negative entry to 0 for drawing.
    await pump(tester);

    expect(_summary(tester), isNot(contains(': sat 0%')));
  });
}
