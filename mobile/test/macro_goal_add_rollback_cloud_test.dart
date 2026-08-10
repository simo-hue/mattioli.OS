// The CLOUD half of `MacroGoalsNotifier.addGoal`'s optimistic-write rollback.
//
// `private_mode_no_supabase_test.dart` only ever drives addGoal in Private
// mode, where the branch returns at line ~188 — so the account-mode catch was
// reachable by no test at all. The id the add-bar mints
// (`'${type.name}-${millisecondsSinceEpoch}'`) is NOT a uuid; Supabase assigns
// the real one and the success path substitutes it. If the INSERT fails and the
// temp-id row is left in state AND in the `macro_goals_cache` blob, it survives
// a restart (build() seeds from the cache) and every later mutation on it hits
// `long_term_goals.id uuid` with a 22P02.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = 'u1';
const _cacheKey = 'macro_goals_cache';

MacroGoal _tempIdGoal() => MacroGoal(
      // Exactly the shape `add_goal_bar.dart` mints.
      id: 'weekly-1754812345678',
      title: 'Run a marathon',
      status: GoalStatus.active,
      type: GoalType.weekly,
      year: 2026,
      month: 8,
      weekNumber: 2,
      createdAt: DateTime.utc(2026, 8, 10),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `Supabase.initialize` builds a process-wide singleton, so it is called once
  // for the whole file and told per test what to answer.
  var goalsStatus = 500;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((req) async {
        if (req.url.path.contains('/long_term_goals')) {
          return http.Response(
            goalsStatus == 200 ? '[]' : '{"message":"boom"}',
            goalsStatus,
            request: req,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200,
            request: req, headers: {'content-type': 'application/json'});
      }),
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

  Future<(ProviderContainer, SharedPreferences)> cloudContainer() async {
    // No 'active_data_mode' key -> account (Supabase) mode, the default.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return (container, prefs);
  }

  test('a failed account-mode INSERT strands no temp-id goal', () async {
    goalsStatus = 500; // offline / 5xx: both the sync and the insert fail
    final (container, prefs) = await cloudContainer();
    container.read(macroGoalsProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await container.read(macroGoalsProvider.notifier).addGoal(_tempIdGoal());

    expect(
      container.read(macroGoalsProvider).goals,
      isEmpty,
      reason: 'the optimistic row must not survive a failed INSERT',
    );
    expect(
      prefs.getString(_cacheKey) ?? '[]',
      isNot(contains('weekly-1754812345678')),
      reason: 'nor may it survive a restart via the offline mirror',
    );
  });
}
