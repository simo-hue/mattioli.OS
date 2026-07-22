// Widget coverage for the start affordance's label states: 'Start {app}' when
// installed, 'Get {app}' when not — asserted for BOTH products, since the whole
// point of the parameterized copy is that LM Studio gets the same treatment
// Ollama already had. (Starting/timeout transitions are covered by the pure
// state-machine tests.)
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/ai_coach/application/local_server_start_controller.dart';
import 'package:evolve_desktop/features/ai_coach/domain/local_server_target.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/start_local_server_button.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool installed,
  required LocalServerTarget target,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localAppInstalledProvider(
          target.preset,
        ).overrideWith((ref) async => installed),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: EvolveTheme.dark(EvolveColors.primaryStrong),
          home: Scaffold(
            body: Center(child: StartLocalServerButton(target: target)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  for (final target in [LocalServerTarget.ollama, LocalServerTarget.lmStudio]) {
    final app = target.displayName;

    testWidgets('shows "Start $app" when the app is installed', (tester) async {
      await _pump(tester, installed: true, target: target);
      expect(
        find.text(t.coachSettings.startLocalServer(app: app)),
        findsOneWidget,
      );
      expect(find.text(t.coachSettings.getLocalServer(app: app)), findsNothing);
    });

    testWidgets('shows "Get $app" when the app is not installed', (
      tester,
    ) async {
      await _pump(tester, installed: false, target: target);
      expect(
        find.text(t.coachSettings.getLocalServer(app: app)),
        findsOneWidget,
      );
      expect(
        find.text(t.coachSettings.startLocalServer(app: app)),
        findsNothing,
      );
    });
  }

  testWidgets('each product names itself, not the other', (tester) async {
    await _pump(tester, installed: true, target: LocalServerTarget.lmStudio);
    expect(find.textContaining('LM Studio'), findsOneWidget);
    expect(find.textContaining('Ollama'), findsNothing);
  });
}
