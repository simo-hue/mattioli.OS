// In ACCOUNT mode the synced settings only reached the app when the Settings
// page was open.
//
// `loadProfilePreferences` is the only `profiles` settings SELECT in
// `desktop/lib`, and it has exactly one caller chain: hydrate <- initState of
// SettingsPage. So a Mac signed into an account whose profile says
// `theme_mode: light`, `accent_color: #FF9500`, `language: it` rendered in the
// system language with the default dark appearance until the user happened to
// open Settings — and after A signed out, B inherited A's look for the same
// reason.
//
// Private mode already had the app-wide read-back
// (`desktopSyncedSettingsProvider`, listened to at the app root under the
// comment "a theme/accent/language changed on the iPhone has to repaint the Mac
// even when Settings is closed"); account mode short-circuited that provider to
// an empty map.
import 'dart:convert';

import 'package:evolve_desktop/app/evolve_desktop_app.dart';
import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _silenceDeepLinks();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((request) async {
        // The account's profile, as set on the user's iPhone.
        return http.Response(
          jsonEncode({
            'id': 'user-a',
            'theme_mode': 'light',
            'accent_color': '#FF9500',
            'language': 'it',
            'notif_habit_reminders': false,
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

  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets("the account's theme, accent and language reach the app without "
      'opening Settings', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(desktopAppearanceControllerProvider).themeMode,
      isNot(ThemeMode.light),
      reason: 'precondition: nothing local says light',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const EvolveDesktopApp(),
      ),
    );
    // Let the profiles read land. No Settings page is ever mounted.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(Duration.zero);

    expect(
      container.read(desktopAppearanceControllerProvider).themeMode,
      ThemeMode.light,
      reason: "the account's theme repaints the Mac with Settings closed",
    );
    expect(
      container.read(desktopAppearanceControllerProvider).accentColor,
      const Color(0xFFFF9500),
      reason: 'and so does its accent',
    );
    expect(
      container.read(desktopLocaleControllerProvider),
      const Locale('it'),
      reason: 'and its language',
    );

    // Drains the zero-duration timer the deferred `it` translation load posts.
    await tester.pump(Duration.zero);
  });

  testWidgets('the read still omits what the account never set', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const EvolveDesktopApp(),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    final values = container.read(desktopSyncedSettingsProvider).value;
    expect(values, isNotNull);
    expect(
      values!.containsKey(kSettingMorningBriefTime),
      isFalse,
      reason:
          'an absent column must not arrive as a fabricated value — every '
          'listener reads "key present" as "the store has an opinion"',
    );
    expect(
      values[kSettingHabitReminders],
      '0',
      reason: 'booleans keep the canonical 1/0 encoding both stores use',
    );
  });
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
