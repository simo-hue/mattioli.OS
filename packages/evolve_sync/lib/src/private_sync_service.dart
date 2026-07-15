import 'cloudkit_bridge.dart';

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

  const PrivateSyncStatus({
    required this.isAvailable,
    required this.isEnabled,
    this.lastSyncedAt,
    this.account,
    this.message,
    this.hasKey = true,
    this.appliedChanges = 0,
  });

  const PrivateSyncStatus.localOnly()
      : isAvailable = false,
        isEnabled = false,
        lastSyncedAt = null,
        account = null,
        message = 'iCloud sync is not available on this platform.',
        hasKey = false,
        appliedChanges = 0;
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

  Future<PrivateSyncStatus> enable();
  Future<PrivateSyncStatus> disable();
  Future<PrivateSyncStatus> syncNow();

  /// Full reset for "delete private data": wipe the CloudKit zone, delete the
  /// shared key + canonical owner from the iCloud Keychain, and turn sync off
  /// (offline → queued and finished on the next sync). The LOCAL wipe is done
  /// separately by the app's private store (`deleteAllPrivateData`).
  Future<PrivateSyncStatus> requestFullReset();
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
  Future<PrivateSyncStatus> enable() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> disable() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> syncNow() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> requestFullReset() async =>
      const PrivateSyncStatus.localOnly();
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
