// Privacy regression guard for SETTINGS persistence in Private mode.
//
// Guarantee under test: when the active data mode is `private`, settings
// changes persist ONLY to the on-device store (via
// `PrivateDataStore.writeSyncedSettings`, backed by the shared
// `SyncedSettingsStore`) and NEVER to the SharedPreferences /
// Supabase "cloud-settings" store. The cloud path is `_saveToPrefs`, which is
// the only code that writes the `pref_*` SharedPreferences keys (and from there
// would sync to Supabase). If a Private-mode branch ever fell through to
// `_saveToPrefs`/`_syncToSupabase`, private settings would leak into the
// cloud-mode store — this test fails loudly if that happens.
//
// We also assert the partner guarantee: Private mode reports `isPro == true`
// (Pro is unlocked locally, never gated on a server entitlement).
//
// Like `private_mode_no_supabase_test.dart`, this test deliberately never calls
// `Supabase.initialize`, so any reach for `Supabase.instance` would throw.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/main.dart' show storedLanguageFor;
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/settings_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_private_data_store.dart';

/// No-op [FlutterLocalNotificationsPlatform] for tests.
///
/// Every settings mutation runs `syncNotifications`, and the private load
/// reaches `cancelAll` when Focus Mode arrives ON — both of which drive
/// `NotificationService` -> `flutter_local_notifications`. (`build()` itself
/// does NOT: an earlier version of this comment said it did, and that
/// misreading is why the private load's missing Focus Mode cancel went
/// unnoticed. See focus_mode_toggle_test.dart.) In a plain unit test no platform
/// implementation is registered (the plugin's static `instance` is `late` and
/// unset), so any call throws `LateInitializationError`. We register this mock
/// as the instance. The only method the settings path calls directly on the
/// platform is `cancelAll` (a no-op here); the scheduling calls go
/// through `resolvePlatformSpecificImplementation`, which returns null for this
/// non-platform-specific mock and is therefore a no-op. None of this is the
/// behaviour under test — it just keeps plugin plumbing from exploding.
class _NoopNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // `_nextInstanceOfTime` reads `tz.local`; initialise the DB so it resolves.
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    // Force iOS so the plugin facade routes scheduling through the iOS branch,
    // which is null-safe (`?.`) for a non-platform-specific mock. The Android
    // branch uses a hard `!`, which would throw on our generic mock.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  /// [seed] pre-populates SharedPreferences. It has to be threaded through here
  /// rather than set by the caller beforehand: `setMockInitialValues` REPLACES
  /// the whole mock store, so anything seeded before this helper runs is wiped
  /// by the helper itself.
  Future<(ProviderContainer, FakePrivateDataStore, SharedPreferences)>
      privateContainer({Map<String, Object> seed = const {}}) async {
    SharedPreferences.setMockInitialValues({
      'active_data_mode': 'private',
      ...seed,
    });
    final prefs = await SharedPreferences.getInstance();
    final fake = FakePrivateDataStore();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith((ref) => fake),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
      ],
    );
    addTearDown(container.dispose);
    return (container, fake, prefs);
  }

  // The notifier kicks off an async `_loadPrivateSettings()` from build(); let
  // it settle before driving mutations so the load doesn't clobber our writes.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('Private mode settings stay on-device', () {
    test('setAccentColor persists locally and never to the cloud store',
        () async {
      final (container, fake, prefs) = await privateContainer();
      container.read(settingsProvider.notifier);
      await settle();

      // Sanity: Private mode reports Pro unlocked from the synchronous build.
      expect(container.read(settingsProvider).isPro, isTrue);

      container
          .read(settingsProvider.notifier)
          .setAccentColor(const Color(0xFF10B981)); // Emerald

      // The private write happened (local store touched)...
      expect(fake.calls, contains('writeSyncedSettings'));
      // ...and the accent color is reflected in state.
      expect(
        container.read(settingsProvider).accentColor,
        const Color(0xFF10B981),
      );

      // The cloud-mode SharedPreferences keys (only written by `_saveToPrefs`,
      // the Supabase path) were NOT touched — no private leak into the cloud
      // settings store.
      expect(prefs.getString('pref_accent_color'), isNull);
      expect(prefs.getString('pref_theme_mode'), isNull);

      // Pro stays unlocked locally after the mutation.
      expect(container.read(settingsProvider).isPro, isTrue);
    });

    test('updateSettings persists locally and never to the cloud store',
        () async {
      final (container, fake, prefs) = await privateContainer();
      container.read(settingsProvider.notifier);
      await settle();

      // Build a full AppSettings from the current state so the real
      // `updateSettings(AppSettings)` signature is satisfied.
      final updated = container.read(settingsProvider).copyWith(
            themeMode: 'light',
            hapticFeedback: false,
          );
      container.read(settingsProvider.notifier).updateSettings(updated);

      // Private write happened...
      expect(fake.calls, contains('writeSyncedSettings'));
      // ...the change is in state...
      expect(container.read(settingsProvider).hapticFeedback, isFalse);

      // ...and nothing leaked into the cloud-mode SharedPreferences store.
      expect(prefs.getString('pref_accent_color'), isNull);
      expect(prefs.getString('pref_theme_mode'), isNull);

      // Private mode keeps Pro unlocked even after a full settings update.
      expect(container.read(settingsProvider).isPro, isTrue);
    });

    test('the language mirror is the ONE deliberate SharedPreferences write',
        () async {
      final (container, _, prefs) = await privateContainer();
      container.read(settingsProvider.notifier);
      await settle();

      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(language: 'de'),
          );

      // main.dart applies the language to slang BEFORE the first frame, and
      // Private mode used to never write it — so a private cold start rendered
      // in a stale cloud-era language until the async DB load resolved and the
      // whole UI visibly re-languaged. This mirror is a one-way cache whose
      // source of truth stays the private DB.
      //
      // It lives under its OWN key. It used to share `pref_language` with the
      // cloud-mode cache, which `_loadFromPrefs` reads back on every build in
      // supabase mode — so the private path was silently overwriting the cloud
      // mode's stored language. See the clobber test below.
      expect(
        prefs.getString(AppSettingsNotifier.privateLanguagePrefKey),
        'de',
      );

      // The rest of the cloud store stays untouched, as above.
      expect(prefs.getString('pref_language'), isNull);
      expect(prefs.getString('pref_accent_color'), isNull);
      expect(prefs.getString('pref_theme_mode'), isNull);
      expect(prefs.getString('notif_morning_brief_time'), isNull);
    });

    test('the private language mirror clobbers the cloud-mode pref_language '
        'cache', () async {
      // `pref_language` is not merely a `pref_*` key the private path touched —
      // it is the CLOUD mode's own cache, read back by `_loadFromPrefs()` on
      // every build in supabase mode and by main.dart before the first frame.
      // The old comment claimed "nothing ever reads it back in private mode",
      // which is true and guards the wrong direction entirely.
      final (container, fake, prefs) =
          await privateContainer(seed: {'pref_language': 'de'});
      // A FRESH private DB: no `language` row, so `_applySyncedSettings` leaves
      // the base standing and the base is `_defaultSettings()` = 'system'.
      expect(fake.syncedSettings.containsKey('language'), isFalse);

      container.read(settingsProvider.notifier);
      await settle();

      expect(
        prefs.getString('pref_language'),
        'de',
        reason: 'merely LOADING private settings stamped the private value over '
            'the cloud-mode language cache, before the user touched anything',
      );

      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(language: 'es'),
          );

      expect(
        prefs.getString('pref_language'),
        'de',
        reason: 'a language change made in Private mode rewrote the cloud '
            "mode's cache, so returning to cloud mode loses the user's choice",
      );
      // ...while the mirror the private path actually needs is still captured,
      // so the first-frame benefit that motivated it survives the fix.
      expect(
        prefs.getString(AppSettingsNotifier.privateLanguagePrefKey),
        'es',
      );
    });

    test('the first frame after a private round trip renders in the device '
        'locale, not the cloud-mode language', () async {
      // The user-visible end of the same bug, pinned where it is observable.
      // `settingsProvider` cannot be built in supabase mode here — this suite
      // deliberately never calls `Supabase.initialize`, and `authProvider`
      // reaches for `Supabase.instance` — so the reader under test is
      // main.dart's `storedLanguageFor`, which decides what slang renders before
      // the first frame. It is also the coupling that breaks silently: if
      // main.dart were left reading `pref_language` in Private mode, the private
      // mirror would stop being applied and every private cold start would go
      // back to visibly re-languaging.
      final (container, _, prefs) =
          await privateContainer(seed: {'pref_language': 'de'});
      container.read(settingsProvider.notifier);
      await settle();
      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(language: 'es'),
          );

      // Still in Private mode: the first frame follows the private mirror.
      expect(storedLanguageFor(prefs), 'es');

      // Back in cloud mode over the SAME store — mutating the key rather than
      // calling `setMockInitialValues` again, which would replace the store and
      // destroy the state under test.
      await prefs.setString('active_data_mode', 'supabase');
      expect(
        storedLanguageFor(prefs),
        'de',
        reason: 'the trip through Private mode cost the cloud-mode user the '
            'language they had chosen',
      );
    });
  });
}
