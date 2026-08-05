import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/streak_audit.dart';
import 'package:mattioli_os/core/streak_utils.dart';

void main() {
  // 2026-01-05 is a Monday.
  final start = DateTime(2026, 1, 5);

  AuditHabit habit({String id = 'h1', List<int>? frequencyDays}) => AuditHabit(
        id: id,
        startDate: start,
        frequencyDays: frequencyDays,
      );

  /// [n] consecutive 'done' days from [start], each carrying the streak value
  /// it genuinely earned (1, 2, 3, …) — i.e. an UNCORRUPTED history.
  List<AuditLog> healthyRun(int n, {String goalId = 'h1'}) => [
        for (var i = 0; i < n; i++)
          AuditLog(
            goalId: goalId,
            date: DateTime(2026, 1, 5 + i),
            status: 'done',
            storedStreak: i + 1,
          ),
      ];

  group('date key', () {
    test('matches the format computeStreak looks logs up by', () {
      // This is the guard on the deliberate duplication of `_dateKey`. If
      // streakDateKey ever diverged from streak_utils' private copy, every
      // lookup inside computeStreak would MISS, a plainly-unbroken 5-day run
      // would score 0, and this test fails. Asserting the string directly would
      // not catch a change made on the other side of the duplication.
      final logs = <String, Map<String, String>>{
        for (var i = 0; i < 5; i++)
          streakDateKey(DateTime(2026, 1, 5 + i)): {'h1': 'done'},
      };
      expect(
        computeStreak(
          habitId: 'h1',
          date: DateTime(2026, 1, 9),
          logs: logs,
          startDate: start,
        ),
        5,
      );
    });

    test('zero-pads month and day', () {
      expect(streakDateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(streakDateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('auditStreaks', () {
    test('reports nothing when every stored streak is already correct', () {
      final report =
          auditStreaks(habits: [habit()], logs: healthyRun(5));

      expect(report.isClean, isTrue);
      expect(report.mismatchCount, 0);
      expect(report.logsAudited, 5);
      expect(report.habitsAudited, 1);
      expect(report.habitsInInput, 1);
    });

    test('flags a row whose stored streak disagrees', () {
      final logs = healthyRun(5);
      // Day 5 genuinely earned 5; pretend it holds 4.
      logs[4] = AuditLog(
        goalId: 'h1',
        date: logs[4].date,
        status: 'done',
        storedStreak: 4,
      );

      final report = auditStreaks(habits: [habit()], logs: logs);

      expect(report.mismatchCount, 1);
      expect(report.mismatches.single.stored, 4);
      expect(report.mismatches.single.computed, 5);
      expect(report.mismatches.single.date, DateTime(2026, 1, 9));
    });

    test(
        'recognises the empty-goals-window signature: a real streak flattened '
        'to 1', () {
      // Exactly what applyAutoVerdict persists when the goal is absent and
      // startDate falls back to the written day: computeStreak's backward walk
      // breaks on its first step, so a long run is stored as 1.
      final logs = healthyRun(10);
      logs[9] = AuditLog(
        goalId: 'h1',
        date: logs[9].date,
        status: 'done',
        storedStreak: 1,
      );

      final report = auditStreaks(habits: [habit()], logs: logs);

      expect(report.mismatchCount, 1);
      final m = report.mismatches.single;
      expect(m.stored, 1);
      expect(m.computed, 10);
      expect(m.looksCollapsed, isTrue);
      expect(report.collapsed, hasLength(1));
    });

    test('a negative streak collapsed to -1 also reads as collapsed', () {
      final logs = [
        for (var i = 0; i < 4; i++)
          AuditLog(
            goalId: 'h1',
            date: DateTime(2026, 1, 5 + i),
            status: 'missed',
            storedStreak: -(i + 1),
          ),
      ];
      logs[3] = AuditLog(
        goalId: 'h1',
        date: logs[3].date,
        status: 'missed',
        storedStreak: -1,
      );

      final report = auditStreaks(habits: [habit()], logs: logs);

      expect(report.mismatches.single.computed, -4);
      expect(report.mismatches.single.looksCollapsed, isTrue);
    });

    test('ordinary staleness is NOT reported as collapsed', () {
      // stored 3 / computed 5 is a real mismatch with no collapse signature —
      // the flag must stay specific enough to be worth reporting separately.
      // (Note stored 1 / computed 2 DOES read as collapsed, and correctly so:
      // a genuine 2-day streak flattened to 1 is the same corruption, and
      // nothing in the data distinguishes it from an off-by-one.)
      final logs = healthyRun(5);
      logs[4] = AuditLog(
        goalId: 'h1',
        date: logs[4].date,
        status: 'done',
        storedStreak: 3,
      );

      final report = auditStreaks(habits: [habit()], logs: logs);

      expect(report.mismatchCount, 1);
      expect(report.mismatches.single.computed, 5);
      expect(report.collapsed, isEmpty);
    });

    test('honours the weekly schedule, so off-days do not read as damage', () {
      // Mon/Wed/Fri only. 2026-01-05 Mon, 07 Wed, 09 Fri — a 3-run, with the
      // unscheduled days in between transparent rather than streak-breaking.
      final logs = [
        AuditLog(
            goalId: 'h1',
            date: DateTime(2026, 1, 5),
            status: 'done',
            storedStreak: 1),
        AuditLog(
            goalId: 'h1',
            date: DateTime(2026, 1, 7),
            status: 'done',
            storedStreak: 2),
        AuditLog(
            goalId: 'h1',
            date: DateTime(2026, 1, 9),
            status: 'done',
            storedStreak: 3),
      ];

      final report = auditStreaks(
        habits: [habit(frequencyDays: const [1, 3, 5])],
        logs: logs,
      );

      expect(report.isClean, isTrue,
          reason: 'a scheduled habit\'s off-days must not count as mismatches');
    });

    test('scores each habit against its OWN history, not a shared one', () {
      final report = auditStreaks(
        habits: [habit(id: 'h1'), habit(id: 'h2')],
        logs: [
          ...healthyRun(3, goalId: 'h1'),
          ...healthyRun(2, goalId: 'h2'),
        ],
      );

      expect(report.isClean, isTrue);
      expect(report.habitsAudited, 2);
      expect(report.logsAudited, 5);
    });

    test('counts rows whose goal no longer exists instead of scoring them', () {
      final report = auditStreaks(
        habits: [habit(id: 'h1')],
        logs: [
          ...healthyRun(2, goalId: 'h1'),
          AuditLog(
            goalId: 'deleted-habit',
            date: DateTime(2026, 1, 5),
            status: 'done',
            storedStreak: 99,
          ),
        ],
      );

      expect(report.orphanLogs, 1);
      expect(report.logsAudited, 2);
      expect(report.isClean, isTrue,
          reason: 'an unscoreable orphan must not be reported as corruption');
    });

    test('carries the caller\'s unparseable-date count into the report', () {
      final report =
          auditStreaks(habits: [habit()], logs: healthyRun(1), undatedLogs: 7);
      expect(report.undatedLogs, 7);
    });

    test('mismatches are grouped per habit and sorted deterministically', () {
      final logs = <AuditLog>[
        ...healthyRun(3, goalId: 'h2'),
        ...healthyRun(3, goalId: 'h1'),
      ];
      // Corrupt the last day of each.
      logs[2] = AuditLog(
          goalId: 'h2', date: logs[2].date, status: 'done', storedStreak: 1);
      logs[5] = AuditLog(
          goalId: 'h1', date: logs[5].date, status: 'done', storedStreak: 1);

      final report = auditStreaks(
        habits: [habit(id: 'h1'), habit(id: 'h2')],
        logs: logs,
      );

      expect(report.mismatchesByGoal, {'h1': 1, 'h2': 1});
      expect(report.mismatches.map((m) => m.goalId).toList(), ['h1', 'h2'],
          reason: 'sorted by goal id so two runs print identically');
    });

    test('is independent of the order logs arrive in', () {
      // The two-loop structure exists so a goal's ENTIRE history is built
      // before ANY of its rows are scored. Folding the build into the scoring
      // loop (a prefix-inclusive history) is indistinguishable from the correct
      // version when rows arrive ascending — which every other test here does,
      // and which real input does NOT: _recomputeCloudStreaks reads
      // `.order('id')` (backup_import_service.dart:380), _recomputeStreaks uses
      // a bare unordered `txn.query` (import_merge.dart:1167), and the CLI
      // preserves the JSON array order. Without this test that regression is
      // green in CI and reports every real export as damaged — which is exactly
      // how the repair would come to overwrite correct data.
      final ascending = healthyRun(6);

      expect(auditStreaks(habits: [habit()], logs: ascending).isClean, isTrue);
      expect(
        auditStreaks(habits: [habit()], logs: ascending.reversed.toList())
            .isClean,
        isTrue,
        reason: 'descending input must score identically to ascending',
      );
      // An interleaved order too, so the test does not merely pin "reversed".
      final scrambled = [
        ascending[3],
        ascending[0],
        ascending[5],
        ascending[1],
        ascending[4],
        ascending[2],
      ];
      expect(
        auditStreaks(habits: [habit()], logs: scrambled).isClean,
        isTrue,
        reason: 'arbitrary input order must score identically',
      );
    });

    test('mismatches come back date-ascending even from unordered input', () {
      // Pins the `a.date.compareTo(b.date)` tiebreaker at streak_audit.dart's
      // sort — dropping it leaves the output order at the mercy of input order,
      // so two runs over the same export print differently.
      final rows = healthyRun(5);
      final corrupted = <AuditLog>[
        AuditLog(
            goalId: 'h1',
            date: rows[4].date,
            status: 'done',
            storedStreak: 1),
        AuditLog(
            goalId: 'h1',
            date: rows[1].date,
            status: 'done',
            storedStreak: 99),
        AuditLog(
            goalId: 'h1',
            date: rows[3].date,
            status: 'done',
            storedStreak: 1),
        rows[0],
        rows[2],
      ];

      final report = auditStreaks(habits: [habit()], logs: corrupted);
      final dates = report.mismatches.map((m) => m.date).toList();

      expect(dates, hasLength(3));
      expect(
        dates,
        [DateTime(2026, 1, 6), DateTime(2026, 1, 8), DateTime(2026, 1, 9)],
        reason: 'sorted by date within a goal, regardless of input order',
      );
    });

    test('a row dated before the habit started is not a collapse', () {
      // computeStreak returns 0 for any day before startDate
      // (streak_utils.dart: `if (day.isBefore(start)) return 0;`), so such a
      // row reads as stored 1 / computed 0. That satisfies `stored.abs() == 1`
      // but is NOT the corruption signature — it is a row that predates its
      // habit. Without the `computed.abs() > 1` clause it would inflate the
      // headline "collapsed" count that argues how much damage the bug did.
      final report = auditStreaks(
        habits: [habit()],
        logs: [
          AuditLog(
            goalId: 'h1',
            date: DateTime(2026, 1, 1), // before start (2026-01-05)
            status: 'done',
            storedStreak: 1,
          ),
          ...healthyRun(3),
        ],
      );

      expect(report.mismatchCount, 1);
      expect(report.mismatches.single.stored, 1);
      expect(report.mismatches.single.computed, 0);
      expect(report.mismatches.single.looksCollapsed, isFalse);
      expect(report.collapsed, isEmpty);
    });

    test('an empty input is clean rather than an error', () {
      final report = auditStreaks(habits: const [], logs: const []);
      expect(report.isClean, isTrue);
      expect(report.logsAudited, 0);
      expect(report.habitsAudited, 0);
    });
  });

  group('formatStreakAuditReport', () {
    test('says so plainly when there is no damage', () {
      final out = formatStreakAuditReport(
          auditStreaks(habits: [habit()], logs: healthyRun(3)));
      expect(out, contains('No corruption found'));
      expect(out, contains('MISMATCHED       : 0'));
    });

    test('names habits by title when titles are supplied', () {
      final logs = healthyRun(4);
      logs[3] = AuditLog(
          goalId: 'h1', date: logs[3].date, status: 'done', storedStreak: 1);
      final out = formatStreakAuditReport(
        auditStreaks(habits: [habit()], logs: logs),
        titlesByGoalId: const {'h1': 'Morning run'},
      );
      expect(out, contains('Morning run'));
      expect(out, contains('stored 1 -> should be 4'));
      expect(out, contains('the corruption signature'));
    });

    test('shows NON-collapsed mismatches too, not just the signature', () {
      // A budget large enough for every row must print every row. Choosing
      // `collapsed` as the whole sample list would drop the other rows the
      // moment one ±1 row existed — and every one of them is a row the repair
      // would overwrite, so hiding them from the operator authorising it is the
      // worst kind of wrong output.
      final logs = healthyRun(10);
      logs[4] = AuditLog(
          goalId: 'h1', date: logs[4].date, status: 'done', storedStreak: 3);
      logs[9] = AuditLog(
          goalId: 'h1', date: logs[9].date, status: 'done', storedStreak: 1);

      final report = auditStreaks(habits: [habit()], logs: logs);
      expect(report.mismatchCount, 2);
      expect(report.collapsed, hasLength(1));

      final out = formatStreakAuditReport(report, sampleRows: 10);

      expect(out, contains('stored 1 -> should be 10'),
          reason: 'the collapsed row');
      expect(out, contains('stored 3 -> should be 5'),
          reason: 'the ordinary mismatch must appear as well');
      expect(out, isNot(contains('more')),
          reason: 'nothing was withheld, so no truncation notice');
      expect(out, contains('[collapsed]'),
          reason: 'the signature rows stay distinguishable when mixed');
    });

    test('truncation counts every withheld row, collapsed or not', () {
      final logs = healthyRun(10);
      for (var i = 1; i < 10; i++) {
        logs[i] = AuditLog(
            goalId: 'h1',
            date: logs[i].date,
            status: 'done',
            storedStreak: i.isEven ? 1 : 99);
      }
      final report = auditStreaks(habits: [habit()], logs: logs);
      expect(report.mismatchCount, 9);

      final out = formatStreakAuditReport(report, sampleRows: 4);
      expect(out, contains('… and 5 more'),
          reason: '9 mismatches, 4 shown — the notice must count all 9, '
              'not just the collapsed subset');
    });

    test('truncates the sample and says how many were withheld', () {
      // 12 corrupted rows, default sample of 10.
      final logs = [
        for (var i = 0; i < 12; i++)
          AuditLog(
            goalId: 'h1',
            date: DateTime(2026, 1, 5 + i),
            status: 'done',
            storedStreak: 1,
          ),
      ];
      final out = formatStreakAuditReport(
          auditStreaks(habits: [habit()], logs: logs));
      expect(out, contains('and 1 more'));
    });
  });
}
