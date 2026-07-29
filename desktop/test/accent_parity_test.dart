// The accent colour is ONE stored string shared by both apps, so it must render
// the same pixels on the Mac and on the iPhone. It did not.
//
// Two independent faults produced that:
//
//  * macOS parses `accent_color` with its own private `_parseColor` instead of
//    the shared `SettingsCodec.normalizeAccentColor` that mobile uses, so the
//    two disagree on every non-canonical spelling the schema permits
//    (`accent_color TEXT NOT NULL DEFAULT '#FFFFFF'` carries no CHECK).
//  * macOS seeds `#FAFAFA` as its default accent while the shared codec, the
//    Postgres DEFAULT and mobile all say `#FFFFFF`.
//
// Both were "fixed" once before while the user-visible symptom survived, so
// these tests assert the RENDERED colour and the RENDERED picker, never that a
// helper was called.
import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'support/settings_navigation.dart';

/// Mobile's accent parser, byte for byte.
///
/// Copied from `mobile/lib/providers/settings_provider.dart` `_accentFromHex`
/// rather than imported, because the two apps are separate packages. If mobile
/// ever changes shape this copy must move with it — that is the point: the
/// contract under test is "desktop paints what mobile paints", and the only
/// honest way to assert it from here is to state mobile's half explicitly.
Color mobileAccentFor(String? hex) {
  final normalized = SettingsCodec.normalizeAccentColor(hex);
  if (normalized == null) return const Color(0xFFFFFFFF); // defaultAccentColor
  return Color(int.parse('ff${normalized.substring(1)}', radix: 16));
}

Future<ProviderContainer> _container(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final preferences = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
}

Future<SharedPreferences> _pumpSettings(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  bool light = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);

  await tester.binding.setSurfaceSize(const Size(1440, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: light
              ? EvolveTheme.light(EvolveColors.lightForeground)
              : EvolveTheme.dark(EvolveColors.primaryStrong),
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

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  group('the same stored accent renders differently on the two apps', () {
    test('a whitespace-padded accent paints invisible on the Mac and orange on '
        'the iPhone', () async {
      // `int.parse` TRIMS, so ' #FF9500' is 7 chars after stripping '#' —
      // the `length == 6` guard declines to prepend the alpha, int.parse
      // succeeds anyway, and the Mac gets alpha 0. No throw, no log, no
      // fallback: a parse that reports success and returns garbage.
      final container = await _container({});
      addTearDown(container.dispose);
      container
          .read(desktopAppearanceControllerProvider.notifier)
          .applyProfile(accentColor: ' #FF9500');

      expect(
        container.read(desktopAppearanceControllerProvider).accentColor,
        mobileAccentFor(' #FF9500'),
        reason: 'the Mac must paint the same pixels the iPhone paints',
      );
      expect(
        container.read(desktopAppearanceControllerProvider).accentColor.a,
        1.0,
        reason: 'an accent with alpha 0 is an invisible primary button',
      );
    });

    test(
      'an ARGB accent keeps its alpha on the Mac and loses it on the iPhone',
      () async {
        final container = await _container({});
        addTearDown(container.dispose);
        container
            .read(desktopAppearanceControllerProvider.notifier)
            .applyProfile(accentColor: '#80FF9500');

        expect(
          container.read(desktopAppearanceControllerProvider).accentColor,
          mobileAccentFor('#80FF9500'),
        );
      },
    );

    test(
      'an unparseable accent falls back on the iPhone but not on the Mac',
      () async {
        // '#FFF' is short hex. Mobile rejects it and keeps its default; desktop
        // parses it as 0x00000FFF — alpha 0 again, and a colour nobody chose.
        final container = await _container({});
        addTearDown(container.dispose);
        container
            .read(desktopAppearanceControllerProvider.notifier)
            .applyProfile(accentColor: '#FFF');

        expect(
          container.read(desktopAppearanceControllerProvider).accentColor,
          DesktopAppearanceController.defaultAccent,
          reason: 'the live accent is kept when the store has nothing usable',
        );
      },
    );

    test(
      'a malformed stored accent crashes the next appearance persist',
      () async {
        // `_toHex` does `toRadixString(16).substring(2, 8)` with no padLeft, so
        // any colour whose leading alpha nibble is zero produces a 6-char string
        // and the substring runs off the end. Reached from setThemeMode /
        // setAccentColor, i.e. an ordinary settings interaction.
        final container = await _container({});
        addTearDown(container.dispose);
        final controller = container.read(
          desktopAppearanceControllerProvider.notifier,
        );
        controller.applyProfile(accentColor: ' #FF9500');

        expect(() => controller.setThemeMode(ThemeMode.light), returnsNormally);
        expect(
          container
              .read(sharedPreferencesProvider)!
              .getString('pref_accent_color'),
          '#FF9500',
        );
      },
    );
  });

  group('the Mac seeds a different default white than everything else', () {
    test(
      'the desktop accent seed IS SettingsCodec.defaultAccentColor',
      () async {
        // The DB DEFAULT, the Postgres DEFAULT, `seedProfile` and mobile all say
        // #FFFFFF. Desktop said #FAFAFA, so an untouched profile hydrated to a
        // different colour depending on which side supplied the value.
        final container = await _container({});
        addTearDown(container.dispose);

        expect(
          dashboardColorToHex(
            container.read(desktopAppearanceControllerProvider).accentColor,
          ),
          SettingsCodec.defaultAccentColor,
        );
      },
    );

    testWidgets(
      'the accent picker shows nothing selected for the canonical seed white',
      (tester) async {
        // The literal user report: "my accent is white and the picker says
        // nothing is selected". The palette led with #FAFAFA while the stored
        // value — written by the DB DEFAULT and by every iPhone — is #FFFFFF,
        // and `_Swatch` compares by exact ARGB.
        await _pumpSettings(
          tester,
          prefs: {'pref_accent_color': SettingsCodec.defaultAccentColor},
        );
        await openSettingsSection(tester, SettingsSection.general);

        final white = find.byTooltip(
          t.settingsPage.useAccent(hex: SettingsCodec.defaultAccentColor),
        );
        expect(white, findsOneWidget, reason: 'the canonical seed is offered');
        await tester.ensureVisible(white);
        expect(
          find.descendant(of: white, matching: find.byIcon(LucideIcons.check)),
          findsOneWidget,
          reason: 'and it renders as the selected accent',
        );
        expect(
          find.byTooltip(t.settingsPage.useAccent(hex: '#FAFAFA')),
          findsNothing,
          reason: 'the stale literal must not survive alongside it',
        );
      },
    );

    testWidgets('picking the default accent in a light theme stores near-black', (
      tester,
    ) async {
      // `_ColorRow` maps the whole palette through `_visibleAccent` BEFORE the
      // loop, so `onTap: () => onChanged(color)` hands over the MAPPED colour.
      // In a light theme the leftmost "white" swatch therefore pushes #09090B
      // to the synced store and on to every other device — a colour the user
      // never chose.
      final prefs = await _pumpSettings(
        tester,
        prefs: {'pref_accent_color': SettingsCodec.defaultAccentColor},
        light: true,
      );
      await openSettingsSection(tester, SettingsSection.general);

      final white = find.byTooltip(
        t.settingsPage.useAccent(hex: SettingsCodec.defaultAccentColor),
      );
      await tester.ensureVisible(white);
      await tester.tap(white);
      await tester.pumpAndSettle();

      expect(
        prefs.getString('pref_accent_color'),
        SettingsCodec.defaultAccentColor,
      );
    });
  });
}
