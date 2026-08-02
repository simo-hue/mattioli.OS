import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter_test/flutter_test.dart';

HabitTarget _count() =>
    TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);
HabitTarget _limit() =>
    TargetPresetCatalog.limitCountDaily.targetWith(amount: 1);

/// Runs the sweep with map-backed lookups, everything scheduled by default.
List<TargetReconcileChange> run({
  required HabitTarget target,
  required DateTime today,
  required DateTime start,
  DateTime? effectiveFrom,
  Map<String, double> progress = const {},
  Map<String, String> status = const {},
  bool Function(DateTime)? isScheduled,
  DateTime? autoFailUnmetFrom,
  int backfillDays = kManualTargetBackfillDays,
}) =>
    reconcileManualTargetDays(
      goalId: 'g1',
      target: target,
      today: today,
      start: start,
      effectiveFrom: effectiveFrom,
      backfillDays: backfillDays,
      isScheduled: isScheduled ?? (_) => true,
      progressFor: (k) => progress[k],
      statusFor: (k) => status[k],
      autoFailUnmetFrom: autoFailUnmetFrom,
    );

void main() {
  final today = DateTime(2026, 7, 24);

  group('limit (atMost) habits — the case the sweep exists for', () {
    test('every quiet closed day resolves to done', () {
      final changes = run(
        target: _limit(),
        today: today,
        start: DateTime(2026, 7, 21), // 3 closed days: 21, 22, 23
      );
      expect(changes.map((c) => c.dateKey), [
        '2026-07-21',
        '2026-07-22',
        '2026-07-23',
      ]);
      // Quiet days carry amount 0 → the caller's setProgress resolves them to
      // 'done'.
      expect(changes.every((c) => c.amount == 0), isTrue);
    });

    test('today is never swept (its verdict is derived live)', () {
      final changes = run(
        target: _limit(),
        today: today,
        start: DateTime(2026, 7, 21),
      );
      expect(changes.any((c) => c.dateKey == '2026-07-24'), isFalse);
    });

    test('a day already marked done is left alone (idempotent)', () {
      final changes = run(
        target: _limit(),
        today: today,
        start: DateTime(2026, 7, 23), // only the 23rd is closed
        status: const {'2026-07-23': 'done'},
      );
      expect(changes, isEmpty);
    });

    test('a breached day (progress over the cap) is left as its stored miss', () {
      final changes = run(
        target: _limit(),
        today: today,
        start: DateTime(2026, 7, 23),
        progress: const {'2026-07-23': 2},
        status: const {'2026-07-23': 'missed'},
      );
      expect(changes, isEmpty);
    });
  });

  group('atLeast habits — untouched days stay absent', () {
    test('a day with NO progress is skipped (no invented miss)', () {
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 20),
      );
      expect(changes, isEmpty,
          reason: 'an untouched count day must read like a checkbox habit: '
              'absent, not missed');
    });

    test('a partial closed day resolves to missed', () {
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 23),
        progress: const {'2026-07-23': 40}, // 40 of 80
      );
      expect(changes.single.dateKey, '2026-07-23');
      expect(changes.single.amount, 40);
    });

    test('a met day already stored as done is left alone', () {
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 23),
        progress: const {'2026-07-23': 80},
        status: const {'2026-07-23': 'done'},
      );
      expect(changes, isEmpty);
    });

    test('a partial day whose stored verdict is stale is corrected', () {
      // Progress says 40/80 (miss) but the row wrongly says done.
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 23),
        progress: const {'2026-07-23': 40},
        status: const {'2026-07-23': 'done'},
      );
      expect(changes.single.dateKey, '2026-07-23');
    });
  });

  group('auto-fail for untouched count days', () {
    test('an untouched closed day at/after the anchor resolves to missed', () {
      final changes = run(
        target: _count(),
        today: today, // 2026-07-24
        start: DateTime(2026, 7, 21),
        autoFailUnmetFrom: DateTime(2026, 7, 21),
      );
      expect(changes.map((c) => c.dateKey), [
        '2026-07-21',
        '2026-07-22',
        '2026-07-23',
      ]);
      // Nothing was ever entered, so there is no number to write back.
      expect(changes.every((c) => c.verdictOnly), isTrue);
      expect(changes.every((c) => c.amount == 0), isTrue);
    });

    test('the anchor clamps the window — earlier days stay untouched', () {
      // The rule went live on the 23rd. The 20th–22nd closed before it existed
      // and must render exactly as the user last saw them.
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 20),
        autoFailUnmetFrom: DateTime(2026, 7, 23),
      );
      expect(changes.map((c) => c.dateKey), ['2026-07-23']);
    });

    test('today is never auto-failed — the day is not over', () {
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 24),
        autoFailUnmetFrom: DateTime(2026, 7, 1),
      );
      expect(changes, isEmpty);
    });

    test('a touched-then-undone day and an untouched day now agree', () {
      // The asymmetry that started this: +20 then −20 deletes the progress row
      // but leaves 'missed' behind, while the neighbouring untouched day stayed
      // pending. Both are days of zero push-ups; both must read the same.
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 22),
        status: const {'2026-07-22': 'missed'}, // the undone day
        autoFailUnmetFrom: DateTime(2026, 7, 22),
      );
      // The undone day is already correct (idempotent, no change); the
      // untouched one is brought into line with it.
      expect(changes.map((c) => c.dateKey), ['2026-07-23']);
    });

    test('an untouched OFF-schedule day is still never scored', () {
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 20),
        isScheduled: (d) => d.weekday == DateTime.monday, // the 20th
        autoFailUnmetFrom: DateTime(2026, 7, 1),
      );
      expect(changes.map((c) => c.dateKey), ['2026-07-20']);
    });

    test('an explicit done with NO number is never overruled', () {
      // The habit reminder's "Done" action writes a goal_logs row and nothing
      // else. Auto-fail must not read the missing count as evidence against a
      // deliberate human answer — absence is not evidence.
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 23),
        status: const {'2026-07-23': 'done'},
        autoFailUnmetFrom: DateTime(2026, 7, 1),
      );
      expect(changes, isEmpty);
    });

    test('a day already stored as missed is left alone (idempotent)', () {
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 23),
        status: const {'2026-07-23': 'missed'},
        autoFailUnmetFrom: DateTime(2026, 7, 1),
      );
      expect(changes, isEmpty);
    });

    test('an untouched day is never auto-failed BEFORE the habit start date',
        () {
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 23), // created the day before yesterday
        autoFailUnmetFrom: DateTime(2026, 7, 1), // anchor reaches further back
      );
      expect(changes.map((c) => c.dateKey), ['2026-07-23']);
    });

    test('effectiveFrom still wins over an earlier anchor', () {
      // The target was edited on the 23rd. Auto-fail must not reach back past
      // that freeze and score days against a target that did not apply to them.
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 20),
        effectiveFrom: DateTime(2026, 7, 23),
        autoFailUnmetFrom: DateTime(2026, 7, 1),
      );
      expect(changes.map((c) => c.dateKey), ['2026-07-23']);
    });

    test('a partial day still carries its number (NOT verdict-only)', () {
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 23),
        progress: const {'2026-07-23': 40},
        autoFailUnmetFrom: DateTime(2026, 7, 1),
      );
      expect(changes.single.amount, 40);
      expect(changes.single.verdictOnly, isFalse,
          reason: 'a day with a stored number must go through the normal '
              'progress path so the number is preserved');
    });

    test('a met day is untouched even with auto-fail on', () {
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 23),
        progress: const {'2026-07-23': 80},
        status: const {'2026-07-23': 'done'},
        autoFailUnmetFrom: DateTime(2026, 7, 1),
      );
      expect(changes, isEmpty);
    });

    test('a NON-daily target is never auto-failed', () {
      // A "3× a week" target's individual day is not a period; auto-failing each
      // one would invent six misses a week. No shipped preset builds one, but
      // the decoder accepts one from synced/legacy data.
      final weekly = _count().copyWith(period: TargetPeriod.week);
      final changes = run(
        target: weekly,
        today: today,
        start: DateTime(2026, 7, 21),
        autoFailUnmetFrom: DateTime(2026, 7, 1),
      );
      expect(changes, isEmpty);
    });

    test('a LIMIT habit is unaffected by the anchor — quiet days still resolve',
        () {
      // Auto-fail must not clamp the limit sweep: its 45-day reach is shipped
      // behaviour and a quiet limit day is a success, not a miss.
      final withAnchor = run(
        target: _limit(),
        today: today,
        start: DateTime(2026, 7, 20),
        autoFailUnmetFrom: DateTime(2026, 7, 23),
      );
      final without = run(
        target: _limit(),
        today: today,
        start: DateTime(2026, 7, 20),
      );
      expect(withAnchor.map((c) => c.dateKey),
          without.map((c) => c.dateKey).toList());
      expect(withAnchor.map((c) => c.dateKey),
          ['2026-07-20', '2026-07-21', '2026-07-22', '2026-07-23']);
    });

    test('a quiet LIMIT day is verdict-only too — absence is absence', () {
      // The delete this flag prevents is not an atLeast problem: a limit day
      // with no row also has no number, and routing it through setProgress(0)
      // issues a DELETE on the strength of an absence. That is the loss this
      // codebase has actually suffered, on exactly this path.
      final changes = run(
        target: _limit(),
        today: today,
        start: DateTime(2026, 7, 23),
      );
      expect(changes.single.verdictOnly, isTrue);
      expect(changes.single.amount, 0);
    });

    test('a limit day that HAS a number keeps the progress path', () {
      final changes = run(
        target: _limit(),
        today: today,
        start: DateTime(2026, 7, 23),
        progress: const {'2026-07-23': 3}, // a recorded breach
      );
      expect(changes.single.verdictOnly, isFalse);
      expect(changes.single.amount, 3);
    });

    test('a measured target is still never swept, anchor or not', () {
      final measured = _count().copyWith(fillSource: TargetFillSource.healthKit);
      final changes = run(
        target: measured,
        today: today,
        start: DateTime(2026, 7, 20),
        autoFailUnmetFrom: DateTime(2026, 7, 1),
      );
      expect(changes, isEmpty);
    });

    test('a second sweep over an auto-failed history is a no-op', () {
      final start = DateTime(2026, 7, 21);
      final anchor = DateTime(2026, 7, 21);
      final first = run(
          target: _count(),
          today: today,
          start: start,
          autoFailUnmetFrom: anchor);
      expect(first, isNotEmpty);
      final status = {for (final c in first) c.dateKey: 'missed'};
      final second = run(
        target: _count(),
        today: today,
        start: start,
        status: status,
        autoFailUnmetFrom: anchor,
      );
      expect(second, isEmpty);
    });

    test('an anchor carrying a time-of-day still scores its OWN day', () {
      // The anchor is a calendar day, not an instant. Stamped from a wall clock
      // it arrives at 18:00; compared unnormalised, `cursor.isBefore(anchor)`
      // is true for that whole day and the anchor's own day is silently skipped
      // — an off-by-one-day the midnight-only tests cannot see.
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 23),
        autoFailUnmetFrom: DateTime(2026, 7, 23, 18, 30),
      );
      expect(changes.map((c) => c.dateKey), ['2026-07-23']);
    });

    test('the anchor widens the rule but never the window', () {
      // An ancient anchor must not defeat the backfill bound: the window still
      // decides how far back the sweep reaches.
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2020, 1, 1),
        autoFailUnmetFrom: DateTime(2020, 1, 1),
        backfillDays: 5, // only 07-19..07-23
      );
      expect(changes.length, 5);
      expect(changes.first.dateKey, '2026-07-19');
      expect(changes.last.dateKey, '2026-07-23');
    });

    test('a DURATION target auto-fails like a count one', () {
      // Auto-fail keys on direction + period, not on which preset built the
      // target — "30 minutes of reading" is the same rule as "80 push-ups".
      final duration =
          TargetPresetCatalog.durationDaily.targetWith(amount: 30, step: 5);
      final changes = run(
        target: duration,
        today: today,
        start: DateTime(2026, 7, 23),
        autoFailUnmetFrom: DateTime(2026, 7, 1),
      );
      expect(changes.single.dateKey, '2026-07-23');
      expect(changes.single.verdictOnly, isTrue);
    });

    test('WITHOUT the anchor an untouched day still stays absent', () {
      // The opt-in is load-bearing: a caller that has not passed an anchor must
      // see byte-identical behaviour to before this rule existed.
      final changes = run(
        target: _count(),
        today: today,
        start: DateTime(2026, 7, 20),
      );
      expect(changes, isEmpty);
    });
  });

  group('DST — every calendar day in the window, exactly once', () {
    // These run in whatever zone the suite is given, so they only *prove* the
    // arithmetic where a transition falls inside the window. The invariant they
    // state is zone-independent and holds everywhere: consecutive calendar days,
    // no gaps, no repeats. Under Europe/Rome the spring-forward case below
    // failed before the fix — 2026-03-29 was never visited, for all 45 days it
    // should have been in reach, so a limit habit lost the day it earned and
    // its streak broke every March.
    List<String> keysFor(DateTime today, {int backfillDays = 45}) => run(
          target: _limit(),
          today: today,
          start: DateTime(2020, 1, 1),
          backfillDays: backfillDays,
        ).map((c) => c.dateKey).toList();

    void expectConsecutiveDays(List<String> keys, {required int count}) {
      expect(keys.length, count);
      expect(keys.toSet().length, count, reason: 'a day was visited twice');
      for (var i = 1; i < keys.length; i++) {
        final prev = DateTime.parse(keys[i - 1]);
        final next = DateTime.parse(keys[i]);
        expect(DateTime(prev.year, prev.month, prev.day + 1), next,
            reason: 'a day was skipped between ${keys[i - 1]} and ${keys[i]}');
      }
    }

    test('a window spanning a spring-forward transition skips nothing', () {
      // Europe/Rome springs forward 2026-03-29; US zones on 2026-03-08.
      expectConsecutiveDays(keysFor(DateTime(2026, 4, 20)), count: 45);
      expectConsecutiveDays(keysFor(DateTime(2026, 3, 30)), count: 45);
      expectConsecutiveDays(keysFor(DateTime(2026, 3, 10)), count: 45);
    });

    test('a window spanning a fall-back transition repeats nothing', () {
      // Seeded from the habit's START DATE, not from windowStart — that is the
      // only entry point the duplicate is reachable through, and pinning it on
      // the window instead made this test unable to fail. (Backward from
      // windowStart the cursor lands at 01:00 on the fall-back side, and 24h
      // steps from 01:00 never repeat; the forward step from a midnight startD
      // is what lands on 23:00 of the same date.)
      for (final start in [
        DateTime(2026, 10, 20), // Europe/Rome falls back 2026-10-25
        DateTime(2026, 10, 28), // US zones fall back 2026-11-01
      ]) {
        final keys = run(
          target: _limit(),
          today: DateTime(2026, 11, 14),
          start: start,
          backfillDays: 45,
        ).map((c) => c.dateKey).toList();
        expectConsecutiveDays(keys,
            count: DateTime(2026, 11, 14).difference(start).inDays.round());
      }
    });

    test('a window spanning a fall-back transition, seeded from windowStart',
        () {
      // The other entry point. Clean today, and asserted so it stays clean.
      expectConsecutiveDays(keysFor(DateTime(2026, 11, 14)), count: 45);
      expectConsecutiveDays(keysFor(DateTime(2026, 10, 26)), count: 45);
      expectConsecutiveDays(keysFor(DateTime(2026, 11, 2)), count: 45);
    });
  });

  group('TargetReconcileChange value semantics', () {
    test('verdictOnly participates in equality', () {
      // Two changes that differ only in HOW they must be applied are not the
      // same change: an applier picking the wrong one either drops a number or
      // deletes one.
      const withFlag = TargetReconcileChange(
          goalId: 'g1', dateKey: '2026-07-23', amount: 0, verdictOnly: true);
      const without = TargetReconcileChange(
          goalId: 'g1', dateKey: '2026-07-23', amount: 0);
      expect(withFlag, isNot(without));
      expect(withFlag.hashCode, isNot(without.hashCode));
    });

    test('a verdict-only change with a number is a programming error', () {
      expect(
        () => TargetReconcileChange(
            goalId: 'g1', dateKey: '2026-07-23', amount: 40, verdictOnly: true),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('windowing and scheduling', () {
    test('never reaches before the habit start date', () {
      final changes = run(
        target: _limit(),
        today: today,
        start: DateTime(2026, 7, 22),
        backfillDays: 45,
      );
      expect(changes.first.dateKey, '2026-07-22');
      expect(changes.map((c) => c.dateKey), ['2026-07-22', '2026-07-23']);
    });

    test('respects the backfill window when the habit is older', () {
      final changes = run(
        target: _limit(),
        today: today,
        start: DateTime(2020, 1, 1),
        backfillDays: 5, // only 07-19..07-23 are in-window
      );
      expect(changes.length, 5);
      expect(changes.first.dateKey, '2026-07-19');
      expect(changes.last.dateKey, '2026-07-23');
    });

    test('off-schedule days never get a verdict', () {
      // Only Mondays scheduled. In 07-20..07-23, Monday is the 20th.
      final changes = run(
        target: _limit(),
        today: today,
        start: DateTime(2026, 7, 20),
        isScheduled: (d) => d.weekday == DateTime.monday,
      );
      expect(changes.map((c) => c.dateKey), ['2026-07-20']);
    });
  });

  test('a measured target is never swept here', () {
    final measured = _count().copyWith(fillSource: TargetFillSource.healthKit);
    final changes = run(
      target: measured,
      today: today,
      start: DateTime(2026, 7, 20),
      progress: const {'2026-07-21': 5000},
    );
    expect(changes, isEmpty);
  });

  test('a second sweep over a resolved history is a no-op', () {
    final start = DateTime(2026, 7, 21);
    final first = run(target: _limit(), today: today, start: start);
    expect(first, isNotEmpty);
    // Simulate the caller having applied every change (quiet days → done).
    final status = {for (final c in first) c.dateKey: 'done'};
    final second =
        run(target: _limit(), today: today, start: start, status: status);
    expect(second, isEmpty);
  });

  group('forward-only freeze (effectiveFrom, v11)', () {
    test('a later effectiveFrom clamps the window — pre-anchor days are frozen',
        () {
      // A limit target became active on 07-23. The 20th–22nd predate it and
      // must keep their historical verdict; only the 23rd is swept.
      final changes = run(
        target: _limit(),
        today: today, // 2026-07-24
        start: DateTime(2026, 7, 20),
        effectiveFrom: DateTime(2026, 7, 23),
      );
      expect(changes.map((c) => c.dateKey), ['2026-07-23']);
    });

    test('null effectiveFrom leaves behaviour identical to start', () {
      final start = DateTime(2026, 7, 21);
      final withNull = run(target: _limit(), today: today, start: start);
      final withEarlier = run(
        target: _limit(),
        today: today,
        start: start,
        effectiveFrom: DateTime(2026, 7, 1), // earlier than start ⇒ ignored
      );
      expect(withNull.map((c) => c.dateKey),
          withEarlier.map((c) => c.dateKey).toList());
    });

    test('raising an atLeast amount does NOT rewrite a day before the anchor',
        () {
      // 07-21 was earned (progress 80, status done) under the old target. The
      // user raised the bar to 200 and the anchor moved to 07-22. The earned
      // day predates the anchor and must survive untouched.
      final raised =
          TargetPresetCatalog.countDaily.targetWith(amount: 200, step: 20);
      final changes = run(
        target: raised,
        today: today,
        start: DateTime(2026, 7, 20),
        effectiveFrom: DateTime(2026, 7, 22),
        progress: {'2026-07-21': 80},
        status: {'2026-07-21': 'done'},
      );
      expect(changes.any((c) => c.dateKey == '2026-07-21'), isFalse);
    });

    test('WITHOUT the anchor the same raised amount rewrites the earned day',
        () {
      // The bug the anchor fixes: with no effective-from, 80 < 200 flips the
      // past 'done' to a change (→ 'missed'). This asserts the guard is load-
      // bearing, not incidental.
      final raised =
          TargetPresetCatalog.countDaily.targetWith(amount: 200, step: 20);
      final changes = run(
        target: raised,
        today: today,
        start: DateTime(2026, 7, 20),
        progress: {'2026-07-21': 80},
        status: {'2026-07-21': 'done'},
      );
      expect(changes.any((c) => c.dateKey == '2026-07-21'), isTrue);
    });
  });
}
