import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'cloudkit_bridge.dart';
import 'private_sync_service.dart';
import 'sync_avatar_store.dart';
import 'sync_crypto.dart';
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

  Future<PrivateSyncStatus> _status({int appliedChanges = 0}) async {
    final enabled = await enabledStore.isEnabled();
    final account = await bridge.accountStatus();
    final store = await storeProvider();
    return PrivateSyncStatus(
      isAvailable: account == CloudAccountStatus.available,
      isEnabled: enabled,
      lastSyncedAt: await store.lastFullSync(),
      account: account,
      hasKey: await keys.readKey() != null,
      appliedChanges: appliedChanges,
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
  Future<PrivateSyncStatus> enable() => _runExclusive(_enable);

  Future<PrivateSyncStatus> _enable() async {
    try {
      logger.info('[CloudKit] Enabling sync...');
      final store = await storeProvider();
      final engine = await _engine(store);
      final localOwner = await ownerProvider();
      final res = await engine.enable(keys: keys, localOwner: localOwner);
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
      } else {
        logger.info('[CloudKit] Sync enable skipped (blocked by: ${res.blockedBy})');
      }
      return _status(appliedChanges: res.applied);
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
