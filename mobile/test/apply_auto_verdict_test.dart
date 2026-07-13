// Provider-level integration test for HabitLogsNotifier.applyAutoVerdict — the
// write path the auto-verification reconcile drives (GoalLogVerificationWriter →
// applyAutoVerdict). It was previously covered by inspection only (it mirrors
// the well-tested cycleStatus). Runs entirely in Private mode over a fake store,
// so Supabase is never initialised/touched.

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

/// Captures the args of every [setHabitLog] write so the test can assert the
/// status + measured value + streak that were persisted.
class _RecordingStore extends FakePrivateDataStore {
  final List<Map<String, Object?>> logWrites = <Map<String, Object?>>[];

  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int streak = 0,
    double? value,
  }) async {
    logWrites.add({
      'goalId': goalId,
      'date': date,
      'status': status,
      'streak': streak,
      'value': value,
    });
    await super.setHabitLog(
      goalId: goalId,
      date: date,
      status: status,
      streak: streak,
      value: value,
    );
  }
}

/// A store whose [setHabitLog] fails, to exercise the optimistic rollback.
class _ThrowingStore extends FakePrivateDataStore {
  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int streak = 0,
    double? value,
  }) async =>
      throw StateError('disk full');
}

Goal _verifiedGoal() => Goal(
      id: 'g1',
      title: 'Steps',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 6, 20),
      verificationRule: VerificationCatalog.steps.ruleWith(10000),
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

  // Let the notifiers' async _loadFromPrivateStore settle before driving writes.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('applyAutoVerdict persists done + measured value + a positive streak',
      () async {
    final store = _RecordingStore();
    final c = await container(store);
    c.read(goalsProvider.notifier);
    final logs = c.read(habitLogsProvider.notifier);
    await settle();
    await c.read(goalsProvider.notifier).addHabit(_verifiedGoal());

    await logs.applyAutoVerdict(
      goalId: 'g1',
      dateKey: '2026-06-24',
      status: 'done',
      value: 12043,
    );

    // In-memory state reflects the verdict...
    expect(c.read(habitLogsProvider)['2026-06-24']?['g1'], 'done');
    // ...and it was persisted locally with the measured value + status.
    final write =
        store.logWrites.lastWhere((w) => w['date'] == '2026-06-24');
    expect(write['status'], 'done');
    expect(write['value'], 12043);
    expect(write['streak'], greaterThan(0)); // a 'done' day builds a streak
  });

  test('applyAutoVerdict persists a missed verdict', () async {
    final store = _RecordingStore();
    final c = await container(store);
    c.read(goalsProvider.notifier);
    final logs = c.read(habitLogsProvider.notifier);
    await settle();

    await logs.applyAutoVerdict(
      goalId: 'g1',
      dateKey: '2026-06-24',
      status: 'missed',
      value: 4210,
    );

    expect(c.read(habitLogsProvider)['2026-06-24']?['g1'], 'missed');
    final write = store.logWrites.single;
    expect(write['status'], 'missed');
    expect(write['value'], 4210);
  });

  test('a persistence failure rolls back the optimistic in-memory update',
      () async {
    final c = await container(_ThrowingStore());
    final logs = c.read(habitLogsProvider.notifier);
    await settle();

    await logs.applyAutoVerdict(
      goalId: 'g1',
      dateKey: '2026-06-24',
      status: 'done',
      value: 12043,
    );

    // The write threw → the optimistic state must have been rolled back.
    expect(c.read(habitLogsProvider)['2026-06-24']?['g1'], isNull);
  });
}
