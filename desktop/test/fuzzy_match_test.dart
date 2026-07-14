// Coverage for the ⌘K command palette's fuzzy matcher: subsequence matching,
// no-match rejection, and the ranking bonuses (prefix / word-start / run) that
// give the palette its "smart" feel.
import 'package:evolve_desktop/features/search/application/fuzzy_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fuzzyMatch', () {
    test('empty query is a neutral match', () {
      final m = fuzzyMatch('', 'anything');
      expect(m, isNotNull);
      expect(m!.score, 0);
      expect(m.matchedIndices, isEmpty);
    });

    test('matches a contiguous prefix', () {
      final m = fuzzyMatch('run', 'Run 5k');
      expect(m, isNotNull);
      expect(m!.matchedIndices, [0, 1, 2]);
    });

    test('matches a non-contiguous subsequence', () {
      expect(fuzzyMatch('r5k', 'Run 5k'), isNotNull);
      expect(fuzzyMatch('mrun', 'Morning run'), isNotNull);
    });

    test('is case-insensitive', () {
      expect(fuzzyMatch('RUN', 'run 5k'), isNotNull);
      expect(fuzzyMatch('run', 'RUN 5K'), isNotNull);
    });

    test('rejects when a character is missing or out of order', () {
      expect(fuzzyMatch('xyz', 'Run 5k'), isNull);
      expect(fuzzyMatch('k5', 'Run 5k'), isNull); // order matters
    });

    test('rejects against an empty target', () {
      expect(fuzzyMatch('a', ''), isNull);
    });

    test('a prefix match outranks a mid-word match', () {
      final prefix = fuzzyMatch('run', 'Run 5k')!;
      final buried = fuzzyMatch('run', 'Morning run')!;
      expect(prefix.score, greaterThan(buried.score));
    });

    test('a contiguous match at a word boundary scores strongly', () {
      // "meal" lands contiguously on the second word of "Plan meal" (word-start
      // + a run of consecutive chars) and should beat the scattered match in
      // "Home almanac".
      final wordBoundary = fuzzyMatch('meal', 'Plan meal')!;
      final scattered = fuzzyMatch('meal', 'Home almanac')!;
      expect(wordBoundary.score, greaterThan(scattered.score));
    });

    test('a contiguous run outranks a gapped match of the same query', () {
      final contiguous = fuzzyMatch('read', 'Read a book')!;
      final gapped = fuzzyMatch('read', 'Re-evaluate my ads')!;
      expect(contiguous.score, greaterThan(gapped.score));
    });
  });

  group('fuzzyMatchBest', () {
    test('returns the best-scoring field', () {
      final m = fuzzyMatchBest('health', ['Run 5k', 'Health']);
      expect(m, isNotNull);
      // The exact-ish "Health" field should win over the non-matching title.
      expect(m!.matchedIndices.first, 0);
    });

    test('returns null when no field matches', () {
      expect(fuzzyMatchBest('zzz', ['Run 5k', 'Health']), isNull);
    });
  });
}
