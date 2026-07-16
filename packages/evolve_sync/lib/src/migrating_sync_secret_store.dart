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
/// - **delete**: BOTH — a full reset must leave no secret behind anywhere.
///
/// ---
/// DO NOT REMOVE THE LEGACY TIER. It is not merely back-compat for iOS ≤1.0.9
/// that expires once those versions die out — it is currently the ONLY way the
/// iPhone can see a sync key the Mac created.
///
/// Why: desktop's `MacOsOptions(groupId: kSyncKeychainAccessGroup)` is inert.
/// `flutter_secure_storage_darwin` 0.3.2 applies `kSecAttrAccessGroup` only
/// under `#if os(iOS)` (`FlutterSecureStorage.swift:233-236`), and every macOS
/// query is built from that one `baseQuery`. So the Mac's sync secrets land in
/// its default access group (`…com.simo.evolve`, listed first in the macOS
/// entitlements), never in [kSyncKeychainAccessGroup]. The iPhone's `primary`
/// read IS group-scoped, so it misses them; it finds them only through this
/// group-less `legacy` tier (a query without an access group matches every
/// group the app is entitled to), which then heals them into `primary`.
///
/// Drop this tier while that holds and a Mac-first sync enable goes silent on
/// the iPhone: `readKey()` returns null forever, or `getOrCreateKeyReporting()`
/// mints a SECOND key plus a competing canonical owner and splits the two
/// devices onto different identities. The mobile-first path keeps working
/// throughout, so neither the test suite nor manual QA starting from the phone
/// will catch it.
///
/// PRECONDITION for removal: desktop writes must actually be group-scoped —
/// i.e. the darwin plugin honours `groupId` on macOS, or desktop writes these
/// secrets via a channel that sets the group itself. Confirm by inspecting a
/// Mac-written item's `kSecAttrAccessGroup`: it must read `…com.simo.evolve.sync`
/// and not `…com.simo.evolve`. Note that making the pin effective also strands
/// every secret already written to the default group, so that change needs its
/// own read-heal migration — which is a further reason this tier outlives it.
/// ---
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
