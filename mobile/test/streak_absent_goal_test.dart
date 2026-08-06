// Regression guard for the streak-corruption half of the empty-goals-window
// bug.
//
// `applyAutoVerdict`, `setDerivedStatus` and `cycleStatus` each recompute
// `goal_logs.streak` from a LIVE `ref.read(goalsProvider)` on every write. In
// Private mode `GoalsNotifier.build()` returns `[]` synchronously and
// `invalidatePrivateDataProviders` fires on every sync that applied a pulled
// change, so that read can resolve to null for a habit that plainly exists —
// mid-loop, long after the reconcile took its goals barrier.
//
// The old code substituted the written day for the habit's start date. That
// makes computeStreak's backward walk break on its first step
// (`if (cursor.isBefore(start)) break;`), so a 40-day streak was PERSISTED as 1
// into `goal_logs` — a synced table, propagated to every device, re-derived by
// nothing.
//
// The rule these tests pin: ABSENCE IS NOT EVIDENCE. The status is known and is
// written; the streak is not known and is left alone (null ⇒ preserve).
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

class _RecordingStore extends FakePrivateDataStore {
  final List<Map<String, Object?>> logWrites = <Map<String, Object?>>[];

  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int? streak,
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

Goal _habit() => Goal(
      id: 'g1',
      title: 'Steps',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 6, 1),
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

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Seeds a run of consecutive 'done' days directly into the logs notifier's
  /// state, so a correctly-computed streak would be well above 1 and a
  /// collapsed one is unmistakable.
  void seedRun(ProviderContainer c, int days) {
    final logs = <String, Map<String, String>>{};
    for (var i = 0; i < days; i++) {
      final d = DateTime(2026, 6, 1 + i);
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      logs[key] = {'g1': 'done'};
    }
    c.read(habitLogsProvider.notifier).state = logs;
  }

  group('applyAutoVerdict', () {
    test('preserves the stored streak when the verdict is UNCHANGED', () async {
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      final logs = c.read(habitLogsProvider.notifier);
      await settle();
      // Deliberately do NOT add the habit: this is the empty-goals window.
      // Day 10 is already 'done'; re-asserting 'done' does not move the run.
      seedRun(c, 10);

      await logs.applyAutoVerdict(
        goalId: 'g1',
        dateKey: '2026-06-10',
        status: 'done',
        value: 12043,
      );

      final write = store.logWrites.last;
      expect(write['status'], 'done',
          reason: 'the verdict IS known and must still be written');
      expect(write['streak'], isNull,
          reason: 'null ⇒ keep the stored run, which has not moved');
    });

    test('does NOT preserve a positive streak onto a flipped-to-missed day',
        () async {
      // The regression this guards: `goal_logs.streak` is SIGNED. Preserving a
      // +40 'done' run onto a day that just became 'missed' asserts a 40-day
      // fire run on a day the user missed — and private_analytics reads that
      // sign for current_streak and worst_streak. Sign-correct beats
      // magnitude-correct here.
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      final logs = c.read(habitLogsProvider.notifier);
      await settle();
      seedRun(c, 10);

      await logs.applyAutoVerdict(
        goalId: 'g1',
        dateKey: '2026-06-10',
        status: 'missed',
      );

      final write = store.logWrites.last;
      expect(write['status'], 'missed');
      expect(write['streak'], -1,
          reason: 'a flipped verdict must be written sign-consistently, never '
              'left holding the previous run\'s positive value');
    });

    test('a brand-new day writes the sign-consistent minimum', () async {
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      final logs = c.read(habitLogsProvider.notifier);
      await settle();
      seedRun(c, 10);

      // Day 11 has no stored verdict, so there is nothing to preserve.
      await logs.applyAutoVerdict(
        goalId: 'g1',
        dateKey: '2026-06-11',
        status: 'done',
      );

      expect(store.logWrites.last['streak'], 1);
    });

    test('still computes the real streak when the goal IS resolvable',
        () async {
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      final logs = c.read(habitLogsProvider.notifier);
      await settle();
      await c.read(goalsProvider.notifier).addHabit(_habit());
      seedRun(c, 10);

      await logs.applyAutoVerdict(
        goalId: 'g1',
        dateKey: '2026-06-10',
        status: 'done',
      );

      final write =
          store.logWrites.lastWhere((w) => w['date'] == '2026-06-10');
      expect(write['streak'], 10,
          reason: 'a resolvable goal must score the full run — this is the '
              'value the collapsed write used to replace with 1');
    });
  });

