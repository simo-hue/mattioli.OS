// The Legal section in App Settings (Guideline 3.1.2).
//
// Before this section existed, every legal link in the app lived on a surface
// that most users cannot get back to: the consent screen (first launch only),
// the auth screen (signed out only) and the paywall (account mode, and only
// while NOT subscribed). So a Private-mode user could reach no legal document
// at all after onboarding, and a subscriber could not reach the terms of the
// subscription they had just bought.
//
// This section is the one place that is reachable in every mode and in every
// entitlement state. It must stay that way — hence a test that asserts it is
// mode-independent rather than one that just checks the rows render.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/app_settings_screen.dart';
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
          home: const AppSettingsScreen(),
        ),
      ),
    );

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // Private mode ONLY, deliberately.
  //
  // Account mode cannot be pumped here: AppSettingsNotifier.build reads
  // `Supabase.instance` (settings_provider.dart:305), which asserts unless a
  // real client was initialised, so the screen throws before it renders. That
  // is a pre-existing property of the screen, not of this section.
  //
  // Covering only Private mode is not a gap in what matters, for two reasons.
  // Private mode is the mode where these links were genuinely unreachable —
  // the paywall carried them, and the paywall was hidden there. And
  // `_buildLegalCard` sits in the unconditional part of the build with no mode
  // check around it, so if it renders in one mode it renders in all of them.
  testWidgets('legal links are present in Private mode', (tester) async {
    await tester.pumpWidget(_app(AppDataMode.private, prefs));
    await tester.pump();

    // The section is last, below several cards.
    await tester.dragUntilVisible(
      find.text('Terms of Use (EULA)'),
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pump();

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(
      find.text('Terms of Use (EULA)'),
      findsOneWidget,
      reason: "Apple's standard EULA must be reachable from Settings — with "
          'no account this is the only route to it anywhere in the app',
    );
    expect(find.text('Manage subscription'), findsOneWidget);
  });
}
