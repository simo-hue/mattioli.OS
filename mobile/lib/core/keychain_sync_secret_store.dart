import 'package:evolve_sync/evolve_sync.dart';

import 'secure_storage_utils.dart';

/// Production [SyncSecretStore] backed by the synchronizable Keychain — the
/// user's iCloud Keychain — in the SHARED access group the macOS app also
/// reads (see [SecureStorageUtils.writeSynced] / [kSyncKeychainAccessGroup]).
class KeychainSyncSecretStore implements SyncSecretStore {
  const KeychainSyncSecretStore();

  @override
  Future<String?> read(String key) => SecureStorageUtils.readSynced(key);

  @override
  Future<void> write(String key, String value) =>
      SecureStorageUtils.writeSynced(key, value, context: '[Sync] $key');

  @override
  Future<void> delete(String key) => SecureStorageUtils.deleteSynced(key);
}

/// The pre-1.0.10 location of the same secrets (no explicit access group, so
/// invisible to the desktop app). Only ever used as the `legacy` tier of
/// [MigratingSyncSecretStore]; drop once ≤1.0.9 installs are extinct.
class LegacyKeychainSyncSecretStore implements SyncSecretStore {
  const LegacyKeychainSyncSecretStore();

  @override
  Future<String?> read(String key) => SecureStorageUtils.readSyncedLegacy(key);

  @override
  Future<void> write(String key, String value) => SecureStorageUtils
      .writeSyncedLegacy(key, value, context: '[Sync legacy] $key');

  @override
  Future<void> delete(String key) =>
      SecureStorageUtils.deleteSyncedLegacy(key);
}

/// The store the sync service should use: shared-group primary, legacy
/// fallback with read-healing and dual-writes during the 1.0.9 → 1.0.10
/// transition.
const SyncSecretStore keychainSyncSecretStore = MigratingSyncSecretStore(
  primary: KeychainSyncSecretStore(),
  legacy: LegacyKeychainSyncSecretStore(),
);
