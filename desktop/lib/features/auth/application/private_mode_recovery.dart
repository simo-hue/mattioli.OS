import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';

/// The terminal state of a private-mode open/recover attempt.
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

/// Result of [openOrRecoverPrivate] — the status plus a little context the UI
/// uses for messaging.
class PrivateRecoveryResult {
  const PrivateRecoveryResult(
    this.status, {
    this.restoredFromCloud = false,
    this.iCloudUnavailable = false,
    this.error,
  });

  final PrivateRecoveryStatus status;

  /// True when [status] is [PrivateRecoveryStatus.ready] because a locked cache
  /// was reset and re-pulled from CloudKit (⇒ show a "restored from iCloud"
  /// notice and refresh the in-memory providers).
  final bool restoredFromCloud;

  /// True when [status] is [PrivateRecoveryStatus.needsUserChoice] specifically
  /// because iCloud sync is on but the account is unavailable (signed out /
  /// restricted) — the UI shows a "sign into iCloud" hint instead of the plain
  /// local-only copy.
  final bool iCloudUnavailable;

  final Object? error;
}

/// Opens the encrypted Private DB, transparently recovering a LOCKED one (its
/// file exists but the SQLCipher key is unreadable — e.g. a code-signing /
/// Keychain-access-group change, or a fresh device) from CloudKit when it is
/// SAFE to do so. Never throws — every failure is captured in the result.
///
/// The recovery POLICY is the shared [decidePrivateModeRecovery] so desktop and
/// mobile behave identically. The store-free [PrivateSyncService.probe] is used
/// to decide (a locked DB can't be opened, so [PrivateSyncService.status] —
/// which reads the store — would itself throw).
Future<PrivateRecoveryResult> openOrRecoverPrivate(
  PrivateSyncService sync,
) async {
  final db = DesktopPrivateDb.instance;

  try {
    await db.database; // opens the DB (and runs the owner self-heal)
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
        await db.resetLockedDatabase();
        // enable() re-joins sync: resolves + adopts the canonical owner from the
        // synced Keychain and full-pulls the zone (a fresh empty DB ⇒ null change
        // token ⇒ every record). Plain syncNow() would NOT adopt the owner, so
        // the re-pulled rows would be orphaned until the next open.
        await sync.enable();
        await db.database; // open the fresh, re-populated DB
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
/// (its key is gone — the data is unrecoverable locally) so the next open mints
/// a fresh key over an empty schema, then re-opens. When [enableSync] is set it
/// also joins iCloud sync (pulling any data another device already synced).
/// Never throws; returns whether the DB is open afterward.
Future<bool> resetAndReopenPrivate(
  PrivateSyncService sync, {
  bool enableSync = false,
}) async {
  final db = DesktopPrivateDb.instance;
  try {
    await db.resetLockedDatabase();
    if (enableSync) await sync.enable();
    await db.database;
    return true;
  } catch (error, stack) {
    AppLogger.error('[PrivateRecovery] reset & reopen failed', error, stack);
    return false;
  }
}
