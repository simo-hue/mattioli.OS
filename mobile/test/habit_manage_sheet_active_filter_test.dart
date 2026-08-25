// The Manage-habits sheet shows the habits whose active range covers today, and
// counts exactly those against the free tier.
//
// Two properties are pinned here because they pull against each other. The sheet
// once filtered by `isActiveOn(now)` and then handed those FILTERED indices to
// `GoalsNotifier.reorder`, which indexes the UNFILTERED list — so the moment any
// habit was inactive, a drag moved a DIFFERENT habit than the one under the
// finger, and habit order is persisted per-row, which made the mistake durable
// rather than transient. The filter was deleted to kill that bug; it is back
// now, with the indices remapped through `activePositions` instead. So: the
// ended habit must be HIDDEN, *and* a drag must still move the habit under the
// finger.
//
// The free-tier gate counts the same population the list shows, so archiving a
// habit FREES a slot. Both clients can end a habit — the web app's soft delete
// and, since `deleteHabit` started archiving rather than destroying history,
// this one too. That is a deliberate trade: counting the hidden rows would
// strand a free user at "5/5" above a list they had just emptied, with no iOS
// screen listing archived habits and so nothing they could tap to resolve it.
// Note the gate is live in ACCOUNT mode only: Private mode forces `isPro: true`,
// which is why these tests override the settings notifier.
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
import 'package:mattioli_os/providers/settings_provider.dart';
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

/// Private mode forces `isPro: true`, which would switch the free-tier gate
/// off entirely. The gate is an ACCOUNT-mode rule, so pin the flag down.
class _FreeTier extends AppSettingsNotifier {
  @override
  AppSettings build() => super.build().copyWith(isPro: false);

  // `build()` alone is not enough: it kicks off `_loadPrivateSettings()`, which
  // lands asynchronously and re-asserts `isPro: true` for Private mode. Pin the
  // flag on the setter so no later write can put it back.
  @override
  set state(AppSettings value) => super.state = value.copyWith(isPro: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `Override` is not part of Riverpod 3's public surface, so the free-tier
  // override is built in here rather than passed in as a typed list.
  Future<ProviderContainer> pumpSheet(
    WidgetTester tester,
    _Store store, {
    bool freeTier = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      privateLocalDatabaseProvider.overrideWith((ref) => store),
      initialGoalsProvider.overrideWithValue('[]'),
      initialLogsProvider.overrideWithValue('{}'),
      if (freeTier) settingsProvider.overrideWith(_FreeTier.new),
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

  testWidgets('an ENDED habit is hidden', (tester) async {
    final keys = renumberedOrderKeys(3);
    final store = _Store([
      _goal('a', keys[0]),
      _goal('b', keys[1], ended: true),
      _goal('c', keys[2]),
    ]);
    await pumpSheet(tester, store);

    expect(find.text('Habit b'), findsNothing,
        reason: 'an ended habit is not part of "what am I doing now"');
    expect(find.text('Habit a'), findsOneWidget);
    expect(find.text('Habit c'), findsOneWidget);
  });

  testWidgets('an ended habit does not consume a free slot', (tester) async {
    // Four active + two ended. The free tier is NOT full, so no banner. Counting
    // every row would put this at 6/5 and lock a user out of a slot they hold.
    final keys = renumberedOrderKeys(6);
    final store = _Store([
      _goal('a', keys[0]),
      _goal('b', keys[1]),
      _goal('c', keys[2]),
      _goal('d', keys[3]),
      _goal('e', keys[4], ended: true),
      _goal('f', keys[5], ended: true),
    ]);
    await pumpSheet(tester, store, freeTier: true);

    expect(find.textContaining('free habit slots'), findsNothing,
        reason: 'four active habits is under the limit of five');
  });

  testWidgets('the banner counts the habits the list shows', (tester) async {
    // Five active + two ended: the tier IS full, and the banner must say 5/5.
    // Counting every row said 7/5 — a number the user cannot reconcile with the
    // five rows in front of them.
    final keys = renumberedOrderKeys(7);
    final store = _Store([
      _goal('a', keys[0]),
      _goal('b', keys[1]),
      _goal('c', keys[2]),
      _goal('d', keys[3]),
      _goal('e', keys[4]),
      _goal('f', keys[5], ended: true),
      _goal('g', keys[6], ended: true),
    ]);
    await pumpSheet(tester, store, freeTier: true);

    expect(find.textContaining('(5/5)'), findsOneWidget,
        reason: 'the gate and the list must report the same population');
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
