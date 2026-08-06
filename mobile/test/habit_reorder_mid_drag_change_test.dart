// A drop must never commit indices that no longer mean what the user saw.
//
// `SliverReorderableList.didUpdateWidget` cancels a drag ONLY when `itemCount`
// changes (flutter reorderable_list.dart:796-800). It does not notice the list
// CONTENTS being swapped underneath it.
//
// That used to be harmless in the Manage-habits sheet purely by accident: an
// applied iCloud sync invalidated goalsProvider, Private-mode `build()` returned
// `[]` synchronously, the count changed, and the drag was cancelled. Once the
// list started refreshing IN PLACE (GoalsNotifier.refresh, the step-3 root fix),
// a reorder pulled from another device arrives with the SAME count and a
// DIFFERENT order — so the gesture survives and `oldIndex` addresses a habit
// that is no longer the one under the finger. Committing that renumbers every
// `display_order`, persists it, syncs it to CloudKit, and fires a haptic
// confirming a reorder nobody made.
//
// The sheet therefore snapshots the visible id order at drag start and refuses
// a drop when the live order no longer matches.
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/widgets/habit_management_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

Goal _goal(String id) => Goal(
      id: id,
      title: 'Habit $id',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
    );

/// Records every reorder the sheet asks for, so a test can assert that a drop
/// was committed — or, crucially, that it was NOT.
class _RecordingStore extends FakePrivateDataStore {
  _RecordingStore(this.goals);

  List<Goal> goals;
  final List<List<String>> reorders = [];

  @override
  Future<List<Goal>> loadGoals() async => goals;

  @override
  Future<void> reorderGoals(List<Goal> ordered) async {
    reorders.add([for (final g in ordered) g.id]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpSheet(
    WidgetTester tester,
    _RecordingStore store,
  ) async {
    // The sheet stacks a very tall add/edit form ABOVE the habit list, and a
    // SliverReorderableList does not build items outside the viewport — so on a
    // default 800x600 surface the rows this test drags simply do not exist.
    await tester.binding.setSurfaceSize(const Size(900, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      privateLocalDatabaseProvider.overrideWith((ref) => store),
      initialGoalsProvider.overrideWithValue('[]'),
      initialLogsProvider.overrideWithValue('{}'),
    ]);
    addTearDown(container.dispose);

    await container.read(goalsProvider.notifier).ensureLoaded();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          locale: const Locale('en'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          home: const Scaffold(body: HabitManagementModal()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // The habit rows sit BELOW the add/edit form inside one shared
    // CustomScrollView, and a sliver does not build items outside the viewport.
    await tester.dragUntilVisible(
      find.text('Habit ${store.goals.first.id}'),
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Presses the drag handle of the row showing [title] and holds, without
  /// releasing, so the caller can change the world mid-gesture.
  Future<TestGesture> startDrag(WidgetTester tester, String title) async {
    final row = find.ancestor(
      of: find.text(title),
      matching: find.byType(Row),
    );
    final handle = find
        .descendant(of: row.first, matching: find.byType(Icon))
        .first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(kLongPressTimeout);
    // Nudge so the drag recognizer actually starts tracking before the caller
    // moves in earnest.
    await gesture.moveBy(const Offset(0, 12));
    await tester.pump(const Duration(milliseconds: 16));
    return gesture;
  }

  testWidgets('THE REGRESSION: a drop is refused when the list changed mid-drag',
      (tester) async {
    final store = _RecordingStore([_goal('a'), _goal('b'), _goal('c')]);
    final container = await pumpSheet(tester, store);
    expect(find.text('Habit a'), findsOneWidget);

    final gesture = await startDrag(tester, 'Habit a');
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, 20));
      // REAL TIME, not a zero-duration pump. SliverReorderableList's drop runs
      // through a 250ms proxy animation: `_DragInfo.end()` calls
      // `_proxyAnimation.reverse()` and then `onEnd` (-> onReorderEnd)
      // synchronously, while onReorderItem fires only when that reverse reaches
      // `dismissed`. Pumping zero duration leaves the animation at 0.0, so
      // reverse() completes SYNCHRONOUSLY and the two callbacks arrive in the
      // opposite order from a real finger — which is how a total loss of
      // reordering passed this suite.
      await tester.pump(const Duration(milliseconds: 16));
    }

    // A reorder arrives from the other device while the finger is still down:
    // SAME count, DIFFERENT order. Under refresh() the count never changes, so
    // Flutter does NOT cancel the drag.
    store.goals = [_goal('c'), _goal('b'), _goal('a')];
    await container.read(goalsProvider.notifier).refresh();
    await tester.pump();

    await gesture.up();
    await tester.pumpAndSettle();
    // The refusal logs a warning, and AppLogger debounces its save by 2s.
    // pumpAndSettle stops as soon as no frame is scheduled, so it never reaches
    // that Timer — drain it explicitly or the binding asserts at teardown. Its
    // presence is itself evidence the guard fired.
    await tester.pump(const Duration(seconds: 3));

    expect(store.reorders, isEmpty,
        reason: 'the drop addressed the order the user SAW, which no longer '
            'exists — committing it would move a habit nobody dragged');
    expect(container.read(goalsProvider).map((g) => g.id), ['c', 'b', 'a'],
        reason: 'the remote order the user can now see is left intact');
  });

  testWidgets('an ordinary drag with no interference still commits',
      (tester) async {
    // The guard must not swallow the normal case — otherwise reordering is
    // simply broken, which is the complaint that started all of this.
    final store = _RecordingStore([_goal('a'), _goal('b'), _goal('c')]);
    await pumpSheet(tester, store);

    final gesture = await startDrag(tester, 'Habit a');
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 20));
      // REAL TIME, not a zero-duration pump. SliverReorderableList's drop runs
      // through a 250ms proxy animation: `_DragInfo.end()` calls
      // `_proxyAnimation.reverse()` and then `onEnd` (-> onReorderEnd)
      // synchronously, while onReorderItem fires only when that reverse reaches
      // `dismissed`. Pumping zero duration leaves the animation at 0.0, so
      // reverse() completes SYNCHRONOUSLY and the two callbacks arrive in the
      // opposite order from a real finger — which is how a total loss of
      // reordering passed this suite.
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.reorders, isNotEmpty,
        reason: 'an uninterrupted drag must still reorder');
  });

  testWidgets('a refresh that leaves the order UNCHANGED does not block a drop',
      (tester) async {
    // A sync applies constantly. Most of them do not touch the habit order, and
    // those must not cost the user their drag.
    final store = _RecordingStore([_goal('a'), _goal('b'), _goal('c')]);
    final container = await pumpSheet(tester, store);

    final gesture = await startDrag(tester, 'Habit a');
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 20));
      // REAL TIME, not a zero-duration pump. SliverReorderableList's drop runs
      // through a 250ms proxy animation: `_DragInfo.end()` calls
      // `_proxyAnimation.reverse()` and then `onEnd` (-> onReorderEnd)
      // synchronously, while onReorderItem fires only when that reverse reaches
      // `dismissed`. Pumping zero duration leaves the animation at 0.0, so
      // reverse() completes SYNCHRONOUSLY and the two callbacks arrive in the
      // opposite order from a real finger — which is how a total loss of
      // reordering passed this suite.
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Same ids, same order — a refresh carrying an unrelated change.
    store.goals = [_goal('a'), _goal('b'), _goal('c')];
    await container.read(goalsProvider.notifier).refresh();
    await tester.pump();

    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.reorders, isNotEmpty,
        reason: 'only a CHANGED order invalidates the drop');
  });
}
