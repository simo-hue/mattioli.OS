/// Fractional ordering keys for the habit list.
///
/// WHY THIS EXISTS. Habit order used to be a dense integer sequence
/// (`goals.display_order` = 0..n-1). Reordering rewrote EVERY row, and the sync
/// engine merges last-write-wins PER ROW — but a dense sequence is a property of
/// the whole COLLECTION, not of any one row. So one goal row pulled from another
/// device overwrote that habit's slot in isolation, producing duplicate and
/// missing positions; `ORDER BY display_order` then broke the ties by
/// `created_at` and the list settled into an order nobody chose.
///
/// A fractional key is a property of the ROW: a habit sits between its
/// neighbours, at a value strictly between theirs. That makes per-row LWW
/// CORRECT BY CONSTRUCTION — two devices moving different habits cannot
/// conflict, and two devices moving the same one resolve to a still-valid total
/// order. A drag writes exactly ONE row instead of all of them, which also ends
/// the `updated_at` storm that dirtied every habit on every reorder.
///
/// WHY DOUBLES AND NOT STRINGS. Lexicographic keys (LexoRank and friends) never
/// exhaust, but SQLite compares TEXT with BINARY collation while PostgreSQL uses
/// a locale-aware default — the same keys would order differently on the two
/// backends unless every comparison and index carried `COLLATE "C"`. That is a
/// subtle, permanent, easy-to-lose trap across two schemas. Doubles compare
/// identically everywhere; their only cost is exhaustion, which [needsRenumber]
/// detects and the caller resolves with a full renumber — the operation the old
/// code performed on EVERY drag, so that path is already written and tested.
library;

/// The gap between adjacent keys when a list is numbered from scratch.
///
/// Deliberately large: `log2(kOrderKeyStep / kOrderKeyMinGap)` is ~40, so a user
/// would have to drop into the same shrinking gap 40 consecutive times — with no
/// intervening renumber — before [needsRenumber] trips.
const double kOrderKeyStep = 1024.0;

/// Two keys closer than this are treated as exhausted. Comfortably above the
/// point where `(a + b) / 2` stops producing a value strictly between them for
/// doubles of this magnitude.
const double kOrderKeyMinGap = 1e-9;

/// The key for a habit dropped between [before] and [after].
///
/// Null [before] means "dropped at the top" and null [after] "at the bottom".
/// Both null means the list has exactly one item.
///
/// Throws [ArgumentError] when the neighbours are not strictly increasing —
/// that is a caller bug (an unsorted list, or the two ends swapped), and
/// inventing a key for it would silently scramble the order.
double orderKeyBetween(double? before, double? after) {
  if (before == null && after == null) return kOrderKeyStep;
  if (before == null) return after! - kOrderKeyStep;
  if (after == null) return before + kOrderKeyStep;
  if (!(before < after)) {
    throw ArgumentError(
      'orderKeyBetween needs strictly increasing neighbours, got '
      'before=$before after=$after',
    );
  }
  return before + (after - before) / 2;
}

/// Whether [before] and [after] are too close to fit another key between them,
/// so the caller must renumber the whole list instead of inserting.
///
/// Checked BEFORE [orderKeyBetween], because the midpoint of two adjacent
/// doubles is one of them — which would give two habits the same key and
/// reintroduce exactly the tie-broken-by-created_at behaviour fractional keys
/// exist to remove.
bool needsRenumber(double? before, double? after) {
  if (before == null || after == null) return false;
  return (after - before) < kOrderKeyMinGap;
}

/// Evenly spaced keys for [count] items, for a fresh list or a renumber.
///
/// Starts at [kOrderKeyStep] rather than 0 so there is always room to drop
/// something above the first item without going negative — negative keys are
/// legal but make the values harder to read in a debugger.
List<double> renumberedOrderKeys(int count) =>
    [for (var i = 0; i < count; i++) kOrderKeyStep * (i + 1)];

/// The key each item should hold after [moved] is taken out of [current] and
/// re-inserted at [toIndex].
///
/// Returns a map of index-in-[current] → new key, containing exactly ONE entry
/// in the common case — the moved habit. When the gap it lands in is exhausted
/// the whole list is renumbered and every index is returned instead.
///
/// [current] must already be in display order. [fromIndex] and [toIndex] are
/// positions in that list, with [toIndex] the FINAL resting position (the
/// convention `onReorderItem` uses — already adjusted for the removal).
Map<int, double> orderKeyMoveResult({
  required List<double?> current,
  required int fromIndex,
  required int toIndex,
}) {
  if (fromIndex < 0 ||
      fromIndex >= current.length ||
      toIndex < 0 ||
      toIndex >= current.length) {
    throw ArgumentError(
      'index out of range: from=$fromIndex to=$toIndex len=${current.length}',
    );
  }
  if (fromIndex == toIndex) return const {};

  // A list still carrying nulls (pre-migration rows, or a peer that has not
  // upgraded) has no usable geometry — renumber rather than guess.
  if (current.contains(null)) {
    return _renumberAfterMove(current.length, fromIndex, toIndex);
  }

  final keys = [for (final k in current) k!];
  // The order AFTER the move, so the moved item's neighbours are the ones it
  // will actually sit between.
  final reordered = [...keys]..removeAt(fromIndex);
  final before = toIndex == 0 ? null : reordered[toIndex - 1];
  final after = toIndex >= reordered.length ? null : reordered[toIndex];

  if (needsRenumber(before, after)) {
    return _renumberAfterMove(current.length, fromIndex, toIndex);
  }

  return {fromIndex: orderKeyBetween(before, after)};
}

/// Fresh evenly-spaced keys for every item, assigned by each item's position in
/// the list AFTER the move.
///
/// Keying by the item's ORIGINAL index (its position in `current`) would be the
/// easy mistake: it renumbers the list into the order it already had and
/// silently discards the move.
Map<int, double> _renumberAfterMove(int count, int fromIndex, int toIndex) {
  final originalIndexAtPosition = [for (var i = 0; i < count; i++) i];
  final moved = originalIndexAtPosition.removeAt(fromIndex);
  originalIndexAtPosition.insert(toIndex, moved);
  final fresh = renumberedOrderKeys(count);
  return {
    for (var position = 0; position < count; position++)
      originalIndexAtPosition[position]: fresh[position],
  };
}
