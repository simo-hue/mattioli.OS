// F46 — the account-mode habit reorder was the only mutation in
// `SupabaseDashboardRepository` that bypassed the offline queue.
//
// Every other write (createHabit, updateHabit, deleteHabit, setHabitStatus,
// setHabitProgress, saveCheckIn, createGoal, updateGoal, deleteGoal) goes
// through `_runOrQueue`; `reorderHabits` issued its N single-row UPDATEs raw.
// Offline, the state and the local cache moved, the shell showed its amber
// "Sync pending" pill via `_recordSyncError` — and nothing was queued. On
// reconnect the flush found an empty queue and the refresh re-read the
// server's untouched `order_key`s straight over both the snapshot and the
// cache, silently reverting the drag.
import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

DashboardHabit _habit(String id) => DashboardHabit(
      id: id,
      title: id,
      color: EvolveColors.primaryStrong,
      streak: 0,
      weeklyProgress: const [false, false, false, false, false, false, false],
      state: HabitState.pending,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pendingKey = 'desktop_dashboard_pending_user-id';

  test('an offline reorder queues every row and replays on the next refresh',
      () async {
    final secureValues = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secureValues);

    final offline = SupabaseDashboardRepository(
      client: SupabaseClient(
        'http://127.0.0.1:9',
        'test-publishable-key',
        httpClient: _OfflineHttpClient(),
      ),
      userId: 'user-id',
    );

    // The user drags "b" above "a" while the Wi-Fi is off.
    await expectLater(
      offline.reorderHabits([_habit('b'), _habit('a')]),
      throwsA(anything),
    );

    final queued =
        (jsonDecode(secureValues[pendingKey]!) as List<dynamic>)
            .cast<Map<String, dynamic>>();
    expect(queued, hasLength(2));
    for (final mutation in queued) {
      expect(mutation['operation'], 'update');
      expect(mutation['table'], 'goals');
    }
    expect(queued[0]['filters'], {'id': 'b'});
    expect((queued[0]['payload'] as Map)['display_order'], 0);
    expect(queued[1]['filters'], {'id': 'a'});
    expect((queued[1]['payload'] as Map)['display_order'], 1);

    // Back online: the queue must flush before the refresh re-reads the rows,
    // or the server's untouched order overwrites the drag.
    final recorder = _RecordingHttpClient();
    final online = SupabaseDashboardRepository(
      client: SupabaseClient(
        'http://127.0.0.1:9',
        'test-publishable-key',
        httpClient: recorder,
      ),
      userId: 'user-id',
    );

    await online.refresh();

    expect(secureValues.containsKey(pendingKey), isFalse);
    expect(recorder.patchedIds, ['b', 'a']);
  });
}

class _OfflineHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const SocketException('Network is unreachable');
  }
}

/// Answers every request with an empty table and records the `id` filter of
/// each PATCH against `goals`, in order.
class _RecordingHttpClient extends http.BaseClient {
  final List<String> patchedIds = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await request.finalize().drain<void>();
    if (request.method == 'PATCH' && request.url.path.endsWith('/goals')) {
      final filter = request.url.queryParameters['id'];
      if (filter != null) patchedIds.add(filter.replaceFirst('eq.', ''));
    }
    final bytes = utf8.encode(jsonEncode(const <dynamic>[]));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
