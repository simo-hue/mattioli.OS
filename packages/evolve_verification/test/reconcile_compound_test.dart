// End-to-end reconcile for compound HealthKit habits (steps OR/AND exercise):
// the engine pulls each condition and folds the verdicts via the Q5 table, then
// writes ordinary done/missed with a null value (Q6) or records couldn't-verify.
import 'package:evolve_verification/evolve_verification.dart';
import 'package:evolve_verification/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 7, 13);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  late FakeHealthKitBridge health;
  late FakeScreenTimeBridge screen;
  setUp(() {
    health = FakeHealthKitBridge();
    screen = FakeScreenTimeBridge();
  });

  VerificationService service() => VerificationService(
        health: health,
        screenTime: screen,
        backfillDays: 3,
        nagWindowDays: 2,
      );

  VerifiableGoal compound(VerificationJoin op) => VerifiableGoal(
        goalId: 'g_c',
        rule: VerificationCatalog.steps.ruleWith(10000),
        additionalConditions: [VerificationCatalog.exerciseMinutes.ruleWith(30)],
        join: op,
        effectiveFrom: daysAgo(30),
      );

  const stepsId = 'stepCount';
  const exId = 'appleExerciseTime';
  final d1 = daysAgo(1);

  LogWrite? writeFor(ReconcilePlan p, DateTime day) {
    final w = p.writes.where((w) => w.day == day && w.goalId == 'g_c');
    return w.isEmpty ? null : w.single;
  }

  bool cnvFor(ReconcilePlan p, DateTime day) =>
      p.couldNotVerify.any((c) => c.day == day && c.goalId == 'g_c');

  group('compound OR (pass if any met)', () {
    test('steps miss + exercise hit → pass, with a null compound value', () async {
      health.setQuantity(stepsId, d1, 3000); // fail
      health.setQuantity(exId, d1, 45); // pass
      final plan =
          await service().reconcile(goals: [compound(VerificationJoin.or)], today: today);
      expect(writeFor(plan, d1)!.outcome, VerificationOutcome.pass);
      expect(writeFor(plan, d1)!.value, isNull);
    });

    test('both definitively missed → fail', () async {
      health.setQuantity(stepsId, d1, 3000); // fail
      health.setQuantity(exId, d1, 5); // fail
      final plan =
          await service().reconcile(goals: [compound(VerificationJoin.or)], today: today);
      expect(writeFor(plan, d1)!.outcome, VerificationOutcome.fail);
    });

    test('one miss + one unreadable → couldNotVerify, no write', () async {
      health.setQuantity(stepsId, d1, 3000); // fail
      // exercise unset → null → couldNotVerify; OR keeps the day open
      final plan =
          await service().reconcile(goals: [compound(VerificationJoin.or)], today: today);
      expect(writeFor(plan, d1), isNull);
      expect(cnvFor(plan, d1), isTrue);
    });
  });

  group('compound AND (pass only if all met)', () {
    test('all met → pass, null value', () async {
      health.setQuantity(stepsId, d1, 12000); // pass
      health.setQuantity(exId, d1, 45); // pass
      final plan =
          await service().reconcile(goals: [compound(VerificationJoin.and)], today: today);
      expect(writeFor(plan, d1)!.outcome, VerificationOutcome.pass);
      expect(writeFor(plan, d1)!.value, isNull);
    });

    test('a hard fail short-circuits past an unreadable condition → fail', () async {
      health.setQuantity(stepsId, d1, 3000); // fail
      // exercise unset → couldNotVerify; AND → fail
      final plan =
          await service().reconcile(goals: [compound(VerificationJoin.and)], today: today);
      expect(writeFor(plan, d1)!.outcome, VerificationOutcome.fail);
    });

    test('a met condition + an unreadable one → couldNotVerify, no write', () async {
      health.setQuantity(stepsId, d1, 12000); // pass
      // exercise unset → couldNotVerify; AND → couldNotVerify
      final plan =
          await service().reconcile(goals: [compound(VerificationJoin.and)], today: today);
      expect(writeFor(plan, d1), isNull);
      expect(cnvFor(plan, d1), isTrue);
    });
  });
}
