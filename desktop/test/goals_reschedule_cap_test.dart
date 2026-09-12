// F59 — the calendar-clock "reschedule" action on the desktop Goals board was
// the one macro-goal create path with no free-tier cap.
//
// `rescheduleGoal` marks the old goal failed and mints a BRAND NEW goal
// (`_createGoalOptimistically` with a fresh id). Quick-add
// (`_submitQuickGoal`) and ⌘K → Create goal both refuse past 100 goals on a
// free account — the palette's own comment calls it "the same free-tier cap the
// dashboard + quick-add enforce (mobile parity)" — and mobile's `_reschedule`
// (goal_item_widget) performs exactly this check. Only the desktop reschedule
// icon skipped it, so a free user at the cap could mint a 101st goal, and go on
// doing it indefinitely.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/goals/presentation/goals_page.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _SeededDashboardRepository extends DashboardRepository {
  _SeededDashboardRepository(this._snapshot);

  DashboardSnapshot _snapshot;
  int createGoalCalls = 0;

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<DashboardGoal> createGoal(DashboardGoal goal) async {
    createGoalCalls++;
    return goal;
  }
}

/// Skips the cloud/private category fetch so the page renders hermetically.
class _NoCategoriesController extends DesktopGoalCategoriesController {
  @override
  Future<List<DesktopGoalCategory>> build() async => const [];
}

void main() {
  // Desktop tests assert the Italian copy; pin the slang locale.
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  testWidgets('a free user at the 100-goal cap cannot reschedule a 101st goal',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Exactly 100 goals: one weekly goal in the period the board opens on (so
    // its reschedule icon is on screen) and 99 lifetime goals off-screen under
    // another plan type. The cap counts every goal, as quick-add does.
    final bucket = weekBucketOf(DateTime.now());
    final goals = <DashboardGoal>[
      DashboardGoal(
        id: 'visible',
        title: 'Correre 10 km',
        category: '',
        color: EvolveColors.violet,
        progress: 0,
        dueLabel: 'Settimana corrente',
        type: GoalType.weekly,
        state: GoalState.active,
        year: bucket.year,
        month: bucket.month,
        weekNumber: bucket.week,
        createdAt: DateTime(2026, 1, 1),
      ),
      for (var i = 0; i < 99; i++)
        DashboardGoal(
          id: 'lifetime-$i',
          title: 'Obiettivo $i',
          category: '',
          color: EvolveColors.violet,
          progress: 0,
          dueLabel: 'Sempre',
          type: GoalType.lifetime,
          state: GoalState.active,
          createdAt: DateTime(2026, 1, 1),
        ),
    ];

    final repository = _SeededDashboardRepository(
      DashboardSnapshot(
        habits: const [],
        goals: goals,
        trend: const [],
        checkIn: const DailyCheckIn(),
      ),
    );
    late final ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(repository),
          desktopGoalCategoriesControllerProvider
              .overrideWith(_NoCategoriesController.new),
          desktopIsProProvider.overrideWithValue(false),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: EvolveTheme.dark(),
              home: const Scaffold(body: GoalsPage()),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(dashboardControllerProvider).goals, hasLength(100));

    final reschedule = find.byIcon(LucideIcons.calendarClock);
    expect(reschedule, findsOneWidget);
    await tester.tap(reschedule, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      container.read(dashboardControllerProvider).goals,
      hasLength(100),
      reason: 'reschedule must be capped like quick-add and ⌘K',
    );
    expect(repository.createGoalCalls, 0);
    // The original must be untouched too: rescheduleGoal fails the old goal
    // before it mints the new one, so a half-applied reschedule would leave the
    // user with a failed goal and nothing to replace it.
    expect(
      container
          .read(dashboardControllerProvider)
          .goals
          .firstWhere((goal) => goal.id == 'visible')
          .state,
      GoalState.active,
    );
  });
}
