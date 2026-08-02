// Provider-level test for HabitProgressNotifier.setProgress — the write path the
// increment/timer UI drives. It persists the day's number to goal_progress AND
// moves the verdict (goal_logs) to match via HabitLogsNotifier.setDerivedStatus.
// Runs in Private mode over a fake store, so Supabase is never touched.

import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

/// Records progress writes AND log writes/deletes, so a test can assert both the
/// number that was stored and the verdict that was derived from it.
class _RecordingStore extends FakePrivateDataStore {
  _RecordingStore({
    this.seededGoals = const <Goal>[],
    this.seededProgress = const <String, Map<String, double>>{},
    this.seededLogs = const <String, Map<String, String>>{},
    this.logsLoadDelay = Duration.zero,
  });

  /// Holds [loadHabitLogs] open, so a test can fire the sweep while the verdict
  /// map is genuinely still in flight. Without this the load resolves during the
  /// sweep's first await and the race never happens — the barrier test would
  /// then pass whether or not the barrier exists.
  final Duration logsLoadDelay;

  /// Goals returned by [loadGoals] on init, so a test can start from a habit
  /// whose target has been effective since a PAST date (a genuinely "started
  /// days ago" habit). addHabit's forward-only create-stamp anchors a new
  /// habit's target to today (v11), so it cannot express a backdated anchor.
  final List<Goal> seededGoals;

  final List<Map<String, Object?>> progressWrites = [];
  final List<Map<String, Object?>> progressDeletes = [];
  final List<Map<String, Object?>> logWrites = [];
  final List<Map<String, Object?>> logDeletes = [];

  @override
  Future<List<Goal>> loadGoals() async => seededGoals;

  /// Progress/logs already on disk when the app starts — i.e. rows a sync pull,
  /// a backup import, or a previous session left behind. The loaders are async,
  /// which is the whole point of the regression test below.
  final Map<String, Map<String, double>> seededProgress;
  final Map<String, Map<String, String>> seededLogs;

  @override
  Future<Map<String, Map<String, double>>> loadHabitProgress() async =>
      {for (final e in seededProgress.entries) e.key: {...e.value}};

  @override
  Future<Map<String, Map<String, String>>> loadHabitLogs() async {
    if (logsLoadDelay > Duration.zero) await Future<void>.delayed(logsLoadDelay);
    return {for (final e in seededLogs.entries) e.key: {...e.value}};
  }

  @override
  Future<void> setHabitProgress({
    required String goalId,
    required String date,
    required double amount,
    String source = 'manual',
  }) async {
    progressWrites.add({'goalId': goalId, 'date': date, 'amount': amount, 'source': source});
    await super.setHabitProgress(
        goalId: goalId, date: date, amount: amount, source: source);
  }

  @override
  Future<void> deleteHabitProgress({
    required String goalId,
    required String date,
  }) async {
    progressDeletes.add({'goalId': goalId, 'date': date});
    await super.deleteHabitProgress(goalId: goalId, date: date);
  }

  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int streak = 0,
    double? value,
  }) async {
    logWrites.add({'goalId': goalId, 'date': date, 'status': status, 'value': value});
    await super.setHabitLog(
        goalId: goalId, date: date, status: status, streak: streak, value: value);
  }

  @override
  Future<void> deleteHabitLog({
    required String goalId,
    required String date,
  }) async {
    logDeletes.add({'goalId': goalId, 'date': date});
    await super.deleteHabitLog(goalId: goalId, date: date);
  }
}

/// SharedPreferences whose ANCHOR read throws — a corrupt entry, or the value
/// stored under a type the plugin cannot decode. Scoped to that one key so the
/// rest of the container (the data-mode provider reads prefs in its build) still
/// works, and the test isolates the anchor's failure branch.
class _ThrowingPrefs implements SharedPreferences {
  _ThrowingPrefs(this._inner);
  final SharedPreferences _inner;

  @override
  String? getString(String key) {
    if (key == kAutoFailAnchorPrefKey) throw StateError('prefs unavailable');
    return _inner.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) =>
      _inner.setString(key, value);

  @override
  bool? getBool(String key) => _inner.getBool(key);

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'unexpected SharedPreferences call: ${invocation.memberName}');
}

