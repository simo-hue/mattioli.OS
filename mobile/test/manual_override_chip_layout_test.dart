// The "Set by you / Use Apple Health" chip must survive accessibility text
// sizes, in every locale, without losing its ACTION.
//
// It was a Row. With both halves `Flexible` the actionable label ellipsized as
// readily as the inert one; with `Flexible(flex: 0)` on the inert half it got
// worse, because `flex: 0` is INFLEXIBLE — "Set by you" took its full intrinsic
// width and "Use Apple Health" collapsed to ZERO. The 44pt tap target stayed
// live, so the release control still worked while saying nothing at all: an
// invisible button over a card whose own tap does something else entirely
// (cycle the status, and re-freeze the day).
//
// At large text scales neither half fits alone, so no pair of flex values
// rescues a Row. It is a Wrap now: the action moves to a second line instead of
// vanishing.

import 'package:evolve_verification/evolve_verification.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/ui/widgets/day_details_modal.dart';

void main() {
  // REAL Inter, not the harness placeholder.
  //
  // `flutter_test` substitutes a fixed-width block font whose glyphs are far
  // wider than Inter's, so a layout measured under it is not the layout the user
  // sees — a chip that "overflows" in a test can be comfortable on device, and
  // the numbers would be fiction either way. The app bundles these faces, so the
  // test can use exactly what ships.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final weight in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final file = File('assets/fonts/Inter-$weight.ttf');
      if (!file.existsSync()) continue;
      final loader = FontLoader('Inter')
        ..addFont(Future.value(
            ByteData.sublistView(await file.readAsBytes())));
      await loader.load();
    }
  });

  Goal verified() => Goal(
        id: 'g1',
        title: 'Steps',
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 6, 20),
        verificationRule: VerificationCatalog.steps.ruleWith(10000),
      );

  Future<void> pumpChip(
    WidgetTester tester, {
    required double width,
    required double textScale,
  }) async {
    tester.view.physicalSize = Size(width * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            // The card reads `context.appColors`, a ThemeExtension — without a
            // real app theme it null-checks and the test fails for a reason
            // that has nothing to do with layout.
            theme: AppTheme.darkTheme(null),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: SizedBox(
                      width: width,
                      child: GoalLogCard(
                        habit: verified(),
                        date: DateTime(2026, 8, 3),
                        status: 'done',
                        streak: 3,
                        manuallyResolved: true,
                        onRelease: () {},
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 320 = the narrowest shipping iPhone width; 390 = iPhone 14/15.
  // 3.1x is roughly iOS's largest accessibility size, which this app does not
  // clamp anywhere.
  // ENGLISH ONLY, and the reason is a harness limit rather than a choice.
  //
  // slang emits every non-English locale as a DEFERRED library. `setLocaleSync`
  // throws `_DeferredNotLoadedError` on one, and the async `setLocale` returns a
  // Future that never completes under `flutter_test` — a `de` case written the
  // obvious way either crashes or hangs for the full ten-minute harness timeout.
  //
  // The scale axis covers the gap for the property being measured, which is
  // purely one of width: German's longest string here ("Apple Health verwenden")
  // is about 1.4x the English, and these run to 3.1x. A layout that survives
  // English at 3.1x has already survived text longer than any locale produces at
  // normal size. Reading it on a real German device stays on the device-QA list,
  // because that is the only place the real thing can be seen.
  for (final width in const [320.0, 390.0]) {
    for (final scale in const [1.0, 2.0, 3.1]) {
      testWidgets('the chip does not overflow at ${width.toInt()}pt / ${scale}x',
          (tester) async {
        await pumpChip(tester, width: width, textScale: scale);

        expect(tester.takeException(), isNull,
            reason: 'a RenderFlex overflow here means the release control is '
                'clipped, and its 44pt tap target stays live regardless');
      });

      testWidgets(
          'the RELEASE label keeps a non-zero width at ${width.toInt()}pt / '
          '${scale}x', (tester) async {
        await pumpChip(tester, width: width, textScale: scale);

        final action = find.text(
          t.verification.manualReleaseToAuto(app: t.health.appName),
        );
        expect(action, findsOneWidget);
        // A LEGIBILITY floor, not `greaterThan(0)`. Under the old Row the
        // action label survived at 17-22pt on the wider widths — a bare
        // ellipsis, which a non-zero assertion waves through on the most common
        // device width while the control is effectively unlabelled.
        expect(
          tester.getSize(action).width,
          greaterThan(60),
          reason: 'THE REGRESSION: `flex: 0` on the inert half starved the '
              'ACTIONABLE half — a tappable control reduced to an ellipsis, '
              'over a card whose own tap re-freezes the day',
        );
      });
    }
  }
}
