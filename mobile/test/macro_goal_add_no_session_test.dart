// The NO-SESSION half of `MacroGoalsNotifier.addGoal`'s optimistic-write
// rollback.
//
// `macro_goal_add_rollback_cloud_test.dart` covers the account-mode INSERT
// failing; this file covers the earlier exit, where the access token has been
// rotated/expired away between the goals screen opening and the user tapping
// add, so `supabase.auth.currentUser` is already null when addGoal runs. The
// optimistic row and the `macro_goals_cache` write both happen BEFORE that
// check, so without a rollback the goal looks saved, is never uploaded, and is
// wiped by the next successful `_syncFromSupabase`.
//
// Supabase is initialised WITHOUT an initial session on purpose: that is what
// makes `currentUser` null while the data mode is still account mode.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((req) async {
        return http.Response('[]', 200,
            request: req, headers: {'content-type': 'application/json'});
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
  });

  test('addGoal with no session strands no ghost goal', () async {
    // No 'active_data_mode' key -> account (Supabase) mode, the default.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(macroGoalsProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    expect(Supabase.instance.client.auth.currentUser, isNull,
        reason: 'the scenario under test is a missing session');

    await container.read(macroGoalsProvider.notifier).addGoal(_tempIdGoal());

    expect(
      container.read(macroGoalsProvider).goals,
      isEmpty,
      reason: 'a goal that was never uploaded must not be shown as saved',
    );
    expect(
      prefs.getString(_cacheKey) ?? '[]',
      isNot(contains('weekly-1754812345678')),
      reason: 'nor may it survive a restart via the offline mirror',
    );
  });
}
