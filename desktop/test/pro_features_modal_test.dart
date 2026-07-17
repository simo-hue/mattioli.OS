// Item 2 — Pro upsell modal. Asserts the Italian pitch copy (reused from mobile)
// and that the CTA deep-links to Settings while "maybe later" just dismisses.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Assert on Italian UI copy; pin the slang locale to Italian.
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  Widget harness() => ProviderScope(
    child: MaterialApp(
      theme: EvolveTheme.dark(),
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: FilledButton(
            onPressed: () => showProFeaturesDialog(context, ref),
            child: const Text('Gate'),
          ),
        ),
      ),
    ),
  );

  ProviderContainer containerFrom(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  // The dialog is a tall scroll view; give it a surface where its CTA is on
  // screen so taps land.
  Future<void> bigSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('opens with the pitch and deep-links to Settings', (
    tester,
  ) async {
    await bigSurface(tester);
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Gate'));
    await tester.pumpAndSettle();

    // Pitch copy reused from mobile.
    expect(find.text('Sblocca Evolve Pro'), findsOneWidget);
    expect(find.text('Abitudini Illimitate'), findsOneWidget);
    expect(find.text('AI Coach, senza configurazione'), findsOneWidget);
    expect(find.text('Vedi i piani Pro'), findsOneWidget);
    expect(find.text('Forse più tardi'), findsOneWidget);

    // THE ORDER IS THE POINT, not decoration. The coach led this pitch back when
    // it was Pro-gated; bring-your-own-key is now free (the Guideline 3.1.1
    // fix), so heading a paywall with it sells something you can have for
    // nothing — an inaccurate subscription description, which is Guideline
    // 3.1.2, the one this app is already rejected under. The habit limit is the
    // gate a free user actually meets, so it leads.
    expect(
      tester.getTopLeft(find.text('Abitudini Illimitate')).dy,
      lessThan(tester.getTopLeft(find.text('AI Coach, senza configurazione')).dy),
      reason: 'the coach must not head the Pro pitch — it is free via BYOK',
    );

    final container = containerFrom(tester);
    expect(
      container.read(navigationControllerProvider),
      DesktopSection.overview,
    );

    // CTA closes the dialog and navigates to Settings.
    await tester.tap(find.text('Vedi i piani Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Sblocca Evolve Pro'), findsNothing);
    expect(
      container.read(navigationControllerProvider),
      DesktopSection.settings,
    );
  });

  testWidgets('"maybe later" dismisses without navigating', (tester) async {
    await bigSurface(tester);
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Gate'));
    await tester.pumpAndSettle();

    final container = containerFrom(tester);
    await tester.tap(find.text('Forse più tardi'));
    await tester.pumpAndSettle();

    expect(find.text('Sblocca Evolve Pro'), findsNothing);
    expect(
      container.read(navigationControllerProvider),
      DesktopSection.overview,
    );
  });
}
