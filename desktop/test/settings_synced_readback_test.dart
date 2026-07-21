// The macOS app used to WRITE settings into the synced row and read back NONE
// of them: `_loadProfilePreferences` began with "no Supabase session? return",
// and Private mode never has one. Every field then hydrated from this Mac's own
// SharedPreferences — which is why the accent was orange on the iPhone and
// yellow on the Mac, and the two ran in different languages.
//
// These tests pin the three halves of the fix: the read itself, the APPLY into
// the live controllers, and the re-read after a sync pull.
import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/private_data_refresh.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-1';
  final now = DateTime.utc(2026, 1, 1).toIso8601String();

  Future<Database> openFreshDb() => databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: PrivateDbSchema.version,
      singleInstance: false,
      onConfigure: PrivateDbSchema.onConfigure,
      onCreate: PrivateDbSchema.onCreate,
      onUpgrade: PrivateDbSchema.onUpgrade,
    ),
  );

  Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final preferences = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
  }

  group('read-back', () {
    test(
      'what the iPhone wrote is what the Mac reads — row first, legacy column '
      'as the fallback',
      () async {
        final db = await openFreshDb();
        addTearDown(db.close);
        await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);

        // The peer device writes through the shared store (per-key row + the
        // legacy profiles column).
        final store = SyncedSettingsStore(db);
        await store.writeAll(owner, {
          'theme_mode': SettingsCodec.themeLight,
          'accent_color': '#FF7A00',
          'language': 'es',
          'morning_brief_time': '07:15',
          'notif_habit_reminders': SyncedSettingsStore.encodeBool(false),
        });

        final read = await store.readAll(owner);

        expect(read['theme_mode'], SettingsCodec.themeLight);
        expect(read['accent_color'], '#FF7A00');
        expect(read['language'], 'es');
        expect(read['morning_brief_time'], '07:15');
        expect(SyncedSettingsStore.decodeBool(read['notif_habit_reminders']),
            isFalse);

        // The per-key ROW wins over the legacy column even when the column
        // looks newer: the inverse rule would let a stale column resurrect a
        // setting the user had deliberately changed on a v6 device.
        await db.update(
          'profiles',
          {'language': 'it', 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [owner],
        );
        expect((await store.readAll(owner))['language'], 'es');
      },
    );

    test('a settings write no longer stamps is_pro / sentry_consent', () async {
      // Before: sanitizeSettings appended {is_pro: 1, sentry_consent: 0} to
      // EVERY settings write, so toggling the Mac's 24h clock re-published an
      // entitlement and silently reset crash-report consent on the iPhone.
      final sanitized = DesktopPrivateDb.sanitizeSettings({
        'pref_time_format_24h': true,
      });

      expect(sanitized, {'pref_time_format_24h': 1});
      expect(sanitized.containsKey('is_pro'), isFalse);
      expect(sanitized.containsKey('sentry_consent'), isFalse);
      for (final column in PrivateDbSchema.deviceLocalProfileColumns) {
        if (column == 'biometric_lock') continue; // a real settings column
        expect(sanitized.containsKey(column), isFalse, reason: column);
      }
    });

    test('a device-local key cannot be pushed through the synced store', () async {
      final db = await openFreshDb();
      addTearDown(db.close);
      await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);

      // "Reset settings to defaults" used to blind-write biometric_lock among
      // 13 other columns. A reset on the Mac must not reach across and unlock
      // the user's iPhone, so the shared store refuses the key outright.
      expect(
        () => SyncedSettingsStore(db).write(owner, 'biometric_lock', '0'),
        throwsArgumentError,
      );

      // Booleans travel in the one encoding both apps already use on the legacy
      // columns, so the dual-write never has to translate.
      expect(encodeDesktopSetting(true), '1');
      expect(encodeDesktopSetting(false), '0');
      expect(encodeDesktopSetting(null), isNull);
      expect(encodeDesktopSetting('09:00'), '09:00');
    });
  });

  group('apply', () {
    testWidgets(
      'the values read back reach the theme, accent and locale controllers',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        late WidgetRef ref;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
            ],
            child: Consumer(
              builder: (_, r, _) {
                ref = r;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // Defaults before the pull: dark, near-white accent, system locale.
        expect(
          ref.read(desktopAppearanceControllerProvider).themeMode,
          ThemeMode.dark,
        );
        expect(ref.read(desktopLocaleControllerProvider), isNull);

        applyDesktopSyncedSettings(ref, const {
          'theme_mode': 'light',
          'accent_color': '#FF7A00',
          'language': 'es',
        });
        await tester.pump();

        final appearance = ref.read(desktopAppearanceControllerProvider);
        expect(appearance.themeMode, ThemeMode.light);
        expect(appearance.accentColor, const Color(0xFFFF7A00));
        // The LOCALE changed, not merely a field on the settings page.
        expect(ref.read(desktopLocaleControllerProvider)?.languageCode, 'es');
      },
    );

    testWidgets('keys the store has no value for are left alone', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'pref_theme_mode': 'light',
        'pref_language': 'de',
      });
      final preferences = await SharedPreferences.getInstance();
      late WidgetRef ref;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: Consumer(
            builder: (_, r, _) {
              ref = r;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Only the accent travelled; theme and language must survive untouched.
      applyDesktopSyncedSettings(ref, const {'accent_color': '#123456'});
      await tester.pump();

      expect(
        ref.read(desktopAppearanceControllerProvider).themeMode,
        ThemeMode.light,
      );
      expect(ref.read(desktopLocaleControllerProvider)?.languageCode, 'de');
    });

    test(
      'applyProfile does not re-persist its coerced theme (a read path must '
      'not write)',
      () async {
        final container = await containerWith({'pref_theme_mode': 'light'});
        addTearDown(container.dispose);
        final preferences = container.read(sharedPreferencesProvider)!;

        container
            .read(desktopAppearanceControllerProvider.notifier)
            .applyProfile(themeMode: SettingsCodec.themeSystem);

        // 'system' resolves to a concrete mode for RENDERING, but the stored
        // preference is untouched: the old code wrote the coercion back and
        // pushed it to every other device, destroying the user's choice.
        expect(preferences.getString('pref_theme_mode'), 'light');
      },
    );

    test('both apps now resolve a legacy language label identically', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      // 'italiano' used to mean 'it' on macOS and 'system' on iOS.
      container
          .read(desktopLocaleControllerProvider.notifier)
          .setLanguage('italiano');

      expect(container.read(desktopLocaleControllerProvider)?.languageCode,
          'it');
      expect(
        container.read(sharedPreferencesProvider)?.getString('pref_language'),
        SettingsCodec.normalizeLanguage('italiano'),
      );
    });
  });

  group('post-pull re-hydration', () {
    test('refreshPrivateAfterPull re-reads the synced settings', () async {
      // Without this the Mac only learned about an iPhone edit on the next cold
      // start: refreshPrivateAfterPull invalidated dashboard / analytics /
      // profile / categories and nothing settings-related, unlike mobile's
      // invalidatePrivateDataProviders.
      var builds = 0;
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          desktopSyncedSettingsProvider.overrideWith((_) async {
            builds++;
            return const <String, String?>{};
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(desktopSyncedSettingsProvider.future);
      expect(builds, 1);

      refreshPrivateAfterPull(container);
      await container.read(desktopSyncedSettingsProvider.future);

      expect(builds, 2);
    });

    test('the settings provider stays empty (and silent) outside Private mode', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      // Supabase mode: the profiles table is the source, and touching the
      // encrypted DB here would be both wrong and a Keychain round-trip.
      expect(
        await container.read(desktopSyncedSettingsProvider.future),
        isEmpty,
      );
    });
  });

  group('defaults', () {
    test('the brief times default to the canonical 09:00 / 21:00', () {
      // macOS's field initialisers said 08:00 / 20:30 and won whenever prefs
      // were empty, dragging the iPhone's briefs 60 and 30 minutes earlier the
      // first time any notification toggle was touched.
      expect(SettingsCodec.defaultMorningBriefTime, '09:00');
      expect(SettingsCodec.defaultEveningReviewTime, '21:00');
    });
  });
}
