// The root fix: refreshing the habit list must never make it go empty first.
//
// `invalidatePrivateDataProviders` runs on EVERY iCloud sync that applied a
// pulled change — which the 60s poll can reach once a minute. It used to
// `ref.invalidate(goalsProvider)`, and Private-mode `build()` returns `[]`
// synchronously and fills in asynchronously, so every listener observed the
// habit list go empty and back.
//
// That empty frame is the root of three separate defects:
//   * a drag in the Manage-habits sheet is CANCELLED — SliverReorderableList
//     calls `cancelReorder()` when its itemCount changes, so N -> 0 -> N
//     mid-gesture drops the drop with no callback, no haptic and no error, and
//     the row springs back to where it started;
//   * the streak write paths cannot resolve their goal and so cannot compute a
//     run length;
//   * every barrier guarding a destructive action has to stand its pass down.
//
// `GoalsNotifier.refresh()` reloads in place instead: state is reassigned once,
// when the real data has arrived.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/providers/sync_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

Goal _goal(String id) => Goal(
      id: id,
      title: id,
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
    );

/// A store whose contents a test can change between loads, with a delay so the
/// load is genuinely asynchronous (a real encrypted-DB open is).
class _MutableStore extends FakePrivateDataStore {
  _MutableStore(this.goals);

  List<Goal> goals;
  int loadCount = 0;

