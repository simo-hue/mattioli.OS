import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics RPC providers degrade to offline fallbacks', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(globalCriticalDayRpcProvider.future), isNull);
    expect(
      await container.read(
        globalTrendRpcProvider('timeframe_week_short').future,
      ),
      isEmpty,
    );
    expect(
      await container.read(habitYearlyGridRpcProvider('habit-id').future),
      isEmpty,
    );
    expect(
      await container.read(macroGoalsStatsRpcProvider('all').future),
      isEmpty,
    );
  });
}
