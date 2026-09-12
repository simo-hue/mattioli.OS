// F34 — the ⌘K / dashboard "Create goal" dialog stored the category NAME in
// `category_key` and never a `category_id`.
//
// `_resolveCategory()` returned a LABEL, and `addGoal` was called without
// `categoryId` at all, so the read path had nothing to match on:
// `_categoryForGoal` matches `goal.categoryId == category.id` first and
// `category.key == goal.category` second — a saved category's `key` is null, so
// neither hit. The goal rendered with `dashboardGoalColor(label)` (blue by
// default) under a category that is orange everywhere else, the archive warning
// counted 0 linked goals, and renames never reached it.
//
// The sibling create paths (`_submitQuickGoal` and the goal editor in
// goals_page) both pass `category: category?.key ?? ''` AND
// `categoryId: category?.id`. This dialog is the odd one out.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/dashboard/presentation/create_goal_dialog.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingDashboardRepository extends DashboardRepository {
  DashboardGoal? created;

  @override
  DashboardSnapshot load() => DashboardSnapshot.empty;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}

  @override
  Future<DashboardGoal> createGoal(DashboardGoal goal) async {
    created = goal;
    return goal;
  }
}

/// One saved category, so the picker shows it and it is the default selection.
class _OneCategoryController extends DesktopGoalCategoriesController {
  @override
  Future<List<DesktopGoalCategory>> build() async => const [
        DesktopGoalCategory(
          id: 'cat-sport',
          label: 'Sport',
          color: EvolveColors.amber,
        ),
      ];
}

/// No saved categories — the branch where the picker degrades to a plain text
/// field and a brand-new category has to be minted before the goal is filed.
class _MintingCategoriesController extends DesktopGoalCategoriesController {
  static String? requestedLabel;

  @override
  Future<List<DesktopGoalCategory>> build() async => const [];

  @override
  Future<DesktopGoalCategory?> addCategory(String label, Color color) async {
    requestedLabel = label;
    return DesktopGoalCategory(id: 'cat-new', label: label, color: color);
  }
}

Future<void> _openDialog(
  WidgetTester tester, {
  required DashboardRepository repository,
  required DesktopGoalCategoriesController Function() categories,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(repository),
        desktopGoalCategoriesControllerProvider.overrideWith(categories),
      ],
      child: MaterialApp(
        theme: EvolveTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const CreateGoalDialog(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  // Desktop tests assert the Italian copy; pin the slang locale.
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  testWidgets('an existing category is filed by id, not by name',
      (tester) async {
    final repository = _RecordingDashboardRepository();
    await _openDialog(
      tester,
      repository: repository,
      categories: _OneCategoryController.new,
    );

    await tester.enterText(find.byType(TextField).first, 'Correre 10 km');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, t.form.add));
    await tester.pumpAndSettle();

    expect(repository.created, isNotNull);
    expect(repository.created!.categoryId, 'cat-sport');
    expect(
      repository.created!.category,
      isEmpty,
      reason: 'category_key is for the built-in preset keys, not a label',
    );
    expect(repository.created!.color, EvolveColors.amber);
  });

  testWidgets('a typed new category is created and its id is stored',
      (tester) async {
    _MintingCategoriesController.requestedLabel = null;
    final repository = _RecordingDashboardRepository();
    await _openDialog(
      tester,
      repository: repository,
      categories: _MintingCategoriesController.new,
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2)); // title + fallback category field
    await tester.enterText(fields.at(0), 'Correre 10 km');
    await tester.enterText(fields.at(1), 'Sport');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, t.form.add));
    await tester.pumpAndSettle();

    expect(_MintingCategoriesController.requestedLabel, 'Sport');
    expect(repository.created, isNotNull);
    expect(repository.created!.categoryId, 'cat-new');
    expect(repository.created!.category, isEmpty);
  });
}
