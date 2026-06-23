import 'dart:convert';
import 'dart:typed_data';

import 'secure_storage_utils.dart';
import 'sync_crypto.dart';

/// The two iCloud-sync secrets the key store manages, abstracted so the logic
/// is unit-testable with an in-memory fake (the real one is the iCloud
/// Keychain, which needs a device).
abstract class SyncSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

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

/// Owns the E2E sync key and the canonical sync-owner id, both shared across the
/// user's devices via the iCloud Keychain. The first device to enable sync
/// generates them; other devices read the synced values.
class SyncKeyStore {
  static const keyKey = 'private_sync_key_v1';
  static const ownerKey = 'private_sync_owner_v1';

  final SyncSecretStore _store;
  final SyncCrypto _crypto;

  SyncKeyStore(this._store, {SyncCrypto? crypto})
      : _crypto = crypto ?? SyncCrypto();

  /// The sync key, or null if none has been generated/synced yet (e.g. a second
  /// device whose iCloud Keychain hasn't delivered it).
  Future<Uint8List?> readKey() async {
    final b64 = await _store.read(keyKey);
    if (b64 == null || b64.isEmpty) return null;
    final bytes = base64Decode(b64);
    return bytes.length == SyncCrypto.keyLengthBytes
        ? Uint8List.fromList(bytes)
        : null; // malformed — treat as absent
  }

  /// Returns the existing key, or generates+stores one (first enabling device).
  Future<Uint8List> getOrCreateKey() async {
    final existing = await readKey();
    if (existing != null) return existing;
    final key = _crypto.generateKey();
    await _store.write(keyKey, base64Encode(key));
    return key;
  }

  Future<String?> readCanonicalOwner() => _store.read(ownerKey);

  Future<void> setCanonicalOwner(String id) => _store.write(ownerKey, id);

  /// Adopt the canonical owner if one is already published (another device set
  /// it); otherwise publish [fallbackOwnerId] (this device's owner). Returns the
  /// effective canonical owner id.
  Future<String> getOrSetCanonicalOwner(String fallbackOwnerId) async {
    final existing = await readCanonicalOwner();
    if (existing != null && existing.isNotEmpty) return existing;
    await setCanonicalOwner(fallbackOwnerId);
    return fallbackOwnerId;
  }

  /// Full reset (delete-private-data): remove both secrets from the iCloud
  /// Keychain so no shared secret lingers after the user wipes their data.
  Future<void> deleteAll() async {
    await _store.delete(keyKey);
    await _store.delete(ownerKey);
  }
}
