// Verifies the WIRING of the Goals period header on mobile: the title line
// names the period ("Week 2", "Q3 2026") and the line under it spells out the
// exact days that period covers, for weekly / quarterly / monthly. Annual and
// lifetime stay single-line — their titles are already their own range.
//
// The wording of every range shape (same month, cross month, cross year, all
// five locales) is pinned by macro_goal_range_label_test.dart. This drives the
// real screen instead, on a FIXED period, so the assertions are exact strings
// and independent of the wall clock.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/macro_goals_stats_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/macro_goals_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isLoggedIn: false);
}

Map<String, dynamic> _emptyStats() => {
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

/// Pumps the goals screen with the tutorial already seen (it would otherwise
/// cover the header with its scrim) and returns the container, so a test can
/// drive the period selection directly instead of tapping through the plan
/// sheet and the ‹ › chevrons.
Future<ProviderContainer> _pumpGoalsScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_tutorial_supabase': true,
    'has_seen_goals_tutorial_supabase': true,
    'has_seen_stats_tutorial_supabase': true,
    'macro_goals_cache': '[]',
  });
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
      macroGoalsStatsProvider.overrideWith((ref, year) async => _emptyStats()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: MacroGoalsScreen(isActive: true)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Selects a plan and a fixed period, so every assertion below is an exact
/// string rather than something recomputed from `DateTime.now()`.
Future<void> _selectPeriod(
  WidgetTester tester,
  ProviderContainer container, {
  required GoalType type,
  int year = 2026,
  int quarter = 3,
  int month = 8,
  int week = 2,
}) async {
  final view = container.read(macroGoalsViewProvider.notifier);
  view.setType(type);
  view.setYear(year);
  view.setQuarter(quarter);
  view.setMonth(month);
  view.setWeek(week);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('weekly names the week and spells out its days below', (
    tester,
  ) async {
    final container = await _pumpGoalsScreen(tester);
    await _selectPeriod(tester, container, type: GoalType.weekly);

    expect(find.text('${t.common.calendarView.week} 2'), findsOneWidget);
    expect(find.text('8 – 14 August 2026'), findsOneWidget);
  });

  testWidgets('the final logical week shows its true cross-month span', (
    tester,
  ) async {
    final container = await _pumpGoalsScreen(tester);
    // August 2026 has five logical weeks; the fifth runs 29 Aug – 4 Sep, and
    // those September days really are summed into the goal.
    await _selectPeriod(tester, container, type: GoalType.weekly, week: 5);

    expect(find.text('29 August – 4 September 2026'), findsOneWidget);
  });

  testWidgets('quarterly shows the quarter first and last day', (tester) async {
    final container = await _pumpGoalsScreen(tester);
    await _selectPeriod(tester, container, type: GoalType.quarterly);

    expect(find.text('Q3 2026'), findsOneWidget);
    expect(find.text('1 July – 30 September 2026'), findsOneWidget);
  });

  testWidgets('monthly shows the month first and last day', (tester) async {
    final container = await _pumpGoalsScreen(tester);
    await _selectPeriod(tester, container, type: GoalType.monthly);

    expect(find.text('1 – 31 August 2026'), findsOneWidget);
  });

  testWidgets('annual stays single-line — the year is its own range', (
    tester,
  ) async {
    final container = await _pumpGoalsScreen(tester);
    await _selectPeriod(tester, container, type: GoalType.annual);

    expect(find.text('2026'), findsOneWidget);
    expect(find.text('1 January – 31 December 2026'), findsNothing);
  });

  testWidgets('lifetime keeps its description and shows no range', (
    tester,
  ) async {
    final container = await _pumpGoalsScreen(tester);
    await _selectPeriod(tester, container, type: GoalType.lifetime);

    expect(find.text(t.macroGoals.lifetimeGoalsDescription), findsOneWidget);
    expect(find.textContaining(' – '), findsNothing);
  });
}
