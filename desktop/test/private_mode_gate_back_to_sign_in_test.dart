// "Torna all'accesso" on the Private-mode recovery screen must take the user to
// the sign-in page — not to the dead-end configuration error page.
//
// Launching with `active_data_mode = 'private'` means `main.dart` skipped
// `Supabase.initialize` entirely, so `supabaseClientProvider` has already
// cached null. `_backToSignIn` only flipped the persisted data mode, and the
// app root then resolves `!backendConfigured && !isPrivateMode` to
// `_DesktopBackendConfigurationErrorPage`: a hardcoded-Italian sentence with no
// buttons and no way back into Private mode short of quitting the app.
//
// `DesktopAuthController.goToLogin()` is the one path that does the lazy
// validate + initialize + `ref.invalidate(supabaseClientProvider)` BEFORE
// flipping the mode — `account_pane.dart` already uses it. This gate was the
// only bypass, under a comment claiming "the user is never stranded".
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/presentation/private_mode_gate.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records whether the gate went through the backend-aware exit.
///
/// It does NOT call `super.goToLogin()`: the real one reaches
/// `DesktopSupabaseConfig.validate()` and `Supabase.initialize`, neither of
/// which is available under `flutter test`. What is under test here is WHICH
/// exit the button takes, which is exactly what the app root's
/// `supabaseClientProvider` read depends on.
class _SpyAuthController extends DesktopAuthController {
  bool wentToLogin = false;

  @override
  DesktopAuthState build() => const DesktopAuthState();

  @override
  Future<void> goToLogin() async {
    wentToLogin = true;
    await ref.read(activeDesktopDataModeProvider.notifier).enterSupabaseMode();
  }
}

void main() {
  // Awaited: 'it' is a DEFERRED library, so the sync variant throws.
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  testWidgets('"Back to sign in" initializes the backend before leaving '
      'Private mode', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_data_mode': DesktopDataMode.private.name,
      // Suppresses the one-time iCloud onboarding prompt; irrelevant here, and
      // it only runs on the READY path anyway.
      'private_sync_onboarding_shown_v1': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = _SpyAuthController();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        desktopAuthControllerProvider.overrideWith(() => auth),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: EvolveTheme.dark(EvolveColors.primaryStrong),
          home: const PrivateModeGate(child: SizedBox.shrink()),
        ),
      ),
    );
    // The private DB cannot open under `flutter test` (path_provider has no
    // implementation), which is exactly the state this screen exists for.
    // `runAsync`: that open is REAL async, which the fake clock alone never
    // lets finish. Two rounds — the first delivers the failure, the second the
    // rebuild.
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }

    final back = find.widgetWithText(
      TextButton,
      t.privateRecovery.backToSignIn,
    );
    expect(back, findsOneWidget, reason: 'the recovery screen is on show');

    await tester.tap(back);
    await tester.pump();
    // Drains AppLogger's 2s debounced save, which the failure above scheduled.
    await tester.pump(const Duration(seconds: 3));

    expect(
      auth.wentToLogin,
      isTrue,
      reason:
          'the exit goes through goToLogin, which initializes Supabase and '
          'invalidates the cached null client before the mode flips',
    );
    expect(
      container.read(activeDesktopDataModeProvider),
      DesktopDataMode.supabase,
      reason: 'and the user does leave Private mode',
    );
  });
}
