// The decision that guards the user's counts: does a setHabitProgress call
// touch the `goal_progress` row at all?
//
// Both backends switch on `progressRowWriteFor`, and neither is otherwise
// reachable from a test — `PrivateDashboardRepository` needs a live SQLCipher
// database and `SupabaseDashboardRepository` a real client, so the statements
// that issue the DELETE are never executed by the suite. Testing the DECISION is
// what makes that branch covered.
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('progressRowWriteFor', () {
    test('a verdict-only write never touches the row — at ANY amount', () {
      // The amount is meaningless on a verdict-only change (the reconciler pins
      // it to 0 with an assert), but this must not depend on that: the flag
      // alone decides, so a future caller that forgets to zero the amount still
      // cannot issue a delete or an upsert.
      for (final amount in [0.0, 0.5, 80.0, -3.0]) {
        expect(
          progressRowWriteFor(verdictOnly: true, amount: amount),
          ProgressRowWrite.none,
          reason: 'verdictOnly must dominate the amount',
        );
      }
    });

    test('zero deletes — the shipped meaning of "back to nothing"', () {
      expect(progressRowWriteFor(verdictOnly: false, amount: 0),
          ProgressRowWrite.delete);
    });

    test('a negative amount deletes rather than storing nonsense', () {
      expect(progressRowWriteFor(verdictOnly: false, amount: -1),
          ProgressRowWrite.delete);
    });

    test('a real number is stored', () {
      expect(progressRowWriteFor(verdictOnly: false, amount: 80),
          ProgressRowWrite.upsert);
      expect(progressRowWriteFor(verdictOnly: false, amount: 0.001),
          ProgressRowWrite.upsert);
    });

    test('none and delete are DIFFERENT answers, not synonyms', () {
      // They produce the same database on a day that genuinely has no row, and
      // diverge exactly when the in-memory map is wrong — which is the case the
      // flag exists for. Collapsing them (`verdictOnly` falling through to the
      // amount <= 0 branch) is the regression this pins.
      expect(progressRowWriteFor(verdictOnly: true, amount: 0),
          isNot(progressRowWriteFor(verdictOnly: false, amount: 0)));
    });
  });
}
