import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/macro_goal_categories_provider.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/macro_goals_screen.dart';
import 'package:mattioli_os/ui/widgets/macro_goals/goal_item_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Goals extends MacroGoalsNotifier {
  _Goals(this.goals);
  final List<MacroGoal> goals;
  @override
  MacroGoalsState build() => MacroGoalsState(goals: goals);
}

class _Categories extends MacroGoalCategoriesNotifier {
  @override
  Future<List<GoalCategory>> build() async => const [
    GoalCategory(key: 'yellow-id', label: 'Finance', color: Colors.amber),
    GoalCategory(key: 'red-id', label: 'Work', color: Colors.red),
  ];

  void renameYellow() => state = const AsyncData([
    GoalCategory(key: 'yellow-id', label: 'Zebra', color: Colors.amber),
    GoalCategory(key: 'red-id', label: 'Work', color: Colors.red),
  ]);
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isLoggedIn: false);
}

MacroGoal _goal(
  String id,
  int day, {
  String? categoryId,
  String? categoryKey,
  GoalStatus status = GoalStatus.active,
}) => MacroGoal(
  id: id,
  title: id,
  type: GoalType.weekly,
  status: status,
  year: 2026,
  month: 10,
  weekNumber: 1,
  categoryId: categoryId,
  categoryKey: categoryKey,
  createdAt: DateTime(2026, 10, day),
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<MacroGoal> goals,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({
    'has_seen_tutorial_supabase': true,
    'has_seen_goals_tutorial_supabase': true,
    'has_seen_stats_tutorial_supabase': true,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_Auth.new),
      macroGoalsProvider.overrideWith(() => _Goals(goals)),
      macroGoalCategoriesProvider.overrideWith(_Categories.new),
    ],
  );
  addTearDown(container.dispose);
  final view = container.read(macroGoalsViewProvider.notifier);
  view.setYear(2026);
  view.setMonth(10);
  view.setWeek(1);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: MacroGoalsScreen(isActive: true)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

List<String> _visibleOrder(WidgetTester tester) => tester
    .widgetList<GoalItemWidget>(find.byType(GoalItemWidget))
    .map((widget) => widget.goal.id)
    .toList();

void main() {
  testWidgets('ID categories cluster with gaps and uncategorized goals last', (
    tester,
  ) async {
    await _pump(tester, [
      _goal('Yellow first', 1, categoryId: 'yellow-id'),
      _goal('Red', 2, categoryId: 'red-id'),
      _goal('Uncategorized', 3),
      _goal('Yellow second', 4, categoryId: 'yellow-id'),
    ]);

    expect(_visibleOrder(tester), [
      'Yellow first',
      'Yellow second',
      'Red',
      'Uncategorized',
    ]);
    double top(String title) => tester.getTopLeft(find.text(title)).dy;
    final withinGroup = top('Yellow second') - top('Yellow first');
    expect(top('Red') - top('Yellow second'), closeTo(withinGroup + 16, 0.1));
    expect(top('Uncategorized') - top('Red'), closeTo(withinGroup + 16, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renaming a category reorders the visible groups', (
    tester,
  ) async {
    final container = await _pump(tester, [
      _goal('Yellow', 1, categoryId: 'yellow-id'),
      _goal('Red', 2, categoryId: 'red-id'),
    ]);
    expect(_visibleOrder(tester), ['Yellow', 'Red']);
    (container.read(macroGoalCategoriesProvider.notifier) as _Categories)
        .renameYellow();
    await tester.pumpAndSettle();
    expect(_visibleOrder(tester), ['Red', 'Yellow']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy keys still group, while completed and failed stay after active',
    (tester) async {
      await _pump(tester, [
        _goal(
          'Completed',
          1,
          categoryId: 'yellow-id',
          status: GoalStatus.completed,
        ),
        _goal('Work first', 2, categoryKey: 'lavoro'),
        _goal('No category', 3),
        _goal('Work second', 4, categoryKey: 'lavoro'),
        _goal('Failed', 5, categoryId: 'red-id', status: GoalStatus.failed),
      ]);
      expect(_visibleOrder(tester), [
        'Work first',
        'Work second',
        'No category',
        'Completed',
        'Failed',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
