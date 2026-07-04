// Item 3 — reusable coach-mark overlay shared by the dashboard + stats tours.
// Verifies step rendering, Next advancing, and Finish on the last step (Italian
// button copy from t.tutorial.*).
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/coach_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  testWidgets('advances through steps and finishes on the last', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final targetKey = GlobalKey();
    var index = 0;
    var finished = false;

    Widget build() => MaterialApp(
      theme: EvolveTheme.dark(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => Stack(
            children: [
              Center(
                child: SizedBox(
                  key: targetKey,
                  width: 120,
                  height: 40,
                  child: const Text('target'),
                ),
              ),
              CoachTutorialOverlay(
                steps: [
                  CoachStep(
                    targetKey: targetKey,
                    title: 'Passo Uno',
                    description: 'Descrizione uno',
                  ),
                  const CoachStep(
                    title: 'Passo Due',
                    description: 'Descrizione due',
                  ),
                ],
                index: index,
                onIndexChanged: (i) => setState(() => index = i),
                onFinish: () => setState(() => finished = true),
                backLabel: t.tutorial.back,
                nextLabel: t.tutorial.next,
                finishLabel: t.tutorial.finish,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    // First step + "Avanti" (t.tutorial.next).
    expect(find.text('Passo Uno'), findsOneWidget);
    expect(find.text('Descrizione uno'), findsOneWidget);
    expect(find.text('Avanti'), findsOneWidget);

    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();

    // Last step shows "Fine" (t.tutorial.finish).
    expect(find.text('Passo Due'), findsOneWidget);
    expect(find.text('Fine'), findsOneWidget);
    expect(finished, isFalse);

    await tester.tap(find.text('Fine'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });

  testWidgets('an unresolvable target settles (no infinite refresh) and still '
      'shows the card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A GlobalKey that is never attached to any widget -> its rect never
    // resolves. The bounded refresh cap must let the frame settle rather than
    // rescheduling setState forever.
    final orphanKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: EvolveTheme.dark(),
        home: Scaffold(
          body: Stack(
            children: [
              CoachTutorialOverlay(
                steps: [
                  CoachStep(
                    targetKey: orphanKey,
                    title: 'Passo Orfano',
                    description: 'Nessun bersaglio',
                  ),
                ],
                index: 0,
                onIndexChanged: (_) {},
                onFinish: () {},
                backLabel: t.tutorial.back,
                nextLabel: t.tutorial.next,
                finishLabel: t.tutorial.finish,
              ),
            ],
          ),
        ),
      ),
    );

    // Would time out if _scheduleGeometryRefresh looped every frame.
    await tester.pumpAndSettle();

    // Card renders (full-scrim fallback) with the Finish button available.
    expect(find.text('Passo Orfano'), findsOneWidget);
    expect(find.text('Fine'), findsOneWidget);
  });
}
