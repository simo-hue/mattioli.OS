// Regression test for finding F02: the Cloud (Supabase) "Replace" import used
// to plan against an EMPTY existing state (`if (replaceExisting) return const
// []`). That was safe only while Replace deleted every row BEFORE upserting;
// once the order was flipped to upsert-then-prune, a blind plan keeps the FILE's
// id for a row the account already holds under a different id, and the upsert
// (ON CONFLICT id) violates the table's natural-key UNIQUE constraint:
// goal_logs(goal_id,date), daily_moods(user_id,date),
// macro_goal_categories(user_id,name). The import then aborts half-written —
// categories/goals/macros already replaced, no deletes, no streak recompute.
//
// The fake backend below enforces those three UNIQUE constraints exactly as
// Postgres does (23505 on an id-conflict upsert that collides on the natural
// key), so reverting the fix turns these tests RED instead of green.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/backup_import_service.dart';
import 'package:mattioli_os/core/import_merge.dart';
import 'package:mattioli_os/core/private_data_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloud import never touches the private store; a throwing stub proves it.
class _UnusedPrivateStore implements PrivateDataStore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Private store must not be used in cloud import');
}

/// The natural key (beyond the primary key) each table carries in schema.sql.
const _naturalKeys = <String, List<String>>{
  'goal_logs': ['goal_id', 'date'],
  'daily_moods': ['user_id', 'date'],
  'macro_goal_categories': ['user_id', 'name'],
};

class _Write {
  final String method; // POST (upsert) | DELETE | PATCH
  final String table;
  final List<Map<String, dynamic>> rows;
  final Set<String> deletedIds;
  _Write(this.method, this.table, this.rows, this.deletedIds);
}

Set<String> _parseIn(String v) {
  final inner = v.substring('in.('.length, v.length - 1);
  if (inner.isEmpty) return {};
  return inner.split(',').map((s) => s.replaceAll('"', '')).toSet();
}

