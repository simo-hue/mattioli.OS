// The Subscription screen in Private mode (Guidelines 3.1.2 and 5.1.1(v)).
//
// Two defects met on this screen and these tests exist to keep them apart:
//
//   1. The paywall was the ONLY surface in the app carrying the Terms of Use
//      (EULA) link, and it was hidden entirely in Private mode
//      (`if (!isPrivateMode)` on the profile row). A Private-mode user could
//      therefore reach no legal document at all after onboarding.
//   2. Private mode force-injects `isPro: true`, so everything Pro unlocks on
//      device is already free there — but the app only ever expressed that as
//      an absence. Nothing said it.
//
// The screen now says it outright, and carries the links. That is both the
// honest UI and the clearest available answer to the guideline Apple cited.
//
// The critical negative assertion is the last one: RevenueCat is never
// configured in Private mode, so any purchase affordance here would be a
// button that cannot work.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/subscription_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedDataMode extends ActiveDataModeNotifier {
  _FixedDataMode(this._mode);

  final AppDataMode _mode;

  @override
  AppDataMode build() => _mode;
}

Widget _app(AppDataMode mode, SharedPreferences prefs) => ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        activeDataModeProvider.overrideWith(() => _FixedDataMode(mode)),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.lightTheme(null),
          home: const SubscriptionScreen(),
        ),
      ),
    );

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('states plainly that there is nothing to purchase',
      (tester) async {
    await tester.pumpWidget(_app(AppDataMode.private, prefs));
    await tester.pump();

    expect(find.text('Nothing to buy here'), findsOneWidget);
    expect(
      find.textContaining('already included'),
      findsOneWidget,
      reason: 'the user must be told they already have every Pro feature, '
          'not left to infer it from nothing being gated',
    );
  });

  testWidgets('carries both mandatory legal links', (tester) async {
    await tester.pumpWidget(_app(AppDataMode.private, prefs));
    await tester.pump();

    expect(find.text('Terms of Use (EULA)'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('does not render without waiting on a store round-trip',
      (tester) async {
    await tester.pumpWidget(_app(AppDataMode.private, prefs));
    await tester.pump();

    // RevenueCat is never configured in Private mode, so if initState still
    // called into it the screen would sit on its spinner forever.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Nothing to buy here'), findsOneWidget);
  });

  testWidgets('offers no purchase or restore affordance', (tester) async {
    await tester.pumpWidget(_app(AppDataMode.private, prefs));
    await tester.pump();

    expect(find.text('Activate Subscription'), findsNothing);
    expect(
      find.text('Restore purchases'),
      findsNothing,
      reason: 'there is no RevenueCat customer in Private mode, so a restore '
          'control could only fail',
    );
  });
}
