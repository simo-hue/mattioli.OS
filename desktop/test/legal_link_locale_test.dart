// The paywall's mandatory privacy link must open the policy in the user's own
// language. The marketing site serves each language from its own directory, and
// a reviewer on a non-Italian device landing in an Italian privacy policy is
// what Guidelines 1.5 and 3.1.2 both punish — the link is "present" but not
// usable by the person reading it.
//
// This lives in its own file on purpose. It needs a real locale CHANGE, and
// slang_flutter 4.18.0's TranslationProvider never deregisters on dispose
// (dispose() removes only the WidgetsBinding observer, and updateState() is
// async with no mounted check). Changing the locale therefore setState()s every
// tree any earlier test in the same file pumped, which throws. A separate file
// is a separate isolate: exactly one tree, no stale providers.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_legal/evolve_legal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _RecordingLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launched = [];

  @override
  final LinkDelegate? linkDelegate = null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

void main() {
  // Italian is the one language served from the site root, so this also pins the
  // URL that shipped binaries hardcode.
  //
  // In setUpAll, not in the test body, for two reasons. setLocale returns a
  // Future and TranslationProvider.build() latches its translations once
  // (`translations ??= ...`), so pumping before it resolves builds an English
  // tree while the global `t` is already Italian. And awaiting it *inside*
  // testWidgets deadlocks: that body runs in a FakeAsync zone which does not
  // advance timers until you pump, so the await never completes.
  setUpAll(() async => LocaleSettings.setLocale(AppLocale.it));

  testWidgets('the privacy link opens the policy in the app\'s language', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
            supportedLocales: const [Locale('it')],
            home: const Scaffold(body: SettingsPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.settingsPage.subscription).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.settingsPage.privacyPolicy));
    await tester.pumpAndSettle();

    expect(launcher.launched, [LegalUrls.privacy('it').toString()]);
    // Not the English page, and not a language-agnostic guess.
    expect(launcher.launched.single, isNot(contains('/en/')));
  });
}
