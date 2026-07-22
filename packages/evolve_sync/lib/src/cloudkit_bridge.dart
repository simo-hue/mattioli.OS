import 'dart:typed_data';

/// Account state reported by CloudKit. Sync only proceeds when [available];
/// everything else surfaces as actionable status and never blocks local mode.
enum CloudAccountStatus {
  available,
  noAccount,
  restricted,
  temporarilyUnavailable,
  couldNotDetermine,
}

/// One CloudKit record (the single generic `PrivateRecord` type). The native
/// bridge only ever sees [payload]/[assetPath] as encrypted bytes — never
/// plaintext.
class CloudRecord {
  /// `"<tableName>:<rowUuid>"` or `"avatar:<owner>"`. Deterministic so both
  /// devices converge on the same record for the same logical row.
  final String recordName;
  final String tableName;

  /// Row edit time in epoch milliseconds (the LWW comparator).
  final int updatedAtMs;
  final bool deleted;

  /// AES-GCM ciphertext of the row JSON. Empty for tombstones.
  final Uint8List? payload;

  /// Path to an encrypted CKAsset file (avatar only).
  final String? assetPath;

  const CloudRecord({
    required this.recordName,
    required this.tableName,
    required this.updatedAtMs,
    required this.deleted,
    this.payload,
    this.assetPath,
  });
}

class CloudConflict {
  final String recordName;
  final int serverUpdatedAtMs;
  const CloudConflict(this.recordName, this.serverUpdatedAtMs);
}

class CloudRecordError {
  final String recordName;
  final String code;
  const CloudRecordError(this.recordName, this.code);
}

class SaveOutcome {
  final List<String> saved;

  /// Records the server has a NEWER version of (server-record-changed). The
  /// engine resolves these by pulling + last-write-wins.
  final List<CloudConflict> conflicts;
  final List<CloudRecordError> errors;

  const SaveOutcome({
    this.saved = const [],
    this.conflicts = const [],
    this.errors = const [],
  });
}

class FetchOutcome {
  final List<CloudRecord> records;

  /// Opaque base64 `CKServerChangeToken` to persist and pass next time.
  final String? newToken;
  final bool moreComing;

  const FetchOutcome({
    this.records = const [],
    this.newToken,
    this.moreComing = false,
  });
}

/// Reserved record name for the empty-zone first-mint arbitration sentinel
/// written by [CloudKitBridge.tryClaimFirstMint]. It is bookkeeping, never a
/// data row: excluded from [CloudKitBridge.zoneHasRecords] and skipped by the
/// pull so it is neither applied nor quarantined. The native bridge writes a
/// record with this exact name, so the constant is duplicated verbatim in both
/// `AppDelegate.swift` files — keep them in sync.
const String kKeyOwnerSentinelRecordName = '__evolve_key_owner__';

/// Thin abstraction over the native CloudKit operations (private database,
/// custom zone). The real implementation is a MethodChannel to Swift; tests use
/// an in-memory fake. All sync logic lives above this, in the Dart engine, so it
/// is unit-testable without a device.
abstract class CloudKitBridge {
  Future<CloudAccountStatus> accountStatus();
  Future<void> ensureZone();
  Future<SaveOutcome> saveRecords(List<CloudRecord> records);
  Future<FetchOutcome> fetchChanges(String? token);
  Future<void> deleteRecords(List<String> recordNames);
  Future<void> deleteZone();

  /// Whether the zone already holds ANY record — the "am I really the first
  /// device?" question, and the guard that stops a second key being minted.
  ///
  /// [SyncKeyStore.getOrCreateKeyReporting] cannot distinguish "no key exists
  /// anywhere" from "the key exists but iCloud Keychain hasn't delivered it to
  /// this device yet", and mints in both cases. When the zone is already full of
  /// records written under the key that is still in flight, that mint orphans
  /// every one of them PERMANENTLY — no device can ever decrypt them again.
  /// That is not hypothetical: it is what happened in production, and the whole
  /// reason this method exists.
  ///
  /// Must be CHEAP — it runs on the enable path. Implementations fetch a single
  /// batch with no desired keys (record ids only), never the whole zone, and
  /// MUST NOT persist or advance the change token.
  ///
  /// Returns false for a missing zone (genuinely nothing there yet).
  Future<bool> zoneHasRecords();

  /// Atomically claim the right to MINT the first E2E key for a genuinely-empty
  /// zone, closing the race [zoneHasRecords] cannot: a READ can never be atomic
  /// with the mint that follows it, so two devices enabling on an empty zone in
  /// the same window both pass that guard and both mint — permanently splitting
  /// the key. This closes the window with server-side arbitration: it creates a
  /// singleton sentinel record ([kKeyOwnerSentinelRecordName]) keyed on
  /// [ownerId] via an `.ifServerRecordUnchanged` (create-if-absent) save, which
  /// only ONE racing device can win.
  ///
  /// Returns:
  ///  * `true`  — this device created the sentinel (or already owns it: the
  ///    call is idempotent for the same [ownerId], so a crash between the claim
  ///    and the mint re-mints instead of dead-locking) ⇒ safe to mint.
  ///  * `false` — another device already claimed ⇒ this device MUST defer and
  ///    adopt that device's key via the iCloud Keychain, never mint a second.
  ///  * `null`  — the answer is unavailable (no native support, or an
  ///    inconclusive error) ⇒ the caller falls back to its prior behaviour.
  ///
  /// The `null` fallback is what makes this **fail-open**: the guard can only
  /// ever ADD a defer on a definitive loss; it never turns a would-be defer into
  /// a mint, and a bridge that predates it (the default below) behaves exactly
  /// as before. The pre-existing [zoneHasRecords] guard still runs first and is
  /// untouched, so the populated-zone case remains protected regardless.
  Future<bool?> tryClaimFirstMint(String ownerId) async => null;

  /// Register the CloudKit subscription that makes the server send this device a
  /// silent push whenever the zone changes.
  ///
  /// A pure LATENCY optimisation over the periodic poll, never a replacement for
  /// it. Apple does not guarantee silent-push delivery — the system throttles and
  /// drops them at its own discretion based on battery, usage and thermal state —
  /// so a device that receives nothing must still converge on its timer. Every
  /// caller therefore treats a failure here as a non-event: log and carry on.
  ///
  /// MUST be idempotent. CloudKit subscriptions outlive app reinstalls, so this
  /// runs against a subscription that already exists far more often than not.
  Future<void> ensureSubscription();
}
