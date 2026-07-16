// Regression tests for finding #39 (desktop twin): the Cloud (Supabase) import's
// existing-state reads must page past PostgREST's per-request `db-max-rows` cap.
// A single unbounded select silently returns only the first ~1000 rows, which
// makes "Replace" leave stale rows behind and makes the streak recompute run on
// a truncated history and write the wrong values back.
//
// Unlike the pure-loop coverage of `fetchAllRowsPaginated`, these tests exercise
// the ACTUAL query wiring: a real `SupabaseClient` is driven by a `MockClient`
// that faithfully models the row cap — an unwindowed GET is truncated to the
// first page, while a windowed (`.order('id')` + `.range()`) GET is served in
// full across pages. That is exactly the part that regresses if the fix is
// reverted, so dropping the pagination turns each test RED.
//
// Mirrors mobile/test/cloud_import_pagination_test.dart so the two service
// files stay coherent.
import 'dart:convert';

import 'package:evolve_desktop/core/desktop_backup_import_service.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/import_merge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every private-mode method is unreachable on the Cloud import path, so a
/// forwarding stub is enough. If the cloud path ever touched the store this
/// would throw and fail the test loudly.
class _UnusedPrivateStore implements DesktopPrivateDb {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Private store must not be used in cloud import');
}

/// PostgREST's default `db-max-rows`. An unbounded select returns at most this
/// many rows; a paginated read has to window past it.
const int _dbMaxRows = 1000;

/// One captured mutation the import issued against the fake backend.
class _Write {
  final String method; // POST (upsert) | DELETE | PATCH
  final String table;
  final List<Map<String, dynamic>> rows; // upsert bodies
  final Set<String> deletedIds; // ids named in a DELETE `id=in.(...)`
  _Write(this.method, this.table, this.rows, this.deletedIds);
}

/// One captured GET the import issued (used to assert pagination wiring).
class _Read {
  final String table;
  final Map<String, String> query;
  _Read(this.table, this.query);
}

/// Parses a PostgREST `col=in.("a","b")` value into its member set.
Set<String> _parseIn(String v) {
  final inner = v.substring('in.('.length, v.length - 1);
  if (inner.isEmpty) return {};
  return inner.split(',').map((s) => s.replaceAll('"', '')).toSet();
}

