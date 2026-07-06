/// Result counts for a data-import merge, per entity type.
///
/// Ported from the mobile client (`mobile/lib/core/import_merge_stats.dart`)
/// so both clients report an import the same way. A *true merge* reconciles
/// imported records against what's already on the device by identity (see
/// [DesktopPrivateDb.applyImport]): each incoming record is either
///   - **added**     — no matching record existed, so it was inserted;
///   - **updated**   — a matching record existed and the incoming one superseded
///                     it under last-write-wins (it was strictly newer); or
///   - **unchanged** — a matching record existed and won (it was newer, equal,
///                     or the incoming timestamp was missing/older).
///
/// Replace-mode imports wipe first, so everything is reported under [added].
library;

/// Mutable per-entity accumulator. Kept mutable so the merge loop can `++` in
/// place; callers read the totals once the merge has finished.
class EntityMerge {
  int added;
  int updated;
  int unchanged;

  /// Rows the file contained but that were dropped before the merge because
  /// they were invalid (missing a required field, out-of-vocabulary status,
  /// out-of-range score, …). Populated by validation, not by the merge loop.
  int skipped;

  EntityMerge({
    this.added = 0,
    this.updated = 0,
    this.unchanged = 0,
    this.skipped = 0,
  });

  /// Every valid record the file contributed for this entity (excludes skipped).
  int get total => added + updated + unchanged;

  /// Records actually written this import (inserted + superseded). Excludes
  /// records that were already present and won under last-write-wins.
  int get written => added + updated;
}

/// The outcome of an import, broken down by entity type.
class ImportMergeStats {
  /// True when the import wiped existing data first (replace mode); in that case
  /// every counted record is an [EntityMerge.added].
  final bool replaced;
  final EntityMerge habits;
  final EntityMerge logs;
  final EntityMerge macroGoals;
  final EntityMerge categories;
  final EntityMerge moods;

  ImportMergeStats({required this.replaced})
    : habits = EntityMerge(),
      logs = EntityMerge(),
      macroGoals = EntityMerge(),
      categories = EntityMerge(),
      moods = EntityMerge();

  /// Total invalid rows dropped across all entities.
  int get totalSkipped =>
      habits.skipped +
      logs.skipped +
      macroGoals.skipped +
      categories.skipped +
      moods.skipped;
}

/// Parses an ISO-8601 `updated_at`/`created_at` string, tolerating null and
/// malformed values (returns null rather than throwing).
DateTime? parseImportTimestamp(String? value) =>
    value == null ? null : DateTime.tryParse(value);

/// Last-write-wins comparison between an incoming record and the existing one.
///
/// Returns true only when [incoming] is *strictly* newer than [existing]:
///   - a missing/unparseable [incoming] timestamp is treated as **oldest** and
///     never wins (guards against null-timestamp records clobbering good data);
///   - a missing [existing] timestamp lets any real [incoming] win;
///   - ties keep the existing record (returns false).
bool incomingWins({required String? incoming, required String? existing}) {
  final inc = parseImportTimestamp(incoming);
  if (inc == null) return false;
  final ex = parseImportTimestamp(existing);
  if (ex == null) return true;
  return inc.isAfter(ex);
}
