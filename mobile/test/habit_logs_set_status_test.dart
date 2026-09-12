// HabitLogsNotifier.setStatus and recomputeStreaksForHabits — the two writes
// behind the day sheet's Save on a past day. Provider-level, over the fake
// private store, so Supabase is never touched.
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
  final List<String> logDeletes = <String>[];

  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int? streak,
    double? value,
  }) async {
    logWrites.add({'goalId': goalId, 'date': date, 'status': status, 'streak': streak});
    await super.setHabitLog(
      goalId: goalId,
      date: date,
      status: status,
      streak: streak,
      value: value,
    );
  }

  @override
  Future<void> deleteHabitLog({
    required String goalId,
    required String date,
  }) async {
    logDeletes.add('$goalId@$date');
    await super.deleteHabitLog(goalId: goalId, date: date);
  }
}

class _ThrowingStore extends _RecordingStore {
  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int? streak,
    double? value,
  }) async =>
      throw StateError('disk full');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final day = DateTime(2026, 8, 3);
  const dateKey = '2026-08-03';

  Goal goal() => Goal(
        id: 'g1',
        title: 'Read',
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 6, 20),
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

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
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier);
    await settle();
    await c.read(goalsProvider.notifier).addHabit(goal());
    await settle();
    return c;
  }

  test('nextManualStatus is the cycle a tap performs', () {
    expect(nextManualStatus(null), 'done');
    expect(nextManualStatus('done'), 'missed');
    expect(nextManualStatus('missed'), isNull);
  });

  test('setStatus writes the given status directly, not the next in the cycle',
      () async {
    final store = _RecordingStore();
    final c = await container(store);
    final logs = c.read(habitLogsProvider.notifier);

    expect(await logs.setStatus(day, 'g1', 'missed'), isTrue);
    await settle();
    expect(c.read(habitLogsProvider)[dateKey]?['g1'], 'missed');
    expect(store.logWrites.single['status'], 'missed');
    expect(store.logWrites.single['streak'], -1,
        reason: 'a lone missed day is a run of one, signed negative');
  });

  test('setStatus with the persisted status is a true no-op', () async {
    final store = _RecordingStore();
    final c = await container(store);
    final logs = c.read(habitLogsProvider.notifier);
    await logs.setStatus(day, 'g1', 'done');
    await settle();
    store.logWrites.clear();

    expect(await logs.setStatus(day, 'g1', 'done'), isTrue);
    await settle();
    expect(store.logWrites, isEmpty);
    expect(store.logDeletes, isEmpty);
  });

  test('setStatus(null) deletes the row', () async {
    final store = _RecordingStore();
    final c = await container(store);
    final logs = c.read(habitLogsProvider.notifier);
    await logs.setStatus(day, 'g1', 'done');
    await settle();

    expect(await logs.setStatus(day, 'g1', null), isTrue);
    await settle();
    expect(c.read(habitLogsProvider)[dateKey]?['g1'], isNull);
    expect(store.logDeletes, ['g1@$dateKey']);
  });

  test('a write that does not land answers false and rolls back', () async {
    final store = _ThrowingStore();
    final c = await container(store);
    final logs = c.read(habitLogsProvider.notifier);

    expect(await logs.setStatus(day, 'g1', 'done'), isFalse);
    await settle();
    expect(c.read(habitLogsProvider)[dateKey]?['g1'], isNull);
  });

  test('recomputeStreaksForHabits hands the changed habits to the store in '
      'Private mode, and skips an empty set', () async {
    final store = _RecordingStore();
    final c = await container(store);
    final logs = c.read(habitLogsProvider.notifier);

    await logs.recomputeStreaksForHabits(const {});
    expect(store.streakRecomputes, isEmpty);

    await logs.recomputeStreaksForHabits({'g1'});
    expect(store.streakRecomputes, [
      {'g1'},
    ]);
  });
}
