// The D9 manual freeze, made undoable.
//
// Tapping a verified habit's day in day-details cycles its status and, on the
// way, records manual provenance — from then on every reconcile pass skips that
// day. That is correct (a deliberate correction must not be overwritten on the
// next foreground) but it was INVISIBLE and had no named way out: the only
// release was a third tap that reads as "clear the status", not as "let Apple
// Health decide again". A user who tapped once to see what happened had silently
// switched automation off for that day, which is how a habit can sit at `missed`
// while the sensor says otherwise.
//
// These pin the release path itself — the freeze must go with the verdict, and
// only ever for a habit the freeze applies to.

import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/core/verification_providers.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

/// Records log deletes so the test can assert the row really went, not just that
/// the in-memory map changed.
class _RecordingStore extends FakePrivateDataStore {
  final List<String> logDeletes = <String>[];

  @override
  Future<void> deleteHabitLog({
    required String goalId,
    required String date,
  }) async {
    logDeletes.add('$goalId@$date');
    await super.deleteHabitLog(goalId: goalId, date: date);
  }
}

/// In-memory manual/couldn't-verify bookkeeping — the D9 store, without sqflite.
class _FakeVerificationStateStore implements VerificationStateStore {
  final Set<String> manual = <String>{};

  String _key(String goalId, DateTime day) =>
      '$goalId@${day.year}-${day.month}-${day.day}';

  @override
  Future<void> markManual(String goalId, DateTime day,
          {String? status}) async =>
      manual.add(_key(goalId, day));

  @override
  Future<void> clearManual(String goalId, DateTime day) async =>
      manual.remove(_key(goalId, day));

  @override
  Future<Map<String, Map<DateTime, String?>>> manualDays({
    required Iterable<String> goalIds,
    required DateTime from,
    required DateTime to,
  }) async => const {};

  @override
  Future<Set<DateTime>> couldNotVerifyDays(String goalId) async => const {};

  @override
  Future<void> recordCouldNotVerify(String goalId, DateTime day) async {}

  @override
  Future<void> resolveCouldNotVerify(String goalId, DateTime day) async {}

  @override
  Future<void> pruneCouldNotVerifyBefore(String goalId, DateTime day) async {}

  @override
  Future<Set<DateTime>> nudgedDays(String goalId) async => const {};

  @override
  Future<void> markNudged(String goalId, DateTime day) async {}

