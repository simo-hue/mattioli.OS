// A Keychain read already in flight must not undo the sign-out's entitlement
// drop.
//
// `_loadSecureSettings` reads `pref_is_pro`, then awaits three MORE sequential
// Keychain reads before applying `isPro: isProVal == 'true'` over whatever
// `state` has become in the meantime. A sign-out landing inside that window
// lowers `isPro` and rewrites both mirrors — and is then overwritten back to
// `true` by the value read before it. State says Pro, the mirrors say free, and
// the next `_saveToPrefs` writes Pro back to both: the leak the sign-out arm
// exists to close comes straight back.
//
// The window is not launch-only. `sync_refresh.dart` invalidates
// `settingsProvider` after every sync that applied remote changes (the 60s
// poll, app resume, a CloudKit push), so this load runs routinely — including
// on exactly the churny sessions where an involuntary sign-out (token rotation
// failure) is most likely.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/settings_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

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

/// A Keychain that PARKS on `pref_is_pro` — after taking its value, so the
/// stale `'true'` is already captured — until the test releases it. That is the
/// real window: the reads either side of it are ordinary awaits on a platform
/// channel, and anything can land in between.
class _GatedSecureStorage extends FlutterSecureStorage {
  _GatedSecureStorage({
    required this.values,
    required this.reachedIsPro,
    required this.release,
  });

  final Map<String, String> values;
  final Completer<void> reachedIsPro;
  final Future<void> release;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final value = values[key];
    if (key == 'pref_is_pro') {
      if (!reachedIsPro.isCompleted) reachedIsPro.complete();
      await release;
    }
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      // `profiles` does not answer — the finding's own scenario, and what makes
      // the in-memory entitlement the only thing standing.
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

  test('THE RACE: a pending Keychain read must not reinstate the signed-out '
      "account's Pro", () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pref_is_pro': true,
    });
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'pref_is_pro': 'true',
    });
    final prefs = await SharedPreferences.getInstance();
    final reachedIsPro = Completer<void>();
    final release = Completer<void>();
    final auth = _TestAuth();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authProvider.overrideWith(() => auth),
      secureStorageProvider.overrideWithValue(_GatedSecureStorage(
        values: const {'pref_is_pro': 'true'},
        reachedIsPro: reachedIsPro,
        release: release.future,
      )),
    ]);
    addTearDown(c.dispose);

    expect(c.read(settingsProvider).isPro, isTrue,
        reason: 'precondition: A holds Pro, seeded offline-first from prefs');

    // The secure load is now parked mid-flight, holding A's `'true'`.
    await reachedIsPro.future;

    auth.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(settingsProvider).isPro, isFalse,
        reason: 'precondition: the sign-out arm dropped the entitlement');

    // The stale read resolves. It must land NOTHING.
    release.complete();
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(c.read(settingsProvider).isPro, isFalse,
        reason: 'the value was read before the sign-out wrote false; applying '
            'it re-grants Pro, and the next _saveToPrefs pushes it back into '
            'both mirrors');
    expect(prefs.getBool('pref_is_pro'), isFalse,
        reason: 'state and the mirrors must not disagree');
  });

  test('an uninterrupted secure load still applies', () async {
    // The generation check must retire only ABANDONED loads: the ordinary
    // cold-start read of the Keychain mirror is what makes a paying user Pro
    // before `profiles` answers.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pref_is_pro': false,
    });
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final prefs = await SharedPreferences.getInstance();
    final release = Completer<void>()..complete();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_TestAuth.new),
      secureStorageProvider.overrideWithValue(_GatedSecureStorage(
        values: const {'pref_is_pro': 'true'},
        reachedIsPro: Completer<void>(),
        release: release.future,
      )),
    ]);
    addTearDown(c.dispose);

    expect(c.read(settingsProvider).isPro, isFalse);
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(c.read(settingsProvider).isPro, isTrue,
        reason: 'the Keychain mirror is the offline-first source of the '
            "entitlement; the guard must not swallow this session's own load");
  });
}
