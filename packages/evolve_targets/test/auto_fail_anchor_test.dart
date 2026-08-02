import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 8, 2, 14, 30); // deliberately not midnight

  group('resolveAutoFailAnchor', () {
    test('an absent value anchors on today — nothing before the rule is scored',
        () {
      expect(resolveAutoFailAnchor(null, today), DateTime(2026, 8, 2));
    });

    test('an empty value is treated as absent', () {
      expect(resolveAutoFailAnchor('', today), DateTime(2026, 8, 2));
    });

    test('a stored anchor is honoured', () {
      expect(resolveAutoFailAnchor('2026-07-15', today), DateTime(2026, 7, 15));
    });

    test('a stored anchor is normalised to midnight', () {
      final anchor = resolveAutoFailAnchor('2026-07-15T23:59:59', today);
      expect(anchor, DateTime(2026, 7, 15));
    });

    test('a corrupt value falls back to today, never to the distant past', () {
      // Failing toward today is the safe direction: an anchor that landed in the
      // past would retroactively redden history the user has already seen.
      expect(resolveAutoFailAnchor('not-a-date', today), DateTime(2026, 8, 2));
    });

    test('round-trips through encodeAutoFailAnchor', () {
      final anchor = resolveAutoFailAnchor(null, today);
      expect(encodeAutoFailAnchor(anchor), '2026-08-02');
      expect(resolveAutoFailAnchor(encodeAutoFailAnchor(anchor), today), anchor);
    });

    test('encodes in the same canonical format as every other day key', () {
      expect(encodeAutoFailAnchor(DateTime(2026, 1, 5)),
          targetDateKey(DateTime(2026, 1, 5)));
    });

    test('a FUTURE anchor is pulled back to today, not obeyed', () {
      // A future anchor is not conservative, it is inert: no closed day is ever
      // at or after it, so auto-fail silently never fires again. Reachable from
      // a clock that ran ahead, or from a value like '2026-13-45' — which is
      // parseable and normalises to 2027-02-14.
      expect(resolveAutoFailAnchor('2027-01-01', today), DateTime(2026, 8, 2));
      expect(resolveAutoFailAnchor('2026-13-45', today), DateTime(2026, 8, 2));
    });

    test('a past anchor is left alone — the backfill window bounds it', () {
      expect(resolveAutoFailAnchor('2020-01-01', today), DateTime(2020, 1, 1));
    });
  });

  group('resolveAndStampAutoFailAnchor', () {
    /// A preference store in a map, recording what was written.
    ({
      Future<DateTime?> Function(String? stored) run,
      List<String> writes,
    }) harness({bool writeSucceeds = true, List<Object>? errors}) {
      final writes = <String>[];
      return (
        writes: writes,
        run: (stored) => resolveAndStampAutoFailAnchor(
              read: () => stored,
              write: (v) async {
                writes.add(v);
                return writeSucceeds;
              },
              today: today,
              onError: (e) => errors?.add(e),
            ),
      );
    }

    test('stamps on the first run', () async {
      final h = harness();
      expect(await h.run(null), DateTime(2026, 8, 2));
      expect(h.writes, ['2026-08-02']);
    });

    test('a healthy stored anchor is not rewritten', () async {
      final h = harness();
      expect(await h.run('2026-07-15'), DateTime(2026, 7, 15));
      expect(h.writes, isEmpty, reason: 'a pointless write every sweep');
    });

    test('a CORRUPT anchor is repaired, not merely tolerated', () async {
      // Left un-repaired it re-resolves to today on every pass, so no closed day
      // is ever at or after it and auto-fail never fires again — silently.
      final h = harness();
      expect(await h.run('not-a-date'), DateTime(2026, 8, 2));
      expect(h.writes, ['2026-08-02']);
    });

    test('a future anchor is NOT written back — no backward ratchet', () async {
      // The bug this pins: persisting the clamp meant a clock that moved
      // backwards (travel, a manual date change, an RTC reset) made a healthy
      // anchor look "future", clamped it to the earlier today, and SAVED that —
      // permanently lowering the anchor and reaching back over history.
      final errors = <Object>[];
      final h = harness(errors: errors);
      expect(await h.run('2027-01-01'), DateTime(2026, 8, 2),
          reason: 'it still resolves to today, so nothing odd is scored');
      expect(h.writes, isEmpty);
      expect(errors, hasLength(1),
          reason: 'an inert anchor must be diagnosable, not silent');
    });

    test('a clock that moves backwards cannot lower a stored anchor', () async {
      // Stamp on 2026-08-02, then the clock reads 2026-07-20.
      final writes = <String>[];
      Future<DateTime?> run(String? stored, DateTime today) =>
          resolveAndStampAutoFailAnchor(
            read: () => stored,
            write: (v) async {
              writes.add(v);
              return true;
            },
            today: today,
          );

      expect(await run(null, DateTime(2026, 8, 2)), DateTime(2026, 8, 2));
      expect(writes, ['2026-08-02']);
      writes.clear();

      await run('2026-08-02', DateTime(2026, 7, 20)); // clock went back
      expect(writes, isEmpty, reason: 'the anchor must never move earlier');

      // Clock corrected: the original anchor is intact.
      expect(await run('2026-08-02', DateTime(2026, 8, 3)),
          DateTime(2026, 8, 2));
    });

    test('a valid non-canonical value is left alone rather than churned',
        () async {
      final h = harness();
      expect(await h.run('2026-07-15T09:30:00'), DateTime(2026, 7, 15));
      expect(h.writes, isEmpty,
          reason: 'it parses to the right day; rewriting it buys nothing');
    });

    test('a write that reports failure is surfaced, and the anchor still holds',
        () async {
      final errors = <Object>[];
      final h = harness(writeSucceeds: false, errors: errors);
      // Still today, so nothing earlier is in reach — safe, and retried next pass.
      expect(await h.run(null), DateTime(2026, 8, 2));
      expect(errors, hasLength(1));
    });

    test('a throwing read turns auto-fail OFF rather than on', () async {
      final errors = <Object>[];
      final anchor = await resolveAndStampAutoFailAnchor(
        read: () => throw StateError('prefs unavailable'),
        write: (_) async => true,
        today: today,
        onError: errors.add,
      );
      expect(anchor, isNull,
          reason: 'a failed read must narrow what gets written, never widen it');
      expect(errors, hasLength(1));
    });
  });
}
