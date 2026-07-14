// Verifies the desktop Goals page keyboard navigation: ← / → page through the
// selected plan's timeline (previous / next week) exactly like the ‹ › buttons,
// while NEVER hijacking the caret when the quick-add field is being edited.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/goals/presentation/goals_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal in-memory repository: the page only needs an (empty) snapshot to
/// render its period selectors and quick-add composer.
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
  // Let the post-frame focus request + any entry animations settle.
  await tester.pumpAndSettle();
}

void main() {
  final weekWord = t.common.calendarView.week;
  Finder weekLabel(int week) => find.text('$weekWord $week');

  testWidgets('→ advances and ← rewinds the selected week', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final initialWeek = logicalWeekOfMonth(now);
    final weeksInMonth = logicalWeeksInMonth(now.year, now.month);
    // Rolls to week 1 of the next month once past the last logical week.
    final nextWeek = initialWeek < weeksInMonth ? initialWeek + 1 : 1;

    await _pumpGoalsPage(tester);

    // The page opens on the current week (weekly is the default plan).
    expect(weekLabel(initialWeek), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(weekLabel(nextWeek), findsWidgets);
    if (nextWeek != initialWeek) {
      expect(weekLabel(initialWeek), findsNothing);
    }

    // ← steps back to exactly where we started (symmetric across a month
    // boundary too).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(weekLabel(initialWeek), findsWidgets);
  });

  testWidgets('arrow keys move the quick-add caret instead of the period', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final initialWeek = logicalWeekOfMonth(DateTime.now());

    await _pumpGoalsPage(tester);
    expect(weekLabel(initialWeek), findsWidgets);

    // Focus and type into the quick-add composer (the only text field).
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pumpAndSettle();

    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.textEditingValue.selection.baseOffset, 3);

    // With the field focused, ← must move the caret, NOT page the period.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(
      editable.textEditingValue.selection.baseOffset,
      2,
      reason: 'the caret should step left inside the quick-add field',
    );
    expect(
      weekLabel(initialWeek),
      findsWidgets,
      reason: 'editing text must not change the selected period',
    );
  });

  testWidgets('arrow keys do not page the period while a picker is open', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final initialWeek = logicalWeekOfMonth(now);
    final yearText = '${now.year}';

    await _pumpGoalsPage(tester);
    expect(weekLabel(initialWeek), findsWidgets);
    // In the weekly view the year appears only in the year picker's trigger.
    expect(find.text(yearText), findsOneWidget);

    // Open the year picker; the current year now shows in the trigger AND as a
    // menu row, so >=2 occurrences confirm the popup is up.
    await tester.tap(find.text(yearText));
    await tester.pumpAndSettle();
    expect(find.text(yearText), findsAtLeastNWidgets(2));

    // With the picker open, arrows must NOT page the timeline behind it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      weekLabel(initialWeek),
      findsWidgets,
      reason: 'the period must not change while a picker is open',
    );
  });
}
