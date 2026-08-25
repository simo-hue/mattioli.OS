// Removing a habit that has history ARCHIVES it; only an empty one is deleted.
//
// `goal_logs.goal_id REFERENCES goals(id) ON DELETE CASCADE` (schema.sql), so
// the old unconditional delete destroyed every logged day the habit owned —
// years of tracking, irreversibly, behind a confirm dialog that named only the
// habit. The web client never did that (`useGoals.ts` soft-deletes a habit that
// still has logs), so the same tap gave opposite outcomes on the two clients.
//
// Archiving stamps `end_date` = YESTERDAY. Yesterday and not today because
// `Goal.isActiveOn` is INCLUSIVE of the end date: stamping today would leave the
// habit sitting in the manage sheet the user just removed it from. Every
// "what am I doing now" surface filters on that predicate, so the habit
// disappears from the list, the day card and the calendars — while the
// statistics picker (which reads the unfiltered list) still offers it and the
// past days it was live still draw it. Removed, not erased.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

/// Both delete paths cancel the habit's reminder, which reaches the plugin.
class _NoopNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

class _Store extends FakePrivateDataStore {
  _Store({
    required this.goals,
    required this.logs,
    this.progress = const {},
  });

  List<Goal> goals;
  Map<String, Map<String, String>> logs;
  Map<String, Map<String, double>> progress;
  final List<Goal> upserted = <Goal>[];
  final List<String> deleted = <String>[];

  @override
  Future<List<Goal>> loadGoals() async => goals;

  @override
  Future<Map<String, Map<String, String>>> loadHabitLogs() async => logs;

  @override
  Future<Map<String, Map<String, double>>> loadHabitProgress() async => progress;

  @override
  Future<void> upsertGoal(Goal goal) async {
    upserted.add(goal);
    await super.upsertGoal(goal);
  }

  @override
  Future<void> deleteGoal(String id) async {
    deleted.add(id);
    await super.deleteGoal(id);
  }
}

class _ThrowingArchiveStore extends _Store {
  _ThrowingArchiveStore({required super.goals, required super.logs});

  @override
  Future<void> upsertGoal(Goal goal) async => throw StateError('disk full');
}

/// The store cannot answer whether the habit has history. The point of the test
/// that uses it is that "unanswerable" must resolve to ARCHIVE.
class _UnreadableStore extends _Store {
  _UnreadableStore({required super.goals}) : super(logs: const {});

  @override
  Future<Map<String, Map<String, String>>> loadHabitLogs() async =>
      throw StateError('database locked');
}

Goal _goal(String id) => Goal(
      id: id,
      title: 'Habit $id',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
    );

/// Captured ONCE, at the start of each test, rather than recomputed at assert
/// time: a run that straddles midnight would otherwise compare the date the
/// code stamped against a different "yesterday" and fail for the calendar
/// rather than for the code.
late DateTime _yesterday;

