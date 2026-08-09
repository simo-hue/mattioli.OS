// Editing a count habit's target must not strand its unscored history.
//
// `target_effective_from` is forward-only: changing a target's amount stamps it
// to today, and `reconcileManualTargetDays` never looks before the anchor. That
// is right for a day that ALREADY carries a verdict — it keeps the one it earned
// under the old target — but a day that never got one becomes permanently
// unreachable and sits at pending for good.
//
// The fix scores those days BEFORE the anchor moves, while the old target is
// still in force. The alternative — letting the sweep fill them afterwards —
// would score them against the NEW target and invent verdicts: raise a goal from
// 3 to 10 and a day that did 3 gets written `missed`, having actually been met.
//
// Dates are relative to the real `DateTime.now()`, because `updateHabit` stamps
// the anchor from it and takes no clock. Hard-coded days would fall out of the
// 45-day backfill window and start failing on their own.

import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

/// The reminder reschedule on the save path would otherwise reach the real
/// plugin and throw before any assertion runs.
class _NoopNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

class _Store extends FakePrivateDataStore {
  _Store({
    this.seededGoals = const <Goal>[],
    this.seededProgress = const <String, Map<String, double>>{},
    this.seededLogs = const <String, Map<String, String>>{},
  });

  final List<Goal> seededGoals;
  final Map<String, Map<String, double>> seededProgress;
  final Map<String, Map<String, String>> seededLogs;

  final List<Map<String, Object?>> logWrites = [];

  @override
  Future<List<Goal>> loadGoals() async => seededGoals;

  @override
  Future<Map<String, Map<String, double>>> loadHabitProgress() async =>
      {for (final e in seededProgress.entries) e.key: {...e.value}};

  @override
  Future<Map<String, Map<String, String>>> loadHabitLogs() async =>
      {for (final e in seededLogs.entries) e.key: {...e.value}};

  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int? streak,
    double? value,
  }) async {
    logWrites.add({'goalId': goalId, 'date': date, 'status': status});
    await super.setHabitLog(
      goalId: goalId,
      date: date,
      status: status,
      streak: streak,
      value: value,
    );
  }
}

/// A store whose VERDICT load fails while everything else works — offline, a
/// 5xx, or a disk error. The materialise pass declines on it, and the anchor
/// must then stay put.
/// Fails the FIRST verdict load, then succeeds. That sequence — an edit made
/// while the map could not be read, followed by a healthy sweep — is the only
/// one in which holding the anchor back actually corrupts anything, so it is the
/// only one that can discriminate the two designs.
class _FlakyLogsStore extends _Store {
  _FlakyLogsStore({
    super.seededGoals,
    super.seededProgress,
    super.seededLogs,
  });

  bool failNext = true;

  @override
  Future<Map<String, Map<String, String>>> loadHabitLogs() async {
    if (failNext) {
      failNext = false;
      throw StateError('disk failure');
    }
    return super.loadHabitLogs();
  }
}

class _ThrowingLogsStore extends _Store {
  _ThrowingLogsStore({super.seededGoals, super.seededProgress});

