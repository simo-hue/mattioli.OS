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
  PrivateSyncService sync, {
  PrivateRecoveryStore? store,
}) async {
  final db = store ?? DesktopPrivateDb.instance;

  try {
    await db.ensureReady(); // opens the DB (and runs the owner self-heal)
    return const PrivateRecoveryResult(PrivateRecoveryStatus.ready);
  } on PrivateDatabaseLockedException {
    // Locked — fall through to the recovery decision below.
  } catch (error, stack) {
    AppLogger.error('[PrivateRecovery] unexpected DB open failure', error, stack);
    return PrivateRecoveryResult(PrivateRecoveryStatus.error, error: error);
  }

  // probe() reaches the Keychain / CloudKit and can throw; honor this function's
  // "never throws" contract (it runs fire-and-forget at Private-mode entry).
  final PrivateSyncStatus probe;
  try {
    probe = await sync.probe();
  } catch (error, stack) {
    AppLogger.error('[PrivateRecovery] probe failed', error, stack);
    return PrivateRecoveryResult(PrivateRecoveryStatus.error, error: error);
  }
  switch (decidePrivateModeRecovery(probe)) {
    case PrivateModeRecoveryAction.autoRecoverFromCloud:
      try {
        AppLogger.warning(
          '[PrivateRecovery] locked Private DB — stashing the local cache and '
          're-pulling from iCloud (its data is safe in CloudKit)',
        );
        // Stash (don't delete) the locked cache so a deferred/blocked enable can
        // be UNDONE — otherwise we'd destroy the only local copy before the cloud
        // pull is confirmed and strand the user in an empty DB.
        await db.stashLockedDatabase();
        // enable() re-joins sync: resolves + adopts the canonical owner from the
        // synced Keychain and full-re-pulls the zone. It can legitimately DEFER
        // (key synced, canonical owner not yet) or be BLOCKED (iCloud went
        // unavailable in the gap), in which case it populated NOTHING.
        // Plain syncNow() would NOT adopt the owner.
        final status = await sync.enable();
        // Records actually landed from the zone ⇒ the re-pull ran AND restored
        // data. That is the only evidence that makes dropping the stash safe.
        // isEnabled must NOT stand in for it: it reports the persisted
        // per-device pref, which is ALREADY true on this branch
        // (decidePrivateModeRecovery only returns autoRecoverFromCloud when
        // probe.isEnabled) and stays true across a deferred/blocked enable.
        if (status.appliedChanges > 0) {
          await db.ensureReady(); // open the fresh, re-populated DB
          await db.discardStashedDatabase(); // recovery committed — drop .bak
          return const PrivateRecoveryResult(
            PrivateRecoveryStatus.ready,
            restoredFromCloud: true,
          );
        }
        // Nothing was restored — put the stashed cache back (locked again) so a
        // later retry can recover the real data instead of accepting an empty DB
        // behind a misleading "restored from iCloud" notice.
        await db.restoreStashedDatabase();
        if (status.isAvailable && status.hasKey) {
          // The engine's OWN answer, not an inference from the timestamp.
          //
          // This used to test `lastSyncedAt == null`, reasoning that only a sync
          // which actually ran stamps it. That was never quite true and is now
          // plainly wrong: the engine no longer stamps a sync that ran but did
          // not fully complete (a rejected push, a held change token), so a
          // rate-limited first pull would be reported as "waiting for iCloud
          // Keychain" — a wait with nothing at the end of it. Deferral is a
          // fact the engine knows (SyncResult.ownerPending); ask it.
          if (status.ownerPending) {
            return const PrivateRecoveryResult(
              PrivateRecoveryStatus.waitingForICloudKey,
            );
          }
          // The pull ran but the zone held nothing to restore, so the locked
          // local copy is the only one left: let the user choose (reset / import)
          // rather than discarding it behind a false "restored" notice.
          return const PrivateRecoveryResult(
            PrivateRecoveryStatus.needsUserChoice,
          );
        }
        // iCloud flipped unavailable in the gap — let the user retry / choose.
        return const PrivateRecoveryResult(
          PrivateRecoveryStatus.needsUserChoice,
          iCloudUnavailable: true,
        );
      } catch (error, stack) {
        AppLogger.error('[PrivateRecovery] cloud recovery failed', error, stack);
        // Put the stashed cache back so a mid-recovery failure doesn't strand the
        // user in an empty DB (best-effort; safe if nothing was stashed).
        try {
          await db.restoreStashedDatabase();
        } catch (_) {}
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
  PrivateRecoveryStore? store,
}) async {
  final db = store ?? DesktopPrivateDb.instance;
  try {
    // Route the file delete + recreate through the sync engine's op chain so an
    // auto-sync opened on launch can't be mid-open over the file while we delete
    // and recreate it — the race that surfaced as SQLCipher "out of memory" on
    // BEGIN EXCLUSIVE plus a double reset. runExclusive REUSES the same lock
    // enable/syncNow take, so this section and any in-flight sync op serialize.
    await sync.runExclusive(() async {
      await db.resetLockedDatabase();
      await db.ensureReady();
    });
    // enable() takes that SAME lock internally (_runExclusive), so it must run
    // AFTER — outside — the block above, never nested inside it: nesting would
    // re-enter the lock and deadlock (the inner op would wait on the outer one,
    // which is waiting on the inner). The reset + reopen is already committed by
    // the time this runs, so a later enable/pull sees the fresh, open DB.
    if (enableSync) await sync.enable();
    return true;
  } catch (error, stack) {
    AppLogger.error('[PrivateRecovery] reset & reopen failed', error, stack);
    return false;
  }
}