DateTime _yesterdayNow() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    _yesterday = _yesterdayNow();
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<ProviderContainer> boot(_Store store) async {
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      privateLocalDatabaseProvider.overrideWith((ref) => store),
      initialGoalsProvider.overrideWithValue('[]'),
      initialLogsProvider.overrideWithValue('{}'),
    ]);
    addTearDown(container.dispose);
    await container.read(goalsProvider.notifier).ensureLoaded();
    return container;
  }

  test('a habit WITH history is archived, and its logs are never touched',
      () async {
    final store = _Store(
      goals: [_goal('a'), _goal('b')],
      logs: {
        '2026-03-01': {'a': 'done'},
        '2026-03-02': {'a': 'missed', 'b': 'done'},
      },
    );
    final container = await boot(store);

    await container.read(goalsProvider.notifier).deleteHabit('a');

    expect(store.deleted, isEmpty,
        reason: 'deleting the row would cascade its goal_logs away');
    expect(store.upserted.single.id, 'a');
    expect(store.upserted.single.endDate, _yesterday);

    final a = container.read(goalsProvider).firstWhere((g) => g.id == 'a');
    expect(a.endDate, _yesterday,
        reason: 'the habit stays in the list, carrying its end date — that is '
            'what keeps it selectable in the statistics picker');
    expect(a.isActiveOn(DateTime.now()), isFalse,
        reason: 'every "what am I doing now" surface filters on this, so the '
            'habit disappears from the manage sheet and the day card');
  });

  test('a habit with NO history is deleted outright', () async {
    // Nothing to preserve, so archiving would only leave an empty row that the
    // user can never see or reach again.
    final store = _Store(
      goals: [_goal('a'), _goal('b')],
      logs: {
        '2026-03-02': {'b': 'done'},
      },
    );
    final container = await boot(store);

    await container.read(goalsProvider.notifier).deleteHabit('a');

    expect(store.deleted, ['a']);
    expect(store.upserted, isEmpty);
    expect(container.read(goalsProvider).map((g) => g.id), ['b']);
  });

  test('progress alone counts as history — goal_progress cascades too',
      () async {
    // `goal_progress.goal_id` references `goals(id) ON DELETE CASCADE` just as
    // `goal_logs` does, and a quantitative habit can accumulate progress with no
    // verdict row at all: a partially-met target scores `pending`, which stores
    // the amount and DELETES the verdict. A non-daily target never gets swept at
    // all. So "run 50 km a month", logged 5 km a day for six months and never
    // completed, has ~120 progress rows and ZERO logs — and asking only about
    // logs would call that "no history" and destroy every kilometre.
    final store = _Store(
      goals: [_goal('a')],
      logs: const {},
      progress: {
        '2026-03-01': {'a': 5.0},
        '2026-03-02': {'a': 4.2},
      },
    );
    final container = await boot(store);

    await container.read(goalsProvider.notifier).deleteHabit('a');

    expect(store.deleted, isEmpty,
        reason: 'the cascade would take goal_progress with the row');
    expect(store.upserted.single.endDate, _yesterday);
  });

  test('an unanswerable history probe archives rather than guessing', () async {
    // The highest-stakes line in the change. If the store cannot say whether
    // there is history, the only safe reading is "there might be" — guessing
    // "no" hard-deletes, and the cascade makes that unrecoverable.
    final store = _UnreadableStore(goals: [_goal('a')]);
    final container = await boot(store);

    await container.read(goalsProvider.notifier).deleteHabit('a');

    expect(store.deleted, isEmpty);
    expect(store.upserted.single.endDate, _yesterday);
  });

  test('the habit disappears immediately, before the probe resolves', () async {
    // The call site does not await this, and both outcomes hide the habit, so
    // the end date is stamped up front. Probing first left a confirmed delete
    // visibly doing nothing for two network round trips.
    final store = _Store(
      goals: [_goal('a')],
      logs: {
        '2026-03-01': {'a': 'done'},
      },
    );
    final container = await boot(store);

    final pending = container.read(goalsProvider.notifier).deleteHabit('a');

    // NOT awaited yet — this is the frame the user sees on confirm.
    expect(container.read(goalsProvider).single.isActiveOn(DateTime.now()),
        isFalse,
        reason: 'the row must be gone from every active surface on the frame '
            'after the tap, not one network round trip later');
    await pending;
  });

  test('a failed archive rolls the habit back rather than half-removing it',
      () async {
    final store = _ThrowingArchiveStore(
      goals: [_goal('a')],
      logs: {
        '2026-03-01': {'a': 'done'},
      },
    );
    final container = await boot(store);

    await container.read(goalsProvider.notifier).deleteHabit('a');

    final a = container.read(goalsProvider).single;
    expect(a.id, 'a');
    expect(a.endDate, isNull,
        reason: 'the optimistic archive must not survive a failed write, or the '
            'habit vanishes from the UI while the store still has it live');
  });
}
