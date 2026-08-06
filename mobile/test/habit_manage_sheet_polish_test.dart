// The FEEL of the Manage-habits drag, as distinct from its correctness.
//
// The reported complaint was that reordering was "not user friendly nor
// professional". Every other test in this area proves the right habit ends up in
// the right place; these pin the things that made it feel unreliable even when
// it worked:
//
//   * a ~32x24 drag target, against Apple's 44x44 minimum, and the ONLY way to
//     start a drag;
//   * the habit list buried under a ~900pt add/edit form, so the rows were
//     off-screen on open and dragging toward the top auto-scrolled the FORM back
//     into view, fighting the gesture.
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/widgets/habit_management_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

class _Store extends FakePrivateDataStore {
  _Store(this.goals);
  List<Goal> goals;
  final List<List<String>> reorders = [];

  @override
  Future<List<Goal>> loadGoals() async => goals;

  @override
  Future<void> reorderGoals(List<Goal> ordered) async {
    reorders.add([for (final g in ordered) g.id]);
  }
}

Goal _goal(String id, double key) => Goal(
      id: id,
      title: 'Habit $id',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
      orderKey: key,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSheet(WidgetTester tester, _Store store) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
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
  }

  _Store threeHabits() {
    final keys = renumberedOrderKeys(3);
    return _Store([_goal('a', keys[0]), _goal('b', keys[1]), _goal('c', keys[2])]);
  }

  testWidgets('the drag handle meets the 44x44 minimum touch target',
      (tester) async {
    await pumpSheet(tester, threeHabits());

    final handle = find.byType(ReorderableDragStartListener).first;
    final size = tester.getSize(handle);

    expect(size.width, greaterThanOrEqualTo(44),
        reason: 'Apple\'s minimum — it was ~32 wide');
    expect(size.height, greaterThanOrEqualTo(44),
        reason: 'Apple\'s minimum — it was ~24 tall');
  });

  testWidgets('the whole row is ALSO a drag affordance, via long press',
      (tester) async {
    // The grip stays an immediate drag; long-press-anywhere is the
    // Reminders/Notes convention and the gesture most people try first.
    await pumpSheet(tester, threeHabits());

    expect(
      find.byType(ReorderableDelayedDragStartListener),
      findsNWidgets(3),
      reason: 'one per habit row',
    );
  });

  testWidgets('THE LAYOUT: the habit list is visible without scrolling',
      (tester) async {
    // The rows used to sit below a ~900pt form, so the sheet opened on a screen
    // of inputs with the habits off-screen — and dragging toward the top
    // scrolled the form back over them.
    await pumpSheet(tester, threeHabits());

    expect(find.text('Habit a'), findsOneWidget);
    expect(find.text('Habit c'), findsOneWidget);

    final listTop = tester.getTopLeft(find.text('Habit a')).dy;
    final formTop = tester.getTopLeft(find.text('Habit Name')).dy;
    expect(listTop, lessThan(formTop),
        reason: 'the habits come BEFORE the add/edit form');
  });

  testWidgets('the add/edit form is still reachable below the list',
      (tester) async {
    // Moving it must not hide it — creating a habit is still a first-class
    // action on this sheet.
    await pumpSheet(tester, threeHabits());

    await tester.dragUntilVisible(
      find.text('Habit Name'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.text('Habit Name'), findsOneWidget);
  });

  // ── the gestures themselves ───────────────────────────────────────────────
  //
  // Geometry and presence assertions cannot see a gesture being swallowed. The
  // first version of these tests only measured the handle and counted
  // listeners, and passed while a hesitant press on DELETE was reordering the
  // list instead of asking to delete anything.

  testWidgets('the GRIP still drags immediately, with no long-press hold',
      (tester) async {
    final store = threeHabits();
    await pumpSheet(tester, store);

    final grip = find.byType(ReorderableDragStartListener).first;
    final gesture = await tester.startGesture(tester.getCenter(grip));
    // No kLongPressTimeout: an immediate drag must not need one.
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.reorders, isNotEmpty,
        reason: 'the grip is the no-delay affordance; wrapping the row in a '
            'DELAYED listener must not have stolen its arena');
  });

  testWidgets('THE REGRESSION: a hesitant press on DELETE deletes, never drags',
      (tester) async {
    // ReorderableDelayedDragStartListener resolves ACCEPTED at 500ms and the
    // button's tap is rejected. With the buttons inside it, holding the trash
    // icon lifted the row instead of confirming, and a press that drifted a few
    // pixels reordered and PERSISTED the habits.
    final store = threeHabits();
    await pumpSheet(tester, store);

    final trash = find.byIcon(LucideIcons.trash2).first;
    final gesture = await tester.startGesture(tester.getCenter(trash));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.reorders, isEmpty,
        reason: 'pressing delete must never reorder anything');
    expect(find.text('Delete Habit'), findsOneWidget,
        reason: 'the confirmation the press was actually asking for');
  });

  testWidgets('a hesitant press on EDIT still opens the edit form',
      (tester) async {
    final store = threeHabits();
    await pumpSheet(tester, store);

    final pencil = find.byIcon(LucideIcons.pencil).first;
    final gesture = await tester.startGesture(tester.getCenter(pencil));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.reorders, isEmpty);
    expect(find.text('Edit Habit'), findsOneWidget);
  });

  testWidgets('long-pressing the habit ITSELF drags it', (tester) async {
    final store = threeHabits();
    await pumpSheet(tester, store);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Habit a')));
    await tester.pump(kLongPressTimeout);
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.reorders, isNotEmpty,
        reason: 'long-press-anywhere is the whole point of the delayed listener');
  });

  testWidgets('an empty habit list still renders the form', (tester) async {
    await pumpSheet(tester, _Store([]));

    await tester.dragUntilVisible(
      find.text('Habit Name'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.text('Habit Name'), findsOneWidget);
  });
}
