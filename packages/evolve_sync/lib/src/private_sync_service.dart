import 'cloudkit_bridge.dart';
import 'sync_diagnostics.dart';

class PrivateSyncStatus {
  final bool isAvailable;
  final bool isEnabled;
  final DateTime? lastSyncedAt;

  /// Raw account status for richer UI messaging (null for the no-op service).
  final CloudAccountStatus? account;
  final String? message;

  /// Whether the E2E sync key is readable from the (shared) iCloud Keychain.
  /// False on a device that enabled sync but is still waiting for iCloud
  /// Keychain to deliver the key — e.g. a Mac paired with an iPhone whose app
  /// predates the shared keychain group. Lets the UI show a "waiting for
  /// iCloud Keychain" state instead of a misleading "up to date".
  final bool hasKey;

  /// How many remote records the just-finished sync applied locally. Lets a
  /// caller know whether to refresh the in-memory data providers (>0). 0 for
  /// status() / no-op.
  final int appliedChanges;

  /// The last enable was DEFERRED because the zone already holds records but
  /// this device has no E2E key yet. Not a failure — the device is waiting for
  /// the iCloud Keychain, and minting a key here would destroy the zone.
  final bool keyPending;

  /// Records in the zone this device could not decrypt: they were sealed with a
  /// different sync key. Non-zero means the devices are on divergent keys and
  /// this one cannot read the shared data — the single condition that must
  /// never be reported as "Up to date", because no amount of syncing fixes it.
  final int undecryptableCount;

  /// The last [PrivateSyncService.enable] was DEFERRED because the shared E2E
  /// key has arrived but the canonical owner id has not yet propagated through
  /// the iCloud Keychain. Nothing was touched; a later enable completes it.
  ///
  /// Explicit because the recovery flow used to infer it from
  /// `lastSyncedAt == null`, and that proxy is not sound: an enable that RAN but
  /// did not fully complete (a rate-limited push, a held change token) also
  /// leaves the timestamp unset, and would then be misread as a deferral. The
  /// two need opposite handling — wait-and-retry versus let-the-user-choose —
  /// so the engine's own answer travels here rather than being guessed at.
  final bool ownerPending;

  const PrivateSyncStatus({
    required this.isAvailable,
    required this.isEnabled,
    this.lastSyncedAt,
    this.account,
    this.message,
    this.hasKey = true,
    this.appliedChanges = 0,
    this.keyPending = false,
    this.undecryptableCount = 0,
    this.ownerPending = false,
  });

  const PrivateSyncStatus.localOnly()
      : isAvailable = false,
        isEnabled = false,
        lastSyncedAt = null,
        account = null,
        message = 'iCloud sync is not available on this platform.',
        hasKey = false,
        appliedChanges = 0,
        keyPending = false,
        undecryptableCount = 0,
        ownerPending = false;
}

abstract class PrivateSyncService {
  Future<PrivateSyncStatus> status();

  /// Store-FREE variant of [status]: reads only the per-device enabled flag, the
  /// iCloud account status and whether the E2E key is in the iCloud Keychain — it
  /// NEVER opens the local encrypted DB. Safe to call when that DB is LOCKED (its
  /// SQLCipher key is unreadable), which is exactly when the recovery flow must
  /// decide whether the data can be re-pulled from CloudKit. Leaves
  /// [PrivateSyncStatus.lastSyncedAt] null (that field needs the store).
  Future<PrivateSyncStatus> probe();

  /// [force] mints a key even when the zone already holds records, making every
  /// existing record permanently unreadable. ONLY for a user who has explicitly
  /// confirmed "start fresh from this device" after being told what it costs —
  /// it exists so a device that will never receive the shared key (iCloud
  /// Keychain disabled) has a way out of an otherwise permanent deferral.
  Future<PrivateSyncStatus> enable({bool force = false});
  Future<PrivateSyncStatus> disable();
  /// [reason] names the trigger (push / poll / launch / resume / write /
  /// manual) purely so the logs can tell them apart on device.
  Future<PrivateSyncStatus> syncNow({String reason = 'manual'});

