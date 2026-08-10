import 'package:evolve_verification/evolve_verification.dart';
import 'package:evolve_verification/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// The durable Screen Time signal buffer.
///
/// The native drain is destructive — `drainSignals` reads and clears the App
/// Group in one call and DeviceActivity has no re-query API — so a signal that
/// is consumed by a pass whose verdict write then fails used to be gone for
/// good. HealthKit does not have this problem: its day is re-queried on every
/// pass, so a failed write simply happens again. These tests pin the asymmetry
/// closed.
void main() {
  final today = DateTime(2026, 7, 13);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

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

  VerifiableGoal limit() => VerifiableGoal(
        goalId: 'st',
        rule: VerificationCatalog.screenTimeApps.ruleWith(60),
        effectiveFrom: daysAgo(30),
      );

  VerifiableGoal steps() => VerifiableGoal(
        goalId: 'hk',
        rule: VerificationCatalog.steps.ruleWith(10000),
        effectiveFrom: daysAgo(30),
      );

  void queue(DateTime day, ScreenTimeSignalKind kind) => screen.addSignal(
        ScreenTimeSignal(goalId: 'st', day: day, kind: kind),
      );

  test('a drained signal is persisted before it is acted on', () async {
    queue(daysAgo(1), ScreenTimeSignalKind.stayedUnder);

    await controller.reconcile(
        goals: [limit()], loggedOutcomes: const {}, today: today);

    expect(store.signals['st']?[daysAgo(1)],
        ScreenTimeSignalKind.stayedUnder,
        reason: 'the only copy of the signal must survive the drain');
  });

  test('a FAILED verdict write leaves the day re-derivable on the next pass',
      () async {
    // Pass 1: the device is offline, so every write is rejected. The App Group
    // buffer is emptied by the drain regardless — that is the native contract.
    writer.succeeds = false;
    queue(daysAgo(1), ScreenTimeSignalKind.stayedUnder);

    final failed = await controller.reconcile(
        goals: [limit()], loggedOutcomes: const {}, today: today);

    expect(writer.writes, hasLength(1), reason: 'the write was attempted');
    expect(failed.writes, isEmpty,
        reason: 'a write that did not land is not a write');
    expect(failed.written, 0);

    // Pass 2: back online, and the extension has nothing new to say.
    writer.succeeds = true;
    writer.writes.clear();
    expect(screen.drainCallCount, 1);

    final recovered = await controller.reconcile(
        goals: [limit()], loggedOutcomes: const {}, today: today);

    expect(recovered.writes, hasLength(1));
    expect(recovered.writes.single.day, daysAgo(1));
    expect(recovered.writes.single.outcome, VerificationOutcome.pass);
  });

  test('a failed write neither clears the "?" nor announces the verdict',
      () async {
    // The day is already marked couldn't-verify from an earlier pass.
    await store.recordCouldNotVerify('st', daysAgo(1));
    writer.succeeds = false;
    queue(daysAgo(1), ScreenTimeSignalKind.reachedThreshold);

    final report = await controller.reconcile(
        goals: [limit()], loggedOutcomes: const {}, today: today);

    expect(await store.couldNotVerifyDays('st'), contains(daysAgo(1)),
        reason: 'the user must keep the affordance that fixes the day');
    expect(report.writes, isEmpty,
        reason: 'nothing was stored, so nothing may be celebrated');
  });

  test('a successful write clears the "?" and is reported', () async {
    await store.recordCouldNotVerify('st', daysAgo(1));
    queue(daysAgo(1), ScreenTimeSignalKind.stayedUnder);

    final report = await controller.reconcile(
        goals: [limit()], loggedOutcomes: const {}, today: today);

    expect(await store.couldNotVerifyDays('st'), isNot(contains(daysAgo(1))));
    expect(report.writes, hasLength(1));
  });

  test('reachedThreshold stays sticky ACROSS passes, not just within one drain',
      () async {
    queue(daysAgo(1), ScreenTimeSignalKind.reachedThreshold);
    await controller.reconcile(
        goals: [limit()], loggedOutcomes: const {}, today: today);
    expect(writer.writes.single.outcome, VerificationOutcome.fail);

    // A late/duplicate interval-end for the SAME day arrives on a later pass.
    // Before the buffer was durable this was a fresh, unopposed `stayedUnder`.
    writer.writes.clear();
    queue(daysAgo(1), ScreenTimeSignalKind.stayedUnder);

    final report = await controller.reconcile(
      goals: [limit()],
      loggedOutcomes: {
        'st': {daysAgo(1): VerificationOutcome.fail},
      },
      today: today,
    );

    expect(report.writes, isEmpty,
        reason: 'the crossing is permanent — the day must not flip to pass');
    expect(store.signals['st']?[daysAgo(1)],
        ScreenTimeSignalKind.reachedThreshold);
  });

  test('buffered signals are pruned once they age out of the window', () async {
    queue(daysAgo(5), ScreenTimeSignalKind.stayedUnder); // outside backfill 3
    queue(daysAgo(1), ScreenTimeSignalKind.stayedUnder);

    await controller.reconcile(
        goals: [limit()], loggedOutcomes: const {}, today: today);

    expect(store.signals['st']?.containsKey(daysAgo(5)), isFalse);
    expect(store.signals['st']?.containsKey(daysAgo(1)), isTrue);
  });

  test('a HealthKit-only goal list never touches the drain', () async {
    // Draining for a list with no Screen Time goal would destroy the buffer of
    // a Screen Time habit whose feature flag is currently off.
    health.setQuantity('stepCount', daysAgo(1), 12000);

    await controller.reconcile(
        goals: [steps()], loggedOutcomes: const {}, today: today);

    expect(screen.drainCallCount, 0);
  });

  test('a buffered signal is NOT replayed while the selection is unresolvable',
      () async {
    // Pass 1: the goal is monitored, and an interval-end lands in the buffer.
    queue(daysAgo(1), ScreenTimeSignalKind.stayedUnder);
    await controller.reconcile(
        goals: [limit()], loggedOutcomes: const {}, today: today);
    expect(writer.writes, hasLength(1));

    // Pass 2: the device-local selection blob is gone (reinstall, a synced goal
    // on a new device, a cancelled picker), so nothing is being watched. The
    // buffered row must not speak for a monitor that no longer exists.
    writer.writes.clear();
    final unmonitored = VerifiableGoal(
      goalId: 'st',
      rule: VerificationCatalog.screenTimeApps.ruleWith(60),
      effectiveFrom: daysAgo(30),
      screenTimeSelectionMissing: true,
    );

    final report = await controller.reconcile(
        goals: [unmonitored], loggedOutcomes: const {}, today: today);

    expect(report.writes, isEmpty,
        reason: 'an unwatched habit must never be handed a pass');
    expect(await store.couldNotVerifyDays('st'), contains(daysAgo(1)));
    expect(store.signals['st']?[daysAgo(1)], ScreenTimeSignalKind.stayedUnder,
        reason: 'suppress the READ, keep the record — the blob may come back');
  });

  test('a store that cannot be written still resolves the day this pass',
      () async {
    final broken = _BrokenSignalStore();
    controller = VerificationController(
      service: VerificationService(
          health: health, screenTime: screen, backfillDays: 3),
      store: broken,
      logWriter: writer,
    );
    queue(daysAgo(1), ScreenTimeSignalKind.stayedUnder);

    final report = await controller.reconcile(
        goals: [limit()], loggedOutcomes: const {}, today: today);

    expect(report.writes, hasLength(1),
        reason: 'persistence is robustness — it must never cost the pass');
  });
}

/// A store whose signal persistence is broken in both directions — the shape of
/// a device whose verification database cannot be opened or written.
class _BrokenSignalStore extends FakeVerificationStateStore {
  @override
  Future<void> recordScreenTimeSignals(Iterable<ScreenTimeSignal> s) async =>
      throw StateError('disk full');

  @override
  Future<List<ScreenTimeSignal>> screenTimeSignals({
    required Iterable<String> goalIds,
    required DateTime from,
    required DateTime to,
  }) async =>
      throw StateError('database is locked');
}