  group('setDerivedStatus', () {
    test('writes a sign-consistent streak when the goal cannot be resolved',
        () async {
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      final logs = c.read(habitLogsProvider.notifier);
      await settle();
      seedRun(c, 10);

      // This path early-returns when the status already matches, so every write
      // it makes IS a flip — the stored streak can never be preserved here.
      await logs.setDerivedStatus(
        goalId: 'g1',
        dateKey: '2026-06-10',
        status: 'missed',
      );

      expect(store.logWrites.last['streak'], -1);
    });

    test('a deleted day is a genuine zero, not an unknown', () async {
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      final logs = c.read(habitLogsProvider.notifier);
      await settle();
      seedRun(c, 3);

      // status null deletes the row; nothing is written, so nothing can be
      // fabricated. Pinned so the null-status branch is not confused with the
      // unknown-streak branch.
      await logs.setDerivedStatus(
        goalId: 'g1',
        dateKey: '2026-06-02',
        status: null,
      );

      expect(store.calls, contains('deleteHabitLog'));
      expect(store.logWrites.where((w) => w['date'] == '2026-06-02'), isEmpty);
    });
  });

  group('cycleStatus', () {
    test('writes a sign-consistent streak when the goal cannot be resolved',
        () async {
      final store = _RecordingStore();
      final c = await container(store);
      c.read(goalsProvider.notifier);
      final logs = c.read(habitLogsProvider.notifier);
      await settle();
      seedRun(c, 10);

      // Day 10 is 'done'; one tap cycles it to 'missed' — a flip.
      await logs.cycleStatus(DateTime(2026, 6, 10), 'g1');

      expect(store.logWrites, isNotEmpty);
      expect(store.logWrites.last['status'], 'missed');
      expect(store.logWrites.last['streak'], -1);
    });
  });

  group('unknownStreakFor', () {
    test('an unchanged verdict keeps the stored run', () {
      expect(
        unknownStreakFor(previousStatus: 'done', newStatus: 'done'),
        isNull,
      );
      expect(
        unknownStreakFor(previousStatus: 'missed', newStatus: 'missed'),
        isNull,
      );
    });

    test('a flipped verdict is written sign-consistently', () {
      expect(unknownStreakFor(previousStatus: 'done', newStatus: 'missed'), -1);
      expect(unknownStreakFor(previousStatus: 'missed', newStatus: 'done'), 1);
    });

    test('a brand-new day has nothing to preserve', () {
      expect(unknownStreakFor(previousStatus: null, newStatus: 'done'), 1);
      expect(unknownStreakFor(previousStatus: null, newStatus: 'missed'), -1);
    });

    test('a status with no signed run asserts none', () {
      // 'skipped' is allowed by the schema CHECK but belongs to neither run.
      expect(unknownStreakFor(previousStatus: 'done', newStatus: 'skipped'), 0);
    });
  });

  group('goalLogUpsertPayload', () {
    test('OMITS streak entirely when it is unknown', () {
      final payload = goalLogUpsertPayload(
        userId: 'u1',
        goalId: 'g1',
        dateKey: '2026-06-10',
        status: 'done',
        streak: null,
      );

      expect(payload.containsKey('streak'), isFalse,
          reason: 'PostgREST puts every present key into ON CONFLICT DO UPDATE '
              'SET, so an explicit null would assign SQL NULL and destroy the '
              'stored streak');
      expect(payload['status'], 'done');
      expect(payload['user_id'], 'u1');
    });

    test('includes streak when it is known, including zero', () {
      expect(
        goalLogUpsertPayload(
            userId: 'u1',
            goalId: 'g1',
            dateKey: '2026-06-10',
            status: 'done',
            streak: 5)['streak'],
        5,
      );
      expect(
        goalLogUpsertPayload(
            userId: 'u1',
            goalId: 'g1',
            dateKey: '2026-06-10',
            status: 'skipped',
            streak: 0),
        containsPair('streak', 0),
      );
      expect(
        goalLogUpsertPayload(
            userId: 'u1',
            goalId: 'g1',
            dateKey: '2026-06-10',
            status: 'missed',
            streak: -3)['streak'],
        -3,
      );
    });
  });

  group('resolveHabitLogStreak', () {
    test('a known streak is written as given', () {
      expect(resolveHabitLogStreak(7, 3), 7);
      expect(resolveHabitLogStreak(0, 3), 0,
          reason: 'an explicit 0 is a real value, not "unknown"');
      expect(resolveHabitLogStreak(-4, 9), -4);
    });

    test('an unknown streak preserves the stored one', () {
      expect(resolveHabitLogStreak(null, 12), 12);
      expect(resolveHabitLogStreak(null, -5), -5);
    });

    test('an unknown streak on a brand-new row takes the column default', () {
      expect(resolveHabitLogStreak(null, null), 0);
    });

    test('a NULL streak column reads as 0 rather than throwing', () {
      // The column is nullable in both schemas; a row written by an older build
      // can hold NULL.
      expect(resolveHabitLogStreak(null, null), 0);
    });
  });
}
