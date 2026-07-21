import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'cloudkit_bridge.dart';
import 'private_sync_service.dart';
import 'sync_avatar_store.dart';
import 'sync_crypto.dart';
import 'sync_diagnostics.dart';
import 'sync_engine.dart';
import 'sync_key_store.dart';
import 'sync_local_store.dart';
import 'sync_logger.dart';

/// Per-device "sync enabled" flag (sync is an opt-in, per-device choice — it is
/// NOT shared via iCloud Keychain).
abstract class SyncEnabledStore {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool value);
}

class PrefsSyncEnabledStore implements SyncEnabledStore {
  static const _key = 'private_sync_enabled_v1';
  final SharedPreferences prefs;
  const PrefsSyncEnabledStore(this.prefs);

  @override
  Future<bool> isEnabled() async => prefs.getBool(_key) ?? false;

  @override
  Future<void> setEnabled(bool value) => prefs.setBool(_key, value);
}

/// Real [PrivateSyncService]: wires the [SyncEngine] to the local store, the
/// E2E key store, and the CloudKit bridge, and tracks the per-device enabled
/// flag. The dependencies are injected so the whole service is unit-testable
/// with fakes.
class CloudKitPrivateSyncService implements PrivateSyncService {
  final CloudKitBridge bridge;
  final SyncKeyStore keys;
  final SyncCrypto crypto;
  final Future<SyncLocalStore> Function() storeProvider;
  final Future<String> Function() ownerProvider;

  /// Persists the canonical sync-owner as this device's owner id after a
  /// second-device merge re-keys local rows onto it (see [enable]).
  final Future<void> Function(String canonicalOwner) ownerWriter;
  final SyncEnabledStore enabledStore;
  final SyncLogger logger;

  /// App-provided file side of avatar sync; null leaves avatar records
  /// unsynced (see [SyncEngine.avatarStore]).
  final SyncAvatarStore? avatarStore;

  CloudKitPrivateSyncService({
    required this.bridge,
    required this.keys,
    required this.crypto,
    required this.storeProvider,
    required this.ownerProvider,
    required this.ownerWriter,
    required this.enabledStore,
    this.avatarStore,
    this.logger = const SilentSyncLogger(),
  });

  Future<SyncEngine> _engine(SyncLocalStore store) async => SyncEngine(
        store: store,
        bridge: bridge,
        crypto: crypto,
        avatarStore: avatarStore,
        logger: logger,
      );

  /// Tail of the in-flight operation chain. Each mutating op links onto it so
  /// only ONE runs at a time. Without this, the foreground-resume syncNow and a
  /// user-tapped syncNow (or an enable) could run concurrently against the same
  /// store and double-push / interleave token writes. Reads ([status]) stay off
  /// the lock so the UI never blocks on an in-progress sync.
  Future<void> _tail = Future<void>.value();

