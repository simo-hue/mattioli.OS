/// A read-only snapshot of what sync has and has not managed to move.
///
/// Exists because the sync layer historically reported success unconditionally:
/// `last_full_sync_at` was stamped even when every record in a push failed, and
/// `sync_state.last_error` was written by the engine and read by NOTHING. A user
/// whose data stopped halfway had no way to see it — the UI said "Up to date"
/// over thousands of stranded rows.
///
/// The single most diagnostic field is [localRowsByTable]: running this on two
/// devices and diffing the per-table counts localises a stall immediately
/// (5000 `long_term_goals` on the phone, 0 on the Mac ⇒ the push never got that
/// far), which no amount of aggregate "last synced" reporting can express.
///
/// Pure data, computed on demand — nothing here is persisted or cached, so it
/// can never itself drift out of sync with the bookkeeping it describes.
class SyncDiagnostics {
  /// Rows physically present locally, per synced table. The ground truth both
  /// devices are compared on.
  final Map<String, int> localRowsByTable;

  /// Records awaiting upload (`dirty = 1, deleted = 0`), per table. A table
  /// stuck at a large non-decreasing number across several syncs is the signal
  /// that the push is dying before it reaches that table.
  final Map<String, int> pendingByTable;

  /// Pending DELETIONS (`dirty = 1, deleted = 1`), per table. Separated from
  /// [pendingByTable] because a pile-up of tombstones means something very
  /// different from a pile-up of upserts.
  final Map<String, int> pendingDeletesByTable;

  /// Distinct `sync_state.last_error` values → count, for records that are
  /// STILL dirty and will therefore be retried on the next sync. Grouped rather
  /// than listed: one rate-limit response can stamp hundreds of records with an
  /// identical reason, and the COUNT is the interesting part.
  ///
  /// These strings are schema- and CloudKit-derived, never row values — see
  /// [UnstorableRowException.reason] and the engine's error paths — so they are
  /// safe to render and to copy out of the app.
  final Map<String, int> errorsByReason;

  /// Distinct error reasons → count, for records carrying an error that are NOT
  /// dirty: nothing will retry them on its own. Chiefly records parked by
  /// [SyncLocalStore.quarantineRecord] because this build's schema cannot store
  /// them.
  ///
  /// Split from [errorsByReason] on `dirty` rather than on the quarantine
  /// timestamp deliberately: `quarantineRecord`'s `ON CONFLICT` branch updates
  /// only `last_error`, so a record that already had a `sync_state` row keeps
  /// its original stamp and a stamp-based test would misclassify it. `dirty` is
  /// the field that actually decides whether anything happens next, which is
  /// also the thing a user needs to know.
  final Map<String, int> parkedByReason;

  /// Whether a zone change token exists. Absent ⇒ the next pull is a FULL
  /// re-fetch of the zone, which is itself worth knowing when diagnosing.
  final bool hasChangeToken;

  final DateTime? lastFullSyncAt;

  const SyncDiagnostics({
    required this.localRowsByTable,
    required this.pendingByTable,
    required this.pendingDeletesByTable,
    required this.errorsByReason,
    required this.parkedByReason,
    required this.hasChangeToken,
    this.lastFullSyncAt,
  });

  int get totalLocalRows =>
      localRowsByTable.values.fold(0, (a, b) => a + b);

  int get totalPending =>
      pendingByTable.values.fold(0, (a, b) => a + b) +
      pendingDeletesByTable.values.fold(0, (a, b) => a + b);

  int get totalErrors => errorsByReason.values.fold(0, (a, b) => a + b);

  int get totalParked => parkedByReason.values.fold(0, (a, b) => a + b);

  /// True when everything local has been acknowledged by CloudKit and nothing
  /// is parked. The ONLY condition under which a UI may claim "up to date".
  bool get isFullySynced =>
      totalPending == 0 && totalErrors == 0 && totalParked == 0;

  /// A single-line, copy-pasteable summary. Deliberately plain text: the point
  /// is that a user can read it out or paste it into a bug report, from a
  /// device that cannot be attached to a debugger.
  String toReport() {
    final b = StringBuffer()
      ..writeln('Evolve sync diagnostics')
      ..writeln('last full sync: ${lastFullSyncAt?.toIso8601String() ?? 'never'}')
      ..writeln('change token: ${hasChangeToken ? 'present' : 'none'}')
      ..writeln('')
      ..writeln('table                  local   pending   deletes');
    final tables = <String>{
      ...localRowsByTable.keys,
      ...pendingByTable.keys,
      ...pendingDeletesByTable.keys,
    }.toList()
      ..sort();
    for (final t in tables) {
      b.writeln(
        '${t.padRight(22)} '
        '${(localRowsByTable[t] ?? 0).toString().padLeft(5)}   '
        '${(pendingByTable[t] ?? 0).toString().padLeft(7)}   '
        '${(pendingDeletesByTable[t] ?? 0).toString().padLeft(7)}',
      );
    }
    if (errorsByReason.isNotEmpty) {
      b..writeln('')..writeln('errors (will retry):');
      for (final e in errorsByReason.entries) {
        b.writeln('  ${e.value}x  ${e.key}');
      }
    }
    if (parkedByReason.isNotEmpty) {
      b..writeln('')..writeln('parked (will NOT retry):');
      for (final e in parkedByReason.entries) {
        b.writeln('  ${e.value}x  ${e.key}');
      }
    }
    return b.toString();
  }
}