  @override
  Future<Map<String, Map<String, String>>> loadHabitLogs() async =>
      throw StateError('disk failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
  });

  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  DateTime shift(int days) =>
      DateTime(today.year, today.month, today.day + days);
  String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Two closed days the old target still owes a verdict on.
  final metDay = shift(-3); // completed under the OLD amount
  final shortDay = shift(-2); // fell short under either

  HabitTarget count(double amount) =>
      TargetPresetCatalog.countDaily.targetWith(amount: amount, step: 1);

  Goal countGoal(HabitTarget target) => Goal(
        id: 'g1',
        title: 'Push-ups',
        color: const Color(0xFF3B82F6),
        startDate: shift(-4),
        target: target,
        targetEffectiveFrom: shift(-4),
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<ProviderContainer> container(_Store store) async {
    SharedPreferences.setMockInitialValues({
      'active_data_mode': 'private',
      // Well before the window, so auto-fail is live for these days.
      kAutoFailAnchorPrefKey: key(shift(-60)),
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
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier);
    c.read(habitProgressProvider.notifier);
    await settle();
    return c;
  }

  test('THE REGRESSION: raising a target scores the days it already owed, '
      'instead of stranding them at pending', () async {
    // 3 of 3 on metDay (completed under the OLD target), 1 of 3 on shortDay.
    final store = _Store(
      seededGoals: [countGoal(count(3))],
      seededProgress: {
        key(metDay): {'g1': 3},
        key(shortDay): {'g1': 1},
      },
    );
    final c = await container(store);

    await c
        .read(goalsProvider.notifier)
        .updateHabit(countGoal(count(3)).copyWith(target: count(10)));
    await settle();

    final logs = c.read(habitLogsProvider);
    expect(
      logs[key(metDay)]?['g1'],
      'done',
      reason: 'the day met the target that was IN FORCE on it (3 of 3). '
          'Scoring it against the new amount would write `missed` for a day '
          'the user actually completed',
    );
    expect(logs[key(shortDay)]?['g1'], 'missed',
        reason: '1 of 3 fell short under the old target too');
  });

  test('a day that ALREADY had a verdict keeps it, and is not rewritten',
      () async {
    final store = _Store(
      seededGoals: [countGoal(count(3))],
      seededProgress: {
        key(metDay): {'g1': 3},
      },
      seededLogs: {
        key(metDay): {'g1': 'done'},
      },
    );
    final c = await container(store);

    await c
        .read(goalsProvider.notifier)
        .updateHabit(countGoal(count(3)).copyWith(target: count(10)));
    await settle();

    expect(c.read(habitLogsProvider)[key(metDay)]?['g1'], 'done');
    expect(
      store.logWrites.where((w) => w['date'] == key(metDay)),
      isEmpty,
      reason: 'idempotent — an already-correct day must not be rewritten',
    );
  });

  test('a rename does NOT re-anchor, so nothing is materialised early',
      () async {
    final store = _Store(
      seededGoals: [countGoal(count(3))],
      seededProgress: {
        key(shortDay): {'g1': 1},
      },
    );
    final c = await container(store);

    await c.read(goalsProvider.notifier).updateHabit(
          countGoal(count(3)).copyWith(title: 'Press-ups'),
        );
    await settle();

    expect(
      store.logWrites,
      isEmpty,
      reason: 'the anchor is preserved on a non-scoring edit, so those days are '
          'still reachable by the ordinary sweep — there is nothing to rush',
    );
    expect(
      c.read(goalsProvider).single.targetEffectiveFrom,
      shift(-4),
      reason: 'a rename must not move the anchor',
    );
  });

  test('REMOVING a target also scores what it owed, before it vanishes',
      () async {
    // Without this the days are unreachable for a second reason: a habit with
    // no target is skipped by the sweep entirely.
    final store = _Store(
      seededGoals: [countGoal(count(3))],
      seededProgress: {
        key(metDay): {'g1': 3},
      },
    );
    final c = await container(store);

    await c
        .read(goalsProvider.notifier)
        .updateHabit(countGoal(count(3)).copyWith(clearTarget: true));
    await settle();

    expect(c.read(habitLogsProvider)[key(metDay)]?['g1'], 'done');
  });

  test('a VERIFIED habit is left to the verification pipeline (one owner)',
      () async {
    final verified = Goal(
      id: 'g1',
      title: 'Steps',
      color: const Color(0xFF3B82F6),
      startDate: shift(-4),
      verificationRule: VerificationCatalog.steps.ruleWith(10000),
      target: count(3),
      targetEffectiveFrom: shift(-4),
    );
    final store = _Store(
      seededGoals: [verified],
      seededProgress: {
        key(metDay): {'g1': 3},
      },
    );
    final c = await container(store);

    await c
        .read(goalsProvider.notifier)
        .updateHabit(verified.copyWith(target: count(10)));
    await settle();

    expect(
      store.logWrites,
      isEmpty,
      reason: 'goal_logs for a verified habit-day has exactly one owner, and '
          'this is not it',
    );
  });

  test('the anchor still moves to today after the old target is settled',
      () async {
    final store = _Store(
      seededGoals: [countGoal(count(3))],
      seededProgress: {
        key(metDay): {'g1': 3},
      },
    );
    final c = await container(store);

    await c
        .read(goalsProvider.notifier)
        .updateHabit(countGoal(count(3)).copyWith(target: count(10)));
    await settle();

    expect(
      c.read(goalsProvider).single.targetEffectiveFrom,
      today,
      reason: 'the forward-only freeze is unchanged — only the stranding is '
          'fixed',
    );
  });

  // The anchor is a ONE-WAY DOOR. `reconcileManualTargetDays` never looks before
  // `target_effective_from`, so moving it past days the materialise could not
  // score strands them at pending permanently — and the pass declines exactly
  // when the maps are untrustworthy, which is when it matters most. Leaving the
  // old anchor keeps those days inside the ordinary sweep's reach.
  // A DECLINED pass still moves the anchor, and that is the deliberate choice —
  // holding it back would leave already-materialised days reachable, and the
  // sweep re-derives those against the NEW target, rewriting correct history.
  // The cost is that days the pass could not score stay pending.
  test('a declined materialise still moves the anchor, because holding it '
      'would let the sweep rewrite correct history', () async {
    final store = _ThrowingLogsStore(
      seededGoals: [countGoal(count(3))],
      seededProgress: {
        key(metDay): {'g1': 3},
      },
    );
    final c = await container(store);

    await c
        .read(goalsProvider.notifier)
        .updateHabit(countGoal(count(3)).copyWith(target: count(10)));
    await settle();

    expect(
      c.read(goalsProvider).single.targetEffectiveFrom,
      today,
      reason: 'the anchor must move even on a decline: leaving it would expose '
          'every already-materialised earlier day to re-derivation against the '
          'NEW target, which is corruption rather than a stranding',
    );
    expect(c.read(goalsProvider).single.target?.amount, 10,
        reason: "the user's edit itself must still be saved");
  });

  test('a SETTLED materialise does move the anchor', () async {
    final store = _Store(
      seededGoals: [countGoal(count(3))],
      seededProgress: {
        key(metDay): {'g1': 3},
      },
    );
    final c = await container(store);

    await c
        .read(goalsProvider.notifier)
        .updateHabit(countGoal(count(3)).copyWith(target: count(10)));
    await settle();

    expect(c.read(goalsProvider).single.targetEffectiveFrom, today);
  });

  // Invariant 5, driven through the ONLY sequence that can violate it.
  //
  // Two earlier attempts at this test were worthless and it is worth recording
  // why. The first used a store whose logs always fail, so the materialise
  // declined and wrote nothing — green under both designs. The second let the
  // materialise SETTLE, in which case the anchor moves either way — also green
  // under both. The corruption needs BOTH halves: a pass that declines (so the
  // hold-back design would keep the old anchor) AND a later sweep that can read
  // the map (so it actually re-derives). A test that does not reproduce the
  // sequence cannot defend against it, and would have shipped the bug.
  test('an already-materialised day survives a target edit that declined, once '
      'the sweep runs again', () async {
    final store = _FlakyLogsStore(
      seededGoals: [countGoal(count(3))],
      seededProgress: {
        key(metDay): {'g1': 3}, // met the OLD target of 3
      },
      seededLogs: {
        key(metDay): {'g1': 'done'}, // and was scored for it
      },
    );
    final c = await container(store);

    // The edit lands while the verdict map cannot be read: the materialise
    // declines, and the anchor moves anyway (that is the whole argument).
    await c
        .read(goalsProvider.notifier)
        .updateHabit(countGoal(count(3)).copyWith(target: count(10)));
    await settle();

    // A healthy foreground: the map loads, and the ordinary sweep runs with the
    // habit now carrying 10.
    c.invalidate(habitLogsProvider);
    c.read(habitLogsProvider.notifier);
    await settle();
    store.logWrites.clear();
    await c.read(habitProgressProvider.notifier).reconcileManualTargets();
    await settle();

    expect(
      c.read(habitLogsProvider)[key(metDay)]?['g1'],
      'done',
      reason: '3 of 3 was a pass under the target in force that day. Re-scored '
          'against the new 10 it becomes `missed` — correct history turned '
          'wrong, with nothing to correct it because the new target is now '
          'authoritative',
    );
    expect(
      store.logWrites.where((w) => w['date'] == key(metDay)),
      isEmpty,
      reason: 'and it must not be rewritten at all, not merely rewritten to the '
          'same value',
    );
  });
}