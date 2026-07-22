import '../cloudkit_bridge.dart';

/// In-memory stand-in for the native CloudKit bridge. Faithful enough to test
/// the engine: a single zone keyed by recordName, a monotonic change counter
/// for delta-fetch tokens, and last-write-wins-on-save by updatedAtMs (the
/// server rejects an older write as a conflict, mirroring serverRecordChanged).
///
/// Two [SyncEngine]s can share ONE instance to simulate two devices syncing
/// through the same iCloud.
class FakeCloudKitBridge implements CloudKitBridge {
  FakeCloudKitBridge({this.pageSize = 1000});

  /// Override to simulate iCloud being unavailable.
  CloudAccountStatus status = CloudAccountStatus.available;

  /// Small values let tests exercise the paginated fetch loop.
  int pageSize;

  final Map<String, CloudRecord> _zone = {};
  final Map<String, int> _seq = {};
  int _counter = 0;

  int ensureZoneCalls = 0;
  int saveCalls = 0;
  bool zoneDeleted = false;

  /// Set false to model a native build that predates [tryClaimFirstMint], so a
  /// test can exercise the fail-open path (the method returns null and the
  /// engine mints exactly as it did before the claim existed).
  bool supportsFirstMintClaim = true;

  int tryClaimFirstMintCalls = 0;

  /// The owner id that won the singleton first-mint sentinel, or null when no
  /// device has claimed it yet. Modelled as native state (NOT in [_zone]) so it
  /// is naturally excluded from [zoneHasRecords] — a device that only wrote the
  /// claim and then crashed before minting must still be able to re-mint.
  String? keyMintClaimOwner;

  /// Record names the fake server rejects with a per-record error instead of
  /// saving, so a test can exercise a push that partially or wholly FAILS.
  ///
  /// This is the shape of a real CloudKit `.partialFailure`: the operation
  /// itself succeeds, the per-record blocks report which records did not land,
  /// and the engine has to notice. Without it, no test could reach the branch
  /// where a push leaves rows stranded — which is precisely how
  /// `last_full_sync_at` came to be stamped unconditionally.
  final Set<String> failSaveFor = {};

  /// The `code` reported for a record named in [failSaveFor]. Mirrors the
  /// native bridge, which stringifies `CKError.Code.rawValue` — 27 is
  /// `.requestRateLimited`, the realistic cause of a large first push failing.
  String failSaveCode = '27';

  Map<String, CloudRecord> get records => Map.unmodifiable(_zone);

  @override
  Future<CloudAccountStatus> accountStatus() async => status;

  @override
  Future<void> ensureZone() async {
    ensureZoneCalls++;
    zoneDeleted = false;
  }

  @override
  Future<SaveOutcome> saveRecords(List<CloudRecord> records) async {
    saveCalls++;
    final saved = <String>[];
    final conflicts = <CloudConflict>[];
    final errors = <CloudRecordError>[];
    for (final r in records) {
      if (failSaveFor.contains(r.recordName)) {
        errors.add(CloudRecordError(r.recordName, failSaveCode));
        continue;
      }
      final existing = _zone[r.recordName];
      if (existing != null && existing.updatedAtMs > r.updatedAtMs) {
        // Server has a strictly-newer version → conflict, don't overwrite.
        conflicts.add(CloudConflict(r.recordName, existing.updatedAtMs));
        continue;
      }
      _zone[r.recordName] = r;
      _seq[r.recordName] = ++_counter;
      saved.add(r.recordName);
    }
    return SaveOutcome(saved: saved, conflicts: conflicts, errors: errors);
  }

  @override
  Future<FetchOutcome> fetchChanges(String? token) async {
    final since = int.tryParse(token ?? '') ?? 0;
    final changed = _seq.entries.where((e) => e.value > since).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final page = changed.take(pageSize).toList();
    final more = changed.length > pageSize;
    final newSeq = page.isEmpty ? since : page.last.value;
    return FetchOutcome(
      records: [for (final e in page) _zone[e.key]!],
      newToken: newSeq.toString(),
      moreComing: more,
    );
  }

  @override
  Future<void> deleteRecords(List<String> recordNames) async {
    for (final rn in recordNames) {
      _zone.remove(rn);
      _seq.remove(rn);
    }
  }

  @override
  Future<void> deleteZone() async {
    _zone.clear();
    _seq.clear();
    // The first-mint sentinel lives IN the zone, so wiping the zone retires the
    // claim too — a reset-from-this-device re-claims cleanly.
    keyMintClaimOwner = null;
    zoneDeleted = true;
  }

  /// Server-side atomic create-if-absent of the singleton first-mint sentinel,
  /// keyed on [ownerId]. Mirrors the native `.ifServerRecordUnchanged` save: the
  /// first caller wins, a caller with the SAME owner wins again (idempotent), a
  /// caller with a different owner loses. The sentinel is materialised as a real
  /// zone record so it flows through [fetchChanges] exactly like the native one
  /// — the engine's pull must SKIP it — while [zoneHasRecords] excludes it.
  @override
  Future<bool?> tryClaimFirstMint(String ownerId) async {
    tryClaimFirstMintCalls++;
    if (!supportsFirstMintClaim) return null; // models a pre-claim native build
    final current = keyMintClaimOwner;
    if (current != null) return current == ownerId;
    keyMintClaimOwner = ownerId;
    _zone[kKeyOwnerSentinelRecordName] = const CloudRecord(
      recordName: kKeyOwnerSentinelRecordName,
      tableName: kKeyOwnerSentinelRecordName,
      updatedAtMs: 0,
      deleted: false,
    );
    _seq[kKeyOwnerSentinelRecordName] = ++_counter;
    return true;
  }

  int ensureSubscriptionCalls = 0;

  /// Mirrors the native contract: idempotent, and never throws — a device that
  /// cannot subscribe must still converge on its poll.
  @override
  Future<void> ensureSubscription() async => ensureSubscriptionCalls++;

  int zoneHasRecordsCalls = 0;

  /// Mirrors the native contract: a token-free peek that must NOT disturb the
  /// change sequence, so a probe can never cost a device its pending changes.
  @override
  Future<bool> zoneHasRecords() async {
    zoneHasRecordsCalls++;
    // The first-mint sentinel is bookkeeping, not data: it must not read as
    // "the zone already has records", or a device that only claimed (then
    // crashed before minting) could never re-mint. Mirrors the native filter.
    return _zone.keys.any((k) => k != kKeyOwnerSentinelRecordName);
  }
}
