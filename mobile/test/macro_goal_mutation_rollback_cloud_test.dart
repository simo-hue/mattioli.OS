// The CLOUD half of the optimistic-write rollback for the three macro-goal
// EDITS and the DELETE — the counterpart of
// `macro_goal_add_rollback_cloud_test.dart`, which covers the INSERT.
//
// `updateStatus` / `updateTitle` / `updateCategory` / `deleteGoal` all apply the
// change to `state` AND to the `macro_goals_cache` blob before the request goes
// out. Their Private-mode branches restore `previousState` when the write
// fails; their account-mode catch blocks used to only log and show the modal, so
// a failed mutation stayed on screen and — because the cache is what `build()`
// seeds from — survived a restart, until some later `_syncFromSupabase`
// replaced `state.goals` wholesale and silently undid it.
//
// The last test pins WHY the rollback is written per-goal instead of
// `state = previousState`: a whole-state restore would also revert a mutation
// that landed on a DIFFERENT goal while this request was in flight.
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

MacroGoal _goal({
  required String id,
  String title = 'Run a marathon',
  GoalStatus status = GoalStatus.active,
  String? categoryKey,
  String? categoryId,
}) => MacroGoal(
  id: id,
  title: title,
  status: status,
  type: GoalType.weekly,
  year: 2026,
  month: 8,
  weekNumber: 2,
  categoryKey: categoryKey,
  categoryId: categoryId,
  createdAt: DateTime.utc(2026, 8, 10),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `Supabase.initialize` builds a process-wide singleton, so it is called once
  // for the whole file and told per test what to answer.
  //
  // GET always fails: the initial `_syncFromSupabase` must NOT overwrite the
  // cache-seeded goals with the server's answer. `mutationResponse` decides
  // what the PATCH/DELETE under test gets.
  late Future<http.Response> Function(http.Request) mutationResponse;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((req) async {
        if (req.url.path.contains('/long_term_goals')) {
          if (req.method == 'GET') {
            return http.Response(
              '{"message":"boom"}',
              500,
              request: req,
              headers: {'content-type': 'application/json'},
            );
          }
          return mutationResponse(req);
        }
        return http.Response(
          '[]',
          200,
          request: req,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'not-a-jwt',
        'token_type': 'bearer',
        'user': {
          'id': _userId,
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
        },
      }),
    );
  });

  setUp(() {
    mutationResponse = (req) async => http.Response(
      '{"message":"boom"}',
      500,
      request: req,
      headers: {'content-type': 'application/json'},
    );
  });

  /// An account-mode container whose macro-goal cache already holds [goals].
  Future<(ProviderContainer, SharedPreferences)> cloudContainer(
    List<MacroGoal> goals,
  ) async {
    // No 'active_data_mode' key -> account (Supabase) mode, the default.
    SharedPreferences.setMockInitialValues(<String, Object>{
      _cacheKey: jsonEncode(goals.map((g) => g.toJson()).toList()),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    // Let the initial (failing) sync settle so it cannot land mid-test.
    container.read(macroGoalsProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    return (container, prefs);
  }

  test('a failed account-mode status UPDATE is rolled back', () async {
    final (container, prefs) = await cloudContainer([_goal(id: 'g1')]);

    await container
        .read(macroGoalsProvider.notifier)
        .updateStatus('g1', GoalStatus.completed);

    expect(
      container.read(macroGoalsProvider).goals.single.status,
      GoalStatus.active,
      reason: 'the UPDATE never landed, so the checkbox must not stay ticked',
    );
    expect(
      prefs.getString(_cacheKey),
      isNot(contains('completed')),
      reason: 'nor may it survive a restart via the offline mirror',
    );
  });

  test('a failed account-mode title UPDATE is rolled back', () async {
    final (container, prefs) = await cloudContainer([_goal(id: 'g1')]);

    await container
        .read(macroGoalsProvider.notifier)
        .updateTitle('g1', 'Renamed');

    expect(
      container.read(macroGoalsProvider).goals.single.title,
      'Run a marathon',
    );
    expect(prefs.getString(_cacheKey), isNot(contains('Renamed')));
  });

  test('a failed account-mode category UPDATE is rolled back', () async {
    final (container, prefs) = await cloudContainer([
      _goal(id: 'g1', categoryKey: 'salute', categoryId: 'cat-old'),
    ]);

    await container
        .read(macroGoalsProvider.notifier)
        .updateCategory('g1', 'cat-new');

    final goal = container.read(macroGoalsProvider).goals.single;
    expect(goal.categoryId, 'cat-old');
    expect(goal.categoryKey, 'salute');
    expect(prefs.getString(_cacheKey), isNot(contains('cat-new')));
  });

  test('a failed account-mode category CLEAR is rolled back', () async {
    // The clearing direction also nulls `category_key`, so both columns have to
    // come back.
    final (container, prefs) = await cloudContainer([
      _goal(id: 'g1', categoryKey: 'salute', categoryId: 'cat-old'),
    ]);

    await container
        .read(macroGoalsProvider.notifier)
        .updateCategory('g1', null);

    final goal = container.read(macroGoalsProvider).goals.single;
    expect(goal.categoryId, 'cat-old');
    expect(goal.categoryKey, 'salute');
    expect(prefs.getString(_cacheKey), contains('cat-old'));
  });

  test('a failed account-mode DELETE puts the goal back', () async {
    final (container, prefs) = await cloudContainer([
      _goal(id: 'g1'),
      _goal(id: 'g2', title: 'Read 24 books'),
    ]);

    await container.read(macroGoalsProvider.notifier).deleteGoal('g1');

    expect(
      container.read(macroGoalsProvider).goals.map((g) => g.id).toList(),
      ['g1', 'g2'],
      reason: 'the row is still on the server, and its position is unchanged',
    );
    expect(prefs.getString(_cacheKey), contains('g1'));
  });

  test('the rollback leaves a concurrent mutation on another goal alone',
      () async {
    final (container, prefs) = await cloudContainer([
      _goal(id: 'g1'),
      _goal(id: 'g2', title: 'Read 24 books'),
    ]);
    final notifier = container.read(macroGoalsProvider.notifier);

    // g1's UPDATE fails, but only after g2's DELETE has already succeeded.
    mutationResponse = (req) async {
      if (req.method == 'DELETE') {
        return http.Response(
          '',
          204,
          request: req,
          headers: {'content-type': 'application/json'},
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return http.Response(
        '{"message":"boom"}',
        500,
        request: req,
        headers: {'content-type': 'application/json'},
      );
    };

    final pendingUpdate = notifier.updateStatus('g1', GoalStatus.completed);
    await notifier.deleteGoal('g2');
    await pendingUpdate;

    expect(
      container.read(macroGoalsProvider).goals.map((g) => g.id).toList(),
      ['g1'],
      reason: 'g2 is gone server-side; rolling g1 back must not resurrect it',
    );
    expect(container.read(macroGoalsProvider).goals.single.status,
        GoalStatus.active);
    expect(prefs.getString(_cacheKey), isNot(contains('Read 24 books')));
  });
}
