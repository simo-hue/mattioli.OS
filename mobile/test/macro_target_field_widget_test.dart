import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/ui/widgets/macro_goals/macro_target_field.dart';

Widget _app(Widget child) => ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.lightTheme(null),
          home: Scaffold(body: child),
        ),
      ),
    );

class _Harness extends StatefulWidget {
  const _Harness({required this.habits, this.onChanged});
  final List<MacroHabitOption> habits;
  final ValueChanged<MacroTargetDraft?>? onChanged;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  MacroTargetDraft? draft;
  @override
  Widget build(BuildContext context) => MacroTargetField(
        value: draft,
        habits: widget.habits,
        onChanged: (d) {
          setState(() => draft = d);
          widget.onChanged?.call(d);
        },
      );
}

const _habits = [
  MacroHabitOption(id: 'h1', title: 'Run'),
  MacroHabitOption(id: 'h2', title: 'Read'),
];

void main() {
  testWidgets('starts on None with no amount field or link picker',
      (tester) async {
    await tester.pumpWidget(_app(const _Harness(habits: _habits)));
    expect(find.text('None'), findsOneWidget);
    expect(find.text('km'), findsOneWidget); // the unit chips render
    // No amount field / link picker until a target is chosen.
    expect(find.text('Target amount'), findsNothing);
    expect(find.text('Manual'), findsNothing);
  });

  testWidgets('picking a unit emits an atLeast target and reveals the fields',
      (tester) async {
    MacroTargetDraft? emitted;
    var emittedCount = 0;
    await tester.pumpWidget(
      _app(_Harness(
        habits: _habits,
        onChanged: (d) {
          emitted = d;
          emittedCount++;
        },
      )),
    );

    await tester.tap(find.text('km'));
    await tester.pumpAndSettle();

    expect(emittedCount, 1);
    expect(emitted, isNotNull);
    expect(emitted!.unit, TargetUnit.kilometers);
    expect(emitted!.amount, 1); // sensible default
    expect(emitted!.linkedGoalId, isNull); // manual by default
    expect(find.text('Target amount'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
  });

  testWidgets('entering an amount and linking a habit emits the full draft',
      (tester) async {
    MacroTargetDraft? emitted;
    await tester.pumpWidget(
      _app(_Harness(habits: _habits, onChanged: (d) => emitted = d)),
    );

    await tester.tap(find.text('km'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '500');
    await tester.pumpAndSettle();
    expect(emitted!.amount, 500);
    expect(emitted!.unit, TargetUnit.kilometers);

    // Link the "Run" habit.
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(emitted!.linkedGoalId, 'h1');
    expect(emitted!.amount, 500); // amount survives the link change
    expect(emitted!.unit, TargetUnit.kilometers);
  });

  testWidgets('switching the unit keeps the amount and link', (tester) async {
    MacroTargetDraft? emitted;
    await tester.pumpWidget(
      _app(_Harness(habits: _habits, onChanged: (d) => emitted = d)),
    );
    await tester.tap(find.text('km'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '24');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    // count has its own chip label from macroTargets.unitCount.
    await tester.tap(find.text('count'));
    await tester.pumpAndSettle();
    expect(emitted!.unit, TargetUnit.count);
    expect(emitted!.amount, 24);
    expect(emitted!.linkedGoalId, 'h2');
  });

  testWidgets('selecting None clears the target', (tester) async {
    MacroTargetDraft? emitted = const MacroTargetDraft(
      amount: 10,
      unit: TargetUnit.count,
    );
    await tester.pumpWidget(
      _app(_Harness(habits: _habits, onChanged: (d) => emitted = d)),
    );
    await tester.tap(find.text('km'));
    await tester.pumpAndSettle();
    expect(emitted, isNotNull);

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    expect(emitted, isNull);
    expect(find.text('Target amount'), findsNothing);
  });
}
