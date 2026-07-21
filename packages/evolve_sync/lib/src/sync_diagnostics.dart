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
  ///
  /// Careful: this is an UNSCOPED count. Two devices agreeing here proves they
  /// converged on the same row SET — not that those rows belong to the user's
  /// active identity. Compare with [ownedRowsByTable].
  final Map<String, int> localRowsByTable;

  /// Rows belonging to the ACTIVE owner, per synced table. The app reads data
  /// with `WHERE user_id = <owner>`, so anything counted in [localRowsByTable]
  /// but missing here is present in the database and invisible in the UI.
  ///
  /// Exists because a per-table `COUNT(*)` cannot distinguish a healthy database
  /// from one whose rows are stranded under an abandoned identity — both produce
  /// identical, matching totals on every device. Without this the only way to
  /// tell them apart is decrypting the database by hand.
  ///
  /// Empty when no owner was supplied.
  final Map<String, int> ownedRowsByTable;

  /// Distinct owner identities appearing across the synced tables. More than one
  /// means profile rows have accumulated and some data may be unreachable.
  final int distinctOwnerCount;

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

  /// Distinct reasons → count for records the PULL could not apply, and for
  /// which the change token is consequently HELD.
  ///
  /// Separate from both maps above because the correct advice differs: these
  /// are re-delivered and re-attempted by the very next sync, with no user
  /// action — but until they succeed, the device rewinds its change token every
  /// time and re-downloads the entire delta, so it never converges. That state
  /// used to be completely invisible: `markError`'s bare UPDATE matched no row
  /// for a record this device had never seen, so the error was discarded and
  /// this snapshot reported a perfectly healthy database.
  final Map<String, int> heldByReason;

  /// Whether a zone change token exists. Absent ⇒ the next pull is a FULL
  /// re-fetch of the zone, which is itself worth knowing when diagnosing.
  final bool hasChangeToken;

  final DateTime? lastFullSyncAt;

  const SyncDiagnostics({
    required this.localRowsByTable,
    this.ownedRowsByTable = const {},
    this.distinctOwnerCount = 1,
    required this.pendingByTable,
    required this.pendingDeletesByTable,
    required this.errorsByReason,
    required this.parkedByReason,
    this.heldByReason = const {},
    required this.hasChangeToken,
    this.lastFullSyncAt,
  });

  int get totalLocalRows =>
      localRowsByTable.values.fold(0, (a, b) => a + b);

  /// Rows present locally but NOT owned by the active identity — invisible in
  /// the app. Non-zero is always a defect.
  int get orphanedRows {
    if (ownedRowsByTable.isEmpty) return 0;
    var n = 0;
    for (final e in localRowsByTable.entries) {
      n += e.value - (ownedRowsByTable[e.key] ?? 0);
    }
    return n;
  }

  int get totalPending =>
      pendingByTable.values.fold(0, (a, b) => a + b) +
      pendingDeletesByTable.values.fold(0, (a, b) => a + b);

  int get totalErrors => errorsByReason.values.fold(0, (a, b) => a + b);

  int get totalParked => parkedByReason.values.fold(0, (a, b) => a + b);

  int get totalHeld => heldByReason.values.fold(0, (a, b) => a + b);

  /// Every record that is not where it should be, for whatever reason. Callers
  /// wanting "how much is wrong" must use THIS rather than adding the buckets
  /// up themselves — both apps did, and both would have silently under-counted
  /// the moment [heldByReason] was added.
  int get totalStuck => totalErrors + totalParked + totalHeld;

  /// True when everything local has been acknowledged by CloudKit and nothing
  /// is parked or stuck. The ONLY condition under which a UI may claim "up to
  /// date".
  bool get isFullySynced => totalPending == 0 && totalStuck == 0;

  /// A single-line, copy-pasteable summary. Deliberately plain text: the point
  /// is that a user can read it out or paste it into a bug report, from a
  /// device that cannot be attached to a debugger.
  String toReport() {
    final b = StringBuffer()
      ..writeln('Evolve sync diagnostics')
      ..writeln('last full sync: ${lastFullSyncAt?.toIso8601String() ?? 'never'}')
      ..writeln('change token: ${hasChangeToken ? 'present' : 'none'}')
      ..writeln('')
      ..writeln('owners: $distinctOwnerCount'
          '${orphanedRows > 0 ? '  ($orphanedRows HIDDEN rows)' : ''}')
      ..writeln('')
      ..writeln('table                  local    mine   pending   deletes');
    final tables = <String>{
      ...localRowsByTable.keys,
      ...pendingByTable.keys,
      ...pendingDeletesByTable.keys,
    }.toList()
      ..sort();
    for (final t in tables) {
      final local = localRowsByTable[t] ?? 0;
      final mine = ownedRowsByTable[t];
      b.writeln(
        '${t.padRight(22)} '
        '${local.toString().padLeft(5)}   '
        '${(mine?.toString() ?? '-').padLeft(5)}   '
        '${(pendingByTable[t] ?? 0).toString().padLeft(7)}   '
        '${(pendingDeletesByTable[t] ?? 0).toString().padLeft(7)}'
        '${mine != null && mine != local ? '   <-- ${local - mine} HIDDEN' : ''}',
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
    if (heldByReason.isNotEmpty) {
      // Named for what it means operationally: the change token is pinned, so
      // this device re-downloads the whole delta every sync and never
      // converges. That is the actionable fact, not the retry itself.
      b
        ..writeln('')
        ..writeln('could not apply (holding the change token, retried each '
            'sync):');
      for (final e in heldByReason.entries) {
        b.writeln('  ${e.value}x  ${e.key}');
      }
    }
    return b.toString();
  }
}
