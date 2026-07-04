// WS9 — mode-selection guard for the statistics providers.
//
// Proves that in Private mode the stat providers compute locally (via the
// ported analytics engine over an injected data source) instead of hitting the
// Supabase RPC path. If the mode gate is ever removed, these providers would
// fall through to the cloud branch (which returns empty/null without a client)
// and this test would fail.
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics_source.dart';
import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Private mode statistics compute locally, not via Supabase RPC',
    () async {
      SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
      final prefs = await SharedPreferences.getInstance();

      final monday = DateTime(2026, 6, 15); // ISODOW 1
      final tuesday = monday.add(const Duration(days: 1));
      final logs = [
        HabitLogEntry(goalId: 'g1', date: monday, status: 'missed'),
        HabitLogEntry(goalId: 'g1', date: tuesday, status: 'done'),
      ];
      final data = PrivateAnalyticsData(
        allLogs: logs,
        logsByGoal: {'g1': logs},
        logsByDate: {},
        goals: [GoalInput(id: 'g1', startDate: DateTime(2026, 1, 1))],
        startDates: {'g1': DateTime(2026, 1, 1)},
        titles: {'g1': 'Read'},
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          privateAnalyticsDataProvider.overrideWith((ref) => data),
        ],
      );
      addTearDown(container.dispose);

      // Critical day = the injected data's worst weekday (Monday, rate 0), which
      // only the local engine can produce — the cloud branch would return null.
      final criticalDay = await container.read(
        globalCriticalDayRpcProvider.future,
      );
      expect(criticalDay, 'mon');

      // Per-goal providers also take the private branch.
      final grid = await container.read(
        habitYearlyGridRpcProvider('g1').future,
      );
      expect(grid, hasLength(365));

      final perf = await container.read(
        habitPerformanceRpcProvider('g1').future,
      );
      expect(perf, isNotEmpty);

      final alerts = await container.read(habitAlertsRpcProvider('g1').future);
      expect(alerts.containsKey('worst_negative_days'), isTrue);
    },
  );
}
