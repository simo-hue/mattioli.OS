// The legacy-address read path, end to end through the real board.
//
// Every client shipped before the week merge files a weekly goal under
// `week_number = 5`, and any client that has not updated still does. There is
// deliberately no migration, so the ONLY thing keeping those goals visible is
// `_matchesPeriod` comparing canonical buckets rather than raw week numbers.
// If that regresses, the goal does not move — it disappears.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/goals/presentation/goals_page.dart';
import 'package:evolve_desktop/features/search/application/goal_nav_target.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _GoalsRepository extends DashboardRepository {
  _GoalsRepository(this._snapshot);
  final DashboardSnapshot _snapshot;
  @override
  DashboardSnapshot load() => _snapshot;
  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}

class _NoCategoriesController extends DesktopGoalCategoriesController {
  @override
  Future<List<DesktopGoalCategory>> build() async => const [];
}

DashboardGoal _weekly({
  required String title,
  required int year,
  required int month,
  required int week,
}) => DashboardGoal(
  id: title,
  title: title,
  category: '',
  color: EvolveColors.cyan,
  state: GoalState.active,
  type: GoalType.weekly,
  createdAt: DateTime(2020),
  dueLabel: '',
  year: year,
  quarter: ((month - 1) ~/ 3) + 1,
  month: month,
  weekNumber: week,
  progress: 0,
);

late ProviderContainer _container;

Future<void> _pump(WidgetTester tester, List<DashboardGoal> goals) async {
  _container = ProviderContainer(
    overrides: [
      dashboardRepositoryProvider.overrideWithValue(
        _GoalsRepository(DashboardSnapshot.empty.copyWith(goals: goals)),
      ),
      desktopGoalCategoriesControllerProvider.overrideWith(
        _NoCategoriesController.new,
      ),
    ],
  );
  addTearDown(_container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        theme: EvolveTheme.dark(),
        home: const Scaffold(body: GoalsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Jumps the board to [bucket] through the same one-shot channel the command
/// palette uses, so the period is exact rather than derived from the wall clock.
Future<void> _selectBucket(WidgetTester tester, WeekBucket bucket) async {
  _container.read(goalNavTargetProvider.notifier).set(
    GoalNavTarget(
      type: GoalType.weekly,
      year: bucket.year,
      month: bucket.month,
      week: bucket.week,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    LocaleSettings.setLocale(AppLocale.en);
  });

  testWidgets('a legacy week 5 goal is visible under next month week 1', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Stored the way a pre-merge client writes it: August week 5.
    await _pump(tester, [
      _weekly(title: 'LegacyGoal', year: 2026, month: 8, week: 5),
    ]);
    await _selectBucket(
      tester,
      const WeekBucket(year: 2026, month: 9, week: 1),
    );

    expect(find.text('LegacyGoal'), findsOneWidget);
    expect(find.text('29 August – 7 September 2026'), findsOneWidget);
  });

  testWidgets('a legacy December week 5 goal is visible in the NEXT year', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The case a plain `goal.year != _selectedYear` guard would silently drop.
    await _pump(tester, [
      _weekly(title: 'NewYearGoal', year: 2026, month: 12, week: 5),
    ]);
    await _selectBucket(
      tester,
      const WeekBucket(year: 2027, month: 1, week: 1),
    );

    expect(find.text('NewYearGoal'), findsOneWidget);
    expect(find.text('29 December 2026 – 7 January 2027'), findsOneWidget);
  });
}