/// A Supabase REST backend over [store] (table -> rows) that ENFORCES the
/// secondary UNIQUE constraints: an `on_conflict=id` upsert whose row duplicates
/// another row's natural key fails with Postgres' 23505, exactly like prod.
MockClient _backend(
  Map<String, List<Map<String, dynamic>>> store,
  List<_Write> writes,
) {
  http.Response json(Object body, http.BaseRequest req, [int code = 200]) =>
      http.Response(jsonEncode(body), code,
          request: req, headers: {'content-type': 'application/json'});

  return MockClient((req) async {
    final table = req.url.pathSegments.last;
    final params = req.url.queryParameters;

    if (req.method == 'GET') {
      var rows = List<Map<String, dynamic>>.of(store[table] ?? const []);
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
      rows.sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
      return json(rows, req);
    }

    if (req.method == 'POST') {
      final body = (jsonDecode(req.body) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      writes.add(_Write('POST', table, body, const {}));
      final list = store.putIfAbsent(table, () => []);
      final key = _naturalKeys[table];
      for (final r in body) {
        if (key != null) {
          final clash = list.any((e) =>
              e['id'] != r['id'] &&
              key.every((c) => '${e[c]}' == '${r[c]}'));
          if (clash) {
            return json({
              'code': '23505',
              'message': 'duplicate key value violates unique constraint '
                  '"${table}_${key.join('_')}_key"',
              'details': null,
              'hint': null,
            }, req, 409);
          }
        }
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
      'aud': 'authenticated',
    },
  }));
  return client;
}

Map<String, dynamic> _canonical({
  List<Map<String, dynamic>> cats = const [],
  List<Map<String, dynamic>> goals = const [],
  List<Map<String, dynamic>> macros = const [],
  List<Map<String, dynamic>> logs = const [],
  List<Map<String, dynamic>> moods = const [],
}) => {
      kCategoriesKey: cats,
      kGoalsKey: goals,
      kMacrosKey: macros,
      kLogsKey: logs,
      kMoodsKey: moods,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const goalRow = {
    'id': 'goal-G',
    'user_id': 'u1',
    'title': 'G',
    'start_date': '2026-01-01',
    'updated_at': '2026-01-01T00:00:00.000Z',
  };
  const backupGoal = {
    'id': 'goal-G',
    'title': 'G',
    'color': '#3B82F6',
    'start_date': '2026-01-01',
    'updated_at': '2026-01-01T00:00:00.000Z',
  };

  test(
      'REPLACE: a goal_logs row re-created under a new server id does not abort '
      'the import on UNIQUE(goal_id,date)', () async {
    final store = <String, List<Map<String, dynamic>>>{
      'goals': [Map<String, dynamic>.of(goalRow)],
      'goal_logs': [
        {
          // Re-created on another device since the export: same (goal_id,date)
          // as the backup row, DIFFERENT id.
          'id': 'srv-log-new',
          'user_id': 'u1',
          'goal_id': 'goal-G',
          'date': '2026-01-02',
          'status': 'done',
          'value': null,
          'created_at': '2026-01-02T00:00:00.000Z',
          'updated_at': '2026-01-02T00:00:00.000Z',
          'streak': 1,
        },
        // A row the backup does NOT contain: Replace must prune it.
        {
          'id': 'srv-log-stale',
          'user_id': 'u1',
          'goal_id': 'goal-G',
          'date': '2026-01-09',
          'status': 'done',
          'value': null,
          'created_at': '2026-01-09T00:00:00.000Z',
          'updated_at': '2026-01-09T00:00:00.000Z',
          'streak': 1,
        },
      ],
      'long_term_goals': <Map<String, dynamic>>[],
      'macro_goal_categories': <Map<String, dynamic>>[],
      'daily_moods': <Map<String, dynamic>>[],
      'goal_progress': <Map<String, dynamic>>[],
    };
    final writes = <_Write>[];
    final client = await _authedClient(_backend(store, writes));
    addTearDown(client.dispose);

    final service = BackupImportService(_UnusedPrivateStore(), client);

    final stats = await service.executeImport(
      canonicalData: _canonical(
        goals: [Map<String, dynamic>.of(backupGoal)],
        logs: [
          {
            'id': 'file-log',
            'goal_id': 'goal-G',
            'date': '2026-01-02',
            'status': 'missed',
            'updated_at': '2026-01-02T00:00:00.000Z',
          },
        ],
      ),
      replaceExisting: true,
      isPrivateMode: false,
    );

    expect(stats.replaced, isTrue);
    // The log lands on the EXISTING row (in place), so the account holds exactly
    // the backup: one log, carrying the backup's status.
    expect(store['goal_logs']!.length, 1);
    expect(store['goal_logs']!.single['id'], 'srv-log-new');
    expect(store['goal_logs']!.single['status'], 'missed');
    // And the prune actually ran (it never did when the upsert threw).
    final deleted = writes
        .where((w) => w.method == 'DELETE' && w.table == 'goal_logs')
        .expand((w) => w.deletedIds)
        .toSet();
    expect(deleted, contains('srv-log-stale'));
  });

  test(
      'REPLACE: a daily_moods row under a new server id does not abort on '
      'UNIQUE(user_id,date)', () async {
    final store = <String, List<Map<String, dynamic>>>{
      'goals': <Map<String, dynamic>>[],
      'goal_logs': <Map<String, dynamic>>[],
      'long_term_goals': <Map<String, dynamic>>[],
      'macro_goal_categories': <Map<String, dynamic>>[],
      'goal_progress': <Map<String, dynamic>>[],
      'daily_moods': [
        {
          'id': 'srv-mood-new',
          'user_id': 'u1',
          'date': '2026-01-02',
          'mood_score': 2,
          'energy_score': 2,
          'created_at': '2026-01-02T00:00:00.000Z',
          'updated_at': '2026-01-02T00:00:00.000Z',
        },
      ],
    };
    final writes = <_Write>[];
    final client = await _authedClient(_backend(store, writes));
    addTearDown(client.dispose);

    final service = BackupImportService(_UnusedPrivateStore(), client);

    await service.executeImport(
      canonicalData: _canonical(moods: [
        {
          'id': 'file-mood',
          'date': '2026-01-02',
          'mood_score': 5,
          'energy_score': 4,
          'updated_at': '2026-01-02T00:00:00.000Z',
        },
      ]),
      replaceExisting: true,
      isPrivateMode: false,
    );

    expect(store['daily_moods']!.length, 1);
    expect(store['daily_moods']!.single['id'], 'srv-mood-new');
    expect(store['daily_moods']!.single['mood_score'], 5);
  });

  test(
      'REPLACE: a same-name category is updated in place and survives the '
      'prune, keeping the macro goal attached', () async {
    final store = <String, List<Map<String, dynamic>>>{
      'goals': <Map<String, dynamic>>[],
      'goal_logs': <Map<String, dynamic>>[],
      'goal_progress': <Map<String, dynamic>>[],
      'daily_moods': <Map<String, dynamic>>[],
      'long_term_goals': <Map<String, dynamic>>[],
      'macro_goal_categories': [
        {
          'id': 'srv-cat',
          'user_id': 'u1',
          'name': 'Salute',
          'color': '#111111',
          'created_at': '2026-01-01T00:00:00.000Z',
          'archived_at': null,
        },
      ],
    };
    final writes = <_Write>[];
    final client = await _authedClient(_backend(store, writes));
    addTearDown(client.dispose);

    final service = BackupImportService(_UnusedPrivateStore(), client);

    await service.executeImport(
      canonicalData: _canonical(
        cats: [
          {'id': 'file-cat', 'name': 'salute', 'color': '#10B981'},
        ],
        macros: [
          {
            'id': 'file-macro',
            'title': 'Fit',
            'status': 'active',
            'type': 'annual',
            'category_id': 'file-cat',
            'updated_at': '2026-01-01T00:00:00.000Z',
          },
        ],
      ),
      replaceExisting: true,
      isPrivateMode: false,
    );

    // One category, under the server's id — not a duplicate name, not deleted.
    expect(store['macro_goal_categories']!.length, 1);
    expect(store['macro_goal_categories']!.single['id'], 'srv-cat');
    expect(store['long_term_goals']!.single['category_id'], 'srv-cat',
        reason: 'the macro must stay attached to the surviving category');
  });
}
