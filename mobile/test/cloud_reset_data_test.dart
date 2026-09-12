// Regression test for the Account-mode (cloud) reset in
// `privacy_settings_screen.dart::_resetData`.
//
// F17 — the cloud branch was exactly two deletes (goals, long_term_goals) behind
//   a confirmation that promises "delete all your data". `daily_moods.user_id`
//   cascades from `auth.users`, NOT from goals, and `macro_goal_categories` is
//   its own table, so every mood/energy check-in and every category survived a
//   reset the user was told was total. The private branch wipes eight tables by
//   name for exactly this reason.
//
// The reset lives in a widget callback behind a Supabase client, so the test
// drives the REAL screen against a MockClient backend and asserts on the DELETEs
// that reach the wire.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/privacy_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Reports logged-out so the screen's data providers skip their Supabase sync
/// during render. `_resetData` doesn't consult it — it reads the global Supabase
/// session — so the reset still runs.
class _LoggedOutAuth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isLoggedIn: false, dataMode: AppDataMode.supabase);
}

/// Every request the fake backend saw, as "METHOD table?query".
final List<String> _requests = [];

http.Response _json(Object body, http.BaseRequest req, [int code = 200]) =>
    http.Response(jsonEncode(body), code,
        request: req, headers: {'content-type': 'application/json'});

MockClient _backend() => MockClient((req) async {
      _requests.add('${req.method} ${req.url.pathSegments.last}'
          '?${req.url.query}');
      return _json(const <dynamic>[], req);
    });

/// The tables a DELETE was issued against, scoped to the signed-in user.
Set<String> _deletedTables() => _requests
    .where((r) => r.startsWith('DELETE ') && r.contains('user_id=eq.u1'))
    .map((r) => r.substring('DELETE '.length).split('?').first)
    .toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: _backend(),
      debug: false,
    );
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
  });

  setUp(() => _requests.clear());

  testWidgets('F17: the account reset deletes moods and categories too',
      (tester) async {
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

    final entry = find.text(t.privacy.deleteAccountData);
    await tester.scrollUntilVisible(entry, 200);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.privacy.resetData));
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.common.actions.confirm));
    await tester.pumpAndSettle();

    // The reset's awaits are not scheduled frames, so give it real time.
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!_deletedTables().contains('long_term_goals') &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();

    final deleted = _deletedTables();
    expect(deleted, contains('goals'));
    expect(deleted, contains('long_term_goals'));
    expect(deleted, contains('daily_moods'),
        reason: 'daily_moods cascades from auth.users, not from goals — a reset '
            'that never names it leaves every check-in on the server');
    expect(deleted, contains('macro_goal_categories'),
        reason: 'categories are their own table and survive the goals delete');

    // Drain AppLogger's flush timer and the success toast.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
