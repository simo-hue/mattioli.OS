// The account-mode `profiles` read must depend on the ACCOUNT, not on the
// auth state object.
//
// `DesktopAuthState` does not override `==`, so Riverpod compares it by
// identity and a brand-new instance is assigned on every auth event — both legs
// of `_execute` (isLoading true, then false), the error leg, and, crucially,
// every Supabase token refresh, which re-emits `onAuthStateChange`
// (`desktop_subscription_controller.dart` says so in as many words: "Supabase
// re-emits this state on every token refresh; only a real account change needs
// a round-trip").
//
// Watching the whole state therefore re-selects `profiles` roughly hourly and
// re-applies theme/accent/language app-wide. Because
// `DesktopAppearanceController.setThemeMode`/`setAccentColor` persist to
// SharedPreferences ONLY and never to `profiles`, that periodic re-apply
// spontaneously reverts a local appearance change — most visibly the ⌘K
// "Switch to light/dark" command — while the user is working.
import 'dart:convert';

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every `profiles` request the mock backend saw, in order.
final List<Uri> _profilesReads = <Uri>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _silenceDeepLinks();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('profiles')) {
          _profilesReads.add(request.url);
        }
        return http.Response(
          jsonEncode({'id': 'user-a', 'theme_mode': 'light'}),
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
    LocaleSettings.setLocaleSync(AppLocale.en);
    _profilesReads.clear();
  });

  test('a token refresh does not re-read profiles', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser!;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        desktopAuthControllerProvider.overrideWith(() => _FakeAuth(user)),
      ],
    );
    addTearDown(container.dispose);
    // The app root holds this provider open; without a listener it would be
    // disposed between reads and every read would look like a fresh one.
    container.listen(
      desktopSyncedSettingsProvider,
      (_, _) {},
      fireImmediately: true,
    );

    await container.read(desktopSyncedSettingsProvider.future);
    expect(_profilesReads, hasLength(1), reason: 'precondition: read once');

    // Exactly what Supabase does on an hourly token refresh, and what
    // `_execute` does on each of its legs: a NEW DesktopAuthState carrying the
    // SAME account.
    final fake = container.read(desktopAuthControllerProvider.notifier);
    (fake as _FakeAuth).reemitSameAccount();
    await container.pump();
    await Future<void>.delayed(Duration.zero);

    expect(
      _profilesReads,
      hasLength(1),
      reason:
          'a token refresh is not an account change: re-reading profiles here '
          'reverts a local theme/accent choice under the user',
    );
  });

  test('a real account change still re-reads profiles', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser!;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        desktopAuthControllerProvider.overrideWith(() => _FakeAuth(user)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      desktopSyncedSettingsProvider,
      (_, _) {},
      fireImmediately: true,
    );

    await container.read(desktopSyncedSettingsProvider.future);
    expect(_profilesReads, hasLength(1));

    (container.read(desktopAuthControllerProvider.notifier) as _FakeAuth)
        .switchAccount(_userB);
    await container.pump();
    await container.read(desktopSyncedSettingsProvider.future);

    expect(_profilesReads, hasLength(2));
    expect(
      _profilesReads.last.query,
      contains('user-b'),
      reason: 'the new account is what gets read, not the old one',
    );
  });
}

/// A second account, for the "this really is still session-dependent" half.
final User _userB = User.fromJson(<String, dynamic>{
  'id': 'user-b',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'aud': 'authenticated',
  'created_at': '2026-01-01T00:00:00Z',
})!;

/// A [DesktopAuthController] whose state this test drives directly; the real
/// one only changes in response to a live Supabase session.
class _FakeAuth extends DesktopAuthController {
  _FakeAuth(this._user);

  final User _user;

  @override
  DesktopAuthState build() => DesktopAuthState(user: _user);

  /// A fresh state instance carrying the same account, as a token refresh or
  /// either leg of `_execute` produces.
  void reemitSameAccount() => state = DesktopAuthState(user: _user);

  void switchAccount(User next) => state = DesktopAuthState(user: next);
}

/// Silences the deep-link listener `Supabase.initialize` starts (see
/// `account_settings_reach_app_root_test.dart` for the full reasoning).
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
