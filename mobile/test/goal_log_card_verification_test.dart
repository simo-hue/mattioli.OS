import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/ui/widgets/day_details_modal.dart';

/// Themed + translated harness for the verification card (it reads
/// `context.appColors` and `context.t`).
Widget _app(Widget child) => ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          home: Scaffold(body: child),
        ),
      ),
    );

Goal _goal() => Goal(
      id: 'g',
      title: 'Steps',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
    );

/// An auto-verified habit, named something other than its metric so the label
/// keeps the metric name (see `habitVerificationLabel`).
Goal _verifiedGoal({String title = 'Morning walk'}) => Goal(
      id: 'g',
      title: title,
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
      verificationRule: VerificationCatalog.steps.ruleWith(10000),
    );

void main() {
  testWidgets('renders the "?" resolve affordance when couldNotVerify',
      (tester) async {
    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: _goal(),
      status: null,
      streak: 0,
      couldNotVerify: true,
      onTap: () {},
    )));

    expect(find.text('?'), findsOneWidget);
    // The short form, so this row can never wrap taller than the others.
    expect(find.text('Not verified — tap'), findsOneWidget);
  });

  testWidgets('a pending habit without couldNotVerify shows no "?"',
      (tester) async {
    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: _goal(),
      status: null,
      streak: 0,
      couldNotVerify: false,
      onTap: () {},
    )));

    expect(find.text('?'), findsNothing);
    expect(find.text('Not verified — tap'), findsNothing);
  });

  testWidgets('tapping the "?" card triggers the resolve callback',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: _goal(),
      status: null,
      streak: 0,
      couldNotVerify: true,
      onTap: () => taps++,
    )));

    await tester.tap(find.byType(GoalLogCard));
    expect(taps, 1);
  });

  testWidgets('a verified habit shows the rule it is measured against',
      (tester) async {
    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: _verifiedGoal(),
      status: null,
      streak: 0,
      onTap: () {},
    )));

    expect(find.text('≥ 10,000 Steps'), findsOneWidget);
    // The generic pill label it replaced is gone — the line says something
    // useful now instead of restating the shield icon.
    expect(find.text('Auto-verified'), findsNothing);
  });

  testWidgets('a verified habit drops the metric label that echoes its name',
      (tester) async {
    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: _verifiedGoal(title: 'Steps'),
      status: null,
      streak: 0,
      onTap: () {},
    )));

    expect(find.text('≥ 10,000'), findsOneWidget);
    expect(find.text('≥ 10,000 Steps'), findsNothing);
  });

  testWidgets('an unresolved verified day shows the prompt instead of the rule',
      (tester) async {
    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: _verifiedGoal(),
      status: null,
      streak: 0,
      couldNotVerify: true,
      onTap: () {},
    )));

    expect(find.text('Not verified — tap'), findsOneWidget);
    expect(find.text('≥ 10,000 Steps'), findsNothing);
    // The long form now lives only in the semantics label and
    // CouldNotVerifyChip — two stacked lines here would make the card change
    // height when a day resolves.
    expect(find.text("Couldn't verify — tap to resolve"), findsNothing);
  });

  testWidgets('the semantics label speaks the rule, and never twice',
      (tester) async {
    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: _verifiedGoal(),
      status: null,
      streak: 0,
      onTap: () {},
    )));

    expect(
      tester.getSemantics(find.byType(GoalLogCard)).label,
      'Morning walk, to do, Auto-verified, ≥ 10,000 Steps',
    );

    // Unresolved: the status already IS the prompt, so the line is not appended.
    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: _verifiedGoal(),
      status: null,
      streak: 0,
      couldNotVerify: true,
      onTap: () {},
    )));

    expect(
      tester.getSemantics(find.byType(GoalLogCard)).label,
      "Morning walk, Couldn't verify — tap to resolve",
    );
  });

  testWidgets('the habit name keeps the full row width on a narrow screen',
      (tester) async {
    // The regression this whole change exists for: the auto-verified pill used
    // to share row 1 with the name, take its intrinsic width (~180pt for the
    // Italian label) and squeeze the name to ~75pt, where it broke mid-word.
    const title = 'Allenamento in palestra';
    await tester.pumpWidget(_app(SizedBox(
      width: 320,
      child: GoalLogCard(
        date: DateTime(2026, 6, 1),
        habit: _verifiedGoal(title: title),
        status: null,
        streak: 0,
        onTap: () {},
      ),
    )));

    expect(tester.getSize(find.text(title)).width, greaterThan(150));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a habit that is BOTH verified and targeted keeps its progress',
      (tester) async {
    // The two are orthogonal (see `displayTargetFor`). Mobile's picker keeps
    // them exclusive, but the macOS editor writes a target without clearing the
    // rule, so this state arrives by sync — and the verification line must not
    // swallow the x / y readout the ring belongs to.
    final hybrid = Goal(
      id: 'g',
      title: 'Morning walk',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
      verificationRule: VerificationCatalog.steps.ruleWith(10000),
      target: TargetPresetCatalog.countDaily.targetWith(amount: 80),
    );

    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: hybrid,
      status: null,
      streak: 0,
      progressAmount: 40,
      target: hybrid.target,
      verdict: evaluateTarget(
        target: hybrid.target!,
        progress: 40,
        periodIsOver: false,
      ),
      onTap: () {},
    )));

    expect(find.text('40 / 80'), findsOneWidget);
    expect(find.text('≥ 10,000 Steps'), findsOneWidget);
  });

  testWidgets('a hybrid habit never shows a prompt its tap cannot honour',
      (tester) async {
    // With a target the tap opens the progress entry sheet, which cannot resolve
    // a verification — so "tap to fix it" would be a lie.
    final hybrid = Goal(
      id: 'g',
      title: 'Morning walk',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
      verificationRule: VerificationCatalog.steps.ruleWith(10000),
      target: TargetPresetCatalog.countDaily.targetWith(amount: 80),
    );

    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: hybrid,
      status: null,
      streak: 0,
      couldNotVerify: true,
      progressAmount: 40,
      target: hybrid.target,
      verdict: evaluateTarget(
        target: hybrid.target!,
        progress: 40,
        periodIsOver: false,
      ),
      onTap: () {},
    )));

    expect(find.text('Not verified — tap'), findsNothing);
    expect(find.text('≥ 10,000 Steps'), findsOneWidget);

    // Whatever the line shows, VoiceOver must say. These two gates desynced
    // once: the widget's was narrowed to `&& target == null` and the semantics
    // one was not, so the rule was on screen and silent.
    expect(
      tester.getSemantics(find.byType(GoalLogCard)).label,
      'Morning walk, 40 / 80, Auto-verified, ≥ 10,000 Steps',
    );
  });

  testWidgets('a stale marker on a de-verified habit stays one line',
      (tester) async {
    // Removing a rule does not clear its couldn't-verify markers, so a manual
    // habit can still carry one. It used to render the long string unbounded and
    // wrap to three rows, making the card 35pt taller than every other state.
    await tester.pumpWidget(_app(SizedBox(
      width: 320,
      child: GoalLogCard(
        date: DateTime(2026, 6, 1),
        habit: _goal(),
        status: null,
        streak: 0,
        couldNotVerify: true,
        onTap: () {},
      ),
    )));

    final text = tester.widget<Text>(find.text('Not verified — tap'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(find.text('Not verified — tap')).height, lessThan(20));
  });

  testWidgets('a day before a rule edit is not labelled with the new threshold',
      (tester) async {
    // Rule edits apply forward only (D10), so a day judged against the old
    // threshold falls back to the generic label, which cannot be wrong.
    final edited = Goal(
      id: 'g',
      title: 'Morning walk',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
      verificationRule: VerificationCatalog.steps.ruleWith(12000),
      verifyEffectiveFrom: DateTime(2026, 6, 10),
    );

    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 1),
      habit: edited,
      status: 'done',
      streak: 3,
      onTap: () {},
    )));

    expect(find.text('≥ 12,000 Steps'), findsNothing);
    expect(find.text('Auto-verified'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(GoalLogCard)).label,
      'Morning walk, done, Auto-verified',
    );

    // On and after the edit date the threshold is the day's own, so it is named.
    await tester.pumpWidget(_app(GoalLogCard(
      date: DateTime(2026, 6, 10),
      habit: edited,
      status: 'done',
      streak: 3,
      onTap: () {},
    )));

    expect(find.text('≥ 12,000 Steps'), findsOneWidget);
  });
}
