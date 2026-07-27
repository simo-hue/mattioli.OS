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

  /// A key IS present but does not decrypt the database file.
  ///
  /// Distinct from [needsUserChoice] because the correct action is the
  /// OPPOSITE: the ciphertext is intact and its key exists somewhere, so the
  /// app must not stash, re-pull, reset or delete anything on its own. It
  /// reports, explains, and waits. Mirrors desktop.
  undecryptable,

  /// The stored schema is NEWER than this build understands: the user installed
  /// a previous build (TestFlight keeps them one tap away). The data is intact
  /// and correctly keyed; the only remedy is to reopen the newer build.
  schemaTooNew,

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
    this.failure,
  });

  final PrivateRecoveryStatus status;

  /// True when [status] is [PrivateRecoveryStatus.ready] because a locked cache
  /// was reset and re-pulled from CloudKit.
  final bool restoredFromCloud;

  /// True when [status] is [PrivateRecoveryStatus.needsUserChoice] specifically
  /// because iCloud sync is on but the account is unavailable.
  final bool iCloudUnavailable;

  final Object? error;

  /// The classified cause, when one was determined. Drives the stable
  /// diagnostic code and, critically, whether a destructive action may be
  /// offered at all.
  final PrivateDbOpenFailure? failure;

  /// Whether the UI may offer the reset for this result. Deliberately computed
  /// here rather than in the widget so both apps share ONE definition of "is it
  /// acceptable to move this user's database out from under them".
  bool get allowsReset {
    final f = failure;
    // A confirmed lock: no key exists, so starting fresh can orphan nothing.
    if (status == PrivateRecoveryStatus.needsUserChoice) return true;
    // Genuine corruption — the one failure where the data really is gone.
    if (f != null && allowsDestructiveRecovery(f)) return true;
    // An undecryptable database. Offering the reset here is CORRECT only
    // because the reset is no longer destructive: it renames the ciphertext to
    // `.locked-<timestamp>` and parks its key beside it, so the user can start
    // using the app again without giving anything up. Withholding it would be
    // the worse failure — it would leave a user whose only key lives in another
    // build, or on a machine they no longer have, permanently unable to enter
    // Private mode at all, with no action on screen but "back to sign in".
    if (status == PrivateRecoveryStatus.undecryptable) return true;
    // schemaTooNew deliberately does NOT: the remedy is to reopen the newer
    // build, and moving the database aside would strand data that build reads
    // perfectly.
    return false;
  }
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
  // An orphaned stash means a PREVIOUS recovery attempt died between stashing
  // the locked database and the discard/restore that ends the attempt — a quit,
  // a crash, or an OS termination during the full zone re-pull, which the code's
  // own logs describe as long enough to watch a spinner through. Nothing else in
  // either app ever looks at a `.recovery-bak`, so without this the user's real
  // database sits in a file no code path, log line or settings screen mentions,
  // while the app silently opens the fresh EMPTY database and reports itself
  // ready.
  //
  // Restoring is the safe answer, not discarding: the stash is encrypted with
  // the old (unreadable) key, so putting it back simply makes isDatabaseLocked()
  // true again and the normal recovery decision below runs on it — a retry
  // rather than a silent, permanent loss of the local copy.
  try {
    if (await store.hasStashedDatabase()) {
      AppLogger.warning(
        '[PrivateRecovery] found an orphaned .recovery-bak — a previous '
        'recovery was interrupted. Restoring it so recovery retries instead of '
        'opening an empty database.',
      );
      await store.restoreStashedDatabase();
    }
  } catch (error, stack) {
    AppLogger.error('[PrivateRecovery] orphan-stash sweep failed', error, stack);
    // Best-effort: fall through to the normal open/probe path.
  }

  try {
    await store.ensureReady(); // opens the DB (and runs the owner self-heal)
    return const PrivateRecoveryResult(PrivateRecoveryStatus.ready);
  } on PrivateDatabaseLockedException {
    // Locked — fall through to the recovery decision below.
  } on PrivateDatabaseUndecryptableException catch (error) {
    // A key is present but does not open the file. STOP HERE — deliberately
    // before the recovery decision, because that path's first act is to rename
    // the database aside and clear the key, which is exactly how an intact
    // database gets orphaned from the key that still opens it.
    AppLogger.error(
      '[PrivateRecovery] the database exists and is intact but this key does '
      'not decrypt it; taking NO action on the file.',
      error,
    );
    return PrivateRecoveryResult(
      PrivateRecoveryStatus.undecryptable,
      error: error,
      failure: PrivateDbOpenFailure.undecryptable,
    );
  } on PrivateDbSchemaTooNewException catch (error) {
    AppLogger.error(
      '[PrivateRecovery] the database was written by a newer build '
      '(stored v${error.storedVersion} > known v${error.knownVersion}); the '
      'data is intact — reopen the newer build.',
      error,
    );
    return PrivateRecoveryResult(
      PrivateRecoveryStatus.schemaTooNew,
      error: error,
      failure: PrivateDbOpenFailure.schemaTooNew,
    );
  } catch (error, stack) {
    AppLogger.error('[PrivateRecovery] unexpected DB open failure', error, stack);
    // Classify before giving up. An unclassified failure must NEVER inherit the
    // destructive recovery: only genuine corruption earns that.
    final failure =
        classifyPrivateDbOpenFailure(error, fileExistedNonEmpty: true);
    if (failure == PrivateDbOpenFailure.undecryptable) {
      return PrivateRecoveryResult(
        PrivateRecoveryStatus.undecryptable,
        error: error,
        failure: failure,
      );
    }
    if (failure == PrivateDbOpenFailure.schemaTooNew) {
      return PrivateRecoveryResult(
        PrivateRecoveryStatus.schemaTooNew,
        error: error,
        failure: failure,
      );
    }
    return PrivateRecoveryResult(
      PrivateRecoveryStatus.error,
      error: error,
      failure: failure,
    );
  }

  // probe() reaches the Keychain / CloudKit and can throw; honor this function's
  // "never throws" contract (it runs fire-and-forget from PrivateModeGate).
  final PrivateSyncStatus probe;
  try {
    probe = await sync.probe();
  } catch (error, stack) {
    AppLogger.error('[PrivateRecovery] probe failed', error, stack);
    return PrivateRecoveryResult(
      PrivateRecoveryStatus.error,
      error: error,
      // Always carry a classification, even an explicitly unknown one: the
      // diagnostics chip is suppressed when `failure` is null, and the states
      // that reach here are exactly the ones nobody can diagnose without it.
      failure: PrivateDbOpenFailure.unknown,
    );
  }
  switch (decidePrivateModeRecovery(probe)) {
    case PrivateModeRecoveryAction.autoRecoverFromCloud:
      try {
        AppLogger.warning(
          '[PrivateRecovery] locked Private DB — stashing the local cache and '
          're-pulling from iCloud (its data is safe in CloudKit)',
        );
        // Stash (don't delete) the locked cache so a deferred/blocked enable can
        // be UNDONE — otherwise we'd destroy the only local copy before the
        // cloud pull is confirmed and strand the user in an empty DB.
        await store.stashLockedDatabase();
        // enable() re-joins sync: resolves + adopts the canonical owner from the
        // synced Keychain and full-pulls the zone. It can legitimately DEFER
        // (key synced, canonical owner not yet — SyncResult.ownerPending, leaves
        // sync disabled) or be BLOCKED (iCloud went unavailable between probe and
        // now), in which case it populated NOTHING. Plain syncNow() would NOT
        // adopt the owner.
        final status = await sync.enable();
        // Records actually landed from the zone ⇒ the re-pull ran AND restored
        // data. That is the only evidence that makes dropping the stash safe.
        //
        // `isEnabled` must NOT stand in for it, and this branch used to test
        // exactly that: it reports the persisted per-device pref, which is
        // ALREADY true here (decidePrivateModeRecovery only returns
        // autoRecoverFromCloud when probe.isEnabled) and stays true across a
        // deferred or blocked enable. So a deferred re-pull — ownerPending,
        // nothing applied — took the success branch and HARD-DELETED the stashed
        // real database, then told the user it had been restored from iCloud.
        // Desktop fixed this in 7156a4f; the mobile twin was never updated.
        if (status.appliedChanges > 0) {
          await store.ensureReady(); // open the fresh, re-populated DB
          await store.discardStashedDatabase(); // recovery committed — drop .bak
          return const PrivateRecoveryResult(
            PrivateRecoveryStatus.ready,
            restoredFromCloud: true,
          );
        }
        // Nothing was restored — restore the stashed cache (locked again) so a
        // later retry can recover the real data instead of accepting an empty DB
        // behind a misleading "restored from iCloud" toast.
        await store.restoreStashedDatabase();
        if (status.isAvailable && status.hasKey) {
          // Deferral is a fact the engine knows — ask it, rather than inferring
          // it from a timestamp (desktop's note explains why that inference was
          // wrong).
          if (status.ownerPending) {
            return const PrivateRecoveryResult(
              PrivateRecoveryStatus.waitingForICloudKey,
            );
          }
          // The pull ran but the zone held nothing to restore, so the locked
          // local copy is the only one left: let the user choose (reset/import)
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
        // Put the stashed cache back so a mid-recovery failure doesn't strand
        // the user in an empty DB (best-effort; safe if nothing was stashed).
        try {
          await store.restoreStashedDatabase();
        } catch (_) {}
        return PrivateRecoveryResult(
      PrivateRecoveryStatus.error,
      error: error,
      // Always carry a classification, even an explicitly unknown one: the
      // diagnostics chip is suppressed when `failure` is null, and the states
      // that reach here are exactly the ones nobody can diagnose without it.
      failure: PrivateDbOpenFailure.unknown,
    );
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
    // Route the file move + recreate through the sync engine's op chain so an
    // auto-sync opened on launch can't be mid-open over the file while we move
    // and recreate it. Desktop fixed this race — it surfaced as SQLCipher "out
    // of memory" on BEGIN EXCLUSIVE plus a double reset — and the mobile twin
    // was simply never updated. runExclusive REUSES the same lock enable/syncNow
    // take, so this section and any in-flight sync op serialize.
    await sync.runExclusive(() async {
      await store.resetLockedDatabase();
      await store.ensureReady();
    });
    // enable() takes that SAME lock internally, so it must run AFTER — outside —
    // the block above, never nested inside it: nesting would re-enter the lock
    // and deadlock. The reset + reopen is already committed by the time this
    // runs, so a later enable/pull sees the fresh, open DB.
    if (enableSync) await sync.enable();
    return true;
  } catch (error, stack) {
    AppLogger.error('[PrivateRecovery] reset & reopen failed', error, stack);
    return false;
  }
}
