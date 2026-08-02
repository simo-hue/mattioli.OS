// App Store Guideline 5.1.2 — Data Use and Sharing.
//
// The macOS twin was rejected on this guideline on 2026-08-01 for uploading to
// a server before consent. iOS carried the same defect in a different place:
// `ConsentScreen._sentryConsent` was `final … = true` with NO control on the
// screen, so tapping Continue enabled third-party crash telemetry for every
// user without ever asking one. The crash-diagnostics card had been deleted at
// some point and the field left behind — the surviving "Item 1" / "Item 3"
// comments were the only trace.
//
// These tests pin the fix: the upload is disclosed before the checkbox that
// agrees to it, diagnostics are opt-in, and an unanswered question never reads
// back as consent. `sentry_teardown_test.dart` covers the `shouldRun` predicate
// itself.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/consent_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/consent_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('stored consent defaults', () {
    test('an absent answer reads back as NOT consented', () async {
      final prefs = await prefsWith(const {});
      final container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final consent = container.read(consentProvider);
      expect(consent.hasCompletedOnboarding, isFalse);
      expect(
        consent.hasSentryConsent,
        isFalse,
        reason: 'absent means unanswered, and unanswered is not consent',
      );
    });

    test('a stored grant survives', () async {
      final prefs = await prefsWith(const {
        'has_completed_consent': true,
        'has_sentry_consent': true,
      });
      final container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final consent = container.read(consentProvider);
      expect(consent.hasCompletedOnboarding, isTrue);
      expect(consent.hasSentryConsent, isTrue);
    });
  });

  group('ConsentScreen', () {
    Future<void> pumpConsentScreen(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final prefs = await prefsWith(const {});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
          child: TranslationProvider(
            child: MaterialApp(
              theme: AppTheme.lightTheme(null),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: const ConsentScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder span(String text) => find.textContaining(text, findRichText: true);

    testWidgets('discloses the upload before asking for consent', (
      tester,
    ) async {
      await pumpConsentScreen(tester, size: const Size(390, 1600));

      expect(find.text(t.consent.uploadTitle), findsOneWidget);
      expect(span(t.consent.uploadAccountBody), findsOneWidget);
      expect(span(t.consent.uploadPrivateBody), findsOneWidget);
      expect(span(t.consent.uploadNeverBody), findsOneWidget);

      // iOS really does read HealthKit and Screen Time, so the disclosure names
      // the boundary rather than denying access. Deleting this bullet while
      // leaving verification on would make the screen untrue.
      expect(span(t.consent.uploadHealthBody), findsOneWidget);

      final disclosureY = tester
          .getTopLeft(span(t.consent.uploadAccountBody))
          .dy;
      final checkboxY = tester.getTopLeft(find.byType(Checkbox)).dy;
      expect(disclosureY, lessThan(checkboxY));
    });

    testWidgets('crash diagnostics are asked for, and start OFF', (
      tester,
    ) async {
      await pumpConsentScreen(tester, size: const Size(390, 1600));

      // The control has to EXIST — its absence, not its value, was the defect.
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(
        tester.widget<Switch>(switchFinder).value,
        isFalse,
        reason: 'a pre-armed switch collects inattention, not consent',
      );
      expect(find.text(t.consent.crashDiagnostics), findsOneWidget);
    });

    // Continue must survive the TEXT SCALE too, not just the screen size.
    //
    // The header used to be a non-flex sibling of the Expanded, so it grew with
    // textScaler until the flex child collapsed and the button was laid out off
    // the bottom edge. iOS accessibility Dynamic Type reaches ~3.1x, and this
    // screen has no other exit — so a clipped button is a lockout. Testing at
    // 1.0 only, as the first version of this file did, cannot see it.
    for (final size in const [
      Size(390, 844), // iPhone 14/15/16
      Size(375, 667), // iPhone SE — the tightest screen still supported
    ]) {
      for (final scale in const [1.0, 2.0, 3.1]) {
        testWidgets('Continue stays on screen at $size, text scale $scale', (
          tester,
        ) async {
          await pumpConsentScreen(tester, size: size, textScale: scale);

          final button = find.text(t.consent.continueButton);
          expect(button, findsOneWidget);
          final rect = tester.getRect(button);
          expect(
            rect.bottom,
            lessThanOrEqualTo(size.height),
            reason: 'below the fold at $size/$scale — the only way forward',
          );
          expect(rect.top, greaterThanOrEqualTo(0.0));
        });
      }
    }

    testWidgets('the gate controls are announced to VoiceOver', (tester) async {
      // Disposed inline, not via addTearDown: the framework's
      // "SemanticsHandle was active at the end of the test" check runs before
      // tear-downs do.
      final handle = tester.ensureSemantics();

      await pumpConsentScreen(tester, size: const Size(390, 1600));

      // Continue is a BUTTON with a name, and — the actual defect — it still
      // carries a tap action while disabled, so VoiceOver can activate it and
      // hear why it is blocked instead of finding an inert piece of text.
      final continueNode = tester.getSemantics(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == t.consent.continueButton,
        ),
      );
      final data = continueNode.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      // Tristate, not bool: a control can be enabled, disabled, or carry no
      // enabled-ness at all. Disabled is the assertion — the button is not
      // usable yet, but it is still a button and still answers a tap.
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(
        continueNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'a disabled node with no action is a VoiceOver dead end',
      );

      // The checkbox and the switch inherit their card's title as their NAME,
      // rather than announcing as an unnamed control.
      expect(
        find.ancestor(
          of: find.byType(Checkbox),
          matching: find.byType(MergeSemantics),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byType(Switch),
          matching: find.byType(MergeSemantics),
        ),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
