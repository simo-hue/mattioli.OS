// "Follow system" is a theme the schema explicitly permits — and the one every
// user who never picked a theme has, because `SettingsCodec.normalizeThemeMode`
// returns `themeSystem` for null/unset/unrecognised input.
//
// The Mac did not follow the system. `DesktopAppearanceController.themeModeFor`
// resolved every stored string through `resolveIsDark` and returned only
// `ThemeMode.dark` or `ThemeMode.light`, so `MaterialApp` never received
// `ThemeMode.system` — the one value that makes Flutter track the OS. Worse,
// the brightness was read through a bare `PlatformDispatcher` access inside a
// Notifier, which registers no dependency, and nothing in `desktop/lib`
// observes `platformBrightness` at all: the resolution happened once at launch
// and never again. macOS flips to dark at sunset, the iPhone follows
// immediately, and the Mac stays light until the app is relaunched.
//
// The prefs mirror then re-collapsed it on every hydration and every persist,
// so even a correct controller would lose `'system'` on the next cold start.
import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/search/presentation/command_palette.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final preferences = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  group('the controller collapses a system theme at launch', () {
    test('a stored system theme does not survive as ThemeMode.system',
        () async {
      final container = await _container({'pref_theme_mode': 'system'});
      addTearDown(container.dispose);

      // ThemeMode.system is precisely the value that makes MaterialApp
      // re-resolve on an OS appearance change; light/dark is the value that
      // ignores it. This is behaviour, not shape.
      expect(
        container.read(desktopAppearanceControllerProvider).themeMode,
        ThemeMode.system,
      );
    });

    test('an explicit theme still pins', () async {
      for (final (stored, expected) in [
        (SettingsCodec.themeDark, ThemeMode.dark),
        (SettingsCodec.themeLight, ThemeMode.light),
      ]) {
        final container = await _container({'pref_theme_mode': stored});
        addTearDown(container.dispose);
        expect(
          container.read(desktopAppearanceControllerProvider).themeMode,
          expected,
        );
      }
    });

    test('picking an accent rewrites a system mirror to a concrete theme',
        () async {
      // `_persist` runs on setAccentColor too, so merely choosing a colour was
      // enough to destroy "follow system" on the next cold start.
      final container = await _container({'pref_theme_mode': 'system'});
      addTearDown(container.dispose);

      container
          .read(desktopAppearanceControllerProvider.notifier)
          .setAccentColor(const Color(0xFF3B82F6));

      expect(
        container.read(sharedPreferencesProvider)!.getString('pref_theme_mode'),
        SettingsCodec.themeSystem,
      );
    });
  });

  group('the settings page collapses a system theme in the prefs mirror', () {
    Future<SharedPreferences> pump(
      WidgetTester tester,
      Map<String, String?> stored, {
      Map<String, Object> prefs = const {},
    }) async {
      SharedPreferences.setMockInitialValues({
        'active_data_mode': DesktopDataMode.private.name,
        ...prefs,
      });
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          desktopSyncedSettingsWriterProvider.overrideWithValue((_) async {}),
          desktopSyncedSettingsProvider.overrideWith((_) async => stored),
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
      return preferences;
    }

    testWidgets('hydrating a synced system theme writes dark or light instead',
        (tester) async {
      // The mirror is what `build()` reads on the next cold start, before the
      // store answers — and on a Mac that never completes a pull, permanently.
      final prefs = await pump(tester, const {'theme_mode': 'system'});
      expect(prefs.getString('pref_theme_mode'), SettingsCodec.themeSystem);
    });

    testWidgets('the theme row offers no way back to "follow system"',
        (tester) async {
      // With a binary switch, a 'system' user who touched it once wrote a
      // concrete 'dark'/'light' into the SYNCED store — pinning the iPhone too
      // — and the Mac then had no control that could express "follow system"
      // again. Fixing the controller without fixing the control is half a fix.
      final prefs = await pump(
        tester,
        const {'theme_mode': 'dark'},
      );
      await tester.tap(find.text(t.settingsPage.sectionApplication).first);
      await tester.pumpAndSettle();

      final row = find.widgetWithText(ListTile, t.settingsPage.themeMode);
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(find.descendant(of: row, matching: find.byType(EvolveSelect<String>)));
      await tester.pumpAndSettle();

      expect(find.text(t.settingsPage.themeLight), findsWidgets);
      expect(find.text(t.settingsPage.themeSystem), findsWidgets);

      await tester.tap(find.text(t.settingsPage.themeSystem).last);
      await tester.pumpAndSettle();

      expect(prefs.getString('pref_theme_mode'), SettingsCodec.themeSystem);
    });

    testWidgets('a pull without theme_mode overwrites the mirror anyway',
        (tester) async {
      // The guard against "fixing" the above by writing
      // `normalizeThemeMode(values[kSettingThemeMode])` unconditionally:
      // `normalizeThemeMode(null)` is 'system', and `SyncedSettingsStore` omits
      // keys that were never set, so any pull carrying only a language would
      // silently convert an explicit local 'dark' into "follow OS".
      final prefs = await pump(
        tester,
        const {'language': 'es'},
        prefs: {'pref_theme_mode': SettingsCodec.themeLight},
      );
      expect(prefs.getString('pref_theme_mode'), SettingsCodec.themeLight);
    });
  });

  testWidgets(
    'the palette offers "switch to dark" while the screen is already dark',
    (tester) async {
      // Once ThemeMode.system can reach the palette, its `mode != ThemeMode.dark`
      // comparisons mislabel the command and `mode == ThemeMode.dark ? light :
      // dark` becomes a no-op on a dark system-theme Mac: the palette would
      // report success and change nothing. This test cannot fail before the
      // controller fix — ThemeMode.system is unreachable today — so it is not
      // the regression proof for that fix; it is the companion that must land
      // WITH it, and it fails if only the controller is fixed.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      SharedPreferences.setMockInitialValues({'pref_theme_mode': 'system'});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              theme: EvolveTheme.light(EvolveColors.lightForeground),
              darkTheme: EvolveTheme.dark(EvolveColors.primaryStrong),
              themeMode:
                  container.read(desktopAppearanceControllerProvider).themeMode,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('en')],
              home: const Scaffold(body: CommandPalette()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'theme');
      await tester.pumpAndSettle();

      expect(
        find.text(t.palette.switchToLight),
        findsOneWidget,
        reason: 'the OS is dark, so the only useful move is to light',
      );
      expect(find.text(t.palette.switchToDark), findsNothing);
    },
  );
}
