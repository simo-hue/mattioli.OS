import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the real notifier so the screen can be driven without a
/// Supabase client. Mirrors the contract AuthNotifier actually implements:
/// a failure returns false and parks a localized message on `error`, while
/// signUp returns true and uses the same `error` field for the "confirm your
/// registration" notice.
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier({this.loginError, this.signUpNotice});

  final String? loginError;
  final String? signUpNotice;

  @override
  AuthState build() => const AuthState(isLoggedIn: false);

  @override
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: false, error: loginError);
    return false;
  }

  @override
  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: false, error: signUpNotice);
    return true;
  }
}

Future<void> _pumpAuthScreen(
  WidgetTester tester,
  _FakeAuthNotifier notifier,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => notifier),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const AuthScreen(),
        ),
      ),
    ),
  );
  // Run out the 800ms entrance fade/slide: until it completes the content is
  // still transparent and offset, so taps do not land on it.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

/// Fills the form with credentials that pass the local validators, so submit
/// actually reaches the notifier.
Future<void> _submit(WidgetTester tester, String buttonLabel) async {
  await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
  await tester.enterText(find.byType(TextFormField).last, 'hunter2');
  await _tap(tester, buttonLabel);
  await tester.pump(const Duration(milliseconds: 50));
}

/// The form scrolls, so a control can sit outside the test viewport; scroll it
/// in before tapping or the hit test silently misses.
Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  testWidgets('a failed sign-in surfaces its error even though the '
      'localized text contains "email"', (tester) async {
    // The EN string for a wrong password. It contains the substring 'email',
    // which the screen previously used to classify messages as notices.
    const message = 'Incorrect email or password.';
    await _pumpAuthScreen(tester, _FakeAuthNotifier(loginError: message));

    await _submit(tester, 'Log In');

    expect(find.text(message), findsOneWidget);
    // The destructive banner is the only thing on this screen using this icon.
    expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
  });

  testWidgets('a failed sign-in whose text has no "email" still surfaces',
      (tester) async {
    const message = 'Network error. Please try again.';
    await _pumpAuthScreen(tester, _FakeAuthNotifier(loginError: message));

    await _submit(tester, 'Log In');

    expect(find.text(message), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
  });

  testWidgets('the sign-up confirmation notice is not painted as an error',
      (tester) async {
    // signUp returns true and leaves this on `error`; it is a notice, so the
    // destructive banner must stay away and let the success toast carry it.
    const notice = 'Check your email to confirm your registration.';
    await _pumpAuthScreen(tester, _FakeAuthNotifier(signUpNotice: notice));

    await _tap(tester, 'Sign Up');
    // Let the mode-switch animation settle so the signup form is laid out.
    await tester.pump(const Duration(milliseconds: 900));

    await _submit(tester, 'Create Account');

    // No destructive banner...
    expect(find.byIcon(LucideIcons.circleAlert), findsNothing);
    // ...and the notice reached the user as a success toast instead.
    expect(find.text(notice), findsOneWidget);
    expect(
      find.byIcon(CupertinoIcons.check_mark_circled_solid),
      findsOneWidget,
    );

    // Let the toast's timers drain so the test leaves nothing pending.
    await tester.pump(const Duration(seconds: 6));
  });
}
