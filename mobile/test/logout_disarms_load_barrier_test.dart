// Signing out must DISARM the load barrier, not just empty `state`.
//
// The login arm of each notifier's auth listener re-arms `_initialLoad` with a
// comment saying why: "a transient logout empties state without rebuilding the
// notifier". The logout arm itself did only `state = []` — leaving
// `_initialLoad` pointing at the PREVIOUS, already-completed load and
// `_syncFailed` false. `ensureLoaded()` therefore vouched for the empty list it
// had just been handed, and the destructive callers that ask it before acting
// on emptiness (`main.dart`'s Screen Time sync, which reads `[]` as "stop
// monitoring everything", and the progress sweep) were told the emptiness was
// real.
//
// The same hole exists on the no-session build path, where `_initialLoad = null`
// and `awaitStableBarrier` returns true for a null barrier.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'support/fake_private_data_store.dart';

const _userId = 'u1';

/// An auth state the test drives directly, so the sign-out can be emitted
/// in-process without a real Supabase session teardown.
class _TestAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        isLoggedIn: true,
        user: Supabase.instance.client.auth.currentUser,
      );

  void signOut() => state = const AuthState(isLoggedIn: false);
}

String _goalsBody() => jsonEncode([
      {
        'id': 'g1',
        'title': 'From the server',
        'color': '#3B82F6',
        'start_date': '2026-01-01T00:00:00.000Z',
      },
    ]);

String _logsBody() => jsonEncode([
      {
        'id': 'l1',
        'goal_id': 'g1',
        'date': '2026-01-02',
        'status': 'done',
      },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((req) async {
        final body = req.url.path.contains('/goal_logs')
            ? _logsBody()
            : req.url.path.contains('/goals')
                ? _goalsBody()
                : '[]';
        return http.Response(body, 200,
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

  Future<ProviderContainer> container(_TestAuth auth) async {
    // No cache owner: the mirror must NOT seed, so `_cacheSeeded` stays false
    // and the successful server sync is the only thing making the load
    // trustworthy — exactly the state a sign-out has to revoke.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => auth),
        privateLocalDatabaseProvider
            .overrideWith((ref) => FakePrivateDataStore()),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
        initialProgressProvider.overrideWithValue('{}'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
      'THE GAP: after a successful load, signing out must make the habit list '
      'UNTRUSTWORTHY', () async {
    final auth = _TestAuth();
    final c = await container(auth);

    expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue,
        reason: 'precondition: the server answered');
    expect(c.read(goalsProvider), isNotEmpty);

    auth.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(goalsProvider), isEmpty,
        reason: 'the logout arm empties state for the /login redirect');
    expect(await c.read(goalsProvider.notifier).ensureLoaded(), isFalse,
        reason: 'that emptiness is a sign-out, not "this user has no habits" — '
            'the Screen Time sync must not tear monitoring down over it');
  });

  test('signing out makes the verdict map UNTRUSTWORTHY too', () async {
    final auth = _TestAuth();
    final c = await container(auth);

    expect(await c.read(habitLogsProvider.notifier).ensureLoaded(), isTrue,
        reason: 'precondition: the server answered');
    expect(c.read(habitLogsProvider), isNotEmpty);

    auth.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(habitLogsProvider), isEmpty);
    expect(await c.read(habitLogsProvider.notifier).ensureLoaded(), isFalse,
        reason: 'an emptied map after sign-out cannot be read as "no verdicts '
            'stored"');
  });
}
