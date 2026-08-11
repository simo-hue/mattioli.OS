// Regression tests: the ACCOUNT-mode `goal_progress` read behind a LINKED
// cumulative macro goal must page past PostgREST's per-request `db-max-rows`
// cap. A single unbounded select silently returns only the first ~1000 rows, so
// a long-history linked goal ("500 km") displays an undercounted total — and
// `snapshotCloudLinkedMacroGoals` then freezes that wrong number into
// `progress_amount` at habit-delete time, permanently.
//
// As in `cloud_import_pagination_test.dart`, these exercise the ACTUAL query
// wiring: a real `SupabaseClient` driven by a `MockClient` that faithfully
// models the row cap — an unwindowed GET is truncated to the first page, while a
// windowed (`.range()`) GET is served in full, one window at a time. Dropping
// the pagination therefore turns both tests RED.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/macro_goal_calendar.dart';
import 'package:mattioli_os/core/supabase_macro_goal_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PostgREST's default `db-max-rows`. An unbounded select returns at most this
/// many rows; a paginated read has to window past it.
const int _dbMaxRows = 1000;

/// One captured GET (used to assert the pagination wiring, not just the total).
class _Read {
  final Map<String, List<String>> query;
  _Read(this.query);
}

/// Fake Supabase REST backend over [rows] (a `goal_progress` table), enforcing
/// the `db-max-rows` cap this regression is about: an unwindowed GET is
/// truncated to the first [_dbMaxRows] rows, a windowed one is served in full.
/// `queryParametersAll` is used on purpose — a `date` BETWEEN sends the SAME key
/// twice (`date=gte.X&date=lte.Y`) and the collapsed map would drop one half.
MockClient _backend(List<Map<String, dynamic>> rows, List<_Read> reads) {
  return MockClient((req) async {
    final params = req.url.queryParametersAll;
    reads.add(_Read(params));

    var result = List<Map<String, dynamic>>.of(rows);
    params.forEach((key, values) {
      if (key == 'select' || key == 'order' || key == 'offset' ||
          key == 'limit') {
        return;
      }
      for (final v in values) {
        if (v.startsWith('eq.')) {
          final want = v.substring(3);
          result = result.where((r) => '${r[key]}' == want).toList();
        } else if (v.startsWith('gte.')) {
          final want = v.substring(4);
          result =
              result.where((r) => '${r[key]}'.compareTo(want) >= 0).toList();
        } else if (v.startsWith('lte.')) {
          final want = v.substring(4);
          result =
              result.where((r) => '${r[key]}'.compareTo(want) <= 0).toList();
        }
      }
    });

    final offsetParam = params['offset']?.single;
    final limitParam = params['limit']?.single;
    if (offsetParam != null || limitParam != null) {
      final offset = int.tryParse(offsetParam ?? '0') ?? 0;
      final limit = int.tryParse(limitParam ?? '$_dbMaxRows') ?? _dbMaxRows;
      result = offset >= result.length
          ? []
          : result.sublist(offset, (offset + limit).clamp(0, result.length));
    } else if (result.length > _dbMaxRows) {
      // Unbounded select: the server caps it and drops the tail, silently.
      result = result.sublist(0, _dbMaxRows);
    }

    // Only the selected column comes back over the wire.
    final body = result.map((r) => {'amount': r['amount']}).toList();
    return http.Response(jsonEncode(body), 200,
        request: req, headers: {'content-type': 'application/json'});
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A per-day progress history far longer than one page: 2500 consecutive days
  // from 2015-01-01, 1.0 each, so the expected total is just the row count.
  const int total = 2500;
  DateTime dayAt(int i) => DateTime.utc(2015, 1, 1).add(Duration(days: i));

  List<Map<String, dynamic>> serverRows() => List.generate(
        total,
        (i) => {
          'id': 'p-${i.toString().padLeft(4, '0')}',
          'user_id': 'u1',
          'goal_id': 'habit-1',
          'date': macroGoalProgressDateKey(dayAt(i)),
          'amount': 1.0,
        },
      );

  SupabaseClient clientFor(MockClient mock) => SupabaseClient(
        'https://dummy.supabase.co',
        'anon-key',
        httpClient: mock,
      );

  test('lifetime (null range) sums the whole history past the row cap',
      () async {
    final reads = <_Read>[];
    final client = clientFor(_backend(serverRows(), reads));
    addTearDown(client.dispose);

    final sum =
        await sumCloudLinkedHabitProgress(client, 'u1', 'habit-1', null);

    // Under the bug this is 1000: the tail is dropped with no error, and the
    // delete-time snapshot would freeze that undercount into progress_amount.
    expect(sum, total.toDouble());
    expect(reads.any((r) => r.query['offset']?.single == '2000'), isTrue,
        reason: 'must window past db-max-rows, not truncate the history');
  });

  test('a period range keeps its date filter on every page', () async {
    final reads = <_Read>[];
    final client = clientFor(_backend(serverRows(), reads));
    addTearDown(client.dispose);

    // Days 500..2400 inclusive = 1901 rows: more than one page, and bounded on
    // both sides so a page that lost its gte/lte would over-count instead.
    final sum = await sumCloudLinkedHabitProgress(
      client,
      'u1',
      'habit-1',
      MacroGoalDateRange(start: dayAt(500), end: dayAt(2400)),
    );

    expect(sum, 1901.0);
    for (final read in reads) {
      expect(read.query['date'], hasLength(2),
          reason: 'every page must carry both range bounds');
    }
  });
}
