// Goals > Performance rendered three hardcoded Italian strings to every
// locale: the "most effective type" card ('Annuale' / 'Trimestrale' / …), the
// All-Years "best year" subtitle ('72% completamento') and the category
// donut's centre label ('obiettivi').
//
// All three now use keys that already exist in all five locales
// (macroGoals.types.*, statistics.ofCompletion, macroGoals.totalGoals) — the
// adjacent cards in the same widget were already reading them.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/goals/presentation/goals_stats_view.dart';
import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Skips the cloud/private category fetch so the view renders hermetically.
class _NoCategoriesController extends DesktopGoalCategoriesController {
  @override
  Future<List<DesktopGoalCategory>> build() async => const [];
}

Map<String, dynamic> _singleYearStats() => {
  'total_goals': 10,
  'completed_goals': 7,
  'success_rate': 70,
  'best_type': 'quarterly',
  'best_type_rate': 80,
  'best_category': null,
  'best_category_rate': 60,
  'best_month': 3,
  'best_month_rate': 90,
  'weekly': 1,
  'monthly': 2,
  'quarterly': 3,
  'annual': 4,
  'lifetime': 0,
  'category_distribution': [
    {'category': 'health', 'count': 6},
    {'category': 'work', 'count': 4},
  ],
};

Map<String, dynamic> _allYearsStats() => {
  'total_goals': 20,
  'completed_goals': 14,
  'success_rate': 70,
  'best_year': 2025,
  'best_year_rate': 72,
  'most_productive_year': 2024,
  'most_productive_count': 12,
  'weekly': 1,
  'monthly': 2,
  'quarterly': 3,
  'annual': 4,
  'lifetime': 0,
};

Future<void> _pump(WidgetTester tester, String year) async {
  tester.view.physicalSize = const Size(1600, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        desktopGoalCategoriesControllerProvider.overrideWith(
          _NoCategoriesController.new,
        ),
        macroGoalsStatsRpcProvider(year).overrideWith(
          (ref) async =>
              year == 'all' ? _allYearsStats() : _singleYearStats(),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: EvolveTheme.dark(),
          home: Scaffold(body: GoalsStatsView(selectedYear: year)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => LocaleSettings.setLocale(AppLocale.it));

  testWidgets('the English build names the goal type in English', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    await _pump(tester, '2026');

    expect(find.text('Trimestrale'), findsNothing);
    expect(find.text('Settimanale'), findsNothing);
    expect(find.text('Mensile'), findsNothing);
    expect(find.text('Annuale'), findsNothing);
    expect(find.text(t.macroGoals.types.quarterly), findsWidgets);
  });

  testWidgets('the English build localizes the donut centre label', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    await _pump(tester, '2026');

    expect(find.text('obiettivi'), findsNothing);
    expect(find.text(t.macroGoals.totalGoals), findsWidgets);
  });

  testWidgets('the English build localizes the best-year subtitle', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.en);
    await _pump(tester, 'all');

    expect(find.textContaining('completamento'), findsNothing);
    expect(find.text('72% ${t.statistics.ofCompletion}'), findsOneWidget);
  });

  testWidgets('the Italian type labels are unchanged', (tester) async {
    LocaleSettings.setLocale(AppLocale.it);
    await _pump(tester, '2026');
    expect(find.text('Trimestrale'), findsOneWidget);
    expect(find.text('obiettivi totali'), findsWidgets);
  });

  // The All-Years view carries the per-type distribution rows.
  testWidgets('the Italian All-Years copy is unchanged', (tester) async {
    LocaleSettings.setLocale(AppLocale.it);
    await _pump(tester, 'all');

    for (final label in const [
      'Settimanale',
      'Mensile',
      'Trimestrale',
      'Annuale',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'it must still say $label');
    }
    expect(find.text('72% di completamento'), findsOneWidget);
  });
}
