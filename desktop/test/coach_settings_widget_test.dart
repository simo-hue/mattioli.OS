// Widget coverage for the AI Coach settings surface: the Settings rail exposes
// an "AI Coach" section whose Configure row opens the shared engine dialog with
// the three-way engine switch. Stays on the default Standard backend, which
// probes nothing — so no local-server network call is triggered.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSettings(WidgetTester tester) async {
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
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('AI Coach section shows the engine rows and opens the dialog',
      (tester) async {
    await _pumpSettings(tester);

    // Open the AI Coach rail section (the rail tile carries the label).
    await tester.tap(find.text(t.coachSettings.settingsSectionLabel).first);
    await tester.pumpAndSettle();

    // The section exposes the active-engine status + the configure entry.
    expect(find.text(t.coachSettings.settingsRowStatus), findsOneWidget);
    expect(find.text(t.coachSettings.settingsRowConfigure), findsOneWidget);

    // Open the shared engine configuration dialog.
    await tester.tap(find.text(t.coachSettings.settingsRowConfigure));
    await tester.pumpAndSettle();

    // The engine switch is unique to the dialog (the title string is also the
    // settings card label, so it legitimately appears twice).
    expect(find.text(t.coachSettings.title), findsWidgets);
    // "Evolve AI" names both the segment and the section below it, so it is
    // expected twice — like the title above.
    expect(find.text(t.coachSettings.backendStandard), findsWidgets);
    expect(find.text(t.coachSettings.backendCloud), findsOneWidget);
    expect(find.text(t.coachSettings.backendLocal), findsOneWidget);

    // THE Guideline 3.1.1 PROPERTY, as a reviewer would see it: a fresh install
    // opens on Standard, where there is no key field at all. The rejection was
    // for unlocking paid functionality with a pasted API key, and the reviewer
    // met that key prompt here, as the default. Now the purchase is the unlock
    // and BYOK is one segment over — free, and chosen rather than required.
    expect(find.text(t.ai.apiKey.fieldLabel), findsNothing);
    expect(find.text(t.ai.apiKey.hint), findsNothing);
    // Standard → no local section either (and so no network probe).
    expect(find.text(t.coachSettings.baseUrlLabel), findsNothing);
  });
}
