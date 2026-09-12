// Quitting mid-onboarding must not lock the user onto Home forever.
//
// The bottom bar and the PageView are both disabled while ANY of the three
// tutorial flags is false — that is deliberate, so the tour is not escaped
// halfway. What was missing is the other half of the deal: the app must put the
// user back where the interrupted tour resumes. It only ever did that as a
// side effect of finishing the previous step (`_onItemTapped(2,
// bypassTutorialLock: true)` from the dashboard tour's last card), so a
// force-quit between the two steps left dashboard=true / goals=false with the
// page stuck on Home: the goals tour can only start when page 2 is active, the
// dashboard tour will not re-run, and navigation is locked. Statistics and Goals
// become unreachable, with 'Repeat tutorial' buried in Profile the only escape.
//
// Reachable without any force-quit at all: `ModeAwareTutorialNotifier.build`
// falls back to the legacy un-suffixed key in Supabase mode, so an account-mode
// user upgrading from a build that only wrote `has_seen_tutorial` starts here.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/macro_goals_stats_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoggedInAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isLoggedIn: true);
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

Future<void> _pumpHome(
  WidgetTester tester, {
  required bool dashboardSeen,
  required bool goalsSeen,
  required bool statsSeen,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  SharedPreferences.setMockInitialValues({
    'has_seen_tutorial_supabase': dashboardSeen,
    'has_seen_goals_tutorial_supabase': goalsSeen,
    'has_seen_stats_tutorial_supabase': statsSeen,
    'macro_goals_cache': '[]',
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_LoggedInAuth.new),
      macroGoalsStatsProvider.overrideWith((ref, year) async => _emptyStats()),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: AppTheme.darkTheme(null),
        locale: const Locale('en'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: AppLocaleUtils.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  ));
  // The resume decision is taken in a post-frame callback, after an async
  // profile check, so a single pump is not enough.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The page the dashboard's own PageView is showing.
///
/// `.first` because MacroGoalsScreen nests a PageView of its own, so once the
/// fix lands on page 2 there are two in the tree; the outermost, in depth-first
/// order, is the dashboard's.
int _currentPage(WidgetTester tester) {
  final pageView = tester.widgetList<PageView>(find.byType(PageView)).first;
  return pageView.controller!.page!.round();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets('an interrupted flow resumes on Goals, not stranded on Home',
      (tester) async {
    await _pumpHome(
      tester,
      dashboardSeen: true,
      goalsSeen: false,
      statsSeen: false,
    );

    expect(_currentPage(tester), 2,
        reason: 'the goals tour can only start while page 2 is active, and '
            'navigation is locked until the flow completes');
  });

  testWidgets('an interrupted flow resumes on Statistics for the last step',
      (tester) async {
    await _pumpHome(
      tester,
      dashboardSeen: true,
      goalsSeen: true,
      statsSeen: false,
    );

    expect(_currentPage(tester), 0);
  });

  testWidgets('a completed flow is left alone on Home', (tester) async {
    await _pumpHome(
      tester,
      dashboardSeen: true,
      goalsSeen: true,
      statsSeen: true,
    );

    expect(_currentPage(tester), 1);
  });

  testWidgets('a fresh install is left on Home for the dashboard tour',
      (tester) async {
    // Step one starts from Home; moving the page here would break the tour that
    // does work.
    await _pumpHome(
      tester,
      dashboardSeen: false,
      goalsSeen: false,
      statsSeen: false,
    );

    expect(_currentPage(tester), 1);
  });
}
