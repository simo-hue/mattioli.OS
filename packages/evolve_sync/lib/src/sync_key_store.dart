import 'dart:convert';
import 'dart:typed_data';

import 'sync_crypto.dart';

/// The two iCloud-sync secrets the key store manages, abstracted so the logic
/// is unit-testable with an in-memory fake. Each app provides the production
/// implementation over its keychain plugin, writing into the SHARED
/// synchronizable keychain access group — the iCloud Keychain is what carries
/// the secrets to the user's other devices, and the shared access group is what
/// lets the iOS and macOS apps read the same items.
abstract class SyncSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
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
  Future<Uint8List> getOrCreateKey() async =>
      (await getOrCreateKeyReporting()).key;

  /// Like [getOrCreateKey] but reports whether the key was freshly GENERATED in
  /// this call (`created: true` ⇒ this device is genuinely the first to enable
  /// sync) vs already present (`created: false` ⇒ adopted from another device
  /// via the iCloud Keychain). The flag lets [resolveCanonicalOwner] avoid the
  /// split-identity race: only a device that just created the key may publish
  /// its own owner as canonical.
  Future<({Uint8List key, bool created})> getOrCreateKeyReporting() async {
    final existing = await readKey();
    if (existing != null) return (key: existing, created: false);
    final key = _crypto.generateKey();
    await _store.write(keyKey, base64Encode(key));
    return (key: key, created: true);
  }

  Future<String?> readCanonicalOwner() => _store.read(ownerKey);

  Future<void> setCanonicalOwner(String id) => _store.write(ownerKey, id);

  /// Resolves the canonical sync-owner for enable, guarding against split
  /// identity:
  ///  • a published canonical owner is always adopted;
  ///  • otherwise, only a device that JUST created the key ([isFirstDevice])
  ///    publishes [fallbackOwnerId] as canonical;
  ///  • a device that ADOPTED the key from another device but hasn't yet seen
  ///    the canonical-owner item returns `null` — the two secrets are separate
  ///    iCloud-Keychain items with no ordering guarantee, so "key here, owner
  ///    not yet" means DEFER, never self-elect a competing owner (which would
  ///    leave each device querying only its own rows).
  Future<String?> resolveCanonicalOwner(
    String fallbackOwnerId, {
    required bool isFirstDevice,
  }) async {
    final existing = await readCanonicalOwner();
    if (existing != null && existing.isNotEmpty) return existing;
    if (!isFirstDevice) return null; // key adopted, owner not yet synced → defer
    await setCanonicalOwner(fallbackOwnerId);
    return fallbackOwnerId;
  }

  /// Adopt the canonical owner if one is already published (another device set
  /// it); otherwise publish [fallbackOwnerId] (this device's owner). Returns the
  /// effective canonical owner id.
  ///
  /// Prefer [resolveCanonicalOwner]: this variant always publishes when the
  /// owner is absent, so it can split identity if called by a device that only
  /// adopted the key. Retained for callers that already know they are the first
  /// device.
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
