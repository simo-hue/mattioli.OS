// The CLOUD half of GoalsNotifier's load-trustworthiness rule.
//
// `goals_load_barrier_test.dart` runs entirely in Private mode over a fake
// store, and `_syncFromSupabase` early-returns on its first line in that mode
// (`if (ref.read(activeDataModeProvider) == AppDataMode.private) return;`). So
// the whole cloud try/catch — and with it the `_syncFailed = true` that protects
// an account-mode user whose sync fails offline / on a 5xx / on an expired
// token — was reachable by no test at all: deleting it left the entire suite
// green.
//
// The same blind spot hid something sharper. `_cacheSeeded` is set TRUE only in
// `_seedFromCache`, and cleared only in `build()` and the auth listener.
// `build()` re-runs on `ref.watch(activeDataModeProvider)`, so a cloud -> private
// switch carrying a stale `_cacheSeeded = true` would make
// `loadIsTrustworthy(settled: true, syncFailed: true, cacheSeeded: true)` return
// TRUE over the `[]` a FAILED private load left behind — resurrecting the exact
// defect the flag exists to prevent. The last test here is that switch.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_private_data_store.dart';

const _userId = 'u1';

/// Lets a test drive the data mode directly, so the cloud -> private switch that
/// re-runs `build()` can be performed in-process.
class _ModeNotifier extends ActiveDataModeNotifier {
  _ModeNotifier(this._mode);
  AppDataMode _mode;

  @override
  AppDataMode build() => _mode;

  void set(AppDataMode mode) {
    _mode = mode;
    state = mode;
  }
}

/// A private store whose load always fails — the `[]` it leaves behind is the
/// FAILURE, which is the whole point of the final test.
class _ThrowingStore extends FakePrivateDataStore {
  @override
  Future<List<Goal>> loadGoals() async => throw StateError('disk failure');
}

String _cacheBlob() => jsonEncode([
      {
        'id': 'cached-1',
        'title': 'From the offline mirror',
        'color': '#3B82F6',
        'start_date': '2026-01-01T00:00:00.000Z',
      },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `Supabase.initialize` builds a process-wide singleton, so it can be called
  // exactly ONCE for the whole file. The client therefore has to be told per
  // test what to answer, rather than each test bringing its own.
  var goalsStatus = 200;
  var goalsBody = '[]';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((req) async {
        if (req.url.path.contains('/goals')) {
          return http.Response(goalsBody, goalsStatus,
              request: req, headers: {'content-type': 'application/json'});
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

  /// Points the shared client at [status]/[body] for the test about to run.
  void serverAnswers(int status, {String body = '[]'}) {
    goalsStatus = status;
    goalsBody = body;
  }

  /// [cacheOwned] decides whether the offline mirror is allowed to seed — i.e.
  /// whether `_cacheSeeded` can become true.
  Future<ProviderContainer> container({
    required bool cacheOwned,
    required _ModeNotifier mode,
    FakePrivateDataStore? store,
  }) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      if (cacheOwned) kCacheOwnerKey: _userId,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        activeDataModeProvider.overrideWith(() => mode),
        privateLocalDatabaseProvider
            .overrideWith((ref) => store ?? FakePrivateDataStore()),
        initialGoalsProvider
            .overrideWithValue(cacheOwned ? _cacheBlob() : '[]'),
        initialLogsProvider.overrideWithValue('{}'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('cloud mode', () {
    test('THE GAP: a FAILED server sync reports UNTRUSTWORTHY', () async {
      serverAnswers(500);
      final c = await container(
        cacheOwned: false,
        mode: _ModeNotifier(AppDataMode.supabase),
      );

      final loaded = await c.read(goalsProvider.notifier).ensureLoaded();
      final goals = c.read(goalsProvider);

      expect(loaded, isFalse,
          reason: 'offline / 5xx / expired token leaves build()\'s empty list, '
              'and that emptiness is the failure — not an empty account');
      expect(goals, isEmpty);
      expect(!loaded && goals.isEmpty, isTrue,
          reason: 'the guard both destructive callers use must fire');
    });

    test('a successful sync is trustworthy', () async {
      serverAnswers(200, body: _cacheBlob());
      final c = await container(
        cacheOwned: false,
        mode: _ModeNotifier(AppDataMode.supabase),
      );

      expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue);
      expect(c.read(goalsProvider), isNotEmpty);
    });

    test('a genuinely empty account is trustworthy', () async {
      serverAnswers(200);
      final c = await container(
        cacheOwned: false,
        mode: _ModeNotifier(AppDataMode.supabase),
      );

      final loaded = await c.read(goalsProvider.notifier).ensureLoaded();

      expect(loaded, isTrue,
          reason: 'the server answered — "no habits" is a real answer');
      expect(c.read(goalsProvider), isEmpty);
    });

    test('the offline mirror rescues a failed sync', () async {
      // loadIsTrustworthy = settled && (!syncFailed || cacheSeeded): the cache
      // holds real habits, so acting on them is safe even though the server
      // could not be reached. This is what sets _cacheSeeded.
      serverAnswers(500);
      final c = await container(
        cacheOwned: true,
        mode: _ModeNotifier(AppDataMode.supabase),
      );

      final loaded = await c.read(goalsProvider.notifier).ensureLoaded();

      expect(loaded, isTrue);
      expect(c.read(goalsProvider).map((g) => g.id), ['cached-1']);
    });
  });

  group('the mode switch', () {
    test(
        'THE LEAK: a cache-seeded cloud session must not vouch for a FAILED '
        'private load after switching mode', () async {
      // _cacheSeeded is set only in _seedFromCache and cleared only in build()
      // and the auth listener. build() re-runs on the mode switch — if it did
      // NOT clear the flag, the stale `true` would rescue the empty list left
      // by the throwing private store below, and ensureLoaded would report it
      // as trustworthy. Nothing else in the suite can reach this.
      serverAnswers(500);
      final mode = _ModeNotifier(AppDataMode.supabase);
      final c = await container(
        cacheOwned: true,
        mode: mode,
        store: _ThrowingStore(),
      );

      expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue,
          reason: 'precondition: the cache seeded, so _cacheSeeded is true');

      mode.set(AppDataMode.private);
      c.read(goalsProvider); // force the rebuild

      final loaded = await c.read(goalsProvider.notifier).ensureLoaded();
      final goals = c.read(goalsProvider);

      expect(goals, isEmpty, reason: 'the private load threw');
      expect(loaded, isFalse,
          reason: 'build() must have cleared _cacheSeeded — a stale seed from '
              'the previous mode cannot vouch for this failed load');
    });
  });
}
