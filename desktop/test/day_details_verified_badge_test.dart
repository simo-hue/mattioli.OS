// The calendar day-detail popup must let the user tell an auto-verified habit
// (completion synced from the iPhone's HealthKit / Screen Time) apart from a
// manual one — the same read-only "Verified" badge the Protocol table shows.
// These drive the real dialog through its public entry point
// [showDayDetailsDialog], so the whole snapshot → dialog → row chain is covered.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The badge copy is read via `t`, so pin the slang locale for determinism.
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  // Manual by default; pass a rule to make it auto-verified. No dates / no
  // frequency ⇒ active and scheduled every day, so it always shows for today.
  DashboardHabit habit(String id, {VerificationRule? rule}) => DashboardHabit(
    id: id,
    title: id,
    color: EvolveColors.primaryStrong,
    streak: 0,
    weeklyProgress: const [false, false, false, false, false, false, false],
    state: HabitState.pending,
    verificationRule: rule,
  );

  DashboardSnapshot snapshotWith(List<DashboardHabit> habits) =>
      DashboardSnapshot(
        habits: habits,
        goals: const [],
        trend: const [],
        checkIn: const DailyCheckIn(),
      );

  Widget harness(DashboardSnapshot snapshot) {
    final today = DateTime.now();
    return ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          _SeededDashboardRepository(snapshot),
        ),
      ],
      child: MaterialApp(
        theme: EvolveTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDayDetailsDialog(context, today),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the day-detail popup badges an auto-verified habit but not a '
      'manual one', (tester) async {
    const rule = VerificationRule(
      provider: VerificationProvider.healthKit,
      metricKey: 'steps',
      comparator: VerificationComparator.atLeast,
      threshold: 8000,
      unit: VerificationUnit.count,
    );
    await tester.pumpWidget(
      harness(snapshotWith([habit('Auto', rule: rule), habit('Manual')])),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    // Both habits are listed for the day...
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    // ...but only the auto-verified one carries the "Verified" badge.
    expect(find.text(t.settingsPage.verified), findsOneWidget);
  });

  testWidgets('no badge appears when every habit for the day is manual', (
    tester,
  ) async {
    await tester.pumpWidget(harness(snapshotWith([habit('A'), habit('B')])));
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text(t.settingsPage.verified), findsNothing);
  });
}

class _SeededDashboardRepository extends DashboardRepository {
  _SeededDashboardRepository(this._snapshot);

  final DashboardSnapshot _snapshot;

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}
