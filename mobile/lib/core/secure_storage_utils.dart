import 'package:evolve_sync/evolve_sync.dart' show kSyncKeychainAccessGroup;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_logger.dart';

class SecureStorageUtils {
  static const AndroidOptions _aOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const FlutterSecureStorage storage = FlutterSecureStorage(
    aOptions: _aOptions,
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Storage for Private-Mode secrets (the local DB encryption key, owner id).
  /// `first_unlock_this_device` keeps these items on this device only — never
  /// synced to iCloud Keychain nor restored onto another device — matching the
  /// local-only, backup-excluded Private database, so the key can't outlive or
  /// migrate away from its data (SEC-5). iOS-only; Android uses the same
  /// encrypted store regardless.
  static const FlutterSecureStorage _deviceLocalStorage = FlutterSecureStorage(
    aOptions: _aOptions,
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Storage for the iCloud-sync secrets (CloudKit payload encryption key +
  /// canonical sync-owner id). `synchronizable: true` sets kSecAttrSynchronizable
  /// so iOS syncs these items through the user's iCloud Keychain to their other
  /// Apple devices — which is exactly how a second device obtains the E2E key.
  /// Deliberately the OPPOSITE of [_deviceLocalStorage]: this is the only secret
  /// allowed to leave the device, and only via the user's own iCloud Keychain.
  ///
  /// The items live in the SHARED keychain access group
  /// ([kSyncKeychainAccessGroup], listed in Runner.entitlements) so the macOS
  /// desktop app — a different bundle id — can read the same secrets. iCloud
  /// Keychain syncs across devices; only the shared group crosses APPS.
  /// iOS-only behavior; Android uses the same encrypted store (sync is iOS-only).
  static const FlutterSecureStorage _syncedStorage = FlutterSecureStorage(
    aOptions: _aOptions,
    iOptions: IOSOptions(
      groupId: kSyncKeychainAccessGroup,
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: true,
    ),
  );

  /// Where versions ≤1.0.9 kept the sync secrets: same options but NO explicit
  /// access group, i.e. the app's default group — unreadable by the desktop
  /// app. Kept only as the `legacy` tier of the package's
  /// `MigratingSyncSecretStore` (reads heal into [_syncedStorage], writes go to
  /// both so older devices still see the secrets, deletes wipe both).
  static const FlutterSecureStorage _syncedLegacyStorage = FlutterSecureStorage(
    aOptions: _aOptions,
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: true,
    ),
  );

  static Future<String?> read(String key) {
    return storage.read(key: key);
  }

  /// Read a Private-Mode device-local secret (see [_deviceLocalStorage]).
  static Future<String?> readDeviceLocal(String key) {
    return _deviceLocalStorage.read(key: key);
  }

  /// Read an iCloud-synced sync secret (see [_syncedStorage]).
  static Future<String?> readSynced(String key) {
    return _syncedStorage.read(key: key);
  }

  /// Read from the pre-1.0.10 sync-secret location (see [_syncedLegacyStorage]).
  static Future<String?> readSyncedLegacy(String key) {
    return _syncedLegacyStorage.read(key: key);
  }

  static Future<bool> containsKey(String key) {
    return storage.containsKey(key: key);
  }

  static Future<void> delete(String key) {
    return storage.delete(key: key);
  }

  /// Delete a Private-Mode device-local secret (see [_deviceLocalStorage]).
  static Future<void> deleteDeviceLocal(String key) {
    return _deviceLocalStorage.delete(key: key);
  }

  /// Delete an iCloud-synced sync secret (see [_syncedStorage]).
  static Future<void> deleteSynced(String key) {
    return _syncedStorage.delete(key: key);
  }

  /// Delete from the pre-1.0.10 sync-secret location (see
  /// [_syncedLegacyStorage]).
  static Future<void> deleteSyncedLegacy(String key) {
    return _syncedLegacyStorage.delete(key: key);
  }

  static Future<void> write(
    String key,
    String value, {
    String context = 'SecureStorage',
  }) {
    return _writeTo(storage, key, value, context);
  }

  /// Write a Private-Mode device-local secret (see [_deviceLocalStorage]).
  static Future<void> writeDeviceLocal(
    String key,
    String value, {
    String context = 'SecureStorage',
  }) {
    return _writeTo(_deviceLocalStorage, key, value, context);
  }

  /// Write an iCloud-synced sync secret (see [_syncedStorage]).
  static Future<void> writeSynced(
    String key,
    String value, {
    String context = 'SecureStorage',
  }) {
    return _writeTo(_syncedStorage, key, value, context);
  }

  /// Write to the pre-1.0.10 sync-secret location (see [_syncedLegacyStorage]).
  static Future<void> writeSyncedLegacy(
    String key,
    String value, {
    String context = 'SecureStorage',
  }) {
    return _writeTo(_syncedLegacyStorage, key, value, context);
  }

  static Future<void> _writeTo(
    FlutterSecureStorage store,
    String key,
    String value,
    String context,
  ) async {
    try {
      await store.write(key: key, value: value);
    } catch (error, stack) {
      if (!_isDuplicateKeychainItem(error)) {
        AppLogger.error('$context write failed for "$key"', error, stack);
        rethrow;
      }

      AppLogger.error(
        '$context found a duplicate Keychain item for "$key"; recreating it.',
        error,
        stack,
      );

      // Recovery is intentionally scoped to the offending [key] only. Never
      // fall back to storage.deleteAll(): this keychain also holds the
      // Private-Mode database encryption key, and wiping it would cause
      // permanent, unrecoverable loss of the user's local data (SEC-6).
      try {
        await store.delete(key: key);
        await store.write(key: key, value: value);
      } catch (retryError, retryStack) {
        AppLogger.error(
          '$context duplicate recovery failed for "$key".',
          retryError,
          retryStack,
        );
        rethrow;
      }
    }
  }

  static Future<void> tryWrite(
    String key,
    String value, {
    String context = 'SecureStorage',
  }) async {
    try {
      await write(key, value, context: context);
    } catch (error, stack) {
      AppLogger.error(
        '$context suppressed secure write failure for "$key"',
        error,
        stack,
      );
    }
  }

  static bool _isDuplicateKeychainItem(Object error) {
    if (error is! PlatformException) return false;

    final code = error.code.toLowerCase();
    final message = error.message?.toLowerCase() ?? '';
    final details = error.details?.toString().toLowerCase() ?? '';

    return code.contains('-25299') ||
        message.contains('-25299') ||
        message.contains('already exists') ||
        details.contains('-25299');
  }
}
