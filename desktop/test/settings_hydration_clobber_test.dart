// Opening Settings in Private mode kicks off the synced read UNAWAITED
// (`initState` -> `_loadProfilePreferences`), and the page is interactive the
// whole time it is in flight. When it lands, `_applySyncedSettings` overwrites
// EVERY field from the store — there is no in-flight-edit guard — so a toggle
// the user flipped during that window is silently reverted on screen AND in the
// SharedPreferences mirror, while `_syncProfile` has already written the new
// value to the store. The UI then disagrees with the store for the rest of the
// session, and says nothing.
//
// Mobile fixed exactly this: `settings_provider.dart` latches `_privateLoaded`
// and replays `_preloadEdits` over the loaded map, pinned by
// `mobile/test/settings_clobber_test.dart` ("an edit made before the load
// resolves survives the load"). Desktop had neither the guard nor the test.
//
// The same code path is also the app's ONLY read-back of the synced settings —
// the seam whose failure produced the original symptom ("macOS wrote settings
// into the synced row and never read them back"). It had no assertion of any
// kind: the one suite that reached it in Private mode did so through the
// swallowed-exception branch, so the read-back could have been deleted outright
// without reddening CI.
import 'dart:async';

import 'package:evolve_desktop/app/evolve_desktop_app.dart';
import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _switchIn(String rowLabel) => find.descendant(
      of: find.widgetWithText(ListTile, rowLabel),
      matching: find.byType(EvolveSwitch),
    );

bool _switchValue(WidgetTester tester, String rowLabel) =>
    tester.widget<EvolveSwitch>(_switchIn(rowLabel)).value;

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets(
    'a toggle made while the read-back is in flight is reverted by it',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'active_data_mode': DesktopDataMode.private.name,
      });
      final prefs = await SharedPreferences.getInstance();
      // The read the user is racing. Held open so the tap lands strictly
      // before `_applySyncedSettings` runs — the real-world window is the
      // encrypted DB open plus a Keychain round-trip, which is not short.
      final gate = Completer<Map<String, String?>>();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          desktopSyncedSettingsWriterProvider.overrideWithValue((_) async {}),
          desktopSyncedSettingsProvider.overrideWith((_) => gate.future),
        ],
      );
      addTearDown(container.dispose);

      await tester.binding.setSurfaceSize(const Size(1440, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              theme: EvolveTheme.dark(EvolveColors.primaryStrong),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('en')],
              home: const Scaffold(body: SettingsPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settingsPage.sectionApplication).first);
      await tester.pumpAndSettle();

      // The user turns Focus Mode ON while the read is still pending.
      expect(_switchValue(tester, t.settingsPage.focusMode), isFalse);
      await tester.ensureVisible(_switchIn(t.settingsPage.focusMode));
      await tester.tap(_switchIn(t.settingsPage.focusMode));
      await tester.pumpAndSettle();
      expect(_switchValue(tester, t.settingsPage.focusMode), isTrue);

      // Now the store answers, and it disagrees about the key the user just
      // touched while carrying a key they did not.
      gate.complete(const {'pref_focus_mode': '0', 'language': 'es'});
      await tester.pumpAndSettle();

      expect(
        _switchValue(tester, t.settingsPage.focusMode),
        isTrue,
        reason: 'the edit the user already made wins over what the load found',
      );
      expect(
        prefs.getBool('pref_focus_mode'),
        isTrue,
        reason: 'and the local mirror is not rewritten back to the old value',
      );
      // The key the user did NOT touch must still be applied — a guard that
      // simply dropped the whole load would pass the two asserts above and
      // resurrect the original "the Mac never reads the store back" bug.
      expect(
        container.read(desktopLocaleControllerProvider)?.languageCode,
        'es',
        reason: 'untouched keys still hydrate from the store',
      );
    },
  );

  testWidgets(
    'a later pull is ignored because an earlier edit is still remembered',
    (tester) async {
      // The other half of the contract, and the reason the guard must be
      // released once the first load lands: after hydration, a genuine change
      // made on the iPhone has to reach the Mac. If `_preloadEdits` were never
      // cleared, the user's own earlier tap would suppress every future pull of
      // that key — "my iPhone change never arrives on the Mac", which is the
      // bug this whole effort exists to kill, reintroduced by its own fix.
      SharedPreferences.setMockInitialValues({
        'active_data_mode': DesktopDataMode.private.name,
      });
      final prefs = await SharedPreferences.getInstance();
      var generation = 0;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          desktopSyncedSettingsWriterProvider.overrideWithValue((_) async {}),
          desktopSyncedSettingsProvider.overrideWith(
            (_) async => generation++ == 0
                ? const {'pref_focus_mode': '0'}
                : const {'pref_focus_mode': '0', 'pref_milestones': '0'},
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.binding.setSurfaceSize(const Size(1440, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              theme: EvolveTheme.dark(EvolveColors.primaryStrong),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('en')],
              home: const Scaffold(body: SettingsPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settingsPage.sectionApplication).first);
      await tester.pumpAndSettle();

      // Hydration has landed. The user now turns Milestones OFF locally…
      await tester.ensureVisible(_switchIn(t.settingsPage.milestones));
      await tester.tap(_switchIn(t.settingsPage.milestones));
      await tester.pumpAndSettle();
      expect(_switchValue(tester, t.settingsPage.milestones), isFalse);

      // …then turns it back ON on the iPhone, and a pull delivers that.
      container.invalidate(desktopSyncedSettingsProvider);
      await container.read(desktopSyncedSettingsProvider.future);
      await tester.pumpAndSettle();

      expect(
        _switchValue(tester, t.settingsPage.milestones),
        isFalse,
        reason: 'the pull carried pref_milestones = 0 and it must be applied',
      );
    },
  );

  testWidgets(
    'the Mac keeps its own appearance when the store says otherwise and '
    'Settings is closed',
    (tester) async {
      // The seam that produced the ORIGINAL user report — accent orange on the
      // iPhone, yellow on the Mac; the two apps in different languages — is the
      // root listener in `evolve_desktop_app.dart`, not the settings page. It
      // is what repaints the app when Settings has never been opened, and it
      // had no coverage at all: `widget_test.dart`'s `_DesktopTestApp`
      // reimplements the root WITHOUT that listener, so the whole widget suite
      // is structurally blind to it, and the one test that pumps the real
      // `EvolveDesktopApp` asserts only the missing-Supabase-config screen.
      //
      // Deleting the listener leaves every settings-page test green. This one
      // goes red.
      SharedPreferences.setMockInitialValues({
        'active_data_mode': DesktopDataMode.private.name,
        // The local mirror deliberately CONTRADICTS the store on all three.
        'pref_accent_color': '#FFEB3B',
        'pref_theme_mode': 'dark',
        'pref_language': 'de',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          desktopSyncedSettingsProvider.overrideWith(
            (_) async => const {
              'accent_color': '#FF7A00',
              'theme_mode': 'light',
              'language': 'es',
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The REAL root widget. Never opens Settings.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const EvolveDesktopApp(),
        ),
      );
      await tester.pumpAndSettle();

      final appearance = container.read(desktopAppearanceControllerProvider);
      expect(appearance.accentColor, const Color(0xFFFF7A00),
          reason: 'orange, as the iPhone renders it — not the local yellow');
      expect(appearance.themeMode, ThemeMode.light);
      expect(
        container.read(desktopLocaleControllerProvider)?.languageCode,
        'es',
        reason: 'the two apps must not run in different languages',
      );
    },
  );
}