  @override
  Future<void> deleteGoal(String goalId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final day = DateTime(2026, 8, 3);
  const dateKey = '2026-08-03';

  Goal verifiedGoal() => Goal(
    id: 'g1',
    title: 'Steps',
    color: const Color(0xFF3B82F6),
    startDate: DateTime(2026, 6, 20),
    verificationRule: VerificationCatalog.steps.ruleWith(10000),
  );

  Goal manualGoal() => Goal(
    id: 'g2',
    title: 'Read',
    color: const Color(0xFF3B82F6),
    startDate: DateTime(2026, 6, 20),
  );

  late _FakeVerificationStateStore verificationStore;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<ProviderContainer> container(
    FakePrivateDataStore store, {
    required List<Goal> goals,
  }) async {
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    verificationStore = _FakeVerificationStateStore();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith((ref) => store),
        verificationStateStoreProvider.overrideWith(
          (ref) async => verificationStore,
        ),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
      ],
    );
    addTearDown(c.dispose);
    // Warm BOTH notifiers and let their async private-store loads land before
    // anything writes. `loadHabitLogs` resolves to `{}`, so a notifier first
    // read after a write would overwrite that write with an empty map — the
    // test would then fail for a reason that has nothing to do with the freeze.
    c.read(goalsProvider.notifier);
    c.read(habitLogsProvider.notifier);
    await settle();
    for (final g in goals) {
      await c.read(goalsProvider.notifier).addHabit(g);
    }
    await settle();
    return c;
  }

  test('a single tap on a verified habit freezes the day — the behaviour the '
      'marker exists to disclose', () async {
    final c = await container(_RecordingStore(), goals: [verifiedGoal()]);
    await settle();

    await c.read(habitLogsProvider.notifier).cycleStatus(day, 'g1');
    await settle();

    expect(c.read(habitLogsProvider)[dateKey]?['g1'], 'done');
    expect(
      verificationStore.manual,
      contains('g1@2026-8-3'),
      reason:
          'one tap must freeze, or a deliberate correction would be '
          'overwritten by the next reconcile pass',
    );
  });

  test(
    'releaseToAutoVerification drops BOTH the verdict and the freeze',
    () async {
      final store = _RecordingStore();
      final c = await container(store, goals: [verifiedGoal()]);
      await settle();

      // Take the day over, then hand it back.
      await c.read(habitLogsProvider.notifier).cycleStatus(day, 'g1');
      await settle();
      expect(verificationStore.manual, isNotEmpty);

      await c
          .read(habitLogsProvider.notifier)
          .releaseToAutoVerification(day, 'g1');
      await settle();

      expect(c.read(habitLogsProvider)[dateKey]?['g1'], isNull);
      expect(store.logDeletes, contains('g1@$dateKey'));
      expect(
        verificationStore.manual,
        isEmpty,
        reason:
            'releasing must clear the freeze too — dropping the verdict alone '
            'would leave the day frozen at "no status", which reconcile skips '
            'forever, so the habit would never resolve again',
      );
    },
  );

  test(
    'releasing an ALREADY-auto day is a harmless no-op, not a second write',
    () async {
      final store = _RecordingStore();
      final c = await container(store, goals: [verifiedGoal()]);
      await settle();

      await c
          .read(habitLogsProvider.notifier)
          .releaseToAutoVerification(day, 'g1');
      await settle();

      expect(c.read(habitLogsProvider)[dateKey]?['g1'], isNull);
      expect(verificationStore.manual, isEmpty);
    },
  );

  test('release lands on the same state the third tap of the cycle does — it '
      'is a named shortcut, not a second write path', () async {
    final cycled = await container(_RecordingStore(), goals: [verifiedGoal()]);
    await settle();
    final logs = cycled.read(habitLogsProvider.notifier);
    await logs.cycleStatus(day, 'g1'); // done
    await logs.cycleStatus(day, 'g1'); // missed
    await logs.cycleStatus(day, 'g1'); // released
    await settle();
    final afterCycle = cycled.read(habitLogsProvider)[dateKey]?['g1'];
    final manualAfterCycle = {...verificationStore.manual};

    final released = await container(
      _RecordingStore(),
      goals: [verifiedGoal()],
    );
    await settle();
    await released.read(habitLogsProvider.notifier).cycleStatus(day, 'g1');
    await released
        .read(habitLogsProvider.notifier)
        .releaseToAutoVerification(day, 'g1');
    await settle();

    expect(released.read(habitLogsProvider)[dateKey]?['g1'], afterCycle);
    expect(verificationStore.manual, manualAfterCycle);
  });

  test(
    'a MANUAL habit is never frozen, so nothing claims Apple Health owns it',
    () async {
      final c = await container(_RecordingStore(), goals: [manualGoal()]);
      await settle();

      await c.read(habitLogsProvider.notifier).cycleStatus(day, 'g2');
      await settle();

      expect(c.read(habitLogsProvider)[dateKey]?['g2'], 'done');
      expect(
        verificationStore.manual,
        isEmpty,
        reason:
            'the freeze only exists to protect a check-in from an AUTO '
            'verdict; a habit with no rule has none to be protected from',
      );
    },
  );

  test('the cycle still advances none → done → missed → none', () async {
    final c = await container(_RecordingStore(), goals: [verifiedGoal()]);
    await settle();
    final logs = c.read(habitLogsProvider.notifier);

    await logs.cycleStatus(day, 'g1');
    await settle();
    expect(c.read(habitLogsProvider)[dateKey]?['g1'], 'done');

    await logs.cycleStatus(day, 'g1');
    await settle();
    expect(c.read(habitLogsProvider)[dateKey]?['g1'], 'missed');
    expect(
      verificationStore.manual,
      isNotEmpty,
      reason: 'still the user\'s day at "missed" — the freeze must persist',
    );

    await logs.cycleStatus(day, 'g1');
    await settle();
    expect(c.read(habitLogsProvider)[dateKey]?['g1'], isNull);
    expect(verificationStore.manual, isEmpty);
  });

  // An UNRESOLVABLE goal must still freeze. `goalsProvider` returns `[]`
  // synchronously from `build()` and the auth listener empties it, so "not
  // found" routinely means "not loaded yet" — reading that as "not verified"
  // skipped the freeze while the check-in row was still written, leaving a
  // verdict with nothing protecting it for the next reconcile to overwrite.
  test('a check-in on a goal that cannot be resolved still freezes the day',
      () async {
    // No habits added at all: the lookup finds nothing, exactly as it would
    // mid-load.
    final c = await container(_RecordingStore(), goals: const []);
    await settle();

    await c.read(habitLogsProvider.notifier).cycleStatus(day, 'g1');
    await settle();

    expect(c.read(habitLogsProvider)[dateKey]?['g1'], 'done');
    expect(
      verificationStore.manual,
      contains('g1@2026-8-3'),
      reason: 'the row was written, so something must protect it. A spurious '
          'freeze on a habit that turns out to be manual is inert — reconcile '
          'only queries manual days for the CURRENT verifiable goals',
    );
  });
}
