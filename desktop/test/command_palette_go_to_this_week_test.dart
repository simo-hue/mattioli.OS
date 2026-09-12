// ⌘K → "today" offered a row that did nothing, and taking it wedged the
// palette.
//
// The launchpad build of the "Go to this week" action attaches a navTarget
// (`GoalNavTarget(weekly, weekBucketOf(now))`); the SEARCH-mode build, which
// turns a `_commandCatalogue` candidate into an `ActionEntry`, passes only
// kind/label/icon/score. `_runAction`'s `goToThisWeek` case then found
// `entry.navTarget == null` and did nothing at all — no navigation, no
// dismissal — after `_activate` had already latched `_activated = true`. Since
// nothing ever clears that latch, every subsequent activation in that visit was
// swallowed by `if (_activated) return;`.
//
// "today", "now" and "current" are its only keywords that reach it: the period
// parser word-matches week/month/quarter/year, so nothing else routes here.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/search/application/goal_nav_target.dart';
import 'package:evolve_desktop/features/search/presentation/command_palette.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubRepository extends DashboardRepository {
  @override
  DashboardSnapshot load() => const DashboardSnapshot(
    habits: [],
    goals: [],
    trend: [],
    checkIn: DailyCheckIn(),
  );

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}

/// Pushes the palette as its own ROUTE, the way the shell opens it, so
/// `_dismiss`'s `maybePop` has something to pop and "did it dismiss?" is a real
/// question rather than a no-op.
Future<ProviderContainer> _pumpPalette(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      dashboardRepositoryProvider.overrideWithValue(_StubRepository()),
    ],
  );
  addTearDown(container.dispose);

  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: EvolveTheme.dark(EvolveColors.primaryStrong),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en')],
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
  return container;
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('the catalogue "Go to this week" row actually jumps, and closes '
      'the palette', (tester) async {
    final container = await _pumpPalette(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(CommandPalette),
        matching: find.byType(TextField),
      ),
      'today',
    );
    await tester.pumpAndSettle();

    final row = find.text(t.palette.goToThisWeek);
    expect(
      row,
      findsOneWidget,
      reason: '"today" is one of the catalogue row\'s own keywords',
    );

    await tester.tap(row);
    await tester.pumpAndSettle();

    final bucket = weekBucketOf(DateTime.now());
    final target = container.read(goalNavTargetProvider);
    expect(
      target,
      isNotNull,
      reason: 'the row is not a decoration — activating it must navigate',
    );
    expect(target!.type, GoalType.weekly);
    expect(
      [target.year, target.month, target.week],
      [bucket.year, bucket.month, bucket.week],
      reason: 'and it lands on the week that contains today',
    );
    expect(
      container.read(navigationControllerProvider),
      DesktopSection.goals,
      reason: 'the jump is to the Goals board',
    );
    expect(
      find.byType(CommandPalette),
      findsNothing,
      reason:
          'and the palette closes — leaving it open with the activation latch '
          'set is what swallowed every later Enter until Esc',
    );
  });
}
