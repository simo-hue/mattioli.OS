// The Manage-habits sheet lists EVERY habit, unfiltered.
//
// It used to filter by `isActiveOn(now)` and then hand those FILTERED indices to
// `GoalsNotifier.reorder`, which indexes the UNFILTERED list. So the moment any
// habit was inactive — a future start date, or a past end date — a drag moved a
// DIFFERENT habit than the one under the finger. Habit order is now persisted
// per-row and survives sync, which made that mistake durable rather than
// transient.
//
// Removing the filter, rather than remapping the indices, is the deliberate
// choice: this is the surface that renames, recolours, reschedules and DELETES a
// habit, so hiding one here makes it unreachable. "What is due today?" belongs
// to the day card; this screen answers "what do I have?".
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
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
  final List<List<String>> reorderWrites = [];

  @override
  Future<List<Goal>> loadGoals() async => goals;

  @override
  Future<void> reorderGoals(List<Goal> ordered) async {
    reorderWrites.add([for (final g in ordered) g.id]);
  }
}

/// [ended] gives the habit a past end date, so `isActiveOn(now)` is false — the
/// only way a habit is currently inactive.
Goal _goal(String id, double key, {bool ended = false}) => Goal(
      id: id,
      title: 'Habit $id',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
      endDate: ended ? DateTime(2026, 1, 2) : null,
      orderKey: key,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpSheet(WidgetTester tester, _Store store) async {
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
    await tester.dragUntilVisible(
      find.text('Habit a'),
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('an ENDED habit is still listed, so it can be managed',
      (tester) async {
    // You cannot rename, reschedule or DELETE a habit you cannot see.
    final keys = renumberedOrderKeys(3);
    final store = _Store([
      _goal('a', keys[0]),
      _goal('b', keys[1], ended: true),
      _goal('c', keys[2]),
    ]);
    await pumpSheet(tester, store);

    expect(find.text('Habit b'), findsOneWidget,
        reason: 'an ended habit must remain reachable on the MANAGE surface');
  });

  testWidgets(
      'THE REGRESSION: a drag moves the habit under the finger, even with an '
      'inactive habit above it', (tester) async {
    // With the old filter, 'b' was hidden, so dragging the SECOND VISIBLE row
    // ('c') passed index 1 — which addressed 'b' in the unfiltered state. The
    // wrong habit moved, and step 5 made that permanent.
    final keys = renumberedOrderKeys(4);
    final store = _Store([
      _goal('a', keys[0]),
      _goal('b', keys[1], ended: true),
      _goal('c', keys[2]),
      _goal('d', keys[3]),
    ]);
    final container = await pumpSheet(tester, store);

    final row = find.ancestor(
      of: find.text('Habit c'),
      matching: find.byType(Row),
    );
    final handle =
        find.descendant(of: row.first, matching: find.byType(Icon)).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(kLongPressTimeout);
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.reorderWrites, isNotEmpty, reason: 'the drag committed');
    expect(store.reorderWrites.last, ['c'],
        reason: 'the habit that MOVED is the one the finger was on — not the '
            'hidden habit that used to share its index');
    expect(
      container.read(goalsProvider).map((g) => g.id).toList(),
      ['c', 'a', 'b', 'd'],
    );
  });
}