/// A store whose VERDICT load fails while everything else works — the shape a
/// disk error (private mode) or an offline/5xx sync (account mode) leaves
/// behind. Both leave an empty map, which is exactly why the failure has to be
/// signalled out of band.
class _ThrowingLogsStore extends _RecordingStore {
  _ThrowingLogsStore({super.seededGoals});

  @override
  Future<Map<String, Map<String, String>>> loadHabitLogs() async =>
      throw StateError('disk failure');
}

Goal _countGoal() => Goal(
      id: 'g1',
      title: 'Push-ups',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 7, 1),
      target: TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20),
    );

Goal _limitGoal() => Goal(
      id: 'g2',
      title: 'Coffee',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 7, 1),
      target: TargetPresetCatalog.limitCountDaily.targetWith(amount: 1),
    );

// A habit that carries BOTH a HealthKit verification rule AND a manual target —
// the (legacy/synced) configuration the class picker prevents. Its goal_logs
// verdict must be owned solely by the verification pipeline (one owner per
// habit-day): the manual sweep and manual setProgress must never touch it.
Goal _verifiedLimitGoal() => Goal(
      id: 'gv',
      title: 'Steps + coffee',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 7, 1),
      verificationRule: VerificationCatalog.steps.ruleWith(10000),
      target: TargetPresetCatalog.limitCountDaily.targetWith(amount: 1),
    );

