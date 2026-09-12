// Language = "System" has to mean the Mac's language, and both localization
// halves have to agree on it.
//
// `_appLocaleFor` mapped the stored `system` value (a null [Locale] — the
// picker's first option, and what every fresh install holds) straight to its
// `default:` branch, English, while `MaterialApp.locale` was handed the same
// null and let Flutter resolve the Material half on its own, falling back to
// `supportedLocales.first`, which is `it`. So an Italian Mac rendered English
// copy; a French Mac rendered English copy inside Italian date pickers; an
// Arabic Mac laid out RTL around English text.
//
// Mobile resolves the identical stored value through
// `AppLocaleUtils.findDeviceLocale()`; desktop never called it — the function
// existed in the tree and had no caller.
//
// The assertions are on `MaterialApp.locale` — the SAME resolved value the app
// hands to `LocaleSettings.setLocale` one line earlier, so it pins both halves
// at once, and it is settled in the frame rather than behind the deferred
// library load every non-base locale goes through.
import 'package:evolve_desktop/app/evolve_desktop_app.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the real app root with NO stored language — i.e. "System".
Future<MaterialApp> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const EvolveDesktopApp(),
    ),
  );
  // TWO pumps: switching to a non-base locale loads a DEFERRED library
  // (`await l_it.loadLibrary()` in translations.g.dart), which posts a
  // zero-duration timer. One pump leaves it pending and the test fails on it.
  await tester.pump();
  await tester.pump(Duration.zero);
  return tester.widget<MaterialApp>(find.byType(MaterialApp));
}

void main() {
  setUp(() {
    // Start from the wrong answer, so a passing assertion can only come from
    // the resolution under test. SYNC: the async variant resolves a microtask
    // later and would land on top of what the app resolves in its own build.
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  testWidgets('a fresh install on an Italian Mac speaks Italian', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [
      Locale('it'),
      Locale('en'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final app = await _pumpApp(tester);

    expect(
      app.locale,
      const Locale('it'),
      reason: '"System" resolves to the device locale, not to the base locale',
    );
  });

  testWidgets('an unsupported device locale falls back to English in BOTH '
      'halves', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final app = await _pumpApp(tester);

    expect(
      app.locale,
      const Locale('en'),
      reason:
          'a null locale let Flutter fall back to supportedLocales.first (it), '
          'so the date picker spoke Italian inside an English dialog',
    );
  });

  testWidgets('an explicit stored language still wins over the device', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('it')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'pref_language': 'es',
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const EvolveDesktopApp(),
      ),
    );
    await tester.pump();
    await tester.pump(Duration.zero);

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('es'),
      reason: 'the device locale is the fallback, not an override',
    );
  });
}
