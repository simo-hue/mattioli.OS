import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/ui/widgets/target_field.dart';
import 'package:mattioli_os/ui/widgets/target_ring.dart';

Widget _app(Widget child) => ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.lightTheme(null),
          home: Scaffold(body: child),
        ),
      ),
    );

class _Harness extends StatefulWidget {
  const _Harness({this.onChanged});
  final ValueChanged<HabitTarget?>? onChanged;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  HabitTarget? target;
  @override
  Widget build(BuildContext context) => TargetField(
        target: target,
        onChanged: (t) {
          setState(() => target = t);
          widget.onChanged?.call(t);
        },
      );
}

void main() {
  testWidgets('starts on Simple with no numeric controls', (tester) async {
    await tester.pumpWidget(_app(const _Harness()));
    // The four preset labels are present as chips…
    expect(find.text('Count'), findsOneWidget);
    expect(find.text('Limit'), findsOneWidget);
    // …but no amount stepper until a preset is chosen.
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('choosing Count emits a manual count target and shows the stepper',
      (tester) async {
    HabitTarget? emitted;
    await tester.pumpWidget(_app(_Harness(onChanged: (t) => emitted = t)));

    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();

    expect(emitted, isNotNull);
    expect(emitted!.fillSource, TargetFillSource.manual);
    expect(emitted!.direction, TargetDirection.atLeast);
    expect(emitted!.unit, TargetUnit.count);
    // The default count amount renders, with +/- controls.
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });

  testWidgets('the amount stepper bumps by the preset step and clamps',
      (tester) async {
    HabitTarget? emitted;
    await tester.pumpWidget(_app(_Harness(onChanged: (t) => emitted = t)));
    await tester.tap(find.text('Count')); // default amount 10, step 1
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(emitted!.amount, 11);

    // Drive down to the min (1) and confirm it clamps rather than going to 0.
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
    }
    expect(emitted!.amount, TargetPresetCatalog.countDaily.minAmount);
  });

  testWidgets('Limit emits an atMost target', (tester) async {
    HabitTarget? emitted;
    await tester.pumpWidget(_app(_Harness(onChanged: (t) => emitted = t)));
    await tester.tap(find.text('Limit'));
    await tester.pumpAndSettle();
    expect(emitted!.direction, TargetDirection.atMost);
    expect(emitted!.isLimit, isTrue);
  });

  testWidgets('switching back to Simple clears the target', (tester) async {
    HabitTarget? emitted = TargetPresetCatalog.countDaily.targetWith();
    await tester.pumpWidget(_app(_Harness(onChanged: (t) => emitted = t)));
    await tester.tap(find.text('Duration'));
    await tester.pumpAndSettle();
    expect(emitted, isNotNull);
    await tester.tap(find.text('Simple'));
    await tester.pumpAndSettle();
    expect(emitted, isNull);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('an amount survives switching between presets of the same shape',
      (tester) async {
    HabitTarget? emitted;
    await tester.pumpWidget(_app(_Harness(onChanged: (t) => emitted = t)));
    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add)); // 11
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limit'));
    await tester.pumpAndSettle();
    // 11 is within the limit preset's bounds, so it carries over.
    expect(emitted!.amount, 11);
  });

  test('formatTargetAmount trims trailing .0 but keeps real decimals', () {
    expect(formatTargetAmount(5), '5');
    expect(formatTargetAmount(5.0), '5');
    expect(formatTargetAmount(0.5), '0.5');
    expect(formatTargetAmount(4.999), '4.999');
  });

  // ── Typing behaviour (added after an adversarial review, 2026-07-27) ──────
  //
  // This half was completely uncovered, and the review found a real bug in it:
  // the widget documents the hint and warnings as LIVE, but the only listeners
  // were on the FocusNodes, so nothing re-entered build() on a keystroke. Worse,
  // `_commitAmount` clamps and rewrites the text BEFORE its setState, so an
  // out-of-range value was already back in range by the time build() ran — the
  // blocking error could never render and the number changed with no reason
  // given.

  testWidgets('the hint tracks the step ON EVERY KEYSTROKE, not on commit',
      (tester) async {
    await tester.pumpWidget(_app(const _Harness()));
    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();

    // Type into the Step box and DO NOT leave it.
    await tester.enterText(find.byType(TextField).last, '7');
    await tester.pump();

    // Assert on the HINT specifically — a bare '7' also matches the field the
    // digit was typed into, which would pass with or without the fix.
    expect(find.textContaining('Each + adds 7'), findsOneWidget,
        reason: 'the hint is documented as live; before the fix it showed the '
            'previous step until the field lost focus');
  });

  testWidgets('an out-of-range amount explains itself WHILE typing',
      (tester) async {
    await tester.pumpWidget(_app(const _Harness()));
    await tester.tap(find.text('Duration')); // maxes at 1440 minutes
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.pump();

    expect(find.textContaining('1440'), findsWidgets,
        reason: 'the range must be shown before the value is snapped on blur — '
            'previously nothing rendered at all and the number just changed');
  });

  testWidgets('re-tapping the selected preset keeps a typed step', (tester) async {
    HabitTarget? emitted;
    await tester.pumpWidget(_app(_Harness(onChanged: (t) => emitted = t)));
    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();

    // Count defaults to amount 10, and _commitStep correctly collapses a step
    // larger than the amount — so 5 (two taps to finish) is the honest fixture.
    await tester.enterText(find.byType(TextField).last, '5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(emitted?.step, 5);

    // A visual no-op that used to reset "4 sets of 20" to 80 single taps.
    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();

    expect(emitted?.step, 5,
        reason: 'a typed step must survive a preset tap, as the amount already did');
  });
}
