// F23 — the Seasonality card always rendered empty.
//
// It sized every quarter's rod from a 'total' key NEITHER backend emits: both
// the private computation and the `get_macro_goals_stats` RPC return only
// {quarter, active, failed, completed} for seasonality. So `tot` was 0.0, and
// fl_chart 0.69.2 wraps BOTH the main rod and the rodStackItems loop in
// `if (barRod.toY != barRod.fromY)` (bar_chart_painter.dart) with fromY
// defaulting to 0 — the stacks were skipped along with the rod, leaving only
// the four flat grey background bars. The same lookup fed maxX, so even those
// collapsed to the 5.0 floor.
//
// This is the 'All years' view, which every free user is pinned to.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/macro_goals_stats_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/widgets/macro_goals/macro_goals_stats_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isLoggedIn: false);
}

/// The 'all' payload, shaped exactly like both producers: seasonality rows
/// carry no 'total'.
Map<String, dynamic> _stats() => {
      'total_goals': 6,
      'completed_goals': 3,
      'success_rate': 50,
      'best_year': 2026,
      'best_year_rate': 50,
      'most_productive_year': 2026,
      'most_productive_count': 6,
      'year_progression': <dynamic>[],
      'category_performance': <dynamic>[],
      'type_distribution': <String, dynamic>{},
      'seasonality': <dynamic>[
        {'quarter': 1, 'active': 2, 'failed': 1, 'completed': 3},
        {'quarter': 3, 'active': 1, 'failed': 0, 'completed': 0},
      ],
      'monthly_history': <dynamic>[],
      'interest_evolution': <dynamic>[],
    };

/// The seasonality chart: the only BarChart on this view whose groups are the
/// four quarters.
BarChartData _seasonalityChart(WidgetTester tester) {
  final charts = tester
      .widgetList<BarChart>(find.byType(BarChart))
      .map((c) => c.data)
      .where((d) =>
          d.barGroups.length == 4 &&
          d.barGroups.map((g) => g.x).toList().toString() == '[1, 2, 3, 4]')
      .toList();
  expect(charts, hasLength(1), reason: 'the seasonality chart must be on screen');
  return charts.single;
}

void main() {
  testWidgets('the quarter rods are sized from the statuses that are emitted',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({'macro_goals_cache': '[]'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
          macroGoalsStatsProvider.overrideWith((ref, year) async => _stats()),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: AppTheme.darkTheme(null),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: AppLocaleUtils.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(body: MacroGoalsStatsView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final data = _seasonalityChart(tester);
    final q1 = data.barGroups.firstWhere((g) => g.x == 1).barRods.single;
    final q3 = data.barGroups.firstWhere((g) => g.x == 3).barRods.single;
    final q2 = data.barGroups.firstWhere((g) => g.x == 2).barRods.single;

    expect(q1.toY, 6.0,
        reason: 'a rod whose toY equals its fromY is skipped by the painter, '
            'and it takes the whole stack with it');
    expect(q1.toY, greaterThan(q1.fromY));
    expect(q1.rodStackItems, hasLength(3));
    expect(q1.rodStackItems.last.toY, 6.0);

    expect(q3.toY, 1.0);
    // A quarter with no goals stays empty, and the background bar is scaled off
    // the busiest quarter rather than the 5.0 floor.
    expect(q2.toY, 0.0);
    expect(q1.backDrawRodData.toY, closeTo(7.2, 0.001));
  });
}
