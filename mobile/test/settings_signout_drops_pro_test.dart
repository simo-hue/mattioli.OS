// Signing out of an account must drop that account's Pro entitlement.
//
// `settingsProvider` was the only auth-dependent provider whose
// `ref.listen(authProvider)` had a login arm and no logout arm: goalsProvider,
// habitLogsProvider, habitProgressProvider, macroGoalsProvider and
// dailyMoodsProvider all clear on sign-out. So `state.isPro` — and the
// `pref_is_pro` mirrors in BOTH SharedPreferences and the Keychain — survived
// the sign-out untouched, and the next account on the same device held the
// previous one's subscription for as long as it took `profiles` to answer, or
// for the whole session when that select failed (it is caught and swallowed),
// or on any later cold start before a sync landed.
//
// Desktop closed the identical gap and documented it in
// desktop_subscription_controller.dart: "Nothing else resets this provider on
// sign-out, so the entitlement has to be dropped here or it survives into the
// next account's session."
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/settings_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'support/fake_private_data_store.dart';

/// Drives the sign-out in-process.
class _TestAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        isLoggedIn: true,
        user: Supabase.instance.client.auth.currentUser,
        dataMode: AppDataMode.supabase,
      );

  void signOut() => state = const AuthState(
        isLoggedIn: false,
        dataMode: AppDataMode.supabase,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      // The `profiles` select fails: the finding's own scenario — the arm has to
      // drop the entitlement without help from the server, because the server
      // is exactly what may not answer.
      httpClient: MockClient((req) async => http.Response('[]', 500,
          request: req, headers: {'content-type': 'application/json'})),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'not-a-jwt',
      'token_type': 'bearer',
      'user': {
        'id': 'user-a',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
      },
    }));
  });

  test('THE GAP: signing out drops Pro from state and from both mirrors',
      () async {
    // Account A is a paying subscriber, cached in both mirrors.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pref_is_pro': true,
    });
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'pref_is_pro': 'true',
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = _TestAuth();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authProvider.overrideWith(() => auth),
    ]);
    addTearDown(c.dispose);

    expect(c.read(settingsProvider).isPro, isTrue,
        reason: 'precondition: A holds Pro, seeded offline-first from prefs');
    // Let the async Keychain load settle, so the assertion below cannot pass
    // merely because it had not run yet.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(settingsProvider).isPro, isTrue);

    auth.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(settingsProvider).isPro, isFalse,
        reason: 'no session, no entitlement — B must not inherit A\'s Pro');
    expect(prefs.getBool('pref_is_pro'), isFalse,
        reason: 'the SharedPreferences mirror is what a cold start reads');
    expect(
      await const FlutterSecureStorage().read(key: 'pref_is_pro'),
      'false',
      reason: 'the Keychain mirror overrides prefs a moment later, so leaving '
          'it at true re-grants Pro asynchronously',
    );
  });

  test('a private-mode session keeps its unlocked entitlement', () async {
    // Private mode reports `isLoggedIn: false` permanently and forces isPro
    // true; the logout arm must not read that as a sign-out and lock the app's
    // own features away from a user who has no account by design.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_data_mode': 'private',
    });
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      privateLocalDatabaseProvider
          .overrideWith((ref) => FakePrivateDataStore()),
    ]);
    addTearDown(c.dispose);

    expect(c.read(settingsProvider).isPro, isTrue);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(settingsProvider).isPro, isTrue);
  });
}
