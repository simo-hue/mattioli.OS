// App Lock is DEVICE-LOCAL, and account mode was the last place it was not.
//
// Private mode already treats `biometric_lock` as a device-local column
// (`PrivateDbSchema.deviceLocalProfileColumns`, pinned by
// `settings_synced_readback_test` and `import_merge_lww_test`), and mobile
// refuses the server value outright — "a Face ID lock set on THIS phone must
// not be silently disabled by a stale value, or a value from another device".
//
// Desktop's account-mode hydration still read `profiles.biometric_lock` and
// pushed it through `applyProfile`, and `setEnabled` still upserted the column.
// So the iPhone turning Face ID off reached across and disarmed Touch ID on the
// Mac — writing `false` into SharedPreferences and the Keychain, so the Mac
// opened straight into the shell from then on. The reverse could arm a lock the
// Mac's owner never asked for.
import 'dart:convert';

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/settings/application/desktop_biometric_controller.dart';
import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every request the app made, so the write half can be asserted on.
final _requests = <http.BaseRequest>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _silenceDeepLinks();
    LocaleSettings.setLocale(AppLocale.it);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((request) async {
        _requests.add(request);
        // The other device's row: App Lock OFF over there.
        return http.Response(
          jsonEncode({
            'id': 'user-a',
            'biometric_lock': false,
            'theme_mode': 'dark',
          }),
          200,
          request: request,
          headers: const {'content-type': 'application/json'},
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
          'id': 'user-a',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
        },
      }),
    );
  });

  setUp(() {
    LocaleSettings.setLocale(AppLocale.it);
    _requests.clear();
  });

  test(
    "another device's biometric_lock:false must not disarm this Mac's App Lock",
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pref_biometric_lock': true,
      });
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'pref_biometric_lock': 'true',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(desktopBiometricControllerProvider).enabled,
        isTrue,
        reason: 'precondition: Touch ID App Lock is armed on this Mac',
      );

      final controller = container.read(
        settingsFormControllerProvider.notifier,
      );
      final token = controller.hydrate();
      addTearDown(() => controller.detach(token));
      await controller.loadProfilePreferences();
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(desktopBiometricControllerProvider).enabled,
        isTrue,
        reason: 'the lock is device-local; the synced row has no say over it',
      );
      expect(
        prefs.getBool('pref_biometric_lock'),
        isTrue,
        reason: 'and the local mirror is not rewritten to the remote value',
      );
      expect(
        await SecureStorageProbe.read(),
        'true',
        reason: 'nor is the Keychain copy the gate reads on the next launch',
      );
    },
  );

  test(
    'turning App Lock off on the Mac does not write the shared column',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pref_biometric_lock': true,
      });
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'pref_biometric_lock': 'true',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final biometric = container.read(
        desktopBiometricControllerProvider.notifier,
      );
      // Let the unawaited Keychain read in `build` land first, so it cannot
      // re-raise `enabled` after the call below lowered it.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await biometric.setEnabled(false);

      expect(
        container.read(desktopBiometricControllerProvider).enabled,
        isFalse,
        reason: 'the local lock still turns off locally',
      );
      expect(
        _requests.where((r) => r.url.path.contains('profiles')),
        isEmpty,
        reason:
            'the Mac is neither reader nor writer of this cross-device column',
      );
    },
  );
}

/// Reads the Keychain copy through the same handle the controller writes.
class SecureStorageProbe {
  static Future<String?> read() =>
      const FlutterSecureStorage().read(key: 'pref_biometric_lock');
}

/// Silences the deep-link listener `Supabase.initialize` starts.
///
/// `supabase_flutter` subscribes to app_links' event channel for OAuth
/// callbacks; under `flutter test` that throws a MissingPluginException
/// ASYNCHRONOUSLY, which the framework then charges to whichever test happens
/// to be running when it lands — a cross-file flake, not a real failure.
/// Answered through the plain method-call mock (an EventChannel's `listen` is
/// an ordinary method call) because `setMockStreamHandler` registers an
/// `addTearDown` and so cannot run in `setUpAll`, which is where this has to
/// be: the subscription starts inside `Supabase.initialize`.
void _silenceDeepLinks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.app_links/events'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.app_links/messages'),
    (call) async => null,
  );
}
