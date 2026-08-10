import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'retryable cloud mutation remains queued while the network is down',
    () async {
      final secureValues = <String, String>{};
      FlutterSecureStorage.setMockInitialValues(secureValues);
      final repository = SupabaseDashboardRepository(
        client: SupabaseClient(
          'http://127.0.0.1:9',
          'test-publishable-key',
          httpClient: _OfflineHttpClient(),
        ),
        userId: 'user-id',
      );
      final habit = DashboardHabit(
        id: 'd710cf5c-45f7-4eb9-af81-a344c7f2546f',
        title: 'Lettura serale',
        color: EvolveColors.violet,
        streak: 0,
        weeklyProgress: const [false, false, false, false, false, false, false],
        state: HabitState.pending,
      );

      await expectLater(repository.createHabit(habit), throwsA(anything));

      final key = 'desktop_dashboard_pending_user-id';
      var queued = jsonDecode(secureValues[key]!) as List<dynamic>;
      expect(queued, hasLength(1));
      expect((queued.single as Map<String, dynamic>)['operation'], 'insert');
      expect((queued.single as Map<String, dynamic>)['table'], 'goals');

      await expectLater(repository.refresh(), throwsA(anything));

      queued = jsonDecode(secureValues[key]!) as List<dynamic>;
      expect(queued, hasLength(1));
    },
  );

  // The `streak` column persisted by the cloud repository must be the SAME
  // number the controller already computed and displayed for that day — the
  // shared `computeStreak`. The queued mutation is the payload that would have
  // gone to Supabase, so asserting on it is asserting on the write itself.
  group('cloud setHabitStatus persists computeStreak', () {
    late Map<String, String> secureValues;
    late SupabaseDashboardRepository repository;

    setUp(() {
      secureValues = <String, String>{};
      FlutterSecureStorage.setMockInitialValues(secureValues);
      repository = SupabaseDashboardRepository(
        client: SupabaseClient(
          'http://127.0.0.1:9',
          'test-publishable-key',
          httpClient: _OfflineHttpClient(),
        ),
        userId: 'user-id',
      );
    });

    DashboardHabit habitWith({List<int>? frequencyDays, required int streak}) {
      return DashboardHabit(
        id: 'habit-id',
        title: 'Lettura serale',
        color: EvolveColors.violet,
        streak: streak,
        weeklyProgress: const [false, false, false, false, false, false, false],
        state: HabitState.pending,
        startDate: DateTime(2026, 8, 3), // Monday
        frequencyDays: frequencyDays,
      );
    }

    Future<Map<String, dynamic>> queuedGoalLogPayload() async {
      final queued =
          jsonDecode(secureValues['desktop_dashboard_pending_user-id']!)
              as List<dynamic>;
      final upsert = queued
          .cast<Map<String, dynamic>>()
          .lastWhere((item) => item['table'] == 'goal_logs');
      return Map<String, dynamic>.from(upsert['payload'] as Map);
    }

    test('does not re-increment the streak the controller already stored',
        () async {
      // Mon + Tue done, Wed toggled: the controller has ALREADY written the new
      // streak (3) into the snapshot before the repository runs, so carrying the
      // snapshot value forward would store 4 for a 3-day run.
      await repository.save(
        DashboardSnapshot(
          habits: [habitWith(streak: 3)],
          goals: const [],
          trend: const [],
          checkIn: const DailyCheckIn(),
          habitLogs: {
            '2026-08-03': const {'habit-id': 'done'},
            '2026-08-04': const {'habit-id': 'done'},
            '2026-08-05': const {'habit-id': 'done'},
          },
        ),
      );

      await expectLater(
        repository.setHabitStatus(
          habitId: 'habit-id',
          date: DateTime(2026, 8, 5), // Wednesday
          currentStatus: null,
        ),
        throwsA(anything),
      );

      expect((await queuedGoalLogPayload())['streak'], 3);
    });

    test('honors frequency_days instead of looking at calendar-yesterday',
        () async {
      // Mon/Wed/Fri habit done Monday, marked done Wednesday: Tuesday is not
      // scheduled, so it is transparent and the streak is 2 — reading only the
      // calendar-previous day would reset it to 1.
      await repository.save(
        DashboardSnapshot(
          habits: [habitWith(frequencyDays: const [1, 3, 5], streak: 2)],
          goals: const [],
          trend: const [],
          checkIn: const DailyCheckIn(),
          habitLogs: {
            '2026-08-03': const {'habit-id': 'done'},
            '2026-08-05': const {'habit-id': 'done'},
          },
        ),
      );

      await expectLater(
        repository.setHabitStatus(
          habitId: 'habit-id',
          date: DateTime(2026, 8, 5), // Wednesday
          currentStatus: null,
        ),
        throwsA(anything),
      );

      expect((await queuedGoalLogPayload())['streak'], 2);
    });

    test('a first missed day is stored as -1, not carried further down',
        () async {
      await repository.save(
        DashboardSnapshot(
          habits: [habitWith(streak: -1)],
          goals: const [],
          trend: const [],
          checkIn: const DailyCheckIn(),
          habitLogs: {
            '2026-08-05': const {'habit-id': 'missed'},
          },
        ),
      );

      await expectLater(
        repository.setHabitStatus(
          habitId: 'habit-id',
          date: DateTime(2026, 8, 5),
          currentStatus: 'done',
        ),
        throwsA(anything),
      );

      expect((await queuedGoalLogPayload())['streak'], -1);
    });
  });

  // A queued write for a habit that was deleted on ANOTHER device can never be
  // applied: `goal_logs.goal_id` references `goals(id)`, so every replay gets
  // the same 23503. Keeping it would abort every future refresh() before a
  // single row is fetched — the flush is the first statement in its try — and
  // freeze this Mac on its cache forever.
  test('a permanently unappliable queued mutation does not wedge refresh',
      () async {
    final secureValues = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secureValues);
    const pendingKey = 'desktop_dashboard_pending_user-id';

    final offline = SupabaseDashboardRepository(
      client: SupabaseClient(
        'http://127.0.0.1:9',
        'test-publishable-key',
        httpClient: _OfflineHttpClient(),
      ),
      userId: 'user-id',
    );
    await offline.save(
      DashboardSnapshot(
        habits: [
          DashboardHabit(
            id: 'habit-id',
            title: 'Lettura serale',
            color: EvolveColors.violet,
            streak: 0,
            weeklyProgress: const [
              false,
              false,
              false,
              false,
              false,
              false,
              false,
            ],
            state: HabitState.pending,
          ),
        ],
        goals: const [],
        trend: const [],
        checkIn: const DailyCheckIn(),
      ),
    );
    await expectLater(
      offline.setHabitStatus(
        habitId: 'habit-id',
        date: DateTime(2026, 8, 5),
        currentStatus: null,
      ),
      throwsA(anything),
    );
    expect(secureValues.containsKey(pendingKey), isTrue);

    // Back online, but the habit is gone server-side.
    final online = SupabaseDashboardRepository(
      client: SupabaseClient(
        'http://127.0.0.1:9',
        'test-publishable-key',
        httpClient: _ForeignKeyViolationHttpClient(),
      ),
      userId: 'user-id',
    );

    await online.refresh();

    expect(secureValues.containsKey(pendingKey), isFalse);
  });
}

class _OfflineHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const SocketException('Network is unreachable');
  }
}

/// Rejects any write to `goal_logs` with PostgREST's foreign-key violation and
/// answers every read with an empty table.
class _ForeignKeyViolationHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await request.finalize().drain<void>();
    if (request.method != 'GET' && request.url.path.endsWith('/goal_logs')) {
      return _json(request, 409, {
        'code': '23503',
        'message':
            'insert or update on table "goal_logs" violates foreign key '
            'constraint "goal_logs_goal_id_fkey"',
        'details': null,
        'hint': null,
      });
    }
    return _json(request, 200, const <dynamic>[]);
  }

  http.StreamedResponse _json(http.BaseRequest request, int status, Object body) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
