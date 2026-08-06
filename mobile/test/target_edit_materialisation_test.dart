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
}
