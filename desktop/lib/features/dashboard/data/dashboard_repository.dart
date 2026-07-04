import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/secure_storage_utils.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/private_dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class DashboardRepository {
  bool get isCloudBacked => false;

  DashboardSnapshot load();

  Future<DashboardSnapshot> refresh() async => load();

  Future<void> save(DashboardSnapshot snapshot);

  Future<DashboardHabit> createHabit(DashboardHabit habit) async => habit;

  Future<void> updateHabit(DashboardHabit habit) async {}

  Future<void> deleteHabit(String id) async {}

  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    return switch (currentStatus) {
      null => 'done',
      'done' => 'missed',
      _ => null,
    };
  }

  Future<void> saveCheckIn(DateTime date, DailyCheckIn checkIn) async {}

  Future<DashboardGoal> createGoal(DashboardGoal goal) async => goal;

  Future<void> updateGoal(DashboardGoal goal) async {}

  Future<void> deleteGoal(String id) async {}

  Future<void> resetData() async {
    await save(DashboardSnapshot.empty);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final dataMode = ref.watch(activeDesktopDataModeProvider);

  if (dataMode.isPrivate) {
    // Private mode: use the local encrypted database.
    // The owner ID is resolved asynchronously on first refresh; we provide a
    // placeholder here that PrivateDashboardRepository will replace.
    return _PrivateRepositoryProxy();
  }

  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(
    desktopAuthControllerProvider.select((state) => state.user?.id),
  );
  if (client == null || userId == null) {
    return UnavailableDashboardRepository();
  }
  return SupabaseDashboardRepository(client: client, userId: userId);
});

/// A proxy that resolves the private owner ID lazily.  The provider is
/// synchronous so we cannot `await` during construction; instead the
/// first call to [refresh] bootstraps the real repository.
class _PrivateRepositoryProxy extends DashboardRepository {
  PrivateDashboardRepository? _inner;

  @override
  DashboardSnapshot load() => _inner?.load() ?? DashboardSnapshot.empty;

  @override
  Future<DashboardSnapshot> refresh() async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    return _inner!.refresh();
  }

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.save(snapshot);
  }

  @override
  Future<DashboardHabit> createHabit(DashboardHabit habit) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    return _inner!.createHabit(habit);
  }

  @override
  Future<void> updateHabit(DashboardHabit habit) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.updateHabit(habit);
  }

  @override
  Future<void> deleteHabit(String id) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.deleteHabit(id);
  }

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    return _inner!.setHabitStatus(
      habitId: habitId,
      date: date,
      currentStatus: currentStatus,
    );
  }

  @override
  Future<void> saveCheckIn(DateTime date, DailyCheckIn checkIn) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.saveCheckIn(date, checkIn);
  }

  @override
  Future<DashboardGoal> createGoal(DashboardGoal goal) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    return _inner!.createGoal(goal);
  }

  @override
  Future<void> updateGoal(DashboardGoal goal) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.updateGoal(goal);
  }

  @override
  Future<void> deleteGoal(String id) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.deleteGoal(id);
  }

  @override
  Future<void> resetData() async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.resetData();
  }
}

class UnavailableDashboardRepository extends DashboardRepository {
  @override
  DashboardSnapshot load() => DashboardSnapshot.empty;

  @override
  Future<DashboardSnapshot> refresh() async => DashboardSnapshot.empty;

  @override
  Future<void> save(DashboardSnapshot snapshot) => _requireSession();

  @override
  Future<DashboardHabit> createHabit(DashboardHabit habit) => _requireSession();

  @override
  Future<void> updateHabit(DashboardHabit habit) => _requireSession();

  @override
  Future<void> deleteHabit(String id) => _requireSession();

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) => _requireSession();

  @override
  Future<void> saveCheckIn(DateTime date, DailyCheckIn checkIn) =>
      _requireSession();

  @override
  Future<DashboardGoal> createGoal(DashboardGoal goal) => _requireSession();

  @override
  Future<void> updateGoal(DashboardGoal goal) => _requireSession();

  @override
  Future<void> deleteGoal(String id) => _requireSession();

  @override
  Future<void> resetData() => _requireSession();

  Future<T> _requireSession<T>() {
    throw StateError('An authenticated Supabase session is required.');
  }
}

