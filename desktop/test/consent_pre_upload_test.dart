// App Store Guideline 5.1.2 — Data Use and Sharing.
//
// macOS 1.0.0(26) was rejected on 2026-08-01 for uploading data to a server
// without consent obtained first. The offending path was not a permission
// prompt (the app holds no protected-data entitlement and declares no
// `NS*UsageDescription` key at all) — it was the diagnostics SDK: an absent
// `has_sentry_consent` read back as `true`, so Sentry started at cold start,
// before the consent screen had ever been drawn.
//
// These tests pin the two halves of the fix so it cannot regress:
//   1. the consent PREDICATE — unanswered is not consent;
//   2. the consent SCREEN — the upload is disclosed, and diagnostics are opt-in.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_sentry_service.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/features/auth/presentation/consent_page.dart';
import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // slang loads non-base locales from DEFERRED libraries. `setLocaleSync`
  // throws `_DeferredNotLoadedError` until they are loaded, and the async
  // `setLocale` never completes when awaited *inside* a `testWidgets` body
  // (the fake-async zone does not drive `loadLibrary()`), which hangs the run.
  // Loading them all once out here, in real async, makes the sync setter usable
  // in the tests below.
  setUpAll(() async {
    for (final locale in AppLocale.values) {
      await LocaleSettings.setLocale(locale);
    }
    await LocaleSettings.setLocale(AppLocale.en);
  });

  Future<ProviderContainer> containerWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('DesktopSentryService.shouldRun', () {
    test('a fresh install never starts the SDK', () {
      // The exact cold-start read on first launch: neither key exists.
      expect(
        DesktopSentryService.shouldRun(
          hasCompletedConsent: false,
          hasSentryConsent: false,
          isPrivateMode: false,
        ),
        isFalse,
      );
    });

    test(
      'an unanswered question is not consent, even if the flag reads true',
      () {
        // The precise regression: `has_sentry_consent` defaulting to true while
        // the consent screen has never been completed.
        expect(
          DesktopSentryService.shouldRun(
            hasCompletedConsent: false,
            hasSentryConsent: true,
            isPrivateMode: false,
          ),
          isFalse,
        );
      },
    );

    test('Private mode overrides a granted consent', () {
      expect(
        DesktopSentryService.shouldRun(
          hasCompletedConsent: true,
          hasSentryConsent: true,
          isPrivateMode: true,
        ),
        isFalse,
      );
    });

    test('answered + granted + account mode is the only true', () {
      expect(
        DesktopSentryService.shouldRun(
          hasCompletedConsent: true,
          hasSentryConsent: true,
          isPrivateMode: false,
        ),
        isTrue,
      );
    });
  });

  group('stored consent defaults', () {
    test('an absent answer reads back as NOT consented', () async {
      final container = await containerWith(const {});
      final consent = container.read(desktopConsentControllerProvider);

      expect(consent.hasCompletedOnboarding, isFalse);
      expect(
        consent.hasSentryConsent,
        isFalse,
        reason: 'absent means unanswered, and unanswered is not consent',
      );
    });

    test('the Settings switch reads back the same OFF', () async {
      final container = await containerWith(const {});
      // Hydration is async (it reads prefs after build); pump the microtask
      // queue so the controller has applied it.
      container.read(settingsFormControllerProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(settingsFormControllerProvider).crashReports,
        isFalse,
      );
    });

    test('a stored grant survives', () async {
      final container = await containerWith(const {
        'has_completed_consent': true,
        'has_sentry_consent': true,
      });
      final consent = container.read(desktopConsentControllerProvider);

      expect(consent.hasCompletedOnboarding, isTrue);
      expect(consent.hasSentryConsent, isTrue);
    });
  });

  group('DesktopConsentPage', () {
    Future<void> pumpConsentPage(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: TranslationProvider(
            child: MaterialApp(
              theme: EvolveTheme.dark(),
              home: const DesktopConsentPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('discloses the upload before asking for consent', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpConsentPage(tester);

      // The three disclosure bullets: what is uploaded and to whom, what stays
      // on the Mac, and what is never touched. They are rich spans (bold
      // lead-in + detail), so the finder has to look inside RichText.
      Finder span(String text) => find.textContaining(text, findRichText: true);

      expect(find.text(t.consentPage.uploadTitle), findsOneWidget);
      expect(span(t.consentPage.uploadAccountBody), findsOneWidget);
      expect(span(t.consentPage.uploadPrivateBody), findsOneWidget);
      expect(span(t.consentPage.uploadNeverBody), findsOneWidget);

      // Disclosure ABOVE the control that agrees to it — the guideline's order.
      final disclosureY = tester
          .getTopLeft(span(t.consentPage.uploadAccountBody))
          .dy;
      final checkboxY = tester
          .getTopLeft(find.text(t.consentPage.acceptTerms))
          .dy;
      expect(disclosureY, lessThan(checkboxY));
    });

    testWidgets('crash diagnostics start OFF and are opt-in', (tester) async {
      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpConsentPage(tester);

      final switchFinder = find.byType(EvolveSwitch);
      expect(switchFinder, findsOneWidget);
      expect(
        tester.widget<EvolveSwitch>(switchFinder).value,
        isFalse,
        reason: 'a pre-armed switch collects inattention, not consent',
      );
    });

    testWidgets('Continue stays disabled until the terms are accepted', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpConsentPage(tester);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    // The invariant that matters is not "Continue is painted somewhere" — a
    // permanently-disabled button is on screen too. It is that the user can
    // actually GET THROUGH: tick the box, then press Continue.
    //
    // Asserting only the button's rect is what let the real defect ship for a
    // while: with the checkbox inside the scroll region, at the window's own
    // minSize it rendered at y447 against a viewport ending at y410 — off the
    // internal fold, untappable, Continue disabled forever. The rect assertion
    // passed the whole time.
    //
    // Every locale, because German and Arabic are the long ones and the pinned
    // footer is what has to absorb them.
    for (final size in const [Size(1440, 900), Size(960, 640)]) {
      for (final locale in AppLocale.values) {
        testWidgets(
          'the gate can be passed at $size in ${locale.languageCode}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);
            // Sync, not `setLocale`: the async variant never completes under
            // `flutter test` and hangs the whole run.
            LocaleSettings.setLocaleSync(locale);
            addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));

            await pumpConsentPage(tester);

            // Continue starts disabled...
            expect(
              tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
              isNull,
            );

            // ...the checkbox is reachable and hit-testable...
            final checkbox = find.byType(CheckboxListTile);
            expect(checkbox, findsOneWidget);
            await tester.tap(checkbox);
            await tester.pumpAndSettle();

            // ...and pressing it enables the only way forward.
            expect(
              tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
              isNotNull,
              reason:
                  'the accept control is unreachable at $size — hard lockout',
            );

            // The legal links stay pinned too (Guideline 3.1.2(c)).
            for (final finder in [
              find.byType(FilledButton),
              find.text(t.consentPage.openTerms),
              find.text(t.consentPage.openPrivacy),
            ]) {
              final rect = tester.getRect(finder);
              expect(rect.bottom, lessThanOrEqualTo(size.height));
              expect(rect.top, greaterThanOrEqualTo(0.0));
            }
          },
        );
      }
    }
  });
}
