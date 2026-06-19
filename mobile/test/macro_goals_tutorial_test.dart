import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/l10n/generated/app_localizations.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/macro_goals_stats_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/macro_goals_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(isLoggedIn: false);
  }
}

Map<String, dynamic> _emptyStats() {
  return {
    'total_goals': 0,
    'completed_goals': 0,
    'success_rate': 0,
    'best_category_rate': 0,
    'best_month_rate': 0,
    'best_type_rate': 0,
    'category_rates': <dynamic>[],
    'category_distribution': <dynamic>[],
    'category_performance': <dynamic>[],
    'monthly_performance': <dynamic>[],
    'type_performance': <dynamic>[],
    'annual_progression': <dynamic>[],
    'seasonality': <dynamic>[],
    'monthly_history': <dynamic>[],
    'interest_evolution': <dynamic>[],
  };
}

Future<void> _pumpGoalsTutorialScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_tutorial_supabase': true,
    'has_seen_goals_tutorial_supabase': false,
    'has_seen_stats_tutorial_supabase': false,
    'macro_goals_cache': '[]',
  });
  final prefs = await SharedPreferences.getInstance();
  final statsNavKey = GlobalKey();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        macroGoalsStatsProvider.overrideWith((ref, year) async {
          return _emptyStats();
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme(null),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: MacroGoalsScreen(
                  isActive: true,
                  statsNavKey: statsNavKey,
                  onFinishTutorial: () {},
                ),
              ),
              SizedBox(key: statsNavKey, height: 72, width: 120),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpGoalsTutorialOverlayFrame(WidgetTester tester) async {
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('goals tutorial popup is visible on the first Goals frame', (
    tester,
  ) async {
    await _pumpGoalsTutorialScreen(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Planning Type'), findsOneWidget);

    await _pumpGoalsTutorialOverlayFrame(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Planning Type'), findsOneWidget);
  });

  testWidgets('goals tutorial pending state ignores surface taps', (
    tester,
  ) async {
    await _pumpGoalsTutorialScreen(tester);

    expect(find.text('Planning Type'), findsOneWidget);

    await tester.tap(find.text('Performance Analysis'), warnIfMissed: false);
    await tester.pump();

    expect(find.text('Performance'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.text('Planning Type'), findsOneWidget);
  });

  testWidgets('goals tutorial advances without delayed coachmark startup', (
    tester,
  ) async {
    await _pumpGoalsTutorialScreen(tester);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('New Goal'), findsOneWidget);
  });

  test('ignores tutorial-only goal mutations in Private mode', () async {
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(macroGoalsProvider.notifier);

    await expectLater(
      notifier.updateStatus('tutorial_fake_goal', GoalStatus.completed),
      completes,
    );
    await expectLater(notifier.deleteGoal('tutorial_fake_goal'), completes);
    await expectLater(
      notifier.rescheduleGoal(
        MacroGoal(
          id: 'tutorial_fake_goal',
          title: 'Tutorial Goal',
          status: GoalStatus.active,
          type: GoalType.weekly,
          year: 2026,
          month: 6,
          weekNumber: 3,
          createdAt: DateTime(2026, 6, 19),
        ),
      ),
      completes,
    );

    expect(container.read(macroGoalsProvider).goals, isEmpty);
  });
}