Goal _verifiedCountGoal() => Goal(
      id: 'gv',
      title: 'Steps + push-ups',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 7, 1),
      verificationRule: VerificationCatalog.steps.ruleWith(10000),
      target: TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadIsTrustworthy — when absence may be read as evidence', () {
    test('a barrier that gave up is never trustworthy', () {
      expect(
        loadIsTrustworthy(settled: false, syncFailed: false, cacheSeeded: true),
        isFalse,
      );
    });

    test('a clean load is trustworthy', () {
      expect(
        loadIsTrustworthy(settled: true, syncFailed: false, cacheSeeded: false),
        isTrue,
        reason: 'a genuinely empty history must not be mistaken for a failure, '
            'or a new user never gets their first days resolved',
      );
    });

    test('offline WITH the mirror seeded is trustworthy', () {
      // The regression this rule exists to prevent: treating every failed server
      // leg as a failed load stopped a no-signal phone resolving anything, where
      // before it swept the last-known-good mirror.
      expect(
        loadIsTrustworthy(settled: true, syncFailed: true, cacheSeeded: true),
        isTrue,
      );
    });

    test('a failed load with NOTHING seeded is not trustworthy', () {
      // The map is empty BECAUSE it failed — the one case that must never be
      // read as "the user recorded nothing".
      expect(
        loadIsTrustworthy(settled: true, syncFailed: true, cacheSeeded: false),
        isFalse,
      );
    });
  });

  /// [autoFailAnchor] pre-seeds the auto-fail anchor (a `YYYY-MM-DD` string).
  /// Leaving it null is the fresh-install case: the sweep stamps it at `now`, so
  /// nothing that closed earlier can be auto-failed.
  Future<ProviderContainer> container(
    FakePrivateDataStore store, {
    String? autoFailAnchor,
  }) async {
    SharedPreferences.setMockInitialValues({
      'active_data_mode': 'private',
      kAutoFailAnchorPrefKey: ?autoFailAnchor,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith((ref) => store),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
        initialProgressProvider.overrideWithValue('{}'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  // A day in the past, so limit habits resolve rather than stay pending.
  const pastDay = '2026-07-10';
  final now = DateTime(2026, 7, 24);

  test('a partial count on an OPEN day stores the number but writes NO verdict',
      () async {
    final store = _RecordingStore();
    final c = await container(store);
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier); // warm it so its async private-load settles first
    final progress = c.read(habitProgressProvider.notifier);
    await settle();
    await c.read(goalsProvider.notifier).addHabit(_countGoal());

    // TODAY, still open: 40 of 80 is in-progress, not yet decided.
    const todayKey = '2026-07-24';
    await progress.setProgress(
      dateKey: todayKey,
      goalId: 'g1',
      amount: 40,
      target: _countGoal().target!,
      now: now,
    );

    expect(c.read(habitProgressProvider)[todayKey]?['g1'], 40);
    expect(store.progressWrites.single['amount'], 40);
    // A half-done open day has no verdict — so no goal_logs row, and it stays
    // out of every rate denominator until it either completes or the day ends.
    expect(c.read(habitLogsProvider)[todayKey]?['g1'], isNull);
    expect(store.logWrites, isEmpty);
  });

  test('a partial count on a CLOSED day is an honest miss', () async {
    final store = _RecordingStore();
    final c = await container(store);
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier); // warm it so its async private-load settles first
    final progress = c.read(habitProgressProvider.notifier);
    await settle();
    await c.read(goalsProvider.notifier).addHabit(_countGoal());

    // The same 40 of 80, but on a past day: the day is over, so it did not make
    // the target — a real 'missed', which is exactly what stats should see.
    await progress.setProgress(
      dateKey: pastDay,
      goalId: 'g1',
      amount: 40,
      target: _countGoal().target!,
      now: now,
    );

    expect(c.read(habitLogsProvider)[pastDay]?['g1'], 'missed');
  });

  test('reaching a count target derives a done verdict', () async {
    final store = _RecordingStore();
    final c = await container(store);
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier); // warm it so its async private-load settles first
    final progress = c.read(habitProgressProvider.notifier);
    await settle();
    await c.read(goalsProvider.notifier).addHabit(_countGoal());

    await progress.setProgress(
      dateKey: pastDay,
      goalId: 'g1',
      amount: 80,
      target: _countGoal().target!,
      now: now,
    );

    expect(c.read(habitProgressProvider)[pastDay]?['g1'], 80);
    expect(c.read(habitLogsProvider)[pastDay]?['g1'], 'done');
    expect(store.logWrites.single['status'], 'done');
    // The verdict row must not carry the progress number — that lives in
    // goal_progress, never on goal_logs.value.
    expect(store.logWrites.single['value'], isNull);
  });

  test('a closed limit day under the cap resolves to done', () async {
    final store = _RecordingStore();
    final c = await container(store);
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier); // warm it so its async private-load settles first
    final progress = c.read(habitProgressProvider.notifier);
    await settle();
    await c.read(goalsProvider.notifier).addHabit(_limitGoal());

    // One coffee, at the limit, on a past (closed) day → success.
    await progress.setProgress(
      dateKey: pastDay,
      goalId: 'g2',
      amount: 1,
      target: _limitGoal().target!,
      now: now,
    );

    expect(c.read(habitLogsProvider)[pastDay]?['g2'], 'done');
  });

  test('exceeding a limit derives a missed verdict', () async {
    final store = _RecordingStore();
    final c = await container(store);
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier); // warm it so its async private-load settles first
    final progress = c.read(habitProgressProvider.notifier);
    await settle();
    await c.read(goalsProvider.notifier).addHabit(_limitGoal());

    await progress.setProgress(
      dateKey: pastDay,
      goalId: 'g2',
      amount: 2, // over the cap of 1
      target: _limitGoal().target!,
      now: now,
    );

    expect(c.read(habitLogsProvider)[pastDay]?['g2'], 'missed');
  });

  test('returning to zero removes both the number and the verdict', () async {
    final store = _RecordingStore();
    final c = await container(store);
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier); // warm it so its async private-load settles first
    final progress = c.read(habitProgressProvider.notifier);
    await settle();
    await c.read(goalsProvider.notifier).addHabit(_countGoal());

    await progress.setProgress(
        dateKey: pastDay, goalId: 'g1', amount: 80, target: _countGoal().target!, now: now);
    expect(c.read(habitLogsProvider)[pastDay]?['g1'], 'done');

    await progress.setProgress(
        dateKey: pastDay, goalId: 'g1', amount: 0, target: _countGoal().target!, now: now);

    expect(c.read(habitProgressProvider)[pastDay]?['g1'], isNull);
    expect(store.progressDeletes, isNotEmpty);
    // 80 (done) → 0 on a closed day is 'unmet' for an atLeast target: a missed
    // verdict, not a cleared one.
    expect(c.read(habitLogsProvider)[pastDay]?['g1'], 'missed');
  });

  test('progress on today does not prematurely resolve a limit habit', () async {
    final store = _RecordingStore();
    final c = await container(store);
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier); // warm it so its async private-load settles first
    final progress = c.read(habitProgressProvider.notifier);
    await settle();
    await c.read(goalsProvider.notifier).addHabit(_limitGoal());

    const todayKey = '2026-07-24';
    await progress.setProgress(
      dateKey: todayKey,
      goalId: 'g2',
      amount: 0, // nothing consumed yet today
      target: _limitGoal().target!,
      now: now,
    );

    // Staying under a cap is only knowable at day end — today is still pending,
    // so no premature 'done'.
    expect(c.read(habitLogsProvider)[todayKey]?['g2'], isNull);
  });

  group('reconcileManualTargets never sweeps an unloaded map', () {
    // Phase 0 blocker. `build()` must return synchronously, so in Private mode it
    // returns {} and loads goal_progress in the BACKGROUND. That makes "no data"
    // and "not loaded yet" indistinguishable — and for an `atMost` target an
    // absent entry means a quiet SUCCESS, whose verdict is applied by writing
    // amount 0, which DELETES the stored row and tombstones it to CloudKit.
    //
    // Every other test here calls `await settle()` before reconciling, which is
    // exactly why none of them caught it. These deliberately do NOT settle.
    test('a breach pulled from the store survives a sweep racing the load',
        () async {
      final store = _RecordingStore(
        seededGoals: [
          _limitGoal().copyWith(
            startDate: DateTime(2026, 7, 21),
            targetEffectiveFrom: DateTime(2026, 7, 21),
          ),
        ],
        // 3 coffees against a cap of 1 on a closed day: a real, recorded breach.
        seededProgress: const {'2026-07-22': {'g2': 3}},
        seededLogs: const {'2026-07-22': {'g2': 'missed'}},
      );
      final c = await container(store);
      // Warm goals + logs FIRST. This is the state that actually ships: Home
      // watches goalsProvider, so by the time a resume fires the habits are
      // loaded — and ONLY the progress map is behind. (Leaving goals unloaded
      // too makes the sweep no-op over an empty habit list, which hides the bug
      // rather than exposing it.)
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      await settle();

      // Now force the progress provider to rebuild, so its async load is in
      // flight while everything else is warm — precisely what
      // invalidatePrivateDataProviders does after a sync pull or an import.
      c.invalidate(habitProgressProvider);
      final progress = c.read(habitProgressProvider.notifier);

      // NO settle() before sweeping: main.dart's resume handler doesn't either.
      await progress.reconcileManualTargets(now: now);
      await settle();

      // Scoped to the breach day on purpose. The sweep legitimately resolves the
      // OTHER quiet days in the window to 'done' and applies that as amount 0,
      // which issues a delete for a row that never existed — harmless. The
      // invariant is narrower and sharper: a day that HAS a recorded amount must
      // never be deleted.
      expect(
        store.progressDeletes.where((d) => d['date'] == '2026-07-22'),
        isEmpty,
        reason: 'the sweep deleted a recorded breach it could not yet see',
      );
      expect(c.read(habitProgressProvider)['2026-07-22']?['g2'], 3,
          reason: 'the real amount must survive the sweep');
      expect(c.read(habitLogsProvider)['2026-07-22']?['g2'], 'missed',
          reason: 'a breach must not be rewritten as a success');
    });

    test('an earned day survives a sweep racing the LOGS load', () async {
      // The hazard auto-fail introduces. The two maps load independently, so
      // progress can be ready while logs are still in flight — and an empty logs
      // map makes every closed day look untouched.
      //
      // The day here is the one that cannot heal itself: a 'done' written by the
      // reminder's Done action, with NO number behind it. Nothing in
      // goal_progress can restore it, so a sweep that ran blind would replace a
      // deliberate answer with 'missed' permanently, and sync that to CloudKit
      // and the Mac.
      final store = _RecordingStore(
        seededGoals: [
          _countGoal().copyWith(
            startDate: DateTime(2026, 7, 22),
            targetEffectiveFrom: DateTime(2026, 7, 22),
          ),
        ],
        seededLogs: const {'2026-07-22': {'g1': 'done'}},
        // Slow enough that the sweep's own awaits cannot accidentally let the
        // logs land first — the race has to be real for this test to mean
        // anything.
        logsLoadDelay: const Duration(milliseconds: 50),
      );
      final c = await container(store, autoFailAnchor: '2026-07-01');
      // Warm goals + progress, then force ONLY the logs map to reload so its
      // async load is in flight when the sweep fires — the mirror image of the
      // progress-map race below.
      c.read(goalsProvider.notifier);
      c.read(habitProgressProvider.notifier);
      await settle();
      c.invalidate(habitLogsProvider);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);

      // No settle() before sweeping — main.dart's resume handler doesn't either.
      await progress.reconcileManualTargets(now: now);
      await settle();

      expect(c.read(habitLogsProvider)['2026-07-22']?['g1'], 'done',
          reason: 'an earned day must not be auto-failed because its verdict '
              'had not loaded yet');
      expect(
        store.logWrites.where(
            (w) => w['date'] == '2026-07-22' && w['status'] == 'missed'),
        isEmpty,
      );
    });

    test('a FAILED logs load disables auto-fail (not just an unfinished one)',
        () async {
      // A settled barrier is not a successful one. Both logs loaders swallow
      // their error and leave `{}` behind, so "no verdicts stored" and "the
      // store did not answer" look identical downstream. Reading the second as
      // the first is how a reminder-written 'done' — which has no number to
      // re-derive it from — gets permanently replaced by 'missed' and synced.
      final store = _ThrowingLogsStore(seededGoals: [
        _countGoal().copyWith(
          startDate: DateTime(2026, 7, 22),
          targetEffectiveFrom: DateTime(2026, 7, 22),
        ),
      ]);
      final c = await container(store, autoFailAnchor: '2026-07-01');
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);

      expect(store.logWrites, isEmpty,
          reason: 'auto-fail must stand down when the verdict map failed to '
              'load, rather than scoring every day as untouched');
    });

    test('an UNDRAINED notification queue disables auto-fail', () async {
      // A queued Done is a habit-day the user already decided, which the verdict
      // map cannot show until the queue reaches the server. Auto-fail would read
      // it as untouched and write 'missed' over it — and with no goal_progress
      // row behind a reminder-written Done, nothing could re-derive it.
      final store = _RecordingStore(seededGoals: [
        _countGoal().copyWith(
          startDate: DateTime(2026, 7, 22),
          targetEffectiveFrom: DateTime(2026, 7, 22),
        ),
      ]);
      final c = await container(store, autoFailAnchor: '2026-07-01');
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now, allowAutoFail: false);

      expect(store.logWrites, isEmpty);
    });

    test('a drained queue lets auto-fail run (the guard is not a kill switch)',
        () async {
      final store = _RecordingStore(seededGoals: [
        _countGoal().copyWith(
          startDate: DateTime(2026, 7, 22),
          targetEffectiveFrom: DateTime(2026, 7, 22),
        ),
      ]);
      final c = await container(store, autoFailAnchor: '2026-07-01');
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now, allowAutoFail: true);

      expect(c.read(habitLogsProvider)['2026-07-22']?['g1'], 'missed');
    });

    test('a failed logs load still lets the LIMIT sweep run', () async {
      // The gate is deliberately narrow. Limit resolution derives from
      // goal_progress (barriered separately) and is unharmed by a thin logs
      // map, so a logs failure must not leave an offline user's limit habits
      // perpetually unresolved — that would be a regression in shipped
      // behaviour, traded for a hazard that only auto-fail has.
      final store = _ThrowingLogsStore(seededGoals: [
        _limitGoal().copyWith(
          startDate: DateTime(2026, 7, 22),
          targetEffectiveFrom: DateTime(2026, 7, 22),
        ),
      ]);
      final c = await container(store, autoFailAnchor: '2026-07-01');
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);

      expect(store.logWrites.map((w) => w['status']), contains('done'));
    });

    test('the sweep still materialises a genuinely quiet closed day', () async {
      // The guard must not defeat the feature: with the map loaded and truly
      // empty, an untouched limit day is still a success.
      final store = _RecordingStore(seededGoals: [
        _limitGoal().copyWith(
          startDate: DateTime(2026, 7, 22),
          targetEffectiveFrom: DateTime(2026, 7, 22),
        ),
      ]);
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);

      await progress.reconcileManualTargets(now: now);
      await settle();

      expect(c.read(habitLogsProvider)['2026-07-22']?['g2'], 'done');
    });
  });

  group('reconcileManualTargets (end-of-day sweep)', () {
    // A limit habit that started a few days ago and was never touched: its quiet
    // past days must be materialised into 'done', its today left pending.
    test('materialises a limit habit\'s quiet closed days as done', () async {
      final store = _RecordingStore(seededGoals: [
        _limitGoal().copyWith(
          startDate: DateTime(2026, 7, 21),
          targetEffectiveFrom: DateTime(2026, 7, 21),
        ),
      ]);
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);

      final logs = c.read(habitLogsProvider);
      // 21, 22, 23 closed & quiet → done; 24 (today) untouched → pending.
      expect(logs['2026-07-21']?['g2'], 'done');
      expect(logs['2026-07-22']?['g2'], 'done');
      expect(logs['2026-07-23']?['g2'], 'done');
      expect(logs['2026-07-24']?['g2'], isNull);
    });

    test('is idempotent — a second pass writes nothing new', () async {
      final store = _RecordingStore(seededGoals: [
        _limitGoal().copyWith(
          startDate: DateTime(2026, 7, 22),
          targetEffectiveFrom: DateTime(2026, 7, 22),
        ),
      ]);
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);
      final writesAfterFirst = store.logWrites.length;
      await progress.reconcileManualTargets(now: now);

      expect(store.logWrites.length, writesAfterFirst,
          reason: 'the second sweep must be a no-op');
    });

    test('does not invent misses for days that closed BEFORE the anchor',
        () async {
      // The first sweep on this build stamps the auto-fail anchor at today, so
      // every day that closed before the rule existed is out of reach. This is
      // what stops shipping auto-fail from retroactively reddening history a
      // user has already seen and moved on from.
      final store = _RecordingStore(seededGoals: [
        _countGoal().copyWith(
          startDate: DateTime(2026, 7, 20),
          targetEffectiveFrom: DateTime(2026, 7, 20),
        ),
      ]);
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);

      expect(store.logWrites, isEmpty);
      expect(c.read(habitLogsProvider)['2026-07-22']?['g1'], isNull);
      // ... and the anchor was stamped, so tomorrow's sweep can score today.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kAutoFailAnchorPrefKey), '2026-07-24');
    });

    test('auto-fails an untouched count day from the anchor on', () async {
      // The bug this feature fixes: 0 push-ups is 0 push-ups whether or not the
      // user ever opened the sheet. With the anchor already in the past, every
      // closed scheduled day the user never touched resolves to 'missed'.
      final store = _RecordingStore(seededGoals: [
        _countGoal().copyWith(
          startDate: DateTime(2026, 7, 21),
          targetEffectiveFrom: DateTime(2026, 7, 21),
        ),
      ]);
      final c = await container(store, autoFailAnchor: '2026-07-01');
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);

      final logs = c.read(habitLogsProvider);
      expect(logs['2026-07-21']?['g1'], 'missed');
      expect(logs['2026-07-22']?['g1'], 'missed');
      expect(logs['2026-07-23']?['g1'], 'missed');
      // Today is still open — it must stay pending, not pre-fail.
      expect(logs['2026-07-24']?['g1'], isNull);
    });

    test('auto-fail writes the verdict ONLY — goal_progress is never touched',
        () async {
      // A day with no entry has no number to write, so the sweep must not route
      // it through setProgress: `amount 0` DELETES, and a delete driven by an
      // absence is how a real count gets destroyed if the map is ever wrong.
      final store = _RecordingStore(seededGoals: [
        _countGoal().copyWith(
          startDate: DateTime(2026, 7, 22),
          targetEffectiveFrom: DateTime(2026, 7, 22),
        ),
      ]);
      final c = await container(store, autoFailAnchor: '2026-07-01');
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);

      expect(c.read(habitLogsProvider)['2026-07-22']?['g1'], 'missed');
      expect(store.progressWrites, isEmpty);
      expect(store.progressDeletes, isEmpty,
          reason: 'auto-fail must not issue a delete on the strength of an '
              'absent progress row');
    });

    test('auto-fail is idempotent — a second pass writes nothing new', () async {
      final store = _RecordingStore(seededGoals: [
        _countGoal().copyWith(
          startDate: DateTime(2026, 7, 22),
          targetEffectiveFrom: DateTime(2026, 7, 22),
        ),
      ]);
      final c = await container(store, autoFailAnchor: '2026-07-01');
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);
      final writesAfterFirst = store.logWrites.length;
      expect(writesAfterFirst, greaterThan(0));
      await progress.reconcileManualTargets(now: now);

      expect(store.logWrites.length, writesAfterFirst);
    });

    test('logging the number afterwards reverses an auto-failed day', () async {
      // Auto-fail must never be a trap: entering the push-ups you did flips the
      // day straight back to done.
      final store = _RecordingStore(seededGoals: [
        _countGoal().copyWith(
          startDate: DateTime(2026, 7, 23),
          targetEffectiveFrom: DateTime(2026, 7, 23),
        ),
      ]);
      final c = await container(store, autoFailAnchor: '2026-07-01');
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);
      expect(c.read(habitLogsProvider)['2026-07-23']?['g1'], 'missed');

      await progress.setProgress(
        dateKey: '2026-07-23',
        goalId: 'g1',
        amount: 80,
        target: _countGoal().target!,
        now: now,
      );

      expect(c.read(habitLogsProvider)['2026-07-23']?['g1'], 'done');
      expect(c.read(habitProgressProvider)['2026-07-23']?['g1'], 80);
    });

    test('an unreadable anchor turns auto-fail OFF, not on', () async {
      // A failed preference read must NARROW what gets written, never widen it.
      // The tempting default — "no anchor stored, so score everything" — would
      // turn a broken prefs store into a retroactive 45-day red streak.
      final store = _RecordingStore(seededGoals: [
        _countGoal().copyWith(
          startDate: DateTime(2026, 7, 22),
          targetEffectiveFrom: DateTime(2026, 7, 22),
        ),
      ]);
      SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(_ThrowingPrefs(prefs)),
        privateLocalDatabaseProvider.overrideWith((ref) => store),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
        initialProgressProvider.overrideWithValue('{}'),
      ]);
      addTearDown(c.dispose);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);

      expect(store.logWrites, isEmpty);
    });

    test('a verified habit is never auto-failed either (one owner)', () async {
      final store = _RecordingStore(seededGoals: [
        _verifiedCountGoal().copyWith(
          startDate: DateTime(2026, 7, 21),
          targetEffectiveFrom: DateTime(2026, 7, 21),
        ),
      ]);
      final c = await container(store, autoFailAnchor: '2026-07-01');
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);

      // "Couldn't verify" is not "you failed" — the verification pipeline owns
      // this habit's verdict and auto-fail must not reach into it.
      expect(store.logWrites, isEmpty);
      expect(c.read(habitLogsProvider)['2026-07-22']?['gv'], isNull);
    });

    test('resolves a partial count day left pending into a miss', () async {
      final store = _RecordingStore(seededGoals: [
        _countGoal().copyWith(
          startDate: DateTime(2026, 7, 20),
          targetEffectiveFrom: DateTime(2026, 7, 20),
        ),
      ]);
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();
      // Simulate progress logged yesterday while it was still open (pending, no
      // verdict): 40 of 80 on the 23rd.
      await progress.setProgress(
        dateKey: '2026-07-23',
        goalId: 'g1',
        amount: 40,
        target: _countGoal().target!,
        now: DateTime(2026, 7, 23, 12), // that day was open when logged
      );
      expect(c.read(habitLogsProvider)['2026-07-23']?['g1'], isNull);

      await progress.reconcileManualTargets(now: now);

      expect(c.read(habitLogsProvider)['2026-07-23']?['g1'], 'missed');
    });

    test('a verified habit is NOT swept even with a manual target (one owner)',
        () async {
      final store = _RecordingStore(seededGoals: [
        _verifiedLimitGoal().copyWith(
          startDate: DateTime(2026, 7, 21),
          targetEffectiveFrom: DateTime(2026, 7, 21),
        ),
      ]);
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      await progress.reconcileManualTargets(now: now);

      // The verification pipeline owns this habit's goal_logs — the manual sweep
      // must write nothing, or the two fight and flip the day's status.
      expect(store.logWrites, isEmpty);
      expect(c.read(habitLogsProvider)['2026-07-22']?['gv'], isNull);
    });

    test(
        'setProgress on a verified habit stores the number but writes NO verdict',
        () async {
      final store = _RecordingStore(seededGoals: [_verifiedCountGoal()]);
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();

      // 80 of 80 would derive 'done' for a plain count habit and overwrite the
      // goal_logs row; here the verification pipeline owns it.
      await progress.setProgress(
        dateKey: '2026-07-23',
        goalId: 'gv',
        amount: 80,
        target: _verifiedCountGoal().target!,
        now: now,
      );

      // The number is persisted (goal_progress) ...
      expect(store.progressWrites.any((w) => w['goalId'] == 'gv'), isTrue);
      // ... but no verdict was derived, so a sensor-earned status is never
      // clobbered or deleted by the manual path.
      expect(store.logWrites, isEmpty);
      expect(store.logDeletes, isEmpty);
    });
  });
}
