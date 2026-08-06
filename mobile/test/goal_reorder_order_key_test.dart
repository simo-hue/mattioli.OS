// GoalsNotifier.reorder on fractional order keys (private schema v12).
//
// Two defects die here.
//
// 1. THE DOUBLE ADJUSTMENT. `onReorderItem` (Flutter 3.41+) hands back a
//    newIndex that ALREADY accounts for the removal, and `reorder` subtracted
//    one again. Every downward drag landed a slot short, and a one-slot-down
//    drag was a complete no-op — the single clearest symptom of the reported
//    bug.
//
// 2. THE WHOLE-COLLECTION WRITE. A reorder rewrote `display_order` on EVERY
//    habit. That dirtied every row for push and, worse, made the ordering a
//    property of the collection while the sync engine merges per ROW. Now a
//    drag writes ONE row: the habit that moved.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
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

Goal _goal(String id, {double? orderKey}) => Goal(
      id: id,
      title: id,
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
      orderKey: orderKey,
    );

/// Habits a..n, evenly keyed — a list that has been through the v12 backfill.
List<Goal> _keyed(int n) {
  final keys = renumberedOrderKeys(n);
  return [
    for (var i = 0; i < n; i++)
      _goal(String.fromCharCode(97 + i), orderKey: keys[i]),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container(_Store store) async {
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      privateLocalDatabaseProvider.overrideWith((ref) => store),
      initialGoalsProvider.overrideWithValue('[]'),
      initialLogsProvider.overrideWithValue('{}'),
    ]);
    addTearDown(c.dispose);
    await c.read(goalsProvider.notifier).ensureLoaded();
    return c;
  }

  List<String> ids(ProviderContainer c) =>
      [for (final g in c.read(goalsProvider)) g.id];

  group('the drop lands exactly where the user let go', () {
    test('THE REGRESSION: a one-slot-down drag actually moves the habit',
        () async {
      // The old double adjustment turned this into a no-op: newIndex 1 became 0,
      // so removeAt(0) + insert(0) put the habit straight back.
      final store = _Store(_keyed(4));
      final c = await container(store);

      await c.read(goalsProvider.notifier).reorder(0, 1);

      expect(ids(c), ['b', 'a', 'c', 'd']);
    });

    test('a multi-slot downward drag lands on the exact slot', () async {
      // The old code landed one short: 0 -> 3 became 0 -> 2.
      final store = _Store(_keyed(5));
      final c = await container(store);

      await c.read(goalsProvider.notifier).reorder(0, 3);

      expect(ids(c), ['b', 'c', 'd', 'a', 'e']);
    });

    test('an upward drag lands on the exact slot', () async {
      final store = _Store(_keyed(5));
      final c = await container(store);

      await c.read(goalsProvider.notifier).reorder(4, 1);

      expect(ids(c), ['a', 'e', 'b', 'c', 'd']);
    });

    test('dragging to the very top and the very bottom', () async {
      final store = _Store(_keyed(4));
      final c = await container(store);

      await c.read(goalsProvider.notifier).reorder(2, 0);
      expect(ids(c), ['c', 'a', 'b', 'd']);

      await c.read(goalsProvider.notifier).reorder(0, 3);
      expect(ids(c), ['a', 'b', 'd', 'c']);
    });
  });

  group('a drag writes ONE row', () {
    test('THE INVARIANT: only the moved habit is persisted', () async {
      final store = _Store(_keyed(5));
      final c = await container(store);

      await c.read(goalsProvider.notifier).reorder(0, 3);

      expect(store.reorderWrites, hasLength(1));
      expect(store.reorderWrites.single, ['a'],
          reason: 'the neighbours did not move, so they must not be dirtied '
              'for push — that storm is what made per-row LWW scramble the list');
    });

    test('the moved habit gets a fresh order-key stamp', () async {
      final store = _Store(_keyed(4));
      final c = await container(store);

      await c.read(goalsProvider.notifier).reorder(0, 2);

      final moved = c.read(goalsProvider).firstWhere((g) => g.id == 'a');
      expect(moved.orderKeyUpdatedAt, isNotNull,
          reason: 'field-level LWW needs the stamp, or a peer rename with an '
              'older key drags the habit back');
      expect(moved.orderKey, isNotNull);
    });

    test('the untouched habits keep their exact keys', () async {
      final before = _keyed(4);
      final store = _Store(before);
      final c = await container(store);

      await c.read(goalsProvider.notifier).reorder(0, 2);

      for (final id in ['b', 'c', 'd']) {
        final now = c.read(goalsProvider).firstWhere((g) => g.id == id);
        final was = before.firstWhere((g) => g.id == id);
        expect(now.orderKey, was.orderKey, reason: '$id did not move');
      }
    });

    test('a no-op reorder writes nothing at all', () async {
      final store = _Store(_keyed(3));
      final c = await container(store);

      await c.read(goalsProvider.notifier).reorder(1, 1);

      expect(store.reorderWrites, isEmpty);
    });

    test('an out-of-range index is refused rather than throwing', () async {
      final store = _Store(_keyed(3));
      final c = await container(store);

      await c.read(goalsProvider.notifier).reorder(0, 9);

      expect(store.reorderWrites, isEmpty);
      expect(ids(c), ['a', 'b', 'c']);
    });
  });

  group('keyless rows', () {
    test('a list with no keys at all still reorders, by renumbering', () async {
      // Pre-migration rows, or a peer on an older build.
      final store = _Store([_goal('a'), _goal('b'), _goal('c')]);
      final c = await container(store);

      await c.read(goalsProvider.notifier).reorder(0, 2);

      expect(ids(c), ['b', 'c', 'a']);
      expect(store.reorderWrites.single, hasLength(3),
          reason: 'a renumber legitimately writes everything');
    });

    test('a NEW habit is appended, not floated to the top', () async {
      // addHabit used to leave order_key/display_order null, and SQLite sorts
      // NULL FIRST — which is how a freshly-added habit leapt to the top of the
      // list after a restart.
      final store = _Store(_keyed(3));
      final c = await container(store);

      await c.read(goalsProvider.notifier).addHabit(_goal('z'));

      final added = c.read(goalsProvider).firstWhere((g) => g.id == 'z');
      final others = c.read(goalsProvider).where((g) => g.id != 'z');
      expect(added.orderKey, isNotNull);
      for (final g in others) {
        expect(added.orderKey, greaterThan(g.orderKey!),
            reason: 'a new habit belongs at the END of the list');
      }
    });
  });
}
