// Guideline 3.1.2 disclosures on the macOS purchase surface, plus the copy and
// price-fallback rules that surface has to hold.
//
// The page is pumped in cloud mode with no Supabase session, which is also the
// state the paywall is in before (and whenever) RevenueCat's offerings fail to
// resolve: no packages, so no store price. That is exactly the state the
// name-as-price fallback used to corrupt.
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
// LinkDelegate is declared on the interface but lives in its own library.
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records what the paywall actually tries to open.
///
/// The links were previously asserted by label only, which is precisely how a
/// link reading "Terms of Service" came to open the privacy policy in three
/// places. A label is not a link; assert the destination.
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

Future<void> _pumpSubscriptionSection(WidgetTester tester) async {
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
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text(t.settingsPage.subscription).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('paywall carries the Guideline 3.1.2 disclosures', (
    tester,
  ) async {
    await _pumpSubscriptionSection(tester);

    // Auto-renewal statement + functional EULA and Privacy Policy links. Their
    // absence is a routine 3.1.2 rejection.
    expect(find.text(t.settingsPage.renewalDisclaimer), findsOneWidget);
    expect(find.text(t.settingsPage.privacyPolicy), findsOneWidget);
    expect(find.text(t.settingsPage.termsEula), findsOneWidget);
  });

  testWidgets('each legal link opens the document its label promises', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;

    await _pumpSubscriptionSection(tester);

    await tester.tap(find.text(t.settingsPage.privacyPolicy));
    await tester.pumpAndSettle();
    expect(
      launcher.launched,
      [LegalUrls.privacy('en').toString()],
      reason: 'the Privacy Policy link must open the privacy policy',
    );

    launcher.launched.clear();
    await tester.tap(find.text(t.settingsPage.termsEula));
    await tester.pumpAndSettle();
    expect(
      launcher.launched,
      [LegalUrls.appleEula.toString()],
      reason: 'the Terms of Use (EULA) link must open Apple\'s standard EULA, '
          'not the privacy policy and not our own Terms of Service',
    );
  });

  // The locale-follows-language case lives in legal_link_locale_test.dart: it
  // needs a locale CHANGE, and slang_flutter 4.18.0's TranslationProvider never
  // deregisters itself on dispose (dispose() drops only the WidgetsBinding
  // observer, and updateState() is async with no mounted check). So a real
  // locale change setState()s every tree any earlier test in the same file
  // pumped. A separate file gets a fresh isolate.

  testWidgets('missing store price never renders the plan name in its place', (
    tester,
  ) async {
    await _pumpSubscriptionSection(tester);

    // With no offering resolved the cards used to read "Monthly" stacked above
    // "Monthly" — the title duplicated where the price per period belongs.
    expect(find.text(t.settingsPage.planMonthly), findsOneWidget);
    expect(find.text(t.settingsPage.planAnnual), findsOneWidget);
    expect(find.text(t.settingsPage.priceUnavailable), findsNWidgets(2));
  });

  testWidgets('paywall ships no developer-facing implementation copy', (
    tester,
  ) async {
    await _pumpSubscriptionSection(tester);

    // The billing vendor and SDK are implementation detail: naming them (or
    // instructing the user to configure an API key) is developer-register copy
    // on the primary monetization screen.
    for (final widget in tester.widgetList<Text>(find.byType(Text))) {
      final data = widget.data;
      if (data == null) continue;
      expect(
        data.toLowerCase(),
        isNot(anyOf(contains('revenuecat'), contains('storekit'))),
        reason: 'user-visible copy names an implementation detail: "$data"',
      );
    }
  });
}
