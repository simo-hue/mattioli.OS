import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('modern desktop dialog opens and closes from its header', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EvolveTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showEvolveDialog<void>(
                context: context,
                builder: (context) => const EvolveAlertDialog(
                  icon: Icons.palette_outlined,
                  title: Text('Preferenze visive'),
                  subtitle: 'Personalizza il client desktop.',
                  content: Text('Contenuto popup'),
                ),
              ),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    expect(find.byType(EvolveDialog), findsOneWidget);
    expect(find.text('Preferenze visive'), findsOneWidget);
    expect(find.text('Contenuto popup'), findsOneWidget);
    expect(find.byTooltip('Chiudi'), findsOneWidget);

    await tester.tap(find.byTooltip('Chiudi'));
    await tester.pumpAndSettle();

    expect(find.byType(EvolveDialog), findsNothing);
  });
}
