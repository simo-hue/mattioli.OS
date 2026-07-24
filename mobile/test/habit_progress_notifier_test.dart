// Provider-level test for HabitProgressNotifier.setProgress — the write path the
// increment/timer UI drives. It persists the day's number to goal_progress AND
// moves the verdict (goal_logs) to match via HabitLogsNotifier.setDerivedStatus.
// Runs in Private mode over a fake store, so Supabase is never touched.

import 'package:evolve_targets/evolve_targets.dart';
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
  final List<Map<String, Object?>> progressWrites = [];
  final List<Map<String, Object?>> progressDeletes = [];
  final List<Map<String, Object?>> logWrites = [];
  final List<Map<String, Object?>> logDeletes = [];

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
    final todayKey = '2026-07-24';
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

    final todayKey = '2026-07-24';
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

  group('reconcileManualTargets (end-of-day sweep)', () {
    // A limit habit that started a few days ago and was never touched: its quiet
    // past days must be materialised into 'done', its today left pending.
    test('materialises a limit habit\'s quiet closed days as done', () async {
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();
      await c.read(goalsProvider.notifier).addHabit(
            _limitGoal().copyWith(startDate: DateTime(2026, 7, 21)),
          );

      await progress.reconcileManualTargets(now: now);

      final logs = c.read(habitLogsProvider);
      // 21, 22, 23 closed & quiet → done; 24 (today) untouched → pending.
      expect(logs['2026-07-21']?['g2'], 'done');
      expect(logs['2026-07-22']?['g2'], 'done');
      expect(logs['2026-07-23']?['g2'], 'done');
      expect(logs['2026-07-24']?['g2'], isNull);
    });

    test('is idempotent — a second pass writes nothing new', () async {
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();
      await c.read(goalsProvider.notifier).addHabit(
            _limitGoal().copyWith(startDate: DateTime(2026, 7, 22)),
          );

      await progress.reconcileManualTargets(now: now);
      final writesAfterFirst = store.logWrites.length;
      await progress.reconcileManualTargets(now: now);

      expect(store.logWrites.length, writesAfterFirst,
          reason: 'the second sweep must be a no-op');
    });

    test('does not invent misses for an untouched count habit', () async {
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();
      await c.read(goalsProvider.notifier).addHabit(
            _countGoal().copyWith(startDate: DateTime(2026, 7, 20)),
          );

      await progress.reconcileManualTargets(now: now);

      // An atLeast habit the user never touched stays absent — like a checkbox.
      expect(store.logWrites, isEmpty);
      expect(c.read(habitLogsProvider)['2026-07-22']?['g1'], isNull);
    });

    test('resolves a partial count day left pending into a miss', () async {
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      c.read(habitLogsProvider.notifier);
      final progress = c.read(habitProgressProvider.notifier);
      await settle();
      await c.read(goalsProvider.notifier).addHabit(
            _countGoal().copyWith(startDate: DateTime(2026, 7, 20)),
          );
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
  });
}
