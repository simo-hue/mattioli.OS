/// A lightweight fuzzy subsequence matcher powering the ⌘K command palette.
///
/// The palette scores every candidate (goal title, habit title, section label,
/// action keyword) against the typed query and keeps the ones that match, best
/// first. "Fuzzy" here means the query characters must appear in the target in
/// order but not necessarily contiguously — so `r5k` matches `Run 5k` and
/// `mrun` matches `Morning run`. The score rewards the matches people intuit as
/// "better": a prefix hit, a hit at a word boundary, and runs of consecutive
/// characters all beat a scattered match.
///
/// The algorithm is a single left-to-right greedy pass. For the short strings a
/// palette deals with (goal/habit titles) this is both fast and predictable; we
/// deliberately avoid a full dynamic-programming search so the ranking never
/// surprises the user with a non-obvious "optimal" alignment.
library;

/// The outcome of scoring one candidate against a query.
class FuzzyMatch {
  const FuzzyMatch({required this.score, required this.matchedIndices});

  /// Higher is a better match. Only meaningful relative to other matches for
  /// the same query.
  final int score;

  /// Indices into the *target* string that the query characters landed on, in
  /// order. Lets the UI bold the matched characters if it wants to.
  final List<int> matchedIndices;
}

// Scoring weights. Tuned so that, for a query, a prefix/word-start match always
// outranks a mid-word one, and a contiguous run always outranks a scattered
// one — matching the "feel" of Spotlight / Raycast / Linear.
const int _kBaseCharScore = 4;
const int _kConsecutiveBonus = 12;
const int _kWordStartBonus = 14;
const int _kFirstCharPrefixBonus = 18;
const int _kLeadingGapPenalty = 2; // per char before the first match, capped
const int _kGapPenalty = 1; // per skipped char between matches, capped

bool _isSeparator(String ch) {
  return ch == ' ' ||
      ch == '_' ||
      ch == '-' ||
      ch == '.' ||
      ch == '/' ||
      ch == ':' ||
      ch == ',' ||
      ch == '(' ||
      ch == ')' ||
      ch == '\t';
}

/// Returns a [FuzzyMatch] when every character of [query] appears in [target]
/// in order (case-insensitive), or `null` when it does not match at all.
///
/// An empty [query] is treated as a neutral match (score 0, no highlight) so
/// callers can decide how to present the "nothing typed yet" state themselves.
FuzzyMatch? fuzzyMatch(String query, String target) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return const FuzzyMatch(score: 0, matchedIndices: <int>[]);
  }
  final t = target.toLowerCase();
  if (t.isEmpty) return null;

  final matched = <int>[];
  var score = 0;
  var ti = 0;
  var lastMatch = -1;

  for (var qi = 0; qi < q.length; qi++) {
    final qc = q[qi];
    var found = -1;
    for (var j = ti; j < t.length; j++) {
      if (t[j] == qc) {
        found = j;
        break;
      }
    }
    if (found == -1) return null; // query char absent from the remainder

    var charScore = _kBaseCharScore;
    final atStart = found == 0;
    final afterSeparator = found > 0 && _isSeparator(t[found - 1]);
    final isConsecutive = found == lastMatch + 1;

    if (qi == 0) {
      // Where the very first query char lands dominates the ranking: a true
      // prefix beats a word-start beats a buried match.
      if (atStart) {
        charScore += _kFirstCharPrefixBonus;
      } else if (afterSeparator) {
        charScore += _kWordStartBonus;
      }
      // Penalise (mildly, capped) how far into the string the match begins so
      // "run" prefers "Run 5k" over "Morning run".
      score -= (found).clamp(0, 6) * _kLeadingGapPenalty;
    } else {
      if (isConsecutive) {
        charScore += _kConsecutiveBonus;
      } else if (atStart || afterSeparator) {
        charScore += _kWordStartBonus;
      }
      final gap = found - lastMatch - 1;
      if (gap > 0) score -= gap.clamp(0, 6) * _kGapPenalty;
    }

    score += charScore;
    matched.add(found);
    lastMatch = found;
    ti = found + 1;
  }

  // Small reward for a tight overall match (query covers a large fraction of a
  // short target), so "run" ranks "Run" above "Running errands to the shop".
  final coverage = (q.length * 100) ~/ t.length;
  score += coverage ~/ 25;

  return FuzzyMatch(score: score, matchedIndices: matched);
}

/// Convenience: the best score across several fields of one entity (e.g. a
/// goal's title and its category), or `null` if none match. The returned
/// [FuzzyMatch.matchedIndices] belong to whichever field won, so only use them
/// against that same field.
FuzzyMatch? fuzzyMatchBest(String query, Iterable<String> fields) {
  FuzzyMatch? best;
  for (final field in fields) {
    final m = fuzzyMatch(query, field);
    if (m == null) continue;
    if (best == null || m.score > best.score) best = m;
  }
  return best;
}
