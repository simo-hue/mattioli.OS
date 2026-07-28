// The AI Coach dialog dissolution: CoachSettingsDialog was a 1,335-line modal
// holding the entire feature, reached from a three-row pane. Its content is now
// the pane itself, and its four entry points navigate here instead of stacking
// a modal on whatever the user was doing.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/coach_settings_panels.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/settings_navigation.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
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
  return container;
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('the engine configuration renders inline, not behind a row', (
    tester,
  ) async {
    await _pump(tester);
    await openSettingsSection(tester, SettingsSection.aiCoach);

    expect(find.byType(CoachEnginePanel), findsOneWidget);
    // The launcher row and its status twin are both gone: a pane whose only
    // job was to open a modal is what made the feature undiscoverable.
    expect(find.text(t.coachSettings.settingsRowConfigure), findsNothing);
    expect(find.text(t.coachSettings.settingsRowStatus), findsNothing);
  });

  testWidgets('the consent row survives being used', (tester) async {
    await _pump(tester);
    await openSettingsSection(tester, SettingsSection.aiCoach);

    // With no consent granted the row still renders, reporting that state.
    // It used to be wrapped in `if (hasAnyCoachConsent)`, so revoking erased
    // the only place that could say sharing was off — or turn it back on.
    expect(find.text(t.ai.consent.rowTitle), findsOneWidget);
    expect(find.text(t.ai.consent.consentStatusRevoked), findsOneWidget);
    expect(
      find.text(t.ai.consent.consentStopSharing),
      findsNothing,
      reason: 'there is nothing to stop sharing before consent exists',
    );
  });

  testWidgets('system prompt and temperature moved to Advanced', (
    tester,
  ) async {
    await _pump(tester);

    await openSettingsSection(tester, SettingsSection.aiCoach);
    expect(find.byType(CoachAdvancedPanel), findsNothing);

    await openSettingsSection(tester, SettingsSection.advanced);
    expect(find.byType(CoachAdvancedPanel), findsOneWidget);
    expect(find.text(t.coachSettings.groupTuning), findsOneWidget);
  });

  testWidgets('a section request lands while Settings is already open', (
    tester,
  ) async {
    // This is the path every retargeted entry point takes: the chat header's
    // engine chip and the coach page's banners fire it from OUTSIDE Settings,
    // but the shell keeps SettingsPage mounted, so a request that only ran in
    // initState would be swallowed.
    final container = await _pump(tester);
    await openSettingsSection(tester, SettingsSection.notifications);

    container
        .read(settingsSectionRequestProvider.notifier)
        .request(SettingsSection.aiCoach);
    await tester.pumpAndSettle();

    expect(find.byType(CoachEnginePanel), findsOneWidget);
    expect(
      container.read(settingsSectionRequestProvider),
      isNull,
      reason: 'the one-shot request must be consumed, not left to re-fire',
    );
  });
}
