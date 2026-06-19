import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/l10n/generated/app_localizations.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/statistics_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(isLoggedIn: false);
  }
}

Future<void> _pumpStatisticsTutorialScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_tutorial_supabase': true,
    'has_seen_goals_tutorial_supabase': true,
    'has_seen_stats_tutorial_supabase': false,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme(null),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(
          body: StatisticsScreen(isActive: true, onFinishTutorial: null),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('statistics tutorial popup is visible on the first frame', (
    tester,
  ) async {
    await _pumpStatisticsTutorialScreen(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Filter by Habit'), findsOneWidget);
  });

  testWidgets('statistics tutorial pending state ignores surface taps', (
    tester,
  ) async {
    await _pumpStatisticsTutorialScreen(tester);

    expect(find.text('Filter by Habit'), findsOneWidget);

    await tester.tapAt(const Offset(24, 24));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Filter by Habit'), findsOneWidget);
  });

  testWidgets(
    'statistics tutorial advances without delayed coachmark startup',
    (tester) async {
      await _pumpStatisticsTutorialScreen(tester);

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Statistics Sections'), findsOneWidget);
    },
  );
}