/// Builds a `MockClient` that models a Supabase REST backend over [store]
/// (table -> rows), enforcing the `db-max-rows` cap the finding is about:
///   * a GET with neither `offset` nor `limit` is truncated to the first
///     [_dbMaxRows] rows in stored (physical) order — exactly how an unbounded
///     `select()` silently drops the tail;
///   * a GET carrying `.order('id')` + `.range()` (offset/limit) is served in
///     full, one window at a time.
/// POST upserts (on_conflict=id) and DELETE (`id=in.(...)`) mutate [store] and
/// are recorded into [writes]; GETs are recorded into [reads].
MockClient _backend(
  Map<String, List<Map<String, dynamic>>> store,
  List<_Write> writes,
  List<_Read> reads,
) {
  http.Response json(Object body, http.BaseRequest req, [int code = 200]) =>
      http.Response(jsonEncode(body), code,
          request: req, headers: {'content-type': 'application/json'});

  return MockClient((req) async {
    final table = req.url.pathSegments.last;
    final params = req.url.queryParameters;

    if (req.method == 'GET') {
      reads.add(_Read(table, params));
      var rows = List<Map<String, dynamic>>.of(store[table] ?? const []);
      // Column filters (only eq. and in. are used by the import).
      params.forEach((k, v) {
        if (k == 'select' || k == 'order' || k == 'offset' || k == 'limit') {
          return;
        }
        if (v.startsWith('eq.')) {
          final want = v.substring(3);
          rows = rows.where((r) => '${r[k]}' == want).toList();
        } else if (v.startsWith('in.(')) {
          final want = _parseIn(v);
          rows = rows.where((r) => want.contains('${r[k]}')).toList();
        }
      });

      final order = params['order'];
      final windowed =
          params.containsKey('offset') || params.containsKey('limit');
      if (order != null && order.startsWith('id.')) {
        final asc = order.contains('.asc.');
        rows.sort((a, b) => asc
            ? '${a['id']}'.compareTo('${b['id']}')
            : '${b['id']}'.compareTo('${a['id']}'));
      }
      if (windowed) {
        final offset = int.tryParse(params['offset'] ?? '0') ?? 0;
        final limit =
            int.tryParse(params['limit'] ?? '$_dbMaxRows') ?? _dbMaxRows;
        if (offset >= rows.length) {
          rows = [];
        } else {
          final end = (offset + limit).clamp(0, rows.length);
          rows = rows.sublist(offset, end);
        }
      } else {
        // Unbounded select: the server caps it at db-max-rows and drops the rest.
        if (rows.length > _dbMaxRows) rows = rows.sublist(0, _dbMaxRows);
      }
      return json(rows, req);
    }

    if (req.method == 'POST') {
      final body = (jsonDecode(req.body) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      writes.add(_Write('POST', table, body, const {}));
      final list = store.putIfAbsent(table, () => []);
      for (final r in body) {
        final idx = list.indexWhere((e) => e['id'] == r['id']);
        if (idx >= 0) {
          list[idx] = Map<String, dynamic>.of(r);
        } else {
          list.add(Map<String, dynamic>.of(r));
        }
      }
      return json(const [], req, 201);
    }

    if (req.method == 'DELETE') {
      final idFilter = params['id'];
      final ids = (idFilter != null && idFilter.startsWith('in.('))
          ? _parseIn(idFilter)
          : <String>{};
      writes.add(_Write('DELETE', table, const [], ids));
      store[table]?.removeWhere((e) => ids.contains('${e['id']}'));
      return json(const [], req);
    }

    if (req.method == 'PATCH') {
      writes.add(_Write('PATCH', table, const [], const {}));
      return json(const [], req);
    }

    return json(const [], req);
  });
}

Future<SupabaseClient> _authedClient(MockClient mock) async {
  final client = SupabaseClient(
    'https://dummy.supabase.co',
    'anon-key',
    httpClient: mock,
  );
  await client.auth.setInitialSession(jsonEncode({
    'access_token': 'not-a-jwt',
    'token_type': 'bearer',
    'user': {
      'id': 'u1',
      'app_metadata': <String, dynamic>{},
      'aud': 'authenticated'
    },
  }));
  return client;
}

/// Canonical backup skeleton with all five entity keys present.
Map<String, dynamic> _canonical({
  List<Map<String, dynamic>> goals = const [],
  List<Map<String, dynamic>> logs = const [],
}) => {
      kCategoriesKey: const <Map<String, dynamic>>[],
      kGoalsKey: goals,
      kMacrosKey: const <Map<String, dynamic>>[],
      kLogsKey: logs,
      kMoodsKey: const <Map<String, dynamic>>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A goal_logs history far larger than one page. Ids are zero-padded so a
  // descending id sort matches numeric order; the witness at index 1200 lands
  // outside BOTH the first stored page (0..999) and the first descending-id
  // page (1500..2499), so a single-page read can never see it.
  const int total = 2500;
  const int witnessIdx = 1200;
  final witnessId = 'srv-${witnessIdx.toString().padLeft(4, '0')}';
  String dateAt(int i) {
    final d = DateTime.utc(2015, 1, 1).add(Duration(days: i));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  final witnessDate = dateAt(witnessIdx);

  List<Map<String, dynamic>> serverLogs() => List.generate(
        total,
        (i) => {
          'id': 'srv-${i.toString().padLeft(4, '0')}',
          'user_id': 'u1',
          'goal_id': 'goal-G',
          'date': dateAt(i),
          'status': 'done',
          'value': null,
          'created_at': '2020-01-01T00:00:00.000Z',
          'updated_at': '2020-01-01T00:00:00.000Z',
          'streak': 0,
        },
      );

  Map<String, List<Map<String, dynamic>>> freshStore() => {
        'goals': [
          {
            'id': 'goal-G',
            'user_id': 'u1',
            'title': 'G',
            'start_date': '2015-01-01',
            'updated_at': '2020-01-01T00:00:00.000Z',
          },
        ],
        'goal_logs': serverLogs(),
        'long_term_goals': <Map<String, dynamic>>[],
        'macro_goal_categories': <Map<String, dynamic>>[],
        'daily_moods': <Map<String, dynamic>>[],
      };

  test(
      'MERGE: a log whose server row is past the row cap is matched, not '
      're-inserted under a fresh id (fetch() pagination)', () async {
    final store = freshStore();
    final writes = <_Write>[];
    final reads = <_Read>[];
    final client = await _authedClient(_backend(store, writes, reads));
    addTearDown(client.dispose);

    final service = DesktopBackupImportService(_UnusedPrivateStore(), client);

    // A check-in edited on another device: same (goal_id, date) as the hidden
    // server row, newer updated_at (so it wins LWW), and a DIFFERENT id.
    await service.executeImport(
      canonicalData: _canonical(logs: [
        {
          'id': 'backup-log-x',
          'goal_id': 'goal-G',
          'date': witnessDate,
          'status': 'missed',
          'updated_at': '2030-01-01T00:00:00.000Z',
        }
      ]),
      replaceExisting: false,
      isPrivateMode: false,
    );

    // The FIRST goal_logs upsert is the plan's log write (recompute may upsert
    // again afterwards). Its row for the witness date must reuse the existing
    // server id — proving planCloudImport saw the row past the cap. Under the
    // bug it would carry 'backup-log-x' and collide on UNIQUE(goal_id, date).
    final planUpsert = writes.firstWhere(
      (w) => w.method == 'POST' && w.table == 'goal_logs',
    );
    final row = planUpsert.rows.firstWhere((r) => r['date'] == witnessDate);
    expect(row['id'], witnessId,
        reason: 'incoming log must update the existing row in place, not mint '
            'a new id for a row hidden past db-max-rows');
  });

  test(
      'MERGE: streak recompute reads the whole affected-goal history past the '
      'row cap (_recomputeCloudStreaks pagination)', () async {
    final store = freshStore();
    final writes = <_Write>[];
    final reads = <_Read>[];
    final client = await _authedClient(_backend(store, writes, reads));
    addTearDown(client.dispose);

    final service = DesktopBackupImportService(_UnusedPrivateStore(), client);

    await service.executeImport(
      canonicalData: _canonical(logs: [
        {
          'id': 'backup-log-x',
          'goal_id': 'goal-G',
          'date': witnessDate,
          'status': 'missed',
          'updated_at': '2030-01-01T00:00:00.000Z',
        }
      ]),
      replaceExisting: false,
      isPrivateMode: false,
    );

    // The recompute reads goal_logs filtered by goal_id (not user_id). It must
    // request the third window (offset 2000) — an unbounded select never would.
    final recomputeReads = reads.where(
      (r) => r.table == 'goal_logs' && r.query.containsKey('goal_id'),
    );
    expect(recomputeReads, isNotEmpty,
        reason: 'recompute must read the affected goal\'s logs');
    expect(
      recomputeReads.any((r) => r.query['offset'] == '2000'),
      isTrue,
      reason: 'recompute must page past db-max-rows, not truncate the history '
          'it feeds into computeStreak',
    );
  });

  test(
      'REPLACE: a stale row past the row cap is pruned (_deleteComplement '
      'pagination)', () async {
    final store = freshStore();
    final writes = <_Write>[];
    final reads = <_Read>[];
    final client = await _authedClient(_backend(store, writes, reads));
    addTearDown(client.dispose);

    final service = DesktopBackupImportService(_UnusedPrivateStore(), client);

    // Replace with a backup that keeps the goal but NO logs: every server log is
    // a stale row that Replace must delete.
    await service.executeImport(
      canonicalData: _canonical(goals: [
        {
          'id': 'goal-G',
          'title': 'G',
          'start_date': '2015-01-01',
          'updated_at': '2020-01-01T00:00:00.000Z',
        }
      ]),
      replaceExisting: true,
      isPrivateMode: false,
    );

    final deleted = <String>{};
    for (final w in writes) {
      if (w.method == 'DELETE' && w.table == 'goal_logs') {
        deleted.addAll(w.deletedIds);
      }
    }
    // The witness row is invisible to a single capped id-read, so under the bug
    // it is never scheduled for deletion and survives the Replace.
    expect(deleted, contains(witnessId),
        reason: 'Replace must delete every row absent from the backup, '
            'including those past db-max-rows');
    // Sanity: the whole history is pruned, not just the first page.
    expect(deleted.length, total);
    expect(store['goal_logs'], isEmpty);
  });
}
