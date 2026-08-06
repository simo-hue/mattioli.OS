// Fractional ordering keys — the arithmetic the habit reorder rests on.
//
// The property that matters: a habit's position is a property of ITS OWN ROW,
// so the sync engine's per-row last-write-wins merge is correct by
// construction. A dense integer sequence is a property of the whole collection,
// which is why one pulled row used to scramble the list.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('orderKeyBetween', () {
    test('an empty list gets the first step', () {
      expect(orderKeyBetween(null, null), kOrderKeyStep);
    });

    test('dropping at the top goes BEFORE the first key', () {
      expect(orderKeyBetween(null, 1024.0), lessThan(1024.0));
    });

    test('dropping at the bottom goes AFTER the last key', () {
      expect(orderKeyBetween(2048.0, null), greaterThan(2048.0));
    });

    test('dropping between two goes strictly between them', () {
      final k = orderKeyBetween(1024.0, 2048.0);
      expect(k, greaterThan(1024.0));
      expect(k, lessThan(2048.0));
      expect(k, 1536.0);
    });

    test('negative neighbours work — the top can grow downwards forever', () {
      // Repeatedly dropping at the top must keep producing smaller keys rather
      // than colliding at zero.
      var top = kOrderKeyStep;
      for (var i = 0; i < 5; i++) {
        final next = orderKeyBetween(null, top);
        expect(next, lessThan(top));
        top = next;
      }
      expect(top, lessThan(0));
    });

    test('REJECTS non-increasing neighbours instead of inventing a key', () {
      // An unsorted list or swapped ends is a caller bug; silently returning
      // something would scramble the order it was asked to preserve.
      expect(() => orderKeyBetween(2048.0, 1024.0), throwsArgumentError);
      expect(() => orderKeyBetween(1024.0, 1024.0), throwsArgumentError);
    });
  });

  group('needsRenumber', () {
    test('is false for ordinary neighbours', () {
      expect(needsRenumber(1024.0, 2048.0), isFalse);
      expect(needsRenumber(null, 1024.0), isFalse);
      expect(needsRenumber(1024.0, null), isFalse);
    });

    test('is true once the gap is exhausted', () {
      expect(needsRenumber(1.0, 1.0 + 1e-12), isTrue);
    });

    test('survives ~40 consecutive halvings into the same gap', () {
      // The exhaustion budget. A user would have to drop into the same
      // shrinking gap this many times in a row to force a renumber.
      var lo = 1024.0;
      const hi = 2048.0;
      var halvings = 0;
      while (!needsRenumber(lo, hi) && halvings < 1000) {
        lo = orderKeyBetween(lo, hi);
        halvings++;
      }
      expect(halvings, greaterThanOrEqualTo(40),
          reason: 'log2(kOrderKeyStep / kOrderKeyMinGap) — a user would have to '
              'drop into the same shrinking gap 40 times in a row');
    });
  });

  group('renumberedOrderKeys', () {
    test('is strictly increasing and starts above zero', () {
      final keys = renumberedOrderKeys(4);
      expect(keys, [1024.0, 2048.0, 3072.0, 4096.0]);
      expect(keys.first, greaterThan(0),
          reason: 'leaves room to drop something above the first item');
    });

    test('an empty list yields no keys', () {
      expect(renumberedOrderKeys(0), isEmpty);
    });
  });

  group('orderKeyMoveResult', () {
    List<double?> keys(int n) => renumberedOrderKeys(n);

    /// Applies the result to [current] and returns the resulting ORDER of the
    /// original indices, sorted by key — i.e. what the user would see.
    List<int> resultingOrder(List<double?> current, Map<int, double> changes) {
      final next = [
        for (var i = 0; i < current.length; i++) changes[i] ?? current[i]!
      ];
      final indices = [for (var i = 0; i < current.length; i++) i];
      indices.sort((a, b) => next[a].compareTo(next[b]));
      return indices;
    }

    test('ONE row changes for an ordinary move', () {
      final changes =
          orderKeyMoveResult(current: keys(5), fromIndex: 0, toIndex: 3);

      expect(changes, hasLength(1),
          reason: 'a drag must dirty ONE habit, not all of them');
      expect(changes.keys.single, 0);
    });

    test('the moved habit lands where the user dropped it', () {
      final current = keys(5);
      final changes =
          orderKeyMoveResult(current: current, fromIndex: 0, toIndex: 3);

      expect(resultingOrder(current, changes), [1, 2, 3, 0, 4]);
    });

    test('moving upward lands correctly too', () {
      final current = keys(5);
      final changes =
          orderKeyMoveResult(current: current, fromIndex: 4, toIndex: 1);

      expect(resultingOrder(current, changes), [0, 4, 1, 2, 3]);
    });

    test('moving to the very top and the very bottom', () {
      final current = keys(4);

      expect(
        resultingOrder(current,
            orderKeyMoveResult(current: current, fromIndex: 2, toIndex: 0)),
        [2, 0, 1, 3],
      );
      expect(
        resultingOrder(current,
            orderKeyMoveResult(current: current, fromIndex: 0, toIndex: 3)),
        [1, 2, 3, 0],
      );
    });

    test('a no-op move writes nothing', () {
      expect(orderKeyMoveResult(current: keys(3), fromIndex: 1, toIndex: 1),
          isEmpty);
    });

    test('an exhausted gap renumbers EVERY row, in the moved order', () {
      // The renumber must apply the move, not merely re-space the list it
      // already had. Keying the fresh keys by each item's ORIGINAL index is the
      // easy mistake, and it silently discards the drag.
      // Indices 1 and 2 are a hair apart; dropping index 0 BETWEEN them is the
      // move with nowhere to land.
      final current = <double?>[1.0, 2.0, 2.0 + 1e-12, 3.0];

      final changes =
          orderKeyMoveResult(current: current, fromIndex: 0, toIndex: 1);

      expect(changes, hasLength(4), reason: 'a renumber touches everything');
      expect(resultingOrder(current, changes), [1, 0, 2, 3]);
    });

    test('a list with NULL keys renumbers rather than guessing', () {
      // Pre-migration rows, or a peer that has not upgraded yet.
      final current = <double?>[1024.0, null, 3072.0];

      final changes =
          orderKeyMoveResult(current: current, fromIndex: 2, toIndex: 0);

      expect(changes, hasLength(3));
      expect(resultingOrder(current, changes), [2, 0, 1]);
    });

    test('rejects out-of-range indices', () {
      expect(() => orderKeyMoveResult(current: keys(3), fromIndex: 5, toIndex: 0),
          throwsArgumentError);
      expect(() => orderKeyMoveResult(current: keys(3), fromIndex: 0, toIndex: 9),
          throwsArgumentError);
    });

    test('every move leaves a STRICTLY increasing key set', () {
      // The invariant that makes per-row LWW safe: no duplicates, so no
      // tie-break by created_at can ever reorder the list behind the user.
      for (var from = 0; from < 5; from++) {
        for (var to = 0; to < 5; to++) {
          final current = keys(5);
          final changes =
              orderKeyMoveResult(current: current, fromIndex: from, toIndex: to);
          final next = [
            for (var i = 0; i < current.length; i++)
              changes[i] ?? current[i]!
          ]..sort();
          for (var i = 1; i < next.length; i++) {
            expect(next[i], greaterThan(next[i - 1]),
                reason: 'from=$from to=$to produced a duplicate key');
          }
        }
      }
    });
  });
}
