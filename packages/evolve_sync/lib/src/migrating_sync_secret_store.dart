import 'sync_key_store.dart';

/// The keychain access group BOTH apps read/write the sync secrets in.
///
/// iCloud Keychain syncs items across a user's *devices*, but access across
/// *apps* is governed by the keychain access group — and an item's group is
/// fixed at write time. The iOS and macOS apps therefore share this explicit
/// group (each lists it in its `keychain-access-groups` entitlement); writing
/// the sync key/owner anywhere else makes them invisible to the other app.
///
/// The string must match the entitlement entry `$(AppIdentifierPrefix)` +
/// `com.simo.evolve.sync` — the prefix is the Apple team id, identical for
/// both apps. Keychain queries need it spelled out in full.
const String kSyncKeychainAccessGroup = '8528AN28A3.com.simo.evolve.sync';

/// [SyncSecretStore] decorator that migrates secrets from a legacy location
/// into the primary one, dual-writing during the transition.
///
/// Mobile ≤1.0.9 stored the sync key + canonical owner in the app's DEFAULT
/// keychain access group (no explicit group), which other apps can never read.
/// 1.0.10+ uses the shared [kSyncKeychainAccessGroup] as `primary` and the old
/// location as `legacy`:
///
/// - **read**: primary wins; on a miss, a legacy hit is copied ("healed") into
///   primary and returned. Idempotent — a second read is a plain primary hit.
/// - **write**: BOTH locations. Older app versions can only see the legacy
///   group (they lack the shared-group entitlement), so dual-writing keeps a
///   key created/rotated by a new device visible to not-yet-updated devices.
///   The legacy copy is garbage once old versions die out; it can be dropped in
///   a later release.
/// - **delete**: BOTH — a full reset must leave no secret behind anywhere.
///
/// Desktop has no legacy location (it never wrote synced secrets before sync
/// existed there) and uses its shared-group store directly, without this.
class MigratingSyncSecretStore implements SyncSecretStore {
  final SyncSecretStore primary;
  final SyncSecretStore legacy;

  const MigratingSyncSecretStore({required this.primary, required this.legacy});

  @override
  Future<String?> read(String key) async {
    final current = await primary.read(key);
    if (current != null && current.isNotEmpty) return current;
    final old = await legacy.read(key);
    if (old == null || old.isEmpty) return null;
    await primary.write(key, old);
    return old;
  }

  @override
  Future<void> write(String key, String value) async {
    await primary.write(key, value);
    await legacy.write(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await primary.delete(key);
    await legacy.delete(key);
  }
}
