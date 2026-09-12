// F22 — the account-mode READ path reported a habit's LAST LOGGED streak
// instead of the streak as of TODAY.
//
// `_fromRemote` mapped every habit with `_latestStreak`, which sorted that
// habit's `goal_logs` rows by date DESC and returned the stored `streak` column
// of the newest row. No rows are written for unlogged days, so a run that ended
// a week ago kept reporting its final value: the Overview row read "🔥 5 days"
// and the Best-streak card read 5 while `computeStreak` for the same habit and
// the same day returned 0 — which is what the iPhone, and the same Mac in
// Private mode (`PrivateDashboardRepository._habitFromRow`), showed. `_toCache`
// then persisted the stale number.
//
// The WRITE path in this class was already corrected to `computeStreak`; the
// read path was not.
import 'dart:convert';

import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  test('a run that ended a week ago reads as no streak today', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});

    final now = DateTime.now();
    DateTime daysAgo(int n) => DateTime(now.year, now.month, now.day - n);

    // Done on days 11..7 ago, then nothing at all since.
    final logRows = <Map<String, dynamic>>[
      for (var i = 0; i < 5; i++)
        {
          'id': 'log-$i',
          'user_id': 'user-id',
          'goal_id': 'habit-id',
          'date': key(daysAgo(11 - i)),
          'status': 'done',
          'streak': i + 1,
        },
    ];

    final repository = SupabaseDashboardRepository(
      client: SupabaseClient(
        'http://127.0.0.1:9',
        'test-publishable-key',
        httpClient: _RowsHttpClient({
          'goals': [
            {
              'id': 'habit-id',
              'user_id': 'user-id',
              'title': 'Lettura serale',
              'color': '#7C5CFF',
              'start_date': key(daysAgo(30)),
              'display_order': 0,
            },
          ],
          'goal_logs': logRows,
        }),
      ),
      userId: 'user-id',
    );

    final snapshot = await repository.refresh();

    expect(snapshot.habits.single.streak, 0);
  });
}

/// Answers every PostgREST GET with the rows registered for that table (empty
/// when none) and every write with an empty list.
class _RowsHttpClient extends http.BaseClient {
  _RowsHttpClient(this._tables);

  final Map<String, List<Map<String, dynamic>>> _tables;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await request.finalize().drain<void>();
    final table = request.url.pathSegments.last;
    final body = jsonEncode(_tables[table] ?? const <dynamic>[]);
    final bytes = utf8.encode(body);
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
