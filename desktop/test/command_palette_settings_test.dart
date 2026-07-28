import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/search/presentation/command_palette.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A goal titled exactly like a settings query, so "an exact goal-name match
/// still wins" can be asserted rather than assumed.
const _languageGoal = DashboardGoal(
  id: 'g1',
  title: 'Language',
  category: 'Learning',
  color: EvolveColors.primaryStrong,
  progress: 0,
  dueLabel: '',
  type: GoalType.annual,
);

class _StubRepository extends DashboardRepository {
  _StubRepository(this._snapshot);
  final DashboardSnapshot _snapshot;

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}

Future<ProviderContainer> _pumpPalette(
  WidgetTester tester, {
  bool privateMode = false,
  List<DashboardGoal> goals = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    if (privateMode) 'active_data_mode': DesktopDataMode.private.name,
  });
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      dashboardRepositoryProvider.overrideWithValue(
        _StubRepository(
          DashboardSnapshot(
            habits: const [],
            goals: goals,
            trend: const [],
            checkIn: const DailyCheckIn(),
          ),
        ),
      ),
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
          home: const Scaffold(body: CommandPalette()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _type(WidgetTester tester, String query) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(CommandPalette),
      matching: find.byType(TextField),
    ),
    query,
  );
  await tester.pumpAndSettle();
}

/// Vertical position of a group header, for asserting group ORDER — the
/// palette's only ranking signal that a user can see.
double _headerY(WidgetTester tester, String title) =>
    tester.getTopLeft(find.text(title.toUpperCase())).dy;

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  group('finding a setting', () {
    testWidgets('a settings row is findable by its own name', (tester) async {
      await _pumpPalette(tester);
      await _type(tester, 'language');

      expect(
        find.text(t.palette.groupSettings.toUpperCase()),
        findsOneWidget,
        reason: 'settings hits are their own group, not loose section results',
      );
      expect(find.text(t.settingsPage.language), findsOneWidget);
      expect(
        find.text(SettingsSection.general.label),
        findsOneWidget,
        reason:
            'the pane is the second line — "Language" alone says nothing '
            'about where it lives',
      );
    });

    testWidgets('a settings row is findable by a phrase from its label', (
      tester,
    ) async {
      // The motivating example: "focus mode" used to return nothing at all.
      await _pumpPalette(tester);
      await _type(tester, 'focus mode');

      expect(find.text(t.settingsPage.focusMode), findsOneWidget);
      expect(find.text(SettingsSection.notifications.label), findsOneWidget);
    });

    testWidgets('keywords find a row whose visible copy never says the word', (
      tester,
    ) async {
      await _pumpPalette(tester);
      await _type(tester, 'dark mode');

      // The row is called "Theme"; "dark mode" is only in its keywords.
      expect(find.text(t.settingsPage.themeMode), findsOneWidget);
    });

    testWidgets('no settings group when nothing matches', (tester) async {
      await _pumpPalette(tester);
      await _type(tester, 'zzzzqqq');

      expect(find.text(t.palette.groupSettings.toUpperCase()), findsNothing);
    });
  });

  group('activating a setting', () {
    testWidgets('opens Settings on the pane that holds the row', (
      tester,
    ) async {
      final container = await _pumpPalette(tester);
      await _type(tester, 'language');
      await tester.tap(find.text(t.settingsPage.language));
      await tester.pumpAndSettle();

      final target = container.read(settingsSectionRequestProvider);
      expect(
        target?.section,
        SettingsSection.general,
        reason: 'the deep link SettingsPage consumes on mount and via listen',
      );
      expect(
        target?.rowId,
        'general.language',
        reason:
            'the request carries the ROW so the pane scrolls to it and tints '
            'it, exactly as the sidebar result list does',
      );
      expect(
        container.read(navigationControllerProvider),
        DesktopSection.settings,
      );
    });

    testWidgets('a row in another pane requests that pane, not General', (
      tester,
    ) async {
      final container = await _pumpPalette(tester);
      await _type(tester, 'export');
      await tester.tap(find.text(t.settingsPage.exportData));
      await tester.pumpAndSettle();

      final target = container.read(settingsSectionRequestProvider);
      expect(target?.section, SettingsSection.dataBackup);
      expect(target?.rowId, 'data.export');
    });
  });

  group('data mode', () {
    testWidgets('Private mode is not offered account-only rows', (
      tester,
    ) async {
      await _pumpPalette(tester, privateMode: true);
      await _type(tester, 'crash');

      expect(
        find.text(t.settingsPage.sendCrashReports),
        findsNothing,
        reason: 'Private mode has no crash-report consent switch to open',
      );
    });

    testWidgets('account mode IS offered the same row', (tester) async {
      await _pumpPalette(tester);
      await _type(tester, 'crash');

      expect(find.text(t.settingsPage.sendCrashReports), findsOneWidget);
    });

    testWidgets('account mode is not offered private-only rows', (
      tester,
    ) async {
      await _pumpPalette(tester);
      await _type(tester, 'sync now');

      expect(find.text(t.icloudSync.syncNow), findsNothing);
    });

    testWidgets('Private mode IS offered the same row', (tester) async {
      await _pumpPalette(tester, privateMode: true);
      await _type(tester, 'sync now');

      expect(find.text(t.icloudSync.syncNow), findsOneWidget);
    });
  });

  group('ranking', () {
    testWidgets('an exact goal-name match still comes first', (tester) async {
      await _pumpPalette(tester, goals: const [_languageGoal]);
      await _type(tester, 'language');

      expect(
        _headerY(tester, t.palette.groupGoals),
        lessThan(_headerY(tester, t.palette.groupSettings)),
        reason:
            'goals are the palette headline use; settings must not bury '
            'a goal the user named exactly',
      );
    });

    testWidgets('a label match outranks the catch-all create actions', (
      tester,
    ) async {
      await _pumpPalette(tester);
      await _type(tester, 'language');

      expect(
        _headerY(tester, t.palette.groupSettings),
        lessThan(_headerY(tester, t.palette.groupActions)),
        reason:
            '"Create goal “language”" exists for EVERY query; a setting '
            'actually called Language is the better answer',
      );
    });

    testWidgets('a keyword-only hit does not displace a parsed period jump', (
      tester,
    ) async {
      await _pumpPalette(tester);
      // "week" parses as a period AND is a keyword of the calendar-view
      // setting. The jump is the stronger intent.
      await _type(tester, 'week');

      expect(find.text(t.settingsPage.defaultCalendarView), findsOneWidget);
      expect(
        _headerY(tester, t.palette.groupActions),
        lessThan(_headerY(tester, t.palette.groupSettings)),
      );
    });
  });
}
