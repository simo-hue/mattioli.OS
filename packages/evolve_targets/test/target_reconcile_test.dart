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
