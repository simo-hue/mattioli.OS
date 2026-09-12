// F41 — clearing a macro goal's category in Account mode could not clear a
// LEGACY `category_key`.
//
// `copyWith(clearCategory: true)` nulls BOTH fields optimistically and the chip
// disappears, but the cloud UPDATE sent only `category_id`. On the next
// _syncFromSupabase the row came back with `category_key` still set and
// GoalItemWidget fell into its `else if (goal.categoryKey != null)` branch — the
// dot reappeared permanently, since account mode has no other writer. The
// private branch persists the whole row (upsertMacroGoal writes category_key)
// and clears correctly; the catch block's own comment already documents that
// clearing "nulls the KEY as well as the id".
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

typedef _Req = ({String method, Object? body});

final List<_Req> _requests = [];

/// Signed in, because the offline mirror only seeds the account that owns it
/// (`cacheSeedAllowed`) — so the goal under test is served by the initial sync
/// instead, and the cache is left out of it entirely.
class _LoggedInAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        isLoggedIn: true,
        user: Supabase.instance.client.auth.currentUser,
      );
}

http.Response _json(Object body, http.BaseRequest req) =>
    http.Response(jsonEncode(body), 200,
        request: req, headers: {'content-type': 'application/json'});

MockClient _backend() => MockClient((req) async {
      _requests
          .add((method: req.method, body: req.body.isEmpty ? null : jsonDecode(req.body)));
      // The initial sync hands the notifier the legacy row; everything else
      // (the PATCH under test) answers empty.
      if (req.method == 'GET' && req.url.path.contains('long_term_goals')) {
        return _json([_legacyGoal.toJson()], req);
      }
      return _json(const <dynamic>[], req);
    });

final _legacyGoal = MacroGoal(
  id: 'goal-1',
  title: 'Ship the release',
  status: GoalStatus.active,
  type: GoalType.annual,
  year: 2026,
  // A legacy built-in slug, from before user categories existed.
  categoryKey: 'lavoro',
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: _backend(),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'not-a-jwt',
      'token_type': 'bearer',
      'user': {
        'id': 'u1',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
      },
    }));
  });

  setUp(() => _requests.clear());

  test('clearing the category nulls the legacy category_key on the server',
      () async {
    SharedPreferences.setMockInitialValues({
      'macro_goals_cache': jsonEncode([_legacyGoal.toJson()]),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_LoggedInAuth.new),
    ]);
    addTearDown(container.dispose);

    container.read(macroGoalsProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(macroGoalsProvider).goals.single.categoryKey,
        'lavoro');
    _requests.clear();

    await container.read(macroGoalsProvider.notifier).updateCategory(
          'goal-1',
          null,
        );

    final patch = _requests.singleWhere((r) => r.method == 'PATCH');
    final body = patch.body as Map<String, dynamic>;
    expect(body['category_id'], isNull);
    expect(body.containsKey('category_key'), isTrue,
        reason: 'a payload that never names category_key leaves the legacy '
            'slug on the row, and the next sync brings the chip back');
    expect(body['category_key'], isNull);
  });
}
