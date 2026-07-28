// Widget coverage for the AI Coach settings surface.
//
// The engine configuration IS the pane now — there is no Configure row and no
// dialog. CoachSettingsDialog held the entire feature (engine cards, API key,
// local server, model picker) two levels down behind a chevron, which is why
// none of it was discoverable. In account mode the pane is the managed engine
// alone (no key prompt — the Guideline 3.1.1 shape); in Private mode it is the
// BYOK + local engine cards.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/ai_coach/application/coach_controllers.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_config.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'support/settings_navigation.dart';

Future<void> _pumpSettings(WidgetTester tester, {bool private = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (private) ...[
        activeDesktopDataModeProvider.overrideWith(_PrivateDataMode.new),
        // The private-mode cards probe both local ports and read the Keychain
        // for the BYOK status. Neither works under the test binding (HTTP is
        // stubbed to 400, secure storage has no channel), so pin them: the
        // point of this test is that the cards RENDER, not what they report.
        coachApiKeyProvider.overrideWith(_NoKey.new),
        coachLocalReachableProvider(
          LocalServerPreset.ollama.baseUrl,
        ).overrideWith((ref) => Future.value(false)),
        coachLocalReachableProvider(
          LocalServerPreset.lmStudio.baseUrl,
        ).overrideWith((ref) => Future.value(false)),
      ],
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
}

Future<void> _openCoachPane(WidgetTester tester) async {
  await openSettingsSection(tester, SettingsSection.aiCoach);

  // No launcher row survives: the controls are the pane.
  expect(find.text(t.coachSettings.settingsRowConfigure), findsNothing);
  expect(find.text(t.coachSettings.groupEngine), findsOneWidget);
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('account mode opens on the managed engine with no key prompt', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await _openCoachPane(tester);

    // Account mode is Evolve-AI-only: the managed engine card is shown, and the
    // note points BYOK/local to Private mode.
    expect(find.text(t.coachSettings.backendStandard), findsWidgets);
    expect(find.text(t.coachSettings.accountModeNote), findsOneWidget);

    // THE Guideline 3.1.1 PROPERTY, as a reviewer would meet it: a fresh install
    // opens on the managed engine, where there is no key field to paste into and
    // no local server to point at. The purchase is the unlock; nothing here is.
    expect(find.text(t.ai.apiKey.fieldLabel), findsNothing);
    expect(find.text(t.ai.apiKey.hint), findsNothing);
    expect(find.text(t.coachSettings.baseUrlLabel), findsNothing);

    // And no BYOK/local engine cards leak into account mode.
    expect(find.text(t.coachSettings.engineOpenRouter), findsNothing);
    expect(find.text(t.coachSettings.presetLmStudio), findsNothing);
  });

  testWidgets('private mode shows the OpenRouter + Ollama + LM Studio cards', (
    tester,
  ) async {
    await _pumpSettings(tester, private: true);
    await _openCoachPane(tester);

    // The redesign's core: local products are first-class, one-tap cards next to
    // BYOK — not options buried behind a preset dropdown.
    expect(find.text(t.coachSettings.engineOpenRouter), findsOneWidget);
    expect(find.text(t.coachSettings.localGroupLabel), findsOneWidget);
    expect(find.text(t.coachSettings.presetOllama), findsOneWidget);
    expect(find.text(t.coachSettings.presetLmStudio), findsOneWidget);
    expect(find.text(t.coachSettings.useCustomServer), findsOneWidget);

    // The managed engine is not offered here — Private mode keeps no account.
    expect(find.text(t.coachSettings.accountModeNote), findsNothing);
  });
}

/// Pins the data mode to Private without touching prefs, so the coach dialog
/// renders its BYOK + local engine cards.
class _PrivateDataMode extends ActiveDesktopDataModeNotifier {
  @override
  DesktopDataMode build() => DesktopDataMode.private;
}

/// A BYOK key controller that reports "no key" without touching the Keychain.
class _NoKey extends CoachApiKeyController {
  @override
  Future<String?> build() async => null;
}
