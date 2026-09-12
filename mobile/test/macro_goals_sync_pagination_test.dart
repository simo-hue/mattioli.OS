// `_syncFromSupabase` read `long_term_goals` with ONE unbounded select ordered
// `created_at` ascending. PostgREST caps an unbounded select at the project's
// `db-max-rows` (1000 by default) and truncates SILENTLY, oldest-first — so past
// the cap the NEWEST goals, i.e. the current period's board, vanished from every
// view, and `_saveToCache` then persisted the truncated list across restarts.
//
// The table grows one row per goal AND one more per reschedule (`rescheduleGoal`
// mints a fresh id for every rolled-forward period), so a weekly-goal user grows
// into the cap over time. `core/supabase_macro_goal_progress.dart` documents the
// same hazard for the same project and already windows its read.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = 'u1';

/// One row past a full page, so the fetch has to ask for a second one.
final _rows = [
  for (var i = 0; i < kMacroGoalsSyncPageSize + 1; i++)
    <String, dynamic>{
      'id': 'macro-$i',
      'title': 'Goal $i',
      'status': 'active',
      'type': 'lifetime',
      'created_at': DateTime.utc(2020).add(Duration(days: i)).toIso8601String(),
    },
];

/// A backend that behaves like PostgREST with `db-max-rows` = the page size:
/// a select with no window is silently truncated to the OLDEST page, and a
/// windowed one gets the window it asked for (the client sends `offset`/`limit`
/// query parameters, not a Range header).
MockClient _cappedBackend() => MockClient((req) async {
      if (!req.url.path.contains('long_term_goals')) {
        return http.Response('[]', 200,
            request: req, headers: {'content-type': 'application/json'});
      }
      final query = req.url.queryParameters;
      final offset = int.tryParse(query['offset'] ?? '') ?? 0;
      final requested =
          int.tryParse(query['limit'] ?? '') ?? kMacroGoalsSyncPageSize;
      // db-max-rows: the server never returns more than this, asked or not.
      final limit = requested.clamp(0, kMacroGoalsSyncPageSize);
      final slice = offset >= _rows.length
          ? const <Map<String, dynamic>>[]
          : _rows.sublist(offset, (offset + limit).clamp(0, _rows.length));
      return http.Response(jsonEncode(slice), 200,
          request: req, headers: {'content-type': 'application/json'});
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: _cappedBackend(),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'not-a-jwt',
      'token_type': 'bearer',
      'user': {
        'id': _userId,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
      },
    }));
  });

  test('THE TRUNCATION: the sync reads past the row cap', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    c.read(macroGoalsProvider);
    // Two round trips, plus the cache seed's Keychain read.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final goals = c.read(macroGoalsProvider).goals;
    expect(goals.length, kMacroGoalsSyncPageSize + 1,
        reason: 'an unbounded select stops at the cap and drops the NEWEST '
            'rows — the board the user is actually looking at');
    expect(goals.last.id, 'macro-$kMacroGoalsSyncPageSize',
        reason: 'the most recent goal is the one truncation loses first');
    expect(prefs.getString('macro_goals_cache'), contains('Goal 1000'),
        reason: 'a truncated list must not be the one persisted across '
            'restarts');
  });
}
