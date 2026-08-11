// Regression guard for the desktop "Create goal" dialog: a second Enter in the
// category field, landing inside the in-flight save window, must NOT file a
// second goal.
//
// The Save button is disabled while `_isLoading`, but the category field's
// `onSubmitted: (_) => _save()` is not gated by that button at all — the field
// stays enabled and editable for the whole `addGoal` round-trip (a Supabase
// write in cloud mode, so seconds are possible). Before the fix `_save()` had no
// re-entrancy guard, so a second Enter re-read the still-populated title and
// called `addGoal` again — which mints a fresh id per call and does not dedupe —
// persisting a duplicate goal.
//
// Ordering note: `TextInputAction.done` unfocuses the field, so the second Enter
// only reaches `onSubmitted` once the field is focused again — the test taps it
// back, which is exactly what a user does when the dialog appears to have
// swallowed the first Enter. That is why this is a guard on `_save()` itself and
// NOT on widget enablement: the fields deliberately stay enabled.
import 'dart:async';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/dashboard/presentation/create_goal_dialog.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory repository whose `createGoal` stays pending until the test releases
/// it, holding the dialog's save window open. It counts how many times it was
/// called, which is the persistence-level proof that a duplicate was filed.
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

/// No saved categories: that is the branch where the category picker degrades to
/// a plain [TextField] whose `onSubmitted` calls `_save()`.
class _NoCategoriesController extends DesktopGoalCategoriesController {
  @override
  Future<List<DesktopGoalCategory>> build() async => const [];
}

void main() {
  testWidgets(
    'a second Enter in the category field while the save is in flight files only one goal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _BlockingDashboardRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardRepositoryProvider.overrideWithValue(repository),
            desktopGoalCategoriesControllerProvider.overrideWith(
              _NoCategoriesController.new,
            ),
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

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2)); // title + fallback category field

      await tester.enterText(fields.at(0), 'Duplicate me');
      await tester.pump();

      // Focus the category field so its `onSubmitted` receives the action.
      await tester.tap(fields.at(1));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);

      // The first save is now parked on the gate, the dialog is still up and the
      // title is still in the controller. Re-focus and submit again.
      await tester.tap(fields.at(1));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(
        repository.createGoalCalls,
        1,
        reason: 'the in-flight guard must reject the second Enter',
      );

      // Release the pending save and let the dialog pop cleanly.
      repository.gate.complete();
      await tester.pumpAndSettle();

      expect(repository.createGoalCalls, 1);
    },
  );
}
