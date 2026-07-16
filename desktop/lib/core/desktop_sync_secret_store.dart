import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_utils.dart';

/// macOS [SyncSecretStore]: the E2E sync key + canonical owner id in the
/// user's iCloud Keychain (`synchronizable`), which is what carries them
/// between the user's Mac and iPhone.
///
/// The [kSyncKeychainAccessGroup] pin below does NOT take effect on macOS, so
/// it is not what makes cross-app interop work. `flutter_secure_storage_darwin`
/// 0.3.2 applies `kSecAttrAccessGroup` under `#if os(iOS)` only
/// (`FlutterSecureStorage.swift:233-236`), and every macOS query — read, write
/// and delete — is built from that one `baseQuery`. This store's items
/// therefore land in the app's DEFAULT group
/// (`$(AppIdentifierPrefix)com.simo.evolve`, listed first in the entitlements),
/// not in the shared `…sync` group. `groupId` stays declared so the intent is
/// explicit and the pin engages if the plugin is ever fixed — but that flip
/// would strand items already written to the default group and needs a
/// read-heal migration first.
///
/// What interop actually rides on today: a keychain query without an access
/// group matches every group the app is entitled to. This app reads the
/// iPhone's `…sync` items that way, and the iPhone reads this app's default-
/// group items only via `MigratingSyncSecretStore`'s group-less legacy tier.
/// That tier is load-bearing for the Mac-first path and must not be removed —
/// see the removal precondition documented on `MigratingSyncSecretStore`.
///
/// Unlike mobile there is no legacy tier here: the desktop never stored sync
/// secrets anywhere else. Distinct from the device-local secrets (SQLCipher
/// key, owner UUID), which stay in the app's default keychain and never sync.
class DesktopSyncSecretStore implements SyncSecretStore {
  const DesktopSyncSecretStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      groupId: kSyncKeychainAccessGroup,
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: true,
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      // Route through the shared scoped writer so a duplicate-item (-25299) on
      // this collision-prone synchronizable/shared-group store self-heals
      // (scoped delete+rewrite, never deleteAll) instead of aborting sync —
      // matching mobile's synced-tier write.
      SecureStorageUtils.writeScoped(
        _storage,
        key,
        value,
        context: '[Sync] keychain',
      );

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
