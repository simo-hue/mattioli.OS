// Regression guard: deleting the account must purge the BYOK OpenRouter API key
// from the Keychain.
//
// The key (`OpenRouterKeyStore.storageKey`, general Keychain tier) survives even
// an app uninstall, so if account deletion leaves it behind, the next user of a
// shared/resold device inherits it and spends the deleted account's OpenRouter
// credits. `_deleteAccount` already purges the cache-owner marker on erasure;
// these tests pin that it also purges the BYOK key, and that the purge is
// resilient — it must run even when an earlier teardown step (here: cancelAll)
// throws, and must never abort the sign-out that frees the user.
//
// The account-deletion flow is cloud-only and reachable only through the UI, so
// the test drives the real screen. To keep the render network-free, `authProvider`
// is overridden to report logged-out (every data provider gates its Supabase
// sync on it), while the global Supabase session still carries a user —
// `_deleteAccount` reads `Supabase.instance.client.auth.currentUser` directly, so
// it still runs. A permissive MockClient answers the delete RPC and sign-out.
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/openrouter_service.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/privacy_settings_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

const String _kByokValue = 'sk-or-v1-secret-should-be-purged';

/// Notifications platform whose `cancelAll` succeeds (no-op). Used for the
/// happy-path teardown.
class _NoopNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancelAll() async {}
}

/// Notifications platform whose `cancelAll` throws — the "an earlier teardown
/// step fails" scenario the BYOK purge must survive.
class _ThrowingNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancelAll() async => throw StateError('cancelAll boom');
}

/// Reports logged-out so the data providers skip their Supabase/RevenueCat sync
/// during render. `_deleteAccount` doesn't consult this — it reads the global
/// Supabase session — so the delete still executes.
class _LoggedOutAuth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isLoggedIn: false, dataMode: AppDataMode.supabase);
}

Future<void> _seedSignedInSession() async {
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
}

Future<void> _pumpAndDeleteAccount(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_LoggedOutAuth.new),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const PrivacySettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Cloud-mode "Delete Account Data" row → the delete/reset sheet.
  await tester.tap(find.text(t.privacy.deleteAccountData));
  await tester.pumpAndSettle();

  // "Delete Account" row → confirmation dialog.
  await tester.tap(find.text(t.privacy.deleteAccount));
  await tester.pumpAndSettle();

  // Confirm → runs _deleteAccount (RPC + on-device teardown + BYOK purge).
  await tester.tap(
    find.widgetWithText(CupertinoDialogAction, t.common.actions.confirm),
  );
  await tester.pumpAndSettle();

  // The error path logs via AppLogger, which schedules a bare 2s flush timer
  // (its callback swallows the test-only file-IO failure). Advance past it so no
  // Timer outlives the widget tree, then let any resulting animation settle.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Supabase.initialize builds a SharedPreferences-backed gotrue store, so the
    // prefs mock must exist before it runs.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final mock = MockClient((req) async {
      // Everything the flow touches (delete_user_account RPC, sign-out, any
      // stray provider read) answers 200 with an empty body.
      return http.Response(jsonEncode(const <dynamic>[]), 200,
          request: req, headers: {'content-type': 'application/json'});
    });
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: mock,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
  });

  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      OpenRouterKeyStore.storageKey: _kByokValue,
    });
    await _seedSignedInSession();
  });

  testWidgets('purges the BYOK OpenRouter key on account deletion',
      (tester) async {
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();

    // Precondition: the key is present before deletion.
    expect(await const OpenRouterKeyStore().read(), _kByokValue);

    await _pumpAndDeleteAccount(tester);

    expect(await const OpenRouterKeyStore().read(), isNull,
        reason: 'account deletion must purge the BYOK key from the Keychain');
  });

  testWidgets(
      'still purges the BYOK key when an earlier teardown step throws',
      (tester) async {
    // cancelAll throws mid-teardown: without the finally-guarded purge the key
    // would leak, exactly the resilience this fix adds.
    FlutterLocalNotificationsPlatform.instance =
        _ThrowingNotificationsPlatform();

    expect(await const OpenRouterKeyStore().read(), _kByokValue);

    await _pumpAndDeleteAccount(tester);

    expect(await const OpenRouterKeyStore().read(), isNull,
        reason: 'the BYOK purge must run even if an earlier teardown step '
            'throws, so the key can never outlive the deleted account');
  });
}
