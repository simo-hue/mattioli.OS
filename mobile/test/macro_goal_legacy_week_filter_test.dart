import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/macro_goal_calendar.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

MacroGoal _weekly({
  required String id,
  required int year,
  required int month,
  required int week,
}) => MacroGoal.fromJson({
  'id': id, 'title': id, 'status': 'active', 'type': 'weekly',
  'year': year, 'month': month, 'week_number': week,
  'created_at': DateTime(2020).toIso8601String(),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient(
        (req) async => http.Response(
          '[]',
          200,
          request: req,
          headers: {'content-type': 'application/json'},
        ),
      ),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
  });

  late ProviderContainer container;
  late MacroGoalsNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    notifier = container.read(macroGoalsProvider.notifier);
  });
  tearDown(() => container.dispose());

  List<String> idsFor({required int year, required int month, required int week}) =>
      notifier
          .getFilteredGoals(
            type: GoalType.weekly,
            year: year,
            month: month,
            weekNumber: week,
          )
          .map((g) => g.id)
          .toList();

  test('a legacy week 5 goal surfaces under the next month week 1', () {
    notifier.state = notifier.state.copyWith(
      goals: [
        _weekly(id: 'legacy', year: 2026, month: 8, week: 5),
        _weekly(id: 'canonical', year: 2026, month: 9, week: 1),
        _weekly(id: 'elsewhere', year: 2026, month: 9, week: 2),
      ],
    );

    // Both spellings of the 31 Aug – 6 Sep bucket, and only those. Order is
    // _sortGoals' business, not this test's.
    expect(
      idsFor(year: 2026, month: 9, week: 1),
      unorderedEquals(<String>['canonical', 'legacy']),
    );
    // Reaching the same bucket by its legacy address finds the same pair.
    expect(
      idsFor(year: 2026, month: 8, week: 5).toSet(),
      idsFor(year: 2026, month: 9, week: 1).toSet(),
    );
    expect(idsFor(year: 2026, month: 9, week: 2), ['elsewhere']);
  });

  test('a legacy December week 5 goal surfaces in the NEXT year', () {
    // The case a plain `goal.year != selectedYear` guard would silently drop:
    // the goal is stored under 2025 but belongs to January 2026 week 1.
    notifier.state = notifier.state.copyWith(
      goals: [_weekly(id: 'newYear', year: 2025, month: 12, week: 5)],
    );

    expect(legacyWeekBucket(2025, 12, 5),
        const WeekBucket(year: 2026, month: 1, week: 1));
    expect(idsFor(year: 2026, month: 1, week: 1), ['newYear']);
    // And it is NOT still sitting in December's last addressable week.
    expect(idsFor(year: 2025, month: 12, week: 4), isEmpty);
  });
}
