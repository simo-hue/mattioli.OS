import 'package:evolve_verification/evolve_verification.dart';
import 'package:evolve_verification/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 7, 13);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  late FakeHealthKitBridge health;
  late FakeScreenTimeBridge screen;
  late FakeVerificationStateStore store;
  late FakeVerificationLogWriter writer;
  late VerificationController controller;

  setUp(() {
    health = FakeHealthKitBridge();
    screen = FakeScreenTimeBridge();
    store = FakeVerificationStateStore();
    writer = FakeVerificationLogWriter();
    controller = VerificationController(
      service: VerificationService(
        health: health,
        screenTime: screen,
        backfillDays: 3,
        nagWindowDays: 2,
      ),
      store: store,
      logWriter: writer,
    );
  });

  VerifiableGoal steps() => VerifiableGoal(
        goalId: 'g',
        rule: VerificationCatalog.steps.ruleWith(10000),
        effectiveFrom: daysAgo(30),
      );

  bool wroteOn(DateTime day, {VerificationOutcome? outcome}) => writer.writes.any(
      (w) => w.day == day && (outcome == null || w.outcome == outcome));

  test('empty goals: no work, no side effects', () async {
    final report = await controller.reconcile(
        goals: const [], loggedOutcomes: const {}, today: today);
    expect(report.changedAnything, isFalse);
    expect(writer.writes, isEmpty);
  });

  test('writes verified verdicts and records couldn\'t-verify', () async {
    health.setQuantity('stepCount', daysAgo(1), 12000); // pass
    // daysAgo(2): no data → couldn't-verify; today: no data → pending (no row).
    final report = await controller.reconcile(
        goals: [steps()], loggedOutcomes: const {}, today: today);

    expect(wroteOn(daysAgo(1), outcome: VerificationOutcome.pass), isTrue);
    expect(writer.writes.single.value, 12000);
    expect(wroteOn(today), isFalse); // today stays pending

    expect(await store.couldNotVerifyDays('g'), contains(daysAgo(2)));
    expect(report.written, 1);
    expect(report.couldNotVerify, greaterThanOrEqualTo(1));
  });

  test('a manually-frozen day is never auto-written (D9)', () async {
    await store.markManual('g', daysAgo(1));
    health.setQuantity('stepCount', daysAgo(1), 5000); // would be a fail
    await controller.reconcile(
        goals: [steps()], loggedOutcomes: const {}, today: today);
    expect(wroteOn(daysAgo(1)), isFalse);
  });

  test('an unchanged logged outcome is not rewritten (idempotent)', () async {
    health.setQuantity('stepCount', daysAgo(1), 12000); // pass
    final logged = {
      'g': {daysAgo(1): VerificationOutcome.pass},
    };
    await controller.reconcile(
        goals: [steps()], loggedOutcomes: logged, today: today);
    expect(wroteOn(daysAgo(1)), isFalse);
  });

  test('couldn\'t-verify is resolved once the day gets a verdict', () async {
    // Pass 1: no data anywhere → daysAgo(1) + daysAgo(2) are couldn't-verify.
    await controller.reconcile(
        goals: [steps()], loggedOutcomes: const {}, today: today);
    expect(await store.couldNotVerifyDays('g'), contains(daysAgo(1)));

    // Pass 2: data arrives for daysAgo(1) → it resolves and its marker clears.
    health.setQuantity('stepCount', daysAgo(1), 12000);
    await controller.reconcile(
        goals: [steps()], loggedOutcomes: const {}, today: today);

    final cnv = await store.couldNotVerifyDays('g');
    expect(cnv.contains(daysAgo(1)), isFalse);
    expect(cnv, contains(daysAgo(2))); // still no data there
    expect(wroteOn(daysAgo(1), outcome: VerificationOutcome.pass), isTrue);
  });

  test('report surfaces nudges within the nag window', () async {
    final report = await controller.reconcile(
        goals: [steps()], loggedOutcomes: const {}, today: today);
    expect(report.nudges, isNotEmpty);
    expect(report.nudges.every((n) => today.difference(n.day).inDays <= 2),
        isTrue);
  });

  test('screen-time signals flow through to the log writer', () async {
    screen.addSignal(ScreenTimeSignal(
        goalId: 'gs',
        day: daysAgo(1),
        kind: ScreenTimeSignalKind.reachedThreshold));
    final goal = VerifiableGoal(
      goalId: 'gs',
      rule: VerificationCatalog.screenTimeTotal.ruleWith(120),
      effectiveFrom: daysAgo(30),
    );
    await controller.reconcile(
        goals: [goal], loggedOutcomes: const {}, today: today);
    expect(
      writer.writes.any((w) =>
          w.goalId == 'gs' &&
          w.day == daysAgo(1) &&
          w.outcome == VerificationOutcome.fail),
      isTrue,
    );
  });

  test('report.writes carries the written verdicts (for D11 notifications)',
      () async {
    health.setQuantity('stepCount', daysAgo(1), 12000); // pass
    final report = await controller.reconcile(
        goals: [steps()], loggedOutcomes: const {}, today: today);
    expect(report.writes, hasLength(1));
    expect(report.writes.single.goalId, 'g');
    expect(report.writes.single.day, daysAgo(1));
    expect(report.writes.single.outcome, VerificationOutcome.pass);
    expect(report.writes.single.value, 12000);
    // A second identical pass is idempotent → no fresh writes to notify on.
    final again = await controller.reconcile(
        goals: [steps()],
        loggedOutcomes: {
          'g': {daysAgo(1): VerificationOutcome.pass},
        },
        today: today);
    expect(again.writes, isEmpty);
  });
}
