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

Future<SharedPreferences> _pumpSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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

Future<void> _openSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

/// The toggle (kit EvolveSwitch) inside the row titled [rowLabel].
Finder _switchIn(String rowLabel) => find.descendant(
      of: find.widgetWithText(ListTile, rowLabel),
      matching: find.byType(EvolveSwitch),
    );

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets(
      'application section shows the AI & System toggles and hides haptics',
      (tester) async {
    await _pumpSettings(tester);
    await _openSection(tester, t.settingsPage.sectionApplication);

    expect(find.text(t.settingsPage.aiSuggestions), findsOneWidget);
    expect(find.text(t.settingsPage.focusMode), findsOneWidget);
    expect(find.text(t.settingsPage.milestones), findsOneWidget);
    expect(find.text(t.settingsPage.deepWorkInsights), findsOneWidget);
    // macOS produces no haptics for this: the row must not render (the synced
    // pref_haptic_feedback profile column is simply left untouched).
    expect(find.text(t.settingsPage.hapticFeedback), findsNothing);
  });

  testWidgets('focus mode toggle dual-writes the mobile pref key',
      (tester) async {
    final prefs = await _pumpSettings(tester);
    await _openSection(tester, t.settingsPage.sectionApplication);

    await tester.ensureVisible(_switchIn(t.settingsPage.focusMode));
    await tester.tap(_switchIn(t.settingsPage.focusMode));
    await tester.pumpAndSettle();

    expect(prefs.getBool('pref_focus_mode'), isTrue);
  });

  testWidgets('AI suggestions is Pro-gated in cloud mode', (tester) async {
    final prefs = await _pumpSettings(tester);
    await _openSection(tester, t.settingsPage.sectionApplication);

    await tester.ensureVisible(_switchIn(t.settingsPage.aiSuggestions));
    await tester.tap(_switchIn(t.settingsPage.aiSuggestions));
    await tester.pumpAndSettle();

    // Not entitled: the Pro features dialog opens and nothing is persisted —
    // mirrors mobile's toggleAi, which is a no-op for non-Pro users.
    expect(find.text(t.proModal.title), findsOneWidget);
    expect(prefs.getBool('pref_ai_suggestions'), isNull);
  });

  testWidgets(
      'notifications section exposes AI insights and weekly reports rows',
      (tester) async {
    final prefs = await _pumpSettings(tester);
    await _openSection(tester, t.settingsPage.notifications);

    expect(find.text(t.settingsPage.aiInsights), findsOneWidget);
    expect(find.text(t.settingsPage.weeklyReports), findsOneWidget);

    await tester.ensureVisible(_switchIn(t.settingsPage.weeklyReports));
    await tester.tap(_switchIn(t.settingsPage.weeklyReports));
    await tester.pumpAndSettle();

    expect(prefs.getBool('notif_weekly_reports'), isTrue);
  });
}
