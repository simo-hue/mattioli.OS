// GoalsNotifier.ensureLoaded — the barrier that lets a caller tell "this user
// has no habits" apart from "the list has not loaded yet".
//
// `build()` returns `[]` and fills in asynchronously, and it re-runs far more
// often than once per launch: `invalidatePrivateDataProviders` invalidates
// goalsProvider on every applied iCloud sync, which the 60s poll can reach once
// a minute. The Screen Time monitoring sync is DESTRUCTIVE on empty — an empty
// spec list tells DeviceActivity to stop watching everything — so believing a
// transient `[]` would tear down and rebuild every activity, re-zeroing each
// goal's accumulated usage for the day. These tests pin the barrier it relies on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

/// A store whose goal load takes a moment, like a real encrypted-DB open.
class _SlowStore extends FakePrivateDataStore {
  _SlowStore(this._goals);

  final List<Goal> _goals;
  int loadCount = 0;

  @override
  Future<List<Goal>> loadGoals() async {
    loadCount++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _goals;
  }
}

Goal _goal(String id) => Goal(
      id: id,
      title: id,
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
    );

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

  test(
      'AN EMPTY LIST BEFORE THE BARRIER IS NOT "no habits" — awaiting '
      'ensureLoaded yields the real list', () async {
    final store = _SlowStore([_goal('a'), _goal('b')]);
    final c = await container(store);
    final notifier = c.read(goalsProvider.notifier);

    // What a listener sees the instant the provider is first built.
    expect(c.read(goalsProvider), isEmpty);

    await notifier.ensureLoaded();

    expect(c.read(goalsProvider).map((g) => g.id), ['a', 'b']);
  });

  test('a genuinely empty account still reads empty AFTER the barrier',
      () async {
    final c = await container(_SlowStore(const []));
    await c.read(goalsProvider.notifier).ensureLoaded();

    // The barrier does not invent data — "no habits" survives it, which is what
    // keeps "I deleted my last Screen Time habit" able to stop monitoring.
    expect(c.read(goalsProvider), isEmpty);
  });

  test('ensureLoaded is idempotent and does not re-trigger the load', () async {
    final store = _SlowStore([_goal('a')]);
    final c = await container(store);
    final notifier = c.read(goalsProvider.notifier);

    await notifier.ensureLoaded();
    await notifier.ensureLoaded();
    await notifier.ensureLoaded();

    expect(store.loadCount, 1);
    expect(c.read(goalsProvider).map((g) => g.id), ['a']);
  });

  // `build()` re-runs on the SAME notifier instance across an invalidate,
  // reassigning `_initialLoad` and resetting state to `[]`. A barrier that
  // returned as soon as the load it happened to capture completed would hand the
  // caller that fresh `[]` while the real load was still in flight — the exact
  // "empty list is not real" case it exists to prevent.
  test('A REBUILD MID-AWAIT DOES NOT SATISFY THE BARRIER WITH THE STALE LOAD',
      () async {
    final store = _SlowStore([_goal('a')]);
    final c = await container(store);
    final barrier = c.read(goalsProvider.notifier).ensureLoaded();

    // Invalidate while load #1 is still in flight, then force the rebuild.
    c.invalidate(goalsProvider);
    c.read(goalsProvider);

    await barrier;

    expect(store.loadCount, 2, reason: 'the rebuild started a second load');
    expect(c.read(goalsProvider).map((g) => g.id), ['a'],
        reason: 'the barrier waited for the CURRENT load, not the stale one');
  });

  // The composition itself, with no Riverpod, Supabase or auth involved. This is
  // the property that was wrong in BOTH notifiers: the barrier must wait for the
  // slow loader even when the fast one has already failed, because the fast one
  // is routinely the failing one (a Supabase call returns in milliseconds when
  // offline; the cache seed first awaits a Keychain round trip).
  test('LOAD BARRIER WAITS FOR THE SLOW LOADER EVEN WHEN THE FAST ONE FAILS',
      () async {
    final started = DateTime.now();
    var slowFinished = false;

    await loadBarrier([
      Future<void>.delayed(const Duration(milliseconds: 5))
          .then((_) => throw StateError('fast failure')),
      Future<void>.delayed(const Duration(milliseconds: 80))
          .then((_) => slowFinished = true),
    ]);

    expect(slowFinished, isTrue,
        reason: 'the fast failure must not resolve the barrier');
    expect(DateTime.now().difference(started).inMilliseconds,
        greaterThanOrEqualTo(70));
  });

  test('load barrier tolerates every loader failing', () async {
    await expectLater(
      loadBarrier([
        Future<void>.error(StateError('a')),
        Future<void>.error(StateError('b')),
      ]),
      completes,
    );
  });

  test('a failing load still completes the barrier rather than hanging',
      () async {
    final c = await container(_ThrowingStore());

    // The loaders swallow their own errors; the barrier must not rethrow, or a
    // disk failure would take the monitoring sync down with it.
    await expectLater(
      c.read(goalsProvider.notifier).ensureLoaded(),
      completes,
    );
  });

  // ── trustworthiness ───────────────────────────────────────────────────────
  //
  // Completing is not the same as succeeding. `_loadFromPrivateStore` CATCHES
  // its error and leaves `[]`, so the barrier settles cleanly over a failure —
  // and `ensureLoaded` used to return true for it. Both Screen Time callers
  // guard with `if (!loaded && goals.isEmpty)`, so `!loaded` never firing meant
  // a failed load handed DeviceActivity `syncMonitoredGoals([])`: stop watching
  // every habit that still exists, then cache that teardown as intended.
  group('a settled load is not necessarily a trustworthy one', () {
    test('THE REGRESSION: a FAILED load reports UNTRUSTWORTHY', () async {
      final c = await container(_ThrowingStore());

      final loaded = await c.read(goalsProvider.notifier).ensureLoaded();

      expect(loaded, isFalse,
          reason: 'the empty list is the FAILURE, not an empty account');
    });

    test('the destructive caller\'s guard actually fires on a failed load',
        () async {
      // The exact shape both call sites use (verification_wiring.dart and
      // main.dart's _runScreenTimeSync).
      final c = await container(_ThrowingStore());

      final loaded = await c.read(goalsProvider.notifier).ensureLoaded();
      final goals = c.read(goalsProvider);

      expect(!loaded && goals.isEmpty, isTrue,
          reason: 'this is the condition that skips the Screen Time teardown');
    });

    test('a genuinely empty account STAYS trustworthy', () async {
      // Load succeeded and found nothing. This must NOT be reported as
      // untrustworthy, or deleting your last Screen Time habit would never stop
      // DeviceActivity monitoring — the opposite failure.
      final c = await container(_SlowStore(const []));

      final loaded = await c.read(goalsProvider.notifier).ensureLoaded();
      final goals = c.read(goalsProvider);

      expect(loaded, isTrue);
      expect(!loaded && goals.isEmpty, isFalse,
          reason: 'the teardown must still be reachable for a real empty list');
    });

    test('a successful load with habits is trustworthy', () async {
      final c = await container(_SlowStore([_goal('a')]));

      expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue);
    });

    test('the flag re-arms: a rebuild after a failure can succeed', () async {
      // `build()` re-runs on the SAME notifier instance across an invalidate, so
      // a sticky failure flag would poison every later load for the session.
      final store = _FlakyStore();
      final c = await container(store);

      expect(await c.read(goalsProvider.notifier).ensureLoaded(), isFalse,
          reason: 'first load throws');

      c.invalidate(goalsProvider);
      c.read(goalsProvider);

      expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue,
          reason: 'the second load succeeded — the flag must have re-armed');
      expect(c.read(goalsProvider).map((g) => g.id), ['a']);
    });

    test('and re-arms the other way: a rebuild after success can fail',
        () async {
      final store = _FlakyStore(succeedFirst: true);
      final c = await container(store);

      expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue);

      c.invalidate(goalsProvider);
      c.read(goalsProvider);

      expect(await c.read(goalsProvider.notifier).ensureLoaded(), isFalse,
          reason: 'a stale success must not vouch for a failed reload');
    });
  });
}

/// Fails its first load and succeeds afterwards (or the reverse), so a test can
/// prove the trustworthiness flag is re-armed by `build()` rather than latched
/// for the life of the notifier.
class _FlakyStore extends FakePrivateDataStore {
  _FlakyStore({this.succeedFirst = false});

  final bool succeedFirst;
  int loadCount = 0;

  @override
  Future<List<Goal>> loadGoals() async {
    final first = loadCount++ == 0;
    if (first == succeedFirst) return [_goal('a')];
    throw StateError('disk failure');
  }
}

/// A store whose goal load fails, to prove the barrier never rethrows.
class _ThrowingStore extends FakePrivateDataStore {
  @override
  Future<List<Goal>> loadGoals() async => throw StateError('disk failure');
}
