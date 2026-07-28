// Settings parity with the iPhone client: the Application section exposes the
// AI & System experience toggles (AI suggestions Pro-gated like mobile's
// toggleAi), the Notifications section has the AI insights / weekly reports
// rows, the haptics row is hidden on desktop, and toggles dual-write the same
// SharedPreferences keys mobile uses.
//
// The page is pumped in cloud mode with no Supabase session: _syncProfile is
// a no-op without a client, so taps exercise the prefs write path without
// touching the network or the encrypted DB.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'support/settings_navigation.dart';

/// [withPreferences] false leaves `sharedPreferencesProvider` at its null
/// default — the first-launch shape where `initState` early-returns before the
/// prefs reads and the page's own field initialisers are what the user sees.
Future<SharedPreferences> _pumpSettings(
  WidgetTester tester, {
  bool withPreferences = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      if (withPreferences) sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);

  await tester.binding.setSurfaceSize(const Size(1440, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: EvolveTheme.dark(EvolveColors.primaryStrong),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

/// The toggle (kit EvolveSwitch) inside the row titled [rowLabel].
Finder _switchIn(String rowLabel) => find.descendant(
  of: find.widgetWithText(ListTile, rowLabel),
  matching: find.byType(EvolveSwitch),
);

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  // The five controls below were verified dead on BOTH platforms: each one
  // persisted to SharedPreferences, dual-wrote a `profiles` column and synced
  // to the iPhone, where nothing read it either. They were internal AppSettings
  // fields surfaced as switches, and iOS never rendered any of them.
  //
  // This asserts the ROWS are gone. The companion test asserts the KEYS are
  // not — dropping them from the sync contract would be a migration, and the
  // iPhone still round-trips all five.
  testWidgets('the dead experience toggles no longer render anywhere', (
    tester,
  ) async {
    await _pumpSettings(tester);

    for (final section in [
      SettingsSection.general,
      SettingsSection.notifications,
    ]) {
      await openSettingsSection(tester, section);
      for (final label in [
        t.settingsPage.aiSuggestions,
        t.settingsPage.milestones,
        t.settingsPage.deepWorkInsights,
        t.settingsPage.aiInsights,
        t.settingsPage.weeklyReports,
      ]) {
        expect(
          find.text(label),
          findsNothing,
          reason: '"$label" has no consumer on either platform',
        );
      }
      // macOS produces no haptics: that row must not render either (the synced
      // pref_haptic_feedback column is simply left untouched for mobile).
      expect(find.text(t.settingsPage.hapticFeedback), findsNothing);
    }
  });

  test('removing the rows did not remove them from the sync contract', () {
    for (final key in const [
      kSettingAiSuggestions,
      kSettingMilestones,
      kSettingDeepWorkInsights,
      kSettingAiInsights,
      kSettingWeeklyReports,
    ]) {
      expect(
        PrivateDbSchema.syncedSettingKeys,
        contains(key),
        reason: 'the iPhone still reads, writes and syncs $key',
      );
    }
  });

  testWidgets(
    'focus mode lives in Notifications and dual-writes its pref key',
    (tester) async {
      final prefs = await _pumpSettings(tester);
      // It used to sit in the Application pane's "AI & SYSTEM" card, three
      // destinations away from the reminders it silences.
      await openSettingsSection(tester, SettingsSection.general);
      expect(find.text(t.settingsPage.focusMode), findsNothing);

      await openSettingsSection(tester, SettingsSection.notifications);
      await tester.ensureVisible(_switchIn(t.settingsPage.focusMode));
      await tester.tap(_switchIn(t.settingsPage.focusMode));
      await tester.pumpAndSettle();

      expect(prefs.getBool('pref_focus_mode'), isTrue);
    },
  );

  testWidgets('a reminder time renders while its switch is off, disabled', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await openSettingsSection(tester, SettingsSection.notifications);

    // Turn the morning brief off. The time row must STAY — it used to be
    // `if (_habitReminders)`, so the pane changed height under the cursor and
    // every row below it jumped.
    await tester.ensureVisible(_switchIn(t.settingsPage.habitReminders));
    await tester.tap(_switchIn(t.settingsPage.habitReminders));
    await tester.pumpAndSettle();

    expect(find.text(t.settingsPage.morningBriefTime), findsOneWidget);
    expect(find.text(t.settingsPage.disabledTurnOnFirst), findsOneWidget);
  });

  // macOS's brief-time defaults said 08:00 / 20:30 and won on a first launch,
  // so a fresh Mac disagreed with the `profiles` schema DEFAULTs and with the
  // iPhone. The old guard for this asserted
  // `SettingsCodec.defaultMorningBriefTime == '09:00'` in
  // settings_synced_readback_test.dart — two compile-time constants from the
  // frozen shared package, against each other, executing no desktop code.
  // Re-hardcoding a desktop literal left it green.
  //
  // TWO cases, because two different desktop expressions decide the answer and
  // neither covers the other:
  //   * prefs ABSENT  -> initState early-returns and the FIELD INITIALISERS win
  //   * prefs EMPTY   -> initState runs on and the `?? SettingsCodec.default…`
  //                      fallbacks win
  // A test of only the second is green while the first is mutated back to
  // '08:00', which is exactly the shape the original bug had.
  for (final (name, absent) in [
    ('SharedPreferences is absent', true),
    ('SharedPreferences is empty', false),
  ]) {
    testWidgets(
      'the brief times are not the canonical 09:00 / 21:00 when $name',
      (tester) async {
        await _pumpSettings(tester, withPreferences: !absent);
        await openSettingsSection(tester, SettingsSection.notifications);

        // The time the user actually READS, through the real initState path.
        expect(
          _timePickerIn(t.settingsPage.morningBriefTime).value,
          const TimeOfDay(hour: 9, minute: 0),
        );
        expect(
          _timePickerIn(t.settingsPage.eveningReviewTime).value,
          const TimeOfDay(hour: 21, minute: 0),
        );
      },
    );
  }
}

/// The kit picker rendered inside the row titled [rowLabel].
EvolveTimePicker _timePickerIn(String rowLabel) =>
    find
            .descendant(
              of: find.widgetWithText(ListTile, rowLabel),
              matching: find.byType(EvolveTimePicker),
            )
            .evaluate()
            .single
            .widget
        as EvolveTimePicker;
