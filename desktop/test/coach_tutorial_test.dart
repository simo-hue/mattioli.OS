// Widget tests for the shared coach-mark overlay used by every tour segment:
// step rendering, Next/Finish, Back hidden on the first step, keyboard
// navigation, and the centered-card fallback when a target can't be resolved.
// Button copy comes from the migrated t.tour.* namespace (Italian locale).
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/coach_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  Widget harness({
    required List<CoachStep> steps,
    required int index,
    required ValueChanged<int> onIndexChanged,
    required VoidCallback onFinish,
    GlobalKey? targetKey,
  }) => MaterialApp(
    theme: EvolveTheme.dark(),
    home: Scaffold(
      body: Stack(
        children: [
          if (targetKey != null)
            Center(
              child: SizedBox(
                key: targetKey,
                width: 120,
                height: 40,
                child: const Text('target'),
              ),
            ),
          CoachTutorialOverlay(
            steps: steps,
            index: index,
            onIndexChanged: onIndexChanged,
            onFinish: onFinish,
            backLabel: t.tour.back,
            nextLabel: t.tour.next,
            finishLabel: t.tour.finish,
          ),
        ],
      ),
    ),
  );

  testWidgets('advances through steps and finishes on the last', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final targetKey = GlobalKey();
    var index = 0;
    var finished = false;

    Widget build() => StatefulBuilder(
      builder: (context, setState) => harness(
        targetKey: targetKey,
        steps: [
          CoachStep(
            targetKey: targetKey,
            title: 'Passo Uno',
            description: 'Descrizione uno',
          ),
          const CoachStep(title: 'Passo Due', description: 'Descrizione due'),
        ],
        index: index,
        onIndexChanged: (i) => setState(() => index = i),
        onFinish: () => setState(() => finished = true),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    // First step: Next ("Avanti") shown, Back ("Indietro") hidden.
    expect(find.text('Passo Uno'), findsOneWidget);
    expect(find.text('Avanti'), findsOneWidget);
    expect(find.text('Indietro'), findsNothing);

    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();

    // Last step: Finish ("Fine") + Back now visible.
    expect(find.text('Passo Due'), findsOneWidget);
    expect(find.text('Fine'), findsOneWidget);
    expect(find.text('Indietro'), findsOneWidget);
    expect(finished, isFalse);

    await tester.tap(find.text('Fine'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('keyboard: → / Enter advance, ← goes back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var index = 0;
    var finished = false;

    Widget build() => StatefulBuilder(
      builder: (context, setState) => harness(
        steps: const [
          CoachStep(title: 'Uno', description: 'd1'),
          CoachStep(title: 'Due', description: 'd2'),
        ],
        index: index,
        onIndexChanged: (i) => setState(() => index = i),
        onFinish: () => setState(() => finished = true),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Due'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Uno'), findsOneWidget);

    // Advance to last, then Enter finishes.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('null-target step renders a centered card (no spotlight)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      harness(
        steps: const [
          CoachStep(title: 'Orientamento', description: 'Benvenuto'),
        ],
        index: 0,
        onIndexChanged: (_) {},
        onFinish: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Orientamento'), findsOneWidget);
    expect(find.text('Fine'), findsOneWidget);
  });

  testWidgets('unresolvable target settles (no infinite refresh) and still '
      'shows the card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A GlobalKey never attached to any widget -> its rect never resolves. The
    // bounded refresh cap must let the frame settle and degrade to a card.
    final orphanKey = GlobalKey();

    await tester.pumpWidget(
      harness(
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
      ),
    );

    // Would time out if _scheduleGeometryRefresh looped every frame.
    await tester.pumpAndSettle();

    expect(find.text('Passo Orfano'), findsOneWidget);
    expect(find.text('Fine'), findsOneWidget);
  });
}