class SupabaseDashboardRepository extends DashboardRepository {
  SupabaseDashboardRepository({required SupabaseClient client, required userId})
    : _client = client,
      _userId = userId;

  final SupabaseClient _client;
  final String _userId;
  DashboardSnapshot _snapshot = DashboardSnapshot.empty;

  String get _cacheKey => 'desktop_dashboard_cache_$_userId';
  String get _pendingKey => 'desktop_dashboard_pending_$_userId';

  @override
  bool get isCloudBacked => true;

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<DashboardSnapshot> refresh() async {
    final cached = await _readCache();
    if (cached != null) _snapshot = cached;

    try {
      await _flushPendingMutations();
      final responses = await Future.wait([
        _client
            .from('goals')
            .select()
            .eq('user_id', _userId)
            .order('display_order', ascending: true)
            .order('created_at', ascending: true),
        _client.from('goal_logs').select().eq('user_id', _userId),
        _client
            .from('long_term_goals')
            .select()
            .eq('user_id', _userId)
            .order('created_at', ascending: true),
        _client.from('daily_moods').select().eq('user_id', _userId),
      ]);
      _snapshot = _fromRemote(
        habitRows: _rows(responses[0]),
        logRows: _rows(responses[1]),
        goalRows: _rows(responses[2]),
        moodRows: _rows(responses[3]),
      );
      await _writeCache(_snapshot);
      return _snapshot;
    } catch (error, stack) {
      AppLogger.error('Unable to refresh the desktop dashboard', error, stack);
      Error.throwWithStackTrace(
        DashboardRefreshException(cachedSnapshot: cached, cause: error),
        stack,
      );
    }
  }

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
    await _writeCache(snapshot);
  }

  @override
  Future<DashboardHabit> createHabit(DashboardHabit habit) async {
    final payload = habit.toRemoteJson()..['user_id'] = _userId;
    final row = await _runOrQueue(
      _PendingMutation.insert('goals', payload),
      () => _client.from('goals').insert(payload).select().single(),
    );
    return DashboardHabit.fromRemoteJson(
      Map<String, dynamic>.from(row),
      weeklyProgress: habit.weeklyProgress,
      state: habit.state,
      streak: habit.streak,
    );
  }

  @override
  Future<void> updateHabit(DashboardHabit habit) async {
    final payload = habit.toRemoteJson()..remove('id');
    await _runOrQueue(
      _PendingMutation.update('goals', payload, {'id': habit.id}),
      () => _client.from('goals').update(payload).eq('id', habit.id),
    );
  }

  @override
  Future<void> deleteHabit(String id) async {
    await _runOrQueue(
      _PendingMutation.delete('goals', {'id': id}),
      () => _client.from('goals').delete().eq('id', id),
    );
  }

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    final nextStatus = await super.setHabitStatus(
      habitId: habitId,
      date: date,
      currentStatus: currentStatus,
    );
    final dateKey = dashboardDateKey(date);
    if (nextStatus == null) {
      final filters = {'user_id': _userId, 'goal_id': habitId, 'date': dateKey};
      await _runOrQueue(
        _PendingMutation.delete('goal_logs', filters),
        () => _client
            .from('goal_logs')
            .delete()
            .eq('user_id', _userId)
            .eq('goal_id', habitId)
            .eq('date', dateKey),
      );
      return null;
    }

    final payload = {
      'user_id': _userId,
      'goal_id': habitId,
      'date': dateKey,
      'status': nextStatus,
      'streak': _nextStreak(habitId, date, nextStatus),
    };
    await _runOrQueue(
      _PendingMutation.upsert('goal_logs', payload, onConflict: 'goal_id,date'),
      () =>
          _client.from('goal_logs').upsert(payload, onConflict: 'goal_id,date'),
    );
    return nextStatus;
  }

  @override
  Future<void> saveCheckIn(DateTime date, DailyCheckIn checkIn) async {
    final payload = {
      'user_id': _userId,
      'date': dashboardDateKey(date),
      'mood_score': checkIn.mood,
      'energy_score': checkIn.energy,
    };
    await _runOrQueue(
      _PendingMutation.upsert(
        'daily_moods',
        payload,
        onConflict: 'user_id,date',
      ),
      () => _client
          .from('daily_moods')
          .upsert(payload, onConflict: 'user_id,date'),
    );
  }

  @override
  Future<DashboardGoal> createGoal(DashboardGoal goal) async {
    final payload = goal.toRemoteJson()..['user_id'] = _userId;
    final row = await _runOrQueue(
      _PendingMutation.insert('long_term_goals', payload),
      () => _client.from('long_term_goals').insert(payload).select().single(),
    );
    return DashboardGoal.fromRemoteJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> updateGoal(DashboardGoal goal) async {
    final payload = goal.toRemoteJson()..remove('id');
    await _runOrQueue(
      _PendingMutation.update('long_term_goals', payload, {'id': goal.id}),
      () => _client.from('long_term_goals').update(payload).eq('id', goal.id),
    );
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _runOrQueue(
      _PendingMutation.delete('long_term_goals', {'id': id}),
      () => _client.from('long_term_goals').delete().eq('id', id),
    );
  }

  @override
  Future<void> resetData() async {
    await _client.from('goals').delete().eq('user_id', _userId);
    await _client.from('long_term_goals').delete().eq('user_id', _userId);
    _snapshot = DashboardSnapshot.empty;
    await SecureStorageUtils.delete(_cacheKey);
    await SecureStorageUtils.delete(_pendingKey);
  }

  Future<T> _runOrQueue<T>(
    _PendingMutation mutation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (error, stack) {
      if (_isRetryable(error)) {
        await _enqueue(mutation);
      }
      AppLogger.error(
        'Unable to sync ${mutation.operation} on ${mutation.table}',
        error,
        stack,
      );
      rethrow;
    }
  }

  Future<void> _flushPendingMutations() async {
    final pending = await _readPendingMutations();
    if (pending.isEmpty) return;

    final remaining = <_PendingMutation>[];
    Object? replayError;
    StackTrace? replayStack;
    for (var index = 0; index < pending.length; index++) {
      final mutation = pending[index];
      try {
        await _applyPending(mutation);
      } catch (error, stack) {
        AppLogger.error(
          'Unable to replay ${mutation.operation} on ${mutation.table}',
          error,
          stack,
        );
        remaining.addAll(pending.skip(index));
        replayError = error;
        replayStack = stack;
        break;
      }
    }
    await _writePendingMutations(remaining);
    if (replayError != null) {
      Error.throwWithStackTrace(replayError, replayStack!);
    }
  }

  Future<void> _applyPending(_PendingMutation mutation) async {
    switch (mutation.operation) {
      case 'insert':
        // A failed response does not prove the insert failed server-side.
        // Replaying it as an upsert keeps the mutation idempotent.
        await _client.from(mutation.table).upsert(mutation.payload);
        return;
      case 'update':
        var query = _client.from(mutation.table).update(mutation.payload);
        for (final filter in mutation.filters.entries) {
          query = query.eq(filter.key, filter.value);
        }
        await query;
        return;
      case 'delete':
        var query = _client.from(mutation.table).delete();
        for (final filter in mutation.filters.entries) {
          query = query.eq(filter.key, filter.value);
        }
        await query;
        return;
      case 'upsert':
        await _client
            .from(mutation.table)
            .upsert(mutation.payload, onConflict: mutation.onConflict);
        return;
      default:
        throw FormatException(
          'Unsupported pending dashboard mutation: ${mutation.operation}',
        );
    }
  }

  Future<List<_PendingMutation>> _readPendingMutations() async {
    final encoded = await SecureStorageUtils.read(_pendingKey);
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .map((item) => _PendingMutation.fromJson(item as Map))
        .toList();
  }

  Future<void> _enqueue(_PendingMutation mutation) async {
    final pending = await _readPendingMutations();
    if (pending.any((item) => item.fingerprint == mutation.fingerprint)) {
      return;
    }
    await _writePendingMutations([...pending, mutation]);
  }

  Future<void> _writePendingMutations(List<_PendingMutation> mutations) async {
    if (mutations.isEmpty) {
      await SecureStorageUtils.delete(_pendingKey);
      return;
    }
    await SecureStorageUtils.write(
      _pendingKey,
      jsonEncode([for (final mutation in mutations) mutation.toJson()]),
      context: 'SupabaseDashboardRepository pending mutations',
    );
  }

  bool _isRetryable(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('clientexception') ||
        message.contains('connection closed') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('network request failed') ||
        message.contains('socketexception') ||
        message.contains('timed out') ||
        message.contains('timeout');
  }

  DashboardSnapshot _fromRemote({
    required List<Map<String, dynamic>> habitRows,
    required List<Map<String, dynamic>> logRows,
    required List<Map<String, dynamic>> goalRows,
    required List<Map<String, dynamic>> moodRows,
  }) {
    final logs = <String, Map<String, String>>{};
    for (final row in logRows) {
      final date = row['date'] as String;
      final goalId = row['goal_id'] as String;
      logs.putIfAbsent(date, () => {})[goalId] = row['status'] as String;
    }

    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final habits = [
      for (final row in habitRows)
        DashboardHabit.fromRemoteJson(
          row,
          weeklyProgress: [
            for (var day = 0; day < 7; day++)
              logs[dashboardDateKey(
                    monday.add(Duration(days: day)),
                  )]?[row['id']] ==
                  'done',
          ],
          state: logs[dashboardDateKey(now)]?[row['id']] == 'done'
              ? HabitState.completed
              : HabitState.pending,
          streak: _latestStreak(row['id'] as String, logRows),
        ),
    ];
    final moods = <String, DailyCheckIn>{};
    for (final row in moodRows) {
      moods[row['date'] as String] = DailyCheckIn(
        mood: row['mood_score'] as int?,
        energy: row['energy_score'] as int?,
      );
    }
    final temporary = DashboardSnapshot(
      habits: habits,
      goals: goalRows.map(DashboardGoal.fromRemoteJson).toList(),
      trend: const [],
      checkIn: moods[dashboardDateKey(now)] ?? const DailyCheckIn(),
      habitLogs: logs,
      moods: moods,
    );
    return temporary.copyWith(
      trend: [
        for (var day = 0; day < 7; day++)
          TrendPoint(
            label: const ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'][day],
            value: temporary.completionFor(monday.add(Duration(days: day))),
          ),
      ],
    );
  }

  int _latestStreak(String habitId, List<Map<String, dynamic>> rows) {
    final matches = rows.where((row) => row['goal_id'] == habitId).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return matches.isEmpty ? 0 : (matches.first['streak'] as int? ?? 0);
  }

  int _nextStreak(String habitId, DateTime date, String nextStatus) {
    final previousDate = dashboardDateKey(
      DateTime(
        date.year,
        date.month,
        date.day,
      ).subtract(const Duration(days: 1)),
    );
    final previousStatus = _snapshot.habitLogs[previousDate]?[habitId];
    final previous = _snapshot.habits
        .where((habit) => habit.id == habitId)
        .map((habit) => habit.streak)
        .firstOrNull;
    if (nextStatus == 'done') {
      return previousStatus == 'done' ? (previous ?? 0) + 1 : 1;
    }
    return previous != null && previous > 0 ? -1 : (previous ?? 0) - 1;
  }

  List<Map<String, dynamic>> _rows(dynamic response) {
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<DashboardSnapshot?> _readCache() async {
    try {
      final encoded = await SecureStorageUtils.read(_cacheKey);
      if (encoded == null) return null;
      return _fromCache(Map<String, dynamic>.from(jsonDecode(encoded) as Map));
    } catch (error, stack) {
      AppLogger.error(
        'Unable to read the desktop dashboard cache',
        error,
        stack,
      );
      return null;
    }
  }

  Future<void> _writeCache(DashboardSnapshot snapshot) async {
    await SecureStorageUtils.write(
      _cacheKey,
      jsonEncode(_toCache(snapshot)),
      context: 'SupabaseDashboardRepository cache',
    );
  }

  Map<String, dynamic> _toCache(DashboardSnapshot snapshot) => {
    'habits': [
      for (final habit in snapshot.habits)
        {
          ...habit.toRemoteJson(),
          'category': habit.category,
          'streak': habit.streak,
          'weekly_progress': habit.weeklyProgress,
          'state': habit.state.name,
        },
    ],
    'goals': [for (final goal in snapshot.goals) goal.toRemoteJson()],
    'trend': [
      for (final point in snapshot.trend)
        {'label': point.label, 'value': point.value},
    ],
    'check_in': snapshot.checkIn.toJson(),
    'habit_logs': snapshot.habitLogs,
    'moods': {
      for (final mood in snapshot.moods.entries) mood.key: mood.value.toJson(),
    },
  };

  DashboardSnapshot _fromCache(Map<String, dynamic> json) {
    final habits = (json['habits'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .map(
          (row) => DashboardHabit.fromRemoteJson(
            row,
            weeklyProgress: (row['weekly_progress'] as List<dynamic>)
                .map((value) => value as bool)
                .toList(),
            state: HabitState.values.byName(row['state'] as String),
            streak: row['streak'] as int,
          ),
        )
        .toList();
    final logs = <String, Map<String, String>>{
      for (final entry in Map<String, dynamic>.from(
        json['habit_logs'] as Map,
      ).entries)
        entry.key: Map<String, String>.from(entry.value as Map),
    };
    final moods = <String, DailyCheckIn>{
      for (final entry in Map<String, dynamic>.from(
        json['moods'] as Map,
      ).entries)
        entry.key: DailyCheckIn.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    };
    return DashboardSnapshot(
      habits: habits,
      goals: (json['goals'] as List<dynamic>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .map(DashboardGoal.fromRemoteJson)
          .toList(),
      trend: (json['trend'] as List<dynamic>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .map(
            (row) => TrendPoint(
              label: row['label'] as String,
              value: (row['value'] as num).toDouble(),
            ),
          )
          .toList(),
      checkIn: DailyCheckIn.fromJson(
        Map<String, dynamic>.from(json['check_in'] as Map),
      ),
      habitLogs: logs,
      moods: moods,
    );
  }
}

class DashboardRefreshException implements Exception {
  const DashboardRefreshException({
    required this.cachedSnapshot,
    required this.cause,
  });

  final DashboardSnapshot? cachedSnapshot;
  final Object cause;

  @override
  String toString() => 'Dashboard refresh failed: $cause';
}

class _PendingMutation {
  const _PendingMutation({
    required this.operation,
    required this.table,
    required this.payload,
    required this.filters,
    this.onConflict,
  });

  factory _PendingMutation.insert(String table, Map<String, dynamic> payload) {
    return _PendingMutation(
      operation: 'insert',
      table: table,
      payload: payload,
      filters: const {},
    );
  }

  factory _PendingMutation.update(
    String table,
    Map<String, dynamic> payload,
    Map<String, dynamic> filters,
  ) {
    return _PendingMutation(
      operation: 'update',
      table: table,
      payload: payload,
      filters: filters,
    );
  }

  factory _PendingMutation.delete(String table, Map<String, dynamic> filters) {
    return _PendingMutation(
      operation: 'delete',
      table: table,
      payload: const {},
      filters: filters,
    );
  }

  factory _PendingMutation.upsert(
    String table,
    Map<String, dynamic> payload, {
    required String onConflict,
  }) {
    return _PendingMutation(
      operation: 'upsert',
      table: table,
      payload: payload,
      filters: const {},
      onConflict: onConflict,
    );
  }

  factory _PendingMutation.fromJson(Map<dynamic, dynamic> json) {
    return _PendingMutation(
      operation: json['operation'] as String,
      table: json['table'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      filters: Map<String, dynamic>.from(json['filters'] as Map),
      onConflict: json['on_conflict'] as String?,
    );
  }

  final String operation;
  final String table;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> filters;
  final String? onConflict;

  String get fingerprint => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
    'operation': operation,
    'table': table,
    'payload': payload,
    'filters': filters,
    if (onConflict != null) 'on_conflict': onConflict,
  };
}
