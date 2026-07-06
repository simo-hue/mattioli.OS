import 'package:evolve_sync/evolve_sync.dart';

import 'secure_storage_utils.dart';

/// Production [SyncSecretStore] backed by the synchronizable Keychain, i.e. the
/// user's iCloud Keychain (see [SecureStorageUtils.writeSynced]).
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
