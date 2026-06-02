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
    expect(appearance.accentColor, const Color(0xFFFAFAFA));
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

  test('theme changes keep the accent visible', () async {
    final container = await _containerWithPreferences({});
    addTearDown(container.dispose);
    final controller = container.read(
      desktopAppearanceControllerProvider.notifier,
    );

    controller.setThemeMode(ThemeMode.light);
    expect(
      container.read(desktopAppearanceControllerProvider).accentColor,
      const Color(0xFF09090B),
    );

    controller.setThemeMode(ThemeMode.dark);
    expect(
      container.read(desktopAppearanceControllerProvider).accentColor,
      const Color(0xFFFAFAFA),
    );
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
