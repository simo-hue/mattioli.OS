// Verifies the WIRING of the Goals board's period date range: that the header's
// second line actually renders the span of days for weekly / quarterly /
// monthly, and that annual and lifetime keep their prose subtitle instead.
//
// The exact wording of each range shape (same month, cross month, cross year,
// every locale) is pinned exhaustively by macro_goal_range_label_test.dart.
// What only a widget test can prove is that the page reaches for the range at
// all — the failure mode where _periodSubtitle keeps returning the old prose.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/core/macro_goal_range_label.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/goals/presentation/goals_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal in-memory repository: the header renders from the selected period
/// alone, so an empty snapshot is enough.
class _EmptyDashboardRepository extends DashboardRepository {
  @override
  DashboardSnapshot load() => DashboardSnapshot.empty;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}

/// Skips the cloud/private category fetch so the page renders hermetically.
class _NoCategoriesController extends DesktopGoalCategoriesController {
  @override
  Future<List<DesktopGoalCategory>> build() async => const [];
}

Future<void> _pumpGoalsPage(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          _EmptyDashboardRepository(),
        ),
        desktopGoalCategoriesControllerProvider.overrideWith(
          _NoCategoriesController.new,
        ),
      ],
      child: MaterialApp(
        theme: EvolveTheme.dark(),
        home: const Scaffold(body: GoalsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The range the page should be showing for [type] on the period it opens on —
/// built from the same fields `initState` seeds, so the expectation tracks the
/// wall clock exactly as the page does.
String _expectedRange(GoalType type) {
  final now = DateTime.now();
  final range = macroGoalPeriodRange(
    type: type.name,
    year: now.year,
    quarter: ((now.month - 1) ~/ 3) + 1,
    month: now.month,
    week: logicalWeekOfMonth(now),
  )!;
  return macroGoalRangeLabel(
    range,
    monthNames: t.common.months,
    sameMonth: t.goalsPage.rangeSameMonth,
    sameYear: t.goalsPage.rangeSameYear,
    crossYear: t.goalsPage.rangeCrossYear,
  );
}

/// Switches the board to [label]'s plan via the toolbar's segmented control.
Future<void> _selectPlan(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('weekly opens on the current week and shows its exact days', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpGoalsPage(tester);

    expect(find.text(_expectedRange(GoalType.weekly)), findsOneWidget);
    // The plan name it replaced is already on the tab and in the title.
    expect(find.text(t.goalsPage.subtitleWeekly), findsNothing);
  });

  testWidgets('quarterly shows the quarter first and last day', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpGoalsPage(tester);
    await _selectPlan(tester, t.macroGoals.types.quarterly);

    expect(find.text(_expectedRange(GoalType.quarterly)), findsOneWidget);
    expect(find.text(t.goalsPage.subtitleQuarterly), findsNothing);
  });

  testWidgets('monthly shows the month first and last day', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpGoalsPage(tester);
    await _selectPlan(tester, t.macroGoals.types.monthly);

    expect(find.text(_expectedRange(GoalType.monthly)), findsOneWidget);
    expect(find.text(t.goalsPage.subtitleMonthly), findsNothing);
  });

  testWidgets('annual keeps its prose subtitle — the title is its own range', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpGoalsPage(tester);
    await _selectPlan(tester, t.macroGoals.types.annual);

    expect(find.text(t.goalsPage.subtitleAnnual), findsOneWidget);
  });

  testWidgets('lifetime keeps its prose subtitle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpGoalsPage(tester);
    await _selectPlan(tester, t.macroGoals.types.lifetime);

    expect(find.text(t.goalsPage.subtitleLifetime), findsOneWidget);
  });

  testWidgets('paging to the next week moves the range with it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpGoalsPage(tester);

    final now = DateTime.now();
    final week = logicalWeekOfMonth(now);
    final weeksInMonth = logicalWeeksInMonth(now.year, now.month);
    // Rolls to week 1 of the next month once past the last logical week.
    final nextIsSameMonth = week < weeksInMonth;
    final nextRange = macroGoalPeriodRange(
      type: 'weekly',
      year: nextIsSameMonth
          ? now.year
          : (now.month == 12 ? now.year + 1 : now.year),
      month: nextIsSameMonth
          ? now.month
          : (now.month == 12 ? 1 : now.month + 1),
      week: nextIsSameMonth ? week + 1 : 1,
    )!;
    final expected = macroGoalRangeLabel(
      nextRange,
      monthNames: t.common.months,
      sameMonth: t.goalsPage.rangeSameMonth,
      sameYear: t.goalsPage.rangeSameYear,
      crossYear: t.goalsPage.rangeCrossYear,
    );

    await tester.tap(find.byTooltip(t.habitsPage.nextPeriod));
    await tester.pumpAndSettle();

    expect(find.text(expected), findsOneWidget);
  });
}
