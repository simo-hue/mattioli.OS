import 'package:evolve_verification/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeVerificationStateStore store;
  DateTime day(int n) => DateTime(2026, 7, n);

  setUp(() => store = FakeVerificationStateStore());

  test('markNudged records only for a live couldn\'t-verify day', () async {
    // No couldn't-verify marker yet → markNudged is a no-op.
    await store.markNudged('g', day(10));
    expect(await store.nudgedDays('g'), isEmpty);

    await store.recordCouldNotVerify('g', day(10));
    await store.markNudged('g', day(10));
    expect(await store.nudgedDays('g'), {day(10)});
  });

  test('resolving a day drops its nudged mark (can nudge afresh)', () async {
    await store.recordCouldNotVerify('g', day(10));
    await store.markNudged('g', day(10));
    await store.resolveCouldNotVerify('g', day(10));
    expect(await store.nudgedDays('g'), isEmpty);

    // The day lapses back into couldn't-verify → a fresh nudge is allowed.
    await store.recordCouldNotVerify('g', day(10));
    await store.markNudged('g', day(10));
    expect(await store.nudgedDays('g'), {day(10)});
  });

  test('a manual freeze clears the nudged mark', () async {
    await store.recordCouldNotVerify('g', day(10));
    await store.markNudged('g', day(10));
    await store.markManual('g', day(10));
    expect(await store.nudgedDays('g'), isEmpty);
  });

  test('deleteGoal wipes nudged marks too', () async {
    await store.recordCouldNotVerify('g', day(10));
    await store.markNudged('g', day(10));
    await store.deleteGoal('g');
    expect(await store.nudgedDays('g'), isEmpty);
  });

  test('pruneCouldNotVerifyBefore drops older markers (and their nudged marks)',
      () async {
    await store.recordCouldNotVerify('g', day(5));
    await store.recordCouldNotVerify('g', day(10));
    await store.markNudged('g', day(5));
    await store.pruneCouldNotVerifyBefore('g', day(10)); // strictly before 10
    expect(await store.couldNotVerifyDays('g'), {day(10)});
    expect(await store.nudgedDays('g'), isEmpty); // day(5)'s nudged mark gone
  });
}
