import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('desktop appearance defaults to the dark monochrome theme', () async {
    final container = await _containerWithPreferences({});
    addTearDown(container.dispose);

    final appearance = container.read(desktopAppearanceControllerProvider);

    expect(appearance.themeMode, ThemeMode.dark);
    // The canonical seed, == SettingsCodec.defaultAccentColor. Pinned by hex
    // rather than by the symbol so this test still fails if the constant drifts
    // away from the shared one again; accent_parity_test.dart owns that tie.
    expect(appearance.accentColor, const Color(0xFFFFFFFF));
  });

  test('accent updates persist the preference keys', () async {
    final container = await _containerWithPreferences({});
    addTearDown(container.dispose);
    final controller = container.read(
      desktopAppearanceControllerProvider.notifier,
    );

    controller.setAccentColor(const Color(0xFF3B82F6));
    final preferences = container.read(sharedPreferencesProvider)!;

    expect(
      container.read(desktopAppearanceControllerProvider).accentColor,
      const Color(0xFF3B82F6),
    );
    expect(preferences.getString('pref_accent_color'), '#3B82F6');
    expect(preferences.getString('pref_theme_mode'), 'dark');
  });

  test('a theme change does NOT rewrite the stored accent', () async {
    // It used to. Coercing the accent on a theme flip persisted a NEW colour
    // and — once settings synced — pushed it to every other device, so merely
    // switching to dark mode on the Mac changed the accent on the iPhone.
    // The stored value is now whatever the user chose, in both themes.
    final container = await _containerWithPreferences({});
    addTearDown(container.dispose);
    final controller = container.read(
      desktopAppearanceControllerProvider.notifier,
    );
    const chosen = Color(0xFFFFFFFF); // white: illegible on a light theme
    controller.setAccentColor(chosen);

    controller.setThemeMode(ThemeMode.light);
    expect(
      container.read(desktopAppearanceControllerProvider).accentColor,
      chosen,
      reason: 'the stored accent survives a theme flip',
    );

    controller.setThemeMode(ThemeMode.dark);
    expect(
      container.read(desktopAppearanceControllerProvider).accentColor,
      chosen,
      reason: 'and survives flipping back — no third colour is invented',
    );
  });

  test('legibility is applied at PAINT time instead', () async {
    // The guarantee the old test was really protecting: an accent that would be
    // invisible is substituted when painting — without touching what is stored,
    // and therefore without changing what other devices see.
    expect(
      DesktopAppearanceController.readableAccent(
        const Color(0xFFFFFFFF),
        Brightness.light,
      ),
      const Color(0xFF09090B),
    );
    expect(
      DesktopAppearanceController.readableAccent(
        const Color(0xFF000000),
        Brightness.dark,
      ),
      DesktopAppearanceController.defaultAccent,
    );
    // A legible colour is passed straight through in both themes.
    const orange = Color(0xFFFF9500);
    for (final b in Brightness.values) {
      expect(DesktopAppearanceController.readableAccent(orange, b), orange);
    }
  });
}

Future<ProviderContainer> _containerWithPreferences(
  Map<String, Object> values,
) async {
  SharedPreferences.setMockInitialValues(values);
  final preferences = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
}
