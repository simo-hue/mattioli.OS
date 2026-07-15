import 'app_logger.dart';
import 'private_data_store.dart';
import 'private_local_database.dart'; // PrivateDatabaseLockedException
import 'private_sync_service.dart'; // re-exports evolve_sync (PrivateSyncService, decidePrivateModeRecovery)

/// The terminal state of a private-mode open/recover attempt. Mirrors desktop's
/// `PrivateRecoveryStatus`.
enum PrivateRecoveryStatus {
  /// The encrypted Private DB is open and ready — enter Private mode.
  ready,

  /// Sync is ON and iCloud is reachable, but the E2E key hasn't arrived through
  /// the iCloud Keychain yet. Don't reset (that would empty the DB) — wait and
  /// retry so a later attempt recovers the real data.
  waitingForICloudKey,

  /// Locked and cannot auto-recover: the user must choose (reset & start fresh,
  /// enable iCloud sync to pull from another device, or import a backup).
  needsUserChoice,

  /// An unexpected, non-lock error while opening the DB.
  error,
}

/// Result of [openOrRecoverPrivate]. Mirrors desktop's `PrivateRecoveryResult`.
class PrivateRecoveryResult {
  const PrivateRecoveryResult(
    this.status, {
    this.restoredFromCloud = false,
    this.iCloudUnavailable = false,
    this.error,
  });

  final PrivateRecoveryStatus status;

  /// True when [status] is [PrivateRecoveryStatus.ready] because a locked cache
  /// was reset and re-pulled from CloudKit.
  final bool restoredFromCloud;

  /// True when [status] is [PrivateRecoveryStatus.needsUserChoice] specifically
  /// because iCloud sync is on but the account is unavailable.
  final bool iCloudUnavailable;

  final Object? error;
}

/// Opens the encrypted Private DB, transparently recovering a LOCKED one (its
/// file exists but the SQLCipher key is unreadable — a code-signing / Keychain
/// change, or a fresh device) from CloudKit when it is SAFE. Never throws.
///
/// The recovery POLICY is the shared [decidePrivateModeRecovery] so mobile and
/// desktop behave identically. The store-free [PrivateSyncService.probe] decides
/// (a locked DB can't open, so [PrivateSyncService.status] would itself throw).
Future<PrivateRecoveryResult> openOrRecoverPrivate({
  required PrivateDataStore store,
  required PrivateSyncService sync,
}) async {
  try {
    await store.ensureReady(); // opens the DB (and runs the owner self-heal)
    return const PrivateRecoveryResult(PrivateRecoveryStatus.ready);
  } on PrivateDatabaseLockedException {
    // Locked — fall through to the recovery decision below.
  } catch (error, stack) {
    AppLogger.error('[PrivateRecovery] unexpected DB open failure', error, stack);
    return PrivateRecoveryResult(PrivateRecoveryStatus.error, error: error);
  }

  final probe = await sync.probe();
  switch (decidePrivateModeRecovery(probe)) {
    case PrivateModeRecoveryAction.autoRecoverFromCloud:
      try {
        AppLogger.warning(
          '[PrivateRecovery] locked Private DB — resetting the local cache and '
          're-pulling from iCloud (its data is safe in CloudKit)',
        );
        await store.resetLockedDatabase();
        // enable() re-joins sync: resolves + adopts the canonical owner from the
        // synced Keychain and full-pulls the zone. Plain syncNow() would NOT
        // adopt the owner, so the re-pulled rows would be orphaned until reopen.
        await sync.enable();
        await store.ensureReady(); // open the fresh, re-populated DB
        return const PrivateRecoveryResult(
          PrivateRecoveryStatus.ready,
          restoredFromCloud: true,
        );
      } catch (error, stack) {
        AppLogger.error('[PrivateRecovery] cloud recovery failed', error, stack);
        return PrivateRecoveryResult(PrivateRecoveryStatus.error, error: error);
      }
    case PrivateModeRecoveryAction.waitForICloudKey:
      return const PrivateRecoveryResult(
        PrivateRecoveryStatus.waitingForICloudKey,
      );
    case PrivateModeRecoveryAction.iCloudUnavailable:
      return const PrivateRecoveryResult(
        PrivateRecoveryStatus.needsUserChoice,
        iCloudUnavailable: true,
      );
    case PrivateModeRecoveryAction.userChoice:
      return const PrivateRecoveryResult(PrivateRecoveryStatus.needsUserChoice);
  }
}

/// The "Reset & start fresh" recovery action: wipes the orphaned encrypted file
/// (its key is gone) so the next open mints a fresh key over an empty schema,
/// then re-opens. When [enableSync] is set it also joins iCloud sync (pulling
/// any data another device already synced). Never throws.
Future<bool> resetAndReopenPrivate({
  required PrivateDataStore store,
  required PrivateSyncService sync,
  bool enableSync = false,
}) async {
  try {
    await store.resetLockedDatabase();
    if (enableSync) await sync.enable();
    await store.ensureReady();
    return true;
  } catch (error, stack) {
    AppLogger.error('[PrivateRecovery] reset & reopen failed', error, stack);
    return false;
  }
}