  /// Make THIS device authoritative: wipe the CloudKit zone, drop the shared
  /// secrets, then re-enable with a fresh key and re-upload everything held
  /// locally.
  ///
  /// The escape hatch from a key split — a state no automatic path can resolve,
  /// because with two divergent keys neither device can read the other's data
  /// and nothing can tell which copy the user wants. Deliberately destructive
  /// and deliberately manual: it discards whatever is in the zone, so it must
  /// be run from the device holding the data worth keeping, and only after the
  /// user has confirmed that.
  ///
  /// Local user data is never touched.
  Future<PrivateSyncStatus> resetSyncFromThisDevice();

  /// Full reset for "delete private data": wipe the CloudKit zone, delete the
  /// shared key + canonical owner from the iCloud Keychain, and turn sync off
  /// (offline → queued and finished on the next sync). The LOCAL wipe is done
  /// separately by the app's private store (`deleteAllPrivateData`).
  Future<PrivateSyncStatus> requestFullReset();

  /// A read-only snapshot of what has and has not been uploaded, for the sync
  /// health UI. Null when there is no local store to inspect (no-op service).
  ///
  /// Never throws for a diagnostic's sake: a status screen that itself crashes
  /// on a broken database is worse than useless, and a locked or corrupt DB is
  /// exactly when a user reaches for this.
  Future<SyncDiagnostics?> diagnostics();

  /// Runs [action] inside the SAME serialization as enable/disable/syncNow so a
  /// caller's own critical section can't interleave with an in-flight sync op.
  /// The Private-mode recovery uses this to delete + recreate the encrypted DB
  /// file while no auto-sync is mid-open over it (the race that surfaced as
  /// SQLCipher "out of memory" on BEGIN EXCLUSIVE and a double reset). A failing
  /// [action] must not poison the chain for later ops.
  Future<T> runExclusive<T>(Future<T> Function() action);
}

/// Used wherever CloudKit sync isn't available (Android; Windows/Linux
/// desktop; Supabase mode) and anywhere sync isn't wired.
class NoOpPrivateSyncService implements PrivateSyncService {
  const NoOpPrivateSyncService();

  @override
  Future<PrivateSyncStatus> status() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> probe() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> enable({bool force = false}) async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> resetSyncFromThisDevice() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> disable() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> syncNow({String reason = 'manual'}) async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> requestFullReset() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<SyncDiagnostics?> diagnostics() async => null;

  // No sync engine here, so there is no op chain to serialize against — just run
  // the action.
  @override
  Future<T> runExclusive<T>(Future<T> Function() action) => action();
}

/// The recovery action for a LOCKED private DB — its file exists but the
/// SQLCipher key is unreadable (a signing / Keychain-access-group change, or a
/// fresh device). PURE policy shared by both apps so desktop and mobile behave
/// identically. Fed by the store-free [PrivateSyncService.probe] so it works
/// while the DB itself can't open.
enum PrivateModeRecoveryAction {
  /// Sync ON + iCloud available + E2E key present: the local DB is a disposable
  /// cache — reset it and full-re-pull the CloudKit zone. No data loss.
  autoRecoverFromCloud,

  /// Sync ON + iCloud available but the E2E key hasn't arrived via iCloud
  /// Keychain yet — wait and retry rather than reset into an empty DB.
  waitForICloudKey,

  /// Sync ON but the iCloud account is unavailable (signed out / restricted):
  /// can't re-pull right now — let the user retry or choose.
  iCloudUnavailable,

  /// Sync OFF (or a local-only platform): the local DB is the ONLY copy and its
  /// key is gone — the user must explicitly choose (reset & start fresh, import
  /// a backup, or enable iCloud sync to recover from another device).
  userChoice,
}

/// Maps a store-free [PrivateSyncService.probe] result to the recovery action
/// for a locked private DB. Single source of truth for the policy on both apps.
PrivateModeRecoveryAction decidePrivateModeRecovery(PrivateSyncStatus probe) {
  if (!probe.isEnabled) return PrivateModeRecoveryAction.userChoice;
  if (!probe.isAvailable) return PrivateModeRecoveryAction.iCloudUnavailable;
  if (!probe.hasKey) return PrivateModeRecoveryAction.waitForICloudKey;
  return PrivateModeRecoveryAction.autoRecoverFromCloud;
}
