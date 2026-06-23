import 'package:shared_preferences/shared_preferences.dart';

import 'cloudkit_bridge.dart';
import 'private_sync_service.dart';
import 'sync_crypto.dart';
import 'sync_engine.dart';
import 'sync_key_store.dart';
import 'sync_local_store.dart';

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
  final SyncEnabledStore enabledStore;

  CloudKitPrivateSyncService({
    required this.bridge,
    required this.keys,
    required this.crypto,
    required this.storeProvider,
    required this.ownerProvider,
    required this.enabledStore,
  });

  Future<SyncEngine> _engine(SyncLocalStore store) async =>
      SyncEngine(store: store, bridge: bridge, crypto: crypto);

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
      appliedChanges: appliedChanges,
    );
  }

  @override
  Future<PrivateSyncStatus> enable() async {
    final store = await storeProvider();
    final engine = await _engine(store);
    final res = await engine.enable(keys: keys, localOwner: await ownerProvider());
    if (res.ran) await enabledStore.setEnabled(true);
    return _status(appliedChanges: res.applied);
  }

  @override
  Future<PrivateSyncStatus> disable() async {
    // Stop syncing; leave the CloudKit data + key intact (re-enable resumes).
    await enabledStore.setEnabled(false);
    return status();
  }

  @override
  Future<PrivateSyncStatus> syncNow() async {
    final store = await storeProvider();
    // Honor a queued full-reset wipe even when sync is disabled (it's cleanup).
    if (await store.pendingZoneWipe()) {
      // The engine's wipe path doesn't use the key (it's gone after a reset).
      final r = await (await _engine(store))
          .syncNow(await keys.readKey() ?? crypto.generateKey());
      return _status(appliedChanges: r.applied);
    }
    if (!await enabledStore.isEnabled()) return status();
    final key = await keys.readKey();
    if (key == null) return status(); // key not in iCloud Keychain yet
    final r = await (await _engine(store)).syncNow(key);
    return _status(appliedChanges: r.applied);
  }

  @override
  Future<PrivateSyncStatus> requestFullReset() async {
    final store = await storeProvider();
    await store.setPendingZoneWipe(true);
    await enabledStore.setEnabled(false);
    await keys.deleteAll(); // remove shared key + owner from iCloud Keychain
    // Attempt the cloud wipe now; if offline it stays queued (pending_zone_wipe)
    // and a later syncNow completes it.
    await syncNow();
    return status();
  }
}