  Future<T> _runExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final prev = _tail;
    // Next op waits for this one to settle (ignore errors so one failure doesn't
    // poison the whole chain).
    _tail = completer.future.then<void>((_) {}, onError: (_) {});
    () async {
      await prev;
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }();
    return completer.future;
  }

  @override
  Future<PrivateSyncStatus> status() => _status();

  /// Off the [_runExclusive] lock on purpose: this is a pure read, and the whole
  /// point is to be able to inspect sync health WHILE a long push is running —
  /// queueing behind it would leave the screen blank exactly when it matters.
  @override
  Future<SyncDiagnostics?> diagnostics() async {
    try {
      final store = await storeProvider();
      // Pass the active owner so the report can distinguish "the data is here"
      // from "the data is here and the app can actually see it".
      return await store.diagnostics(owner: await ownerProvider());
    } catch (e, st) {
      // A locked or corrupt private DB is precisely when a user opens this
      // screen. Degrade to "no data" rather than taking the screen down.
      logger.error('[CloudKit] diagnostics() failed', e, st, const {});
      return null;
    }
  }

  Future<PrivateSyncStatus> _status({
    int appliedChanges = 0,
    bool keyPending = false,
    int undecryptableCount = 0,
  }) async {
    final enabled = await enabledStore.isEnabled();
    final account = await bridge.accountStatus();
    final store = await storeProvider();
    // A key split persists across syncs, so the count cannot come only from the
    // op that just ran: a user opening this screen a day later must still see
    // it. Fall back to what is parked in the store.
    var undecryptable = undecryptableCount;
    if (undecryptable == 0) {
      undecryptable = (await store.diagnostics())
              .parkedByReason[SyncLocalStore.undecryptableReason] ??
          0;
    }
    return PrivateSyncStatus(
      isAvailable: account == CloudAccountStatus.available,
      isEnabled: enabled,
      lastSyncedAt: await store.lastFullSync(),
      account: account,
      hasKey: await keys.readKey() != null,
      appliedChanges: appliedChanges,
      keyPending: keyPending,
      undecryptableCount: undecryptable,
    );
  }

  @override
  Future<PrivateSyncStatus> probe() async {
    // Store-FREE (never calls storeProvider()), so it works when the local DB is
    // locked — exactly when the recovery flow needs it. See PrivateSyncService.probe.
    final account = await bridge.accountStatus();
    return PrivateSyncStatus(
      isAvailable: account == CloudAccountStatus.available,
      isEnabled: await enabledStore.isEnabled(),
      account: account,
      hasKey: await keys.readKey() != null,
    );
  }

  @override
  Future<PrivateSyncStatus> enable({bool force = false}) =>
      _runExclusive(() => _enable(force: force));

  Future<PrivateSyncStatus> _enable({bool force = false}) async {
    try {
      logger.info('[CloudKit] Enabling sync...');
      final store = await storeProvider();
      final engine = await _engine(store);
      final localOwner = await ownerProvider();
      final res = await engine.enable(
        keys: keys,
        localOwner: localOwner,
        force: force,
        // Persisted BEFORE the re-key, inside the engine — see
        // SyncEngine.enable's [adoptOwner] doc. The post-hoc write below is kept
        // as a belt-and-braces retry for the case where this one failed.
        adoptOwner: ownerWriter,
      );
      if (res.ran) {
        // On a second device the engine re-keyed every local row onto the
        // canonical sync-owner. Persist it as THIS device's owner id too, or
        // ownerId() would keep returning the old device-local id and every data
        // query (which filters by owner) would miss the re-keyed rows.
        //
        // Adopt the EXACT canonical the engine used (res.canonicalOwner), and do
        // it BEFORE setEnabled(true): re-reading the Keychain here could observe
        // a different value mid-propagation, and if this write failed AFTER
        // enabling, sync would read as "on" with the owner unadopted (all rows
        // hidden). Ordering adoption first means a failure just leaves sync off,
        // and a retry (or the app's on-open owner self-heal) repairs it.
        final canonical = res.canonicalOwner;
        if (canonical != null &&
            canonical.isNotEmpty &&
            canonical != localOwner) {
          await ownerWriter(canonical);
        }
        await enabledStore.setEnabled(true);
        logger.info('[CloudKit] Sync enabled successfully');
      } else if (res.ownerPending) {
        // Key synced but the canonical owner hasn't yet: leave sync disabled so
        // a later enable retry completes the merge once the owner propagates.
        logger.info(
          '[CloudKit] Sync enable deferred: canonical owner not yet synced '
          'from iCloud Keychain',
        );
      } else if (res.keyPending) {
        // The zone already holds records but this device has no key yet.
        // Deliberately leaves sync OFF so the UI can explain the wait and offer
        // the deliberate override, rather than looking enabled-but-empty.
        logger.info(
          '[CloudKit] Sync enable deferred: waiting for the E2E key from '
          'iCloud Keychain (zone already has data)',
        );
      } else {
        logger.info('[CloudKit] Sync enable skipped (blocked by: ${res.blockedBy})');
      }
      return _status(
        appliedChanges: res.applied,
        keyPending: res.keyPending,
        undecryptableCount: res.undecryptable,
      );
    } catch (e, stack) {
      logger.error('[CloudKit] Failed to enable sync', e, stack);
      rethrow;
    }
  }

  @override
  Future<PrivateSyncStatus> disable() => _runExclusive(() async {
        try {
          logger.info('[CloudKit] Disabling sync...');
          // Stop syncing; leave the CloudKit data + key intact (re-enable resumes).
          await enabledStore.setEnabled(false);
          logger.info('[CloudKit] Sync disabled successfully');
          return _status();
        } catch (e, stack) {
          logger.error('[CloudKit] Failed to disable sync', e, stack);
          rethrow;
        }
      });

  @override
  Future<PrivateSyncStatus> syncNow() => _runExclusive(_syncNow);

  Future<PrivateSyncStatus> _syncNow() async {
    try {
      final store = await storeProvider();
      // Honor a queued full-reset wipe even when sync is disabled (it's cleanup).
      if (await store.pendingZoneWipe()) {
        logger.info('[CloudKit] Executing pending zone wipe...');
        // The engine's wipe path doesn't use the key (it's gone after a reset).
        final r = await (await _engine(store))
            .syncNow(await keys.readKey() ?? crypto.generateKey());
        logger.info('[CloudKit] Zone wipe completed');
        return _status(appliedChanges: r.applied);
      }
      if (!await enabledStore.isEnabled()) return status();
      final key = await keys.readKey();
      if (key == null) return status(); // key not in iCloud Keychain yet
      
      logger.info('[CloudKit] Sync starting...');
      final r = await (await _engine(store)).syncNow(key);

      // Sweep abandoned identity shells left by the seed-then-reconcile bug (and
      // by any future interrupted re-key). Deliberately AFTER the sync, so a
      // profile row still arriving from another device has already landed and
      // cannot be mistaken for an orphan. Local-only and precondition-guarded —
      // it never touches an identity that owns data, which is also what makes it
      // safe when this device's active owner is transiently stale.
      final reaped = await store.reapOrphanIdentities(await ownerProvider());
      if (reaped.isNotEmpty) {
        logger.info(
          '[CloudKit] Reaped ${reaped.length} abandoned identity shell(s)',
        );
      }

      logger.info('[CloudKit] Sync finished', extras: {
        'pushed': r.pushed,
        'applied': r.applied,
        'skipped': r.skipped,
      });
      return _status(appliedChanges: r.applied);
    } catch (e, stack) {
      logger.error('[CloudKit] Sync failed', e, stack);
      rethrow;
    }
  }

  // Share the ONE op chain with enable/disable/syncNow (don't create a second
  // lock) so a recovery reset routed through here can't run while an auto-sync
  // op still holds/reopens the store. _runExclusive isolates a failing action so
  // it doesn't poison the chain for later ops.
  @override
  Future<T> runExclusive<T>(Future<T> Function() action) =>
      _runExclusive(action);

  @override
  Future<PrivateSyncStatus> resetSyncFromThisDevice() =>
      _runExclusive(() async {
        try {
          logger.info('[CloudKit] Resetting sync from this device...');
          final store = await storeProvider();

          // 1. Destroy the zone. Everything in it is either this device's own
          //    data (about to be re-uploaded) or records sealed under a key
          //    nothing can read — in both cases worthless.
          await bridge.deleteZone();

          // 2. Drop the shared secrets so step 4 mints a genuinely fresh key
          //    rather than re-adopting the one that caused the split. This
          //    propagates through the iCloud Keychain, which is what lets the
          //    OTHER device stop using its rival key.
          await keys.deleteAll();

          // 3. Clear local bookkeeping: every sync_state row, the change token
          //    and the key fingerprint describe a zone that no longer exists.
          //    Without this, records already marked synced would never be
          //    re-uploaded and the reset would produce an empty zone. Local
          //    user data is untouched.
          await store.resetSyncState();
          await store.setPendingZoneWipe(false);
          await enabledStore.setEnabled(false);

          // 4. Re-enable as the first device. `force` is NOT needed — the zone
          //    is empty now, so the guard passes on its own; passing it would
          //    only mask a failed wipe in step 1.
          final res = await _enable();
          // Report what the reset actually achieved, from the store rather than
          // from `res`: PrivateSyncStatus carries `appliedChanges` (a PULL
          // count, 0 by definition here — the zone was just emptied) and no
          // push count at all. Logging that under a "pushed" key made a
          // successful 6000-record upload read as `pushed: 0`, which is the
          // opposite of the truth and exactly the kind of false signal this
          // whole hardening pass exists to remove.
          final diag = await store.diagnostics();
          logger.info('[CloudKit] Sync reset complete', extras: {
            'localRows': diag.totalLocalRows,
            'stillPending': diag.totalPending,
            'errors': diag.totalErrors,
          });
          return res;
        } catch (e, stack) {
          logger.error('[CloudKit] Reset sync from this device failed', e, stack);
          rethrow;
        }
      });

  @override
  Future<PrivateSyncStatus> requestFullReset() => _runExclusive(() async {
        try {
          logger.info('[CloudKit] Requesting full reset...');
          final store = await storeProvider();
          await store.setPendingZoneWipe(true);
          await enabledStore.setEnabled(false);
          await keys.deleteAll(); // remove shared key + owner from iCloud Keychain
          // Attempt the cloud wipe now; if offline it stays queued
          // (pending_zone_wipe) and a later syncNow completes it. Call the
          // un-locked _syncNow directly — we already hold the lock.
          await _syncNow();
          return _status();
        } catch (e, stack) {
          logger.error('[CloudKit] Request full reset failed', e, stack);
          rethrow;
        }
      });
}
