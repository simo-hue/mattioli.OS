// F59 (second surface) — ⌘K → goal row → "reschedule" was the last macro-goal
// create path with no free-tier cap.
//
// `rescheduleGoal` fails the old goal and mints a BRAND NEW one
// (`_createGoalOptimistically` with a fresh id). The palette's own
// `PaletteActionKind.createGoal` case refuses past 100 goals on a free account
// — its comment calls it "the same free-tier cap the dashboard + quick-add
// enforce (mobile parity)" — and the Goals board's reschedule icon now does the
// same. The palette's row menu did not, so a free user at the cap could open
// ⌘K, pick any non-lifetime goal and mint a 101st, indefinitely.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/search/presentation/command_palette.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  // Desktop tests assert the Italian copy; pin the slang locale.
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  testWidgets(
    'a free user at the 100-goal cap cannot reschedule from the ⌘K row menu',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();

      // Exactly 100 goals: one weekly goal in the current week bucket (so the
      // launchpad lists it and its row menu is on screen) plus 99 lifetime
      // goals. The cap counts every goal, as quick-add and ⌘K → Create do.
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

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          dashboardRepositoryProvider.overrideWithValue(repository),
          desktopIsProProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The palette is pushed as its own route, the way the shell opens it.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              theme: EvolveTheme.dark(EvolveColors.primaryStrong),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('it')],
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(body: CommandPalette()),
                      ),
                    ),
                    child: const Text('open palette'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open palette'));
      await tester.pumpAndSettle();

      expect(container.read(dashboardControllerProvider).goals, hasLength(100));
      expect(
        find.text('Correre 10 km'),
        findsOneWidget,
        reason: 'the launchpad lists this week\'s active weekly goals',
      );

      // Open that row's "…" menu, then take the reschedule item.
      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pumpAndSettle();
      final reschedule = find.text(t.palette.rowReschedule);
      expect(reschedule, findsOneWidget);
      await tester.tap(reschedule);
      await tester.pumpAndSettle();

      expect(
        container.read(dashboardControllerProvider).goals,
        hasLength(100),
        reason: 'the ⌘K reschedule must be capped like ⌘K → Create goal',
      );
      expect(repository.createGoalCalls, 0);
      // The original must be untouched too: rescheduleGoal fails the old goal
      // before minting the new one, so a half-applied reschedule would leave
      // the user with a failed goal and nothing to replace it.
      expect(
        container
            .read(dashboardControllerProvider)
            .goals
            .firstWhere((goal) => goal.id == 'visible')
            .state,
        GoalState.active,
      );
    },
  );
}
