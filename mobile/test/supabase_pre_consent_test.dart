// App Store Guideline 5.1.2 — no third-party request before the user answers.
//
// `consent_pre_upload_test.dart` covers the Sentry half. This is the Supabase
// half, and it is the same defect in a place the Sentry fix did not reach.
//
// `main()` used to gate `Supabase.initialize` on `if (!startsInPrivateMode)`.
// That is the whole condition on a FRESH install — but not on a REINSTALL. iOS
// Keychain items survive app deletion; `NSUserDefaults` does not. So a returning
// user arrives with `has_completed_consent` gone (the router correctly sends
// them to `/consent`) and their Supabase session still on the device, and the
// SDK restored it and refreshed the token over the network while the consent
// screen was still being built. A request carrying the user's credentials, made
// on the screen that exists to ask whether that is allowed.
//
// The gate now asks whether the question was ANSWERED, not what the answer was —
// the same shape as `SentryService.shouldRun` (see `sentry_teardown_test.dart`),
// because an absent key means "never asked", not "yes".
//
// This file NEVER calls `Supabase.initialize`. That is the point: it reproduces
// the pre-consent cold start, where reaching for `Supabase.instance` throws.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shouldInitialiseSupabaseAtStartup', () {
    test('an UNANSWERED consent question does not start the SDK', () {
      // The reinstall case. There may be a perfectly good session in the
      // Keychain — that is exactly why this must not run.
      expect(
        shouldInitialiseSupabaseAtStartup(
          hasCompletedConsent: false,
          isPrivateMode: false,
        ),
        isFalse,
      );
    });

    test('an answered question in account mode starts it', () {
      expect(
        shouldInitialiseSupabaseAtStartup(
          hasCompletedConsent: true,
          isPrivateMode: false,
        ),
        isTrue,
        reason: 'the ordinary launch must not pay a lazy-init round trip on '
            'the first action that needs the session',
      );
    });

    test('private mode never starts it, answered or not', () {
      // Private mode keeps no account at all. This is the pre-existing half of
      // the gate and it must survive the change.
      for (final answered in [true, false]) {
        expect(
          shouldInitialiseSupabaseAtStartup(
            hasCompletedConsent: answered,
            isPrivateMode: true,
          ),
          isFalse,
          reason: 'hasCompletedConsent: $answered',
        );
      }
    });
  });

  group('the pre-consent cold start', () {
    test('Supabase is not initialised in this isolate', () {
      // States the fixture rather than guarding it — test order is not a
      // contract, so this cannot police the tests below. What keeps THEM honest
      // is that each was run with the fix removed and observed to fail.
      expect(isSupabaseInitialized, isFalse);
    });

    test('AuthNotifier reports signed-out instead of throwing', () async {
      // THE REGRESSION. `build()` read `supabase.auth.currentSession`
      // unconditionally outside private mode, so with the SDK deferred it threw
      // out of the provider — taking the router's `refreshListenable` with it
      // and leaving the app with no consent screen to show.
      //
      // "Signed out" is the honest answer, not a lie: there may be a session on
      // the device, but we have not looked, and must not until the user says we
      // may. `adoptSessionAfterConsent` is what looks.
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      final auth = container.read(authProvider);

      expect(auth.dataMode, AppDataMode.supabase,
          reason: 'a fresh install defaults to account mode — the pre-consent '
              'state is NOT private mode, which is why the old private-only '
              'guard did not cover it');
      expect(auth.isLoggedIn, isFalse);
      expect(auth.user, isNull);
    });

    test('nothing the notifier does on build reaches Supabase', () async {
      // A second reading of the same property, from the other side: if any part
      // of `build()` still touched the SDK — the session read, the
      // `onAuthStateChange` subscription — this would throw rather than settle.
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      // `read(provider)` — NOT `read(provider.notifier)`. Riverpod 3 rethrows a
      // build failure through the value; through the notifier it does not, so
      // the notifier form passes even with the fix removed. Verified by
      // mutation, which is the only way to find a hole like that.
      expect(() => container.read(authProvider), returnsNormally);
      expect(isSupabaseInitialized, isFalse,
          reason: 'building the auth notifier must not bring the SDK up as a '
              'side effect');
    });
  });

  group('adoptSessionAfterConsent', () {
    test('is a no-op in Private mode', () async {
      // Pins the ENTRY guard. The method also re-reads the mode AFTER its await,
      // because `ensureSupabaseInitialized` waits on a Keychain read and a
      // possible token refresh while the user is on a live screen and can reach
      // the chooser — but driving that second guard needs the mode to flip
      // mid-await, which cannot be arranged without a seam that would exist only
      // for the test. It is verified by reading, and named here so a later
      // reader knows the difference.
      //
      // What both guards prevent: writing an account-mode state over a private
      // one, which hands a Private-mode user a cloud auth subscription and fires
      // `settingsProvider`'s auth listener — a `profiles` read plus a RevenueCat
      // configure with the Supabase uid.
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      await container.read(activeDataModeProvider.notifier).enterPrivateMode();
      await container.read(authProvider.notifier).adoptSessionAfterConsent();

      final auth = container.read(authProvider);
      expect(auth.dataMode, AppDataMode.private,
          reason: 'the mode the user actually chose must survive');
      expect(auth.isLoggedIn, isFalse);
      expect(isSupabaseInitialized, isFalse,
          reason: 'Private mode never initialises the SDK, and adoption must '
              'not be a side door that does');
    });
  });
}
