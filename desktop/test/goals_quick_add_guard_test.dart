// Regression guard for the desktop Goals quick-add '+' button: a double-click
// (or two rapid Enters) inside the in-flight save window must NOT file two
// identical goals.
//
// `_submitQuickGoal` clears the field only AFTER `addGoal` resolves (a Supabase
// round-trip in cloud mode), so while that write is pending the controller
// still holds the typed title. Before the fix there was no re-entrancy guard on
// that handler and the accent '+' `InkWell(onTap: onSubmit)` was never disabled,
// so a second click re-read the same title and `addGoal` — which mints a fresh
// id per call with no dedupe — persisted a duplicate goal.
//
// The two taps here land WITHOUT an intervening pump, so the InkWell has not yet
// rebuilt into its disabled state when the second tap fires — exactly the real
// double-click ordering. That makes this a test of the SYNCHRONOUS `_quickAdding`
// guard specifically (the button-disable alone would not catch this ordering).
import 'dart:async';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/goals/presentation/goals_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// In-memory repository whose `createGoal` stays pending until the test releases
/// it, holding the quick-add save window open. It counts how many times it was
/// called so the test can assert the duplicate write never happened.
class _BlockingDashboardRepository extends DashboardRepository {
  final Completer<void> gate = Completer<void>();
  int createGoalCalls = 0;

  @override
  DashboardSnapshot load() => DashboardSnapshot.empty;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}

  @override
  Future<DashboardGoal> createGoal(DashboardGoal goal) async {
    createGoalCalls++;
    await gate.future;
    return goal;
  }
}

/// Skips the cloud/private category fetch so the page renders hermetically.
class _NoCategoriesController extends DesktopGoalCategoriesController {
  @override
  Future<List<DesktopGoalCategory>> build() async => const [];
}

void main() {
  testWidgets(
    'double-clicking quick-add while the save is in flight files only one goal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _BlockingDashboardRepository();
      late final ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardRepositoryProvider.overrideWithValue(repository),
            desktopGoalCategoriesControllerProvider.overrideWith(
              _NoCategoriesController.new,
            ),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: EvolveTheme.dark(),
                home: const Scaffold(body: GoalsPage()),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Duplicate me');
      await tester.pump();

      // The accent '+' submit button: the InkWell wrapping the plus glyph.
      final plusButton = find.ancestor(
        of: find.byIcon(LucideIcons.plus),
        matching: find.byType(InkWell),
      );
      expect(plusButton, findsOneWidget);

      // Two taps with NO pump between them: the second lands before the widget
      // rebuilds into its disabled state — the real double-click ordering that
      // only the synchronous re-entrancy guard can catch.
      await tester.tap(plusButton, warnIfMissed: false);
      await tester.tap(plusButton, warnIfMissed: false);

      // The first save is still pending on the gate; the second tap must have
      // been rejected by the guard.
      expect(
        repository.createGoalCalls,
        1,
        reason: 'the in-flight guard must reject the second click',
      );
      expect(
        container.read(dashboardControllerProvider).goals.length,
        1,
        reason: 'only one optimistic goal should have been inserted',
      );

      // Release the pending save and let everything settle cleanly.
      repository.gate.complete();
      await tester.pumpAndSettle();

      expect(container.read(dashboardControllerProvider).goals.length, 1);
    },
  );
}
