// Widget coverage for the Start-Ollama affordance's label states: 'Start Ollama'
// when installed, 'Get Ollama' when not. (Starting/timeout transitions are
// covered by the pure state-machine tests.)
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/ai_coach/application/ollama_start_controller.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/start_ollama_button.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required bool installed}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ollamaInstalledProvider.overrideWith((ref) async => installed),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: EvolveTheme.dark(EvolveColors.primaryStrong),
          home: const Scaffold(body: Center(child: StartOllamaButton())),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('shows "Start Ollama" when the app is installed', (tester) async {
    await _pump(tester, installed: true);
    expect(find.text(t.coachSettings.startOllama), findsOneWidget);
    expect(find.text(t.coachSettings.getOllama), findsNothing);
  });

  testWidgets('shows "Get Ollama" when the app is not installed',
      (tester) async {
    await _pump(tester, installed: false);
    expect(find.text(t.coachSettings.getOllama), findsOneWidget);
    expect(find.text(t.coachSettings.startOllama), findsNothing);
  });
}
