import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_logger.dart';

class SecureStorageUtils {
  const SecureStorageUtils._();

  static const FlutterSecureStorage storage = FlutterSecureStorage();

  /// Storage for Private-Mode device-local secrets: the SQLCipher database key
  /// and the owner UUID. `first_unlock_this_device` keeps these items on THIS
  /// Mac only — never synced to the user's iCloud Keychain nor restored onto
  /// another device — matching the local-only, backup-excluded Private database
  /// so the key can never outlive or migrate away from its data. Mirrors
  /// mobile's device-local tier and is deliberately the OPPOSITE of
  /// [DesktopSyncSecretStore] (the only secret allowed to sync).
  static const FlutterSecureStorage _deviceLocalStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static Future<String?> read(String key) => storage.read(key: key);

  static Future<bool> containsKey(String key) => storage.containsKey(key: key);

  static Future<void> delete(String key) => storage.delete(key: key);

  /// Write [value] under [key] to [store], recovering from a duplicate-item
  /// (-25299) error with a delete+rewrite scoped to [key]. NEVER calls
  /// `deleteAll()`: several secrets — including the Private-Mode SQLCipher key —
  /// can share one macOS keychain service (they differ only by accessibility,
  /// which delete ignores, and macOS ignores access groups), so a blanket wipe
  /// would destroy unrelated, unrecoverable data. Rethrows on unrecoverable
  /// failure so callers can fail closed. Mirrors mobile's `_writeTo`.
  static Future<void> writeScoped(
    FlutterSecureStorage store,
    String key,
    String value, {
    String context = 'SecureStorage',
  }) async {
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

      try {
        await store.delete(key: key);
        await store.write(key: key, value: value);
      } catch (retryError, retryStack) {
        AppLogger.error(
          '$context duplicate recovery failed for "$key"',
          retryError,
          retryStack,
        );
        rethrow;
      }
    }
  }

  /// Write a general secret (default keychain tier) with scoped -25299 recovery.
  static Future<void> write(
    String key,
    String value, {
    String context = 'SecureStorage',
  }) =>
      writeScoped(storage, key, value, context: context);

  /// Read a Private-Mode device-local secret (see [_deviceLocalStorage]).
  static Future<String?> readDeviceLocal(String key) =>
      _deviceLocalStorage.read(key: key);

  /// Delete a Private-Mode device-local secret (see [_deviceLocalStorage]).
  static Future<void> deleteDeviceLocal(String key) =>
      _deviceLocalStorage.delete(key: key);

  /// Write a Private-Mode device-local secret (see [_deviceLocalStorage]) with
  /// scoped -25299 recovery (never `deleteAll`).
  static Future<void> writeDeviceLocal(
    String key,
    String value, {
    String context = 'SecureStorage(device-local)',
  }) =>
      writeScoped(_deviceLocalStorage, key, value, context: context);

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
