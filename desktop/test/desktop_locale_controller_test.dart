import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('desktop locale defaults to the system language', () async {
    final container = await _containerWithPreferences({});
    addTearDown(container.dispose);

    expect(container.read(desktopLocaleControllerProvider), isNull);
  });

  test('desktop locale persists the canonical language key', () async {
    final container = await _containerWithPreferences({});
    addTearDown(container.dispose);

    container.read(desktopLocaleControllerProvider.notifier).setLanguage('de');

    expect(container.read(desktopLocaleControllerProvider)?.languageCode, 'de');
    expect(
      container.read(sharedPreferencesProvider)?.getString('pref_language'),
      'de',
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
