// `macro_goals_cache` is a single, non-user-keyed blob shared by every account
// on the device — exactly like `goals_cache` / `goal_logs_cache` /
// `goal_progress_cache`, which are all gated by `cacheSeedAllowed(userId)` /
// `rememberCacheOwner(userId)` against `kCacheOwnerKey`. This one was gated on
// neither, and it is only cleared by an auth listener that a lazily-built
// provider may never register: MacroGoalsScreen is index 2 of a lazy PageView,
// so a session that never opened the Goals tab never built this provider, and
// the sign-out that followed left the blob in place. The next account's first
// build then seeded ITS state from the previous account's long-term goals — and
// if its own first sync failed, the catch deliberately keeps "la cache locale".
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/goal_provider.dart' show kCacheOwnerKey;
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// The account actually signed in for these tests.
const _currentUser = 'user-b';

class _TestAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        isLoggedIn: true,
        user: Supabase.instance.client.auth.currentUser,
        dataMode: AppDataMode.supabase,
      );
}

String _cacheBlob() => jsonEncode([
      {
        'id': 'macro-1',
        'title': "A's long-term goal",
        'status': 'active',
        'type': 'lifetime',
        'created_at': '2026-01-01T00:00:00.000Z',
      },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      // The sync FAILS: the scenario the finding describes, and the state in
      // which `_syncFromSupabase`'s catch deliberately keeps whatever the cache
      // put in `state`.
      httpClient: MockClient((req) async => http.Response('[]', 500,
          request: req, headers: {'content-type': 'application/json'})),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'not-a-jwt',
      'token_type': 'bearer',
      'user': {
        'id': _currentUser,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
      },
    }));
  });

  Future<ProviderContainer> container({required String? cacheOwner}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'macro_goals_cache': _cacheBlob(),
    });
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      kCacheOwnerKey: ?cacheOwner,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_TestAuth.new),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('THE LEAK: another account\'s cached macro goals must not seed this one',
      () async {
    final c = await container(cacheOwner: 'user-a');

    c.read(macroGoalsProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(macroGoalsProvider).goals, isEmpty,
        reason: "the blob belongs to user-a; user-b must not inherit it, and "
            'the failed sync leaves it in place for the whole session');
  });

  test('the owning account IS still seeded from the mirror', () async {
    // The guard must refuse the wrong account, not the offline mirror itself.
    final c = await container(cacheOwner: _currentUser);

    c.read(macroGoalsProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(macroGoalsProvider).goals.map((g) => g.id), ['macro-1']);
  });

  test('an UNOWNED blob is refused rather than trusted', () async {
    // Mirrors `cacheSeedAllowed`: a blob with no recorded owner can only be a
    // leftover from a build that did not stamp one, and its account is
    // unknowable.
    final c = await container(cacheOwner: null);

    c.read(macroGoalsProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(macroGoalsProvider).goals, isEmpty);
  });
}
