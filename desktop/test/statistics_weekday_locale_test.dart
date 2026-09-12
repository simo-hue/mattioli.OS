// Two weekday arrays in the Statistics page were hardcoded Italian, so the
// Trend chart's week axis and the per-habit Performance bars read
// 'Lun Mar Mer Gio Ven Sab Dom' in all five shipped locales — Latin-script
// Italian day names even inside the RTL Arabic build.
//
// Both now go through `_weekdayShort`, the localized 3-letter abbreviation the
// radar chart on the same screen already used. Italian is byte-identical
// ('Lunedì' → 'Lun', …), so only the other four locales change.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/features/statistics/presentation/statistics_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The seven Italian abbreviations that used to be hardcoded at both sites.
const _italianTokens = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

final _habit = DashboardHabit(
  id: 'g1',
  title: 'Lesen',
  color: Colors.blue,
  streak: 3,
  weeklyProgress: List.filled(7, false),
  state: HabitState.pending,
  startDate: DateTime(2025, 1, 1),
);

class _StubDashboardRepository extends DashboardRepository {
  @override
  DashboardSnapshot load() => DashboardSnapshot(
    habits: [_habit],
    goals: const [],
    trend: const [],
    checkIn: const DailyCheckIn(),
  );

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}

/// One RPC row per day of the week beginning Monday 2026-06-08, so the chart
/// renders seven weekday labels through `_trendLabel`.
List<Map<String, dynamic>> _weekTrendRows() => [
  for (var i = 0; i < 7; i++)
    {'date': '2026-06-${(8 + i).toString().padLeft(2, '0')}', 'rate': 50},
];

Future<void> _pumpStats(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          _StubDashboardRepository(),
        ),
        desktopIsProProvider.overrideWithValue(true),
        globalTrendRpcProvider(
          'timeframe_week_short',
        ).overrideWith((ref) async => _weekTrendRows()),
        bestHabitsRpcProvider(
          'timeframe_week_short',
        ).overrideWith((ref) async => const []),
        criticalHabitsRpcProvider.overrideWith((ref) async => const []),
        habitPerformanceRpcProvider('g1').overrideWith((ref) async => const []),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: EvolveTheme.dark(),
          home: const Scaffold(body: StatisticsPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.de));
  tearDown(() => LocaleSettings.setLocale(AppLocale.it));

  testWidgets('the Trend week axis is localized, not hardcoded Italian', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpStats(tester);
    await tester.tap(find.text(t.stats.tabTrend).first);
    await tester.pumpAndSettle();

    for (final token in _italianTokens) {
      expect(
        find.text(token),
        findsNothing,
        reason: 'the German build must not render the Italian "$token"',
      );
    }
    expect(find.text('Mon'), findsWidgets); // Montag
    expect(find.text('Son'), findsWidgets); // Sonntag
  });

  testWidgets('the per-habit Performance bars are localized too', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpStats(tester);

    // Switch the scope selector from "all habits" to the single habit (Pro).
    await tester.tap(find.byType(EvolveSelect<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lesen').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.stats.tabPerformance).first);
    await tester.pumpAndSettle();

    for (final token in _italianTokens) {
      expect(
        find.text(token),
        findsNothing,
        reason: 'the German build must not render the Italian "$token"',
      );
    }
    expect(find.text('Mon'), findsWidgets);
    expect(find.text('Son'), findsWidgets);
  });

  testWidgets('the Italian build is byte-identical to the old constants', (
    tester,
  ) async {
    LocaleSettings.setLocale(AppLocale.it);
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpStats(tester);
    await tester.tap(find.text(t.stats.tabTrend).first);
    await tester.pumpAndSettle();

    for (final token in _italianTokens) {
      expect(find.text(token), findsWidgets, reason: 'it must still say $token');
    }
  });
}
