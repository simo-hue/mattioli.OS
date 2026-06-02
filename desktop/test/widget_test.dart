import 'package:evolve_desktop/app/evolve_desktop_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop shell exposes the primary navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: EvolveDesktopApp()));

    expect(find.text('Evolve'), findsOneWidget);
    expect(find.text('Panoramica'), findsOneWidget);
    expect(find.text('Abitudini'), findsOneWidget);
    expect(find.text('Statistiche'), findsOneWidget);
    expect(find.text('Obiettivi'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
  });

  testWidgets('habits calendar exposes the mobile parity views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: EvolveDesktopApp()));
    await tester.tap(find.text('Abitudini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendario'));
    await tester.pumpAndSettle();

    expect(find.text('Mese'), findsOneWidget);
    expect(find.text('Settimana'), findsOneWidget);
    expect(find.text('Anno'), findsOneWidget);
    expect(find.text('Vita'), findsOneWidget);
  });

  testWidgets('macro goals expose mobile horizons and period selectors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: EvolveDesktopApp()));
    await tester.tap(find.text('Obiettivi'));
    await tester.pumpAndSettle();

    expect(find.text('Vita'), findsOneWidget);
    expect(find.text('Annuale'), findsOneWidget);
    expect(find.text('Trimestrale'), findsOneWidget);
    expect(find.text('Mensile'), findsOneWidget);
    expect(find.text('Settimanale'), findsOneWidget);
    expect(find.text('Categorie'), findsOneWidget);
    expect(find.text('Statistiche'), findsWidgets);
  });

  testWidgets('macro goals toolbar fits the minimum desktop window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: EvolveDesktopApp()));
    await tester.tap(find.byTooltip('Obiettivi'));
    await tester.pumpAndSettle();

    expect(find.text('Settimanale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance settings apply the selected contrast color', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: EvolveDesktopApp()));
    await tester.tap(find.text('Impostazioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Applicazione'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Usa accento #3B82F6'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme?.colorScheme.primary, const Color(0xFF3B82F6));
    expect(find.byTooltip('Colore personalizzato'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
