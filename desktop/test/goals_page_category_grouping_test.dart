import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/goals/presentation/goals_page.dart';
import 'package:evolve_desktop/features/search/application/goal_nav_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends DashboardRepository {
  _Repository(this.goals);
  final List<DashboardGoal> goals;
  @override
  DashboardSnapshot load() => DashboardSnapshot.empty.copyWith(goals: goals);
  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}

class _Categories extends DesktopGoalCategoriesController {
  _Categories(this.categories);
  final List<DesktopGoalCategory> categories;

  @override
  Future<List<DesktopGoalCategory>> build() async => categories;

  void replace(List<DesktopGoalCategory> value) => state = AsyncData(value);
}

const _categories = [
  DesktopGoalCategory(id: 'yellow-id', label: 'Finance', color: Colors.amber),
  DesktopGoalCategory(id: 'red-id', label: 'Work', color: Colors.red),
];

DashboardGoal _goal(
  String title,
  int day, {
  String? categoryId,
  String category = '',
  GoalState state = GoalState.active,
}) => DashboardGoal(
  id: title,
  title: title,
  category: category,
  categoryId: categoryId,
  color: Colors.amber,
  state: state,
  type: GoalType.weekly,
  createdAt: DateTime(2026, 10, day),
  dueLabel: '',
  year: 2026,
  quarter: 4,
  month: 10,
  weekNumber: 1,
  progress: 0,
);

Future<_Categories> _pump(
  WidgetTester tester,
  List<DashboardGoal> goals, {
  List<DesktopGoalCategory> categories = _categories,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = _Categories(categories);
  final container = ProviderContainer(
    overrides: [
      dashboardRepositoryProvider.overrideWithValue(_Repository(goals)),
      desktopGoalCategoriesControllerProvider.overrideWith(() => controller),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(goalNavTargetProvider.notifier)
      .set(
        GoalNavTarget(type: GoalType.weekly, year: 2026, month: 10, week: 1),
      );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: EvolveTheme.dark(),
        home: const Scaffold(body: GoalsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

double _top(WidgetTester tester, String title) =>
    tester.getTopLeft(find.text(title)).dy;

void _expectOrder(WidgetTester tester, List<String> titles) {
  for (var i = 1; i < titles.length; i++) {
    expect(
      _top(tester, titles[i - 1]),
      lessThan(_top(tester, titles[i])),
      reason: '${titles[i - 1]} should appear before ${titles[i]}',
    );
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'ID categories cluster with spacing and uncategorized goals last',
    (tester) async {
      await _pump(tester, [
        _goal('Yellow first', 1, categoryId: 'yellow-id'),
        _goal('Red', 2, categoryId: 'red-id'),
        _goal('Uncategorized', 3),
        // A selected ID takes priority over an older category key.
        _goal('Yellow second', 4, categoryId: 'yellow-id', category: 'lavoro'),
      ]);
      _expectOrder(tester, [
        'Yellow first',
        'Yellow second',
        'Red',
        'Uncategorized',
      ]);
      final withinGroup =
          _top(tester, 'Yellow second') - _top(tester, 'Yellow first');
      expect(
        _top(tester, 'Red') - _top(tester, 'Yellow second'),
        closeTo(withinGroup + 16, 0.1),
      );
      expect(
        _top(tester, 'Uncategorized') - _top(tester, 'Red'),
        closeTo(withinGroup + 16, 0.1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('equal category names keep distinct ID groups together', (
    tester,
  ) async {
    await _pump(
      tester,
      [
        _goal('A first', 1, categoryId: 'a'),
        _goal('B', 2, categoryId: 'b'),
        _goal('A second', 3, categoryId: 'a'),
      ],
      categories: const [
        DesktopGoalCategory(id: 'a', label: 'Work', color: Colors.amber),
        DesktopGoalCategory(id: 'b', label: 'work', color: Colors.red),
      ],
    );
    _expectOrder(tester, ['A first', 'A second', 'B']);
    final withinGroup = _top(tester, 'A second') - _top(tester, 'A first');
    expect(
      _top(tester, 'B') - _top(tester, 'A second'),
      closeTo(withinGroup + 16, 0.1),
    );
  });

  testWidgets(
    'groups survive missing category metadata and reorder when it arrives',
    (tester) async {
      final controller = await _pump(tester, [
        _goal('A first', 1, categoryId: 'a'),
        _goal('B', 2, categoryId: 'b'),
        _goal('A second', 3, categoryId: 'a'),
      ], categories: const []);
      _expectOrder(tester, ['A first', 'A second', 'B']);
      controller.replace(const [
        DesktopGoalCategory(id: 'a', label: 'Work', color: Colors.amber),
        DesktopGoalCategory(id: 'b', label: 'Finance', color: Colors.red),
      ]);
      await tester.pumpAndSettle();
      _expectOrder(tester, ['B', 'A first', 'A second']);
    },
  );

  testWidgets('renaming a category reorders visible groups', (tester) async {
    final controller = await _pump(tester, [
      _goal('Yellow', 1, categoryId: 'yellow-id'),
      _goal('Red', 2, categoryId: 'red-id'),
    ]);
    _expectOrder(tester, ['Yellow', 'Red']);
    controller.replace(const [
      DesktopGoalCategory(id: 'yellow-id', label: 'Zebra', color: Colors.amber),
      DesktopGoalCategory(id: 'red-id', label: 'Work', color: Colors.red),
    ]);
    await tester.pumpAndSettle();
    _expectOrder(tester, ['Red', 'Yellow']);
  });

  testWidgets(
    'goals retain archived category names for alphabetical grouping',
    (tester) async {
      await _pump(
        tester,
        [
          _goal('Archived category', 1, categoryId: 'a'),
          _goal('Active category', 2, categoryId: 'b'),
        ],
        categories: [
          DesktopGoalCategory(
            id: 'a',
            label: 'Zebra',
            color: Colors.amber,
            archivedAt: DateTime(2026),
          ),
          const DesktopGoalCategory(
            id: 'b',
            label: 'Finance',
            color: Colors.red,
          ),
        ],
      );
      _expectOrder(tester, ['Active category', 'Archived category']);
    },
  );

  testWidgets(
    'legacy categories group and completed/failed sections follow active',
    (tester) async {
      await _pump(tester, [
        _goal('Completed', 1, state: GoalState.completed),
        _goal('Work first', 2, category: 'lavoro'),
        _goal('Uncategorized', 3),
        _goal('Work second', 4, category: 'lavoro'),
        _goal('Failed', 5, state: GoalState.failed),
      ]);
      _expectOrder(tester, [
        'Work first',
        'Work second',
        'Uncategorized',
        'Completed',
        'Failed',
      ]);
    },
  );
}