  @override
  Future<List<Goal>> loadGoals() async {
    loadCount++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return goals;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container(FakePrivateDataStore store) async {
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith((ref) => store),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('THE ROOT FIX: a refresh never emits an empty list', () async {
    final store = _MutableStore([_goal('a'), _goal('b'), _goal('c')]);
    final c = await container(store);
    await c.read(goalsProvider.notifier).ensureLoaded();
    expect(c.read(goalsProvider), hasLength(3));

    // Everything a listener observes from here on. The Manage-habits sheet
    // derives its SliverReorderableList itemCount from exactly this.
    final observed = <int>[];
    c.listen(goalsProvider, (_, next) => observed.add(next.length),
        fireImmediately: false);

    store.goals = [_goal('a'), _goal('b'), _goal('c'), _goal('d')];
    await c.read(goalsProvider.notifier).refresh();

    expect(observed, isNot(contains(0)),
        reason: 'an empty frame here cancels an in-flight drag outright');
    expect(observed.last, 4, reason: 'the new data still arrives');
    expect(c.read(goalsProvider).map((g) => g.id), ['a', 'b', 'c', 'd']);
  });

  test('CONTRAST: invalidate DOES emit an empty list', () async {
    // Pins the reason refresh() exists. If Riverpod or `build()` ever stopped
    // passing through `[]`, this test fails and refresh() can be reconsidered —
    // rather than the difference quietly becoming a no-op nobody rechecks.
    final store = _MutableStore([_goal('a'), _goal('b')]);
    final c = await container(store);
    await c.read(goalsProvider.notifier).ensureLoaded();

    final observed = <int>[];
    c.listen(goalsProvider, (_, next) => observed.add(next.length),
        fireImmediately: false);

    c.invalidate(goalsProvider);
    c.read(goalsProvider); // force the rebuild
    await c.read(goalsProvider.notifier).ensureLoaded();

    expect(observed, contains(0),
        reason: 'this is the behaviour refresh() exists to avoid');
  });

  test('a refresh that finds FEWER habits still reports them', () async {
    // The list must be able to shrink — a habit deleted on another device has
    // to disappear. "Never empty" is not the rule; "never transiently empty"
    // is.
    final store = _MutableStore([_goal('a'), _goal('b')]);
    final c = await container(store);
    await c.read(goalsProvider.notifier).ensureLoaded();

    store.goals = [_goal('a')];
    await c.read(goalsProvider.notifier).refresh();

    expect(c.read(goalsProvider).map((g) => g.id), ['a']);
  });

  test('a refresh down to genuinely zero habits is allowed', () async {
    // Deleting your last habit on the Mac must reach this device, or Screen
    // Time monitoring would never be torn down.
    final store = _MutableStore([_goal('a')]);
    final c = await container(store);
    await c.read(goalsProvider.notifier).ensureLoaded();

    store.goals = [];
    await c.read(goalsProvider.notifier).refresh();

    expect(c.read(goalsProvider), isEmpty);
    expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue,
        reason: 'a real empty list is still a trustworthy one');
  });

  test('ensureLoaded awaits the REFRESH\'s load, not the stale one', () async {
    final store = _MutableStore([_goal('a')]);
    final c = await container(store);
    await c.read(goalsProvider.notifier).ensureLoaded();

    // Start a refresh that will return different data, then barrier on it
    // WITHOUT awaiting the refresh future directly.
    store.goals = [_goal('a'), _goal('b')];
    unawaited(c.read(goalsProvider.notifier).refresh());

    final loaded = await c.read(goalsProvider.notifier).ensureLoaded();

    expect(loaded, isTrue);
    expect(c.read(goalsProvider).map((g) => g.id), ['a', 'b'],
        reason: 'the barrier must have waited for the in-flight refresh');
  });

  // The WIRING. Everything above tests `refresh()` in isolation; this pins the
  // one line that actually puts it on the sync path. Reverting
  // `invalidatePrivateDataProviders` to `ref.invalidate(goalsProvider)` passes
  // every other test in this file, because none of them go through it.
  testWidgets('invalidatePrivateDataProviders refreshes goals in place',
      (tester) async {
    // NOT _MutableStore: its `Future.delayed` is a Timer, and `testWidgets`
    // runs in FakeAsync, where awaiting one without pumping the clock hangs
    // forever. The empty frame this test hunts comes from `build()` returning
    // `[]` SYNCHRONOUSLY, so a load with no timer still exposes it.
    final store = _InstantStore([_goal('a'), _goal('b'), _goal('c')]);
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();

    late WidgetRef captured;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith((ref) => store),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
      ],
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        return const SizedBox.shrink();
      }),
    ));

    await captured.read(goalsProvider.notifier).ensureLoaded();
    await tester.pump();
    expect(captured.read(goalsProvider), hasLength(3));

    final observed = <int>[];
    final sub = captured.listenManual(
      goalsProvider,
      (_, next) => observed.add(next.length),
      fireImmediately: false,
    );
    addTearDown(sub.close);

    store.goals = [_goal('a'), _goal('b'), _goal('c'), _goal('d')];
    invalidatePrivateDataProviders(captured);
    await captured.read(goalsProvider.notifier).ensureLoaded();
    await tester.pump();

    expect(observed, isNot(contains(0)),
        reason: 'the sync path must not flash the habit list empty');
    expect(captured.read(goalsProvider), hasLength(4));
  });

  test('a refresh whose load FAILS reports untrustworthy and keeps no lie',
      () async {
    final store = _FlakyOnRefreshStore([_goal('a')]);
    final c = await container(store);
    await c.read(goalsProvider.notifier).ensureLoaded();
    expect(c.read(goalsProvider), hasLength(1));

    await c.read(goalsProvider.notifier).refresh();

    expect(await c.read(goalsProvider.notifier).ensureLoaded(), isFalse,
        reason: 'the failed reload must not be reported as trustworthy');
  });
}

/// Loads with no Timer, for use inside `testWidgets` (FakeAsync).
class _InstantStore extends FakePrivateDataStore {
  _InstantStore(this.goals);
  List<Goal> goals;

  @override
  Future<List<Goal>> loadGoals() async => goals;
}

/// Succeeds on the first load and throws on every one after it, so a test can
/// exercise a refresh that fails without disturbing the initial load.
class _FlakyOnRefreshStore extends FakePrivateDataStore {
  _FlakyOnRefreshStore(this.goals);

  final List<Goal> goals;
  int loadCount = 0;

  @override
  Future<List<Goal>> loadGoals() async {
    if (loadCount++ == 0) return goals;
    throw StateError('disk failure');
  }
}
