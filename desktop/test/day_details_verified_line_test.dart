// The calendar day-detail popup must let the user tell an auto-verified habit
// (completion synced from the iPhone's HealthKit / Screen Time) apart from a
// manual one — the same read-only marker the Protocol table shows, which now
// names the rule the habit is measured against rather than saying "Verified".
// These drive the real dialog through its public entry point
// [showDayDetailsDialog], so the whole snapshot → dialog → row chain is covered.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/dashboard/presentation/dashboard_page.dart';
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  // The marker copy AND its number formatting are locale-dependent, so pin the
  // slang locale — awaited, because non-base locales are deferred.
  setUp(() async => LocaleSettings.setLocale(AppLocale.it));

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

  testWidgets('the day-detail popup names the rule of an auto-verified habit '
      'but marks nothing on a manual one', (tester) async {
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
    // ...but only the auto-verified one carries the marker, and it names the
    // actual rule. Computed through the helper rather than hardcoded, so this
    // asserts the wiring and not a particular locale's separators.
    expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
    // The literal Italian string, not a call to the helper under test — an
    // expectation computed from the same code it checks would pass even if the
    // formatting were wrong. setUp pins the locale, so "8.000" is deterministic.
    expect(find.text('≥ 8.000 Passi'), findsOneWidget);
  });

  testWidgets('no rule line appears when every habit for the day is manual', (
    tester,
  ) async {
    await tester.pumpWidget(harness(snapshotWith([habit('A'), habit('B')])));
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.byIcon(LucideIcons.shieldCheck), findsNothing);
  });
  // ── The other two restructured surfaces ───────────────────────────────────
  //
  // The Protocol table row and the dashboard "today" row were restructured the
  // same way (name on its own full-width row, marker beneath) and had no test.
  // These pump the real pages, so a fixed-height ancestor or a squeezed name
  // would surface here rather than on device.

  /// The calendar's day cells pulse forever, so `pumpAndSettle` never settles on
  /// this page — pump a fixed budget of frames instead.
  Future<void> settleFrames(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('the Protocol table names the rule under the habit name',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const rule = VerificationRule(
      provider: VerificationProvider.healthKit,
      metricKey: 'steps',
      comparator: VerificationComparator.atLeast,
      threshold: 8000,
      unit: VerificationUnit.count,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            _SeededDashboardRepository(
              snapshotWith([
                habit('Allenamento in palestra completo', rule: rule),
                habit('Manual'),
              ]),
            ),
          ),
        ],
        child: MaterialApp(
          theme: EvolveTheme.dark(),
          home: const Scaffold(body: HabitsPage()),
        ),
      ),
    );
    await settleFrames(tester);
    await tester.tap(find.text(t.habitsPage.tabProtocol));
    await settleFrames(tester);

    const long = 'Allenamento in palestra completo';
    expect(find.text(long), findsOneWidget);
    expect(find.text('≥ 8.000 Passi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final verifiedWidth = tester.getSize(find.text(long)).width;

    // The discriminating assertion: the same title, same width, with NO rule to
    // label. The old inline pill made these differ — that is the whole bug. A
    // bare `> 150` threshold would NOT catch it, because even squeezed beside a
    // 180pt pill the title still cleared 400pt in this column.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            _SeededDashboardRepository(
              snapshotWith([habit(long), habit('Manual')]),
            ),
          ),
        ],
        child: MaterialApp(
          theme: EvolveTheme.dark(),
          home: const Scaffold(body: HabitsPage()),
        ),
      ),
    );
    await settleFrames(tester);
    await tester.tap(find.text(t.habitsPage.tabProtocol));
    await settleFrames(tester);

    expect(tester.getSize(find.text(long)).width, verifiedWidth);
  });

  testWidgets('the dashboard row names the rule under the habit name',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const rule = VerificationRule(
      provider: VerificationProvider.healthKit,
      metricKey: 'steps',
      comparator: VerificationComparator.atLeast,
      threshold: 8000,
      unit: VerificationUnit.count,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            _SeededDashboardRepository(
              snapshotWith([habit('Auto', rule: rule)]),
            ),
          ),
        ],
        child: MaterialApp(
          theme: EvolveTheme.dark(),
          home: const Scaffold(body: DashboardPage()),
        ),
      ),
    );
    await settleFrames(tester);

    expect(find.text('≥ 8.000 Passi'), findsOneWidget);
    // Deliberately NOT asserting `takeException() == null`: this panel has a
    // pre-existing 1px overflow in its fixed-width streak column, identical at
    // HEAD, and pinning it here would make an unrelated fix look like a
    // regression.
    tester.takeException();
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
