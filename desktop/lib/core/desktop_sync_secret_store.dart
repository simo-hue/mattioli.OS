import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_logger.dart';

/// macOS [SyncSecretStore]: the E2E sync key + canonical owner id in the
/// user's iCloud Keychain (`synchronizable`), inside the SHARED access group
/// both apps list in their entitlements ([kSyncKeychainAccessGroup]) — that
/// group is what lets this app read the items the iPhone wrote, and vice
/// versa.
///
/// Unlike mobile there is no legacy tier: the desktop never stored sync
/// secrets anywhere else, so it reads/writes the shared group directly.
/// Distinct from the device-local secrets (SQLCipher key, owner UUID), which
/// stay in the app's default keychain and never sync.
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
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (error, stack) {
      AppLogger.error('[Sync] keychain write failed for "$key"', error, stack);
      rethrow;
    }
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
