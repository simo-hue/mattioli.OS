import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_logger.dart';

class SecureStorageUtils {
  const SecureStorageUtils._();

  static const FlutterSecureStorage storage = FlutterSecureStorage();

  /// Storage for Private-Mode device-local secrets: the SQLCipher database key
  /// and the owner UUID.
  ///
  /// IMPORTANT — this uses the DEFAULT keychain options, NOT an accessibility
  /// pin, and it MUST stay that way. On macOS, `flutter_secure_storage` puts
  /// `kSecAttrAccessible` into the LOOKUP query (see the darwin plugin's
  /// `baseQuery`), so reading with an accessibility that differs from how the
  /// item was WRITTEN silently misses it (`errSecItemNotFound`). Desktop's
  /// private-mode secrets have always been written with default options, so
  /// pinning this to e.g. `first_unlock_this_device` makes an existing key
  /// unreadable — after which the fail-closed guard in
  /// [DesktopPrivateDb] fires and locks the user out of their intact data on the
  /// very next update. Default options already keep the key device-local
  /// (`whenUnlocked` + non-synchronizable ⇒ never in the iCloud Keychain), and
  /// the DB file itself is separately backup-excluded — so the pin bought almost
  /// nothing while risking a mass lockout. Kept as a distinct handle so callers
  /// read as intent-revealing and any future migration (read-heal into a pinned
  /// store) has a single home. Unlike mobile — which shipped its device-local
  /// tier pinned from day one (no legacy items to migrate) — desktop cannot
  /// retroactively change the accessibility of already-written keys.
  static const FlutterSecureStorage _deviceLocalStorage = FlutterSecureStorage();

  static Future<String?> read(String key) => storage.read(key: key);

  static Future<bool> containsKey(String key) => storage.containsKey(key: key);

  static Future<void> delete(String key) => storage.delete(key: key);

  /// Write [value] under [key] to [store], recovering from a duplicate-item
  /// (-25299) error with a delete+rewrite scoped to [key]. NEVER calls
  /// `deleteAll()`: several secrets — including the Private-Mode SQLCipher key —
  /// can share one macOS keychain service. They differ only by accessibility,
  /// which delete ignores, and by access group, which never distinguishes them
  /// here: `flutter_secure_storage_darwin` 0.3.2 sets `kSecAttrAccessGroup`
  /// under `#if os(iOS)` only (`FlutterSecureStorage.swift:233-236`), so every
  /// macOS query this class issues is group-less — including the recovery
  /// delete below. (macOS itself does honour access groups: `MacOsOptions`
  /// defaults `usesDataProtectionKeychain` to true. It is the plugin dropping
  /// the parameter, not the platform ignoring it.) A blanket wipe would
  /// therefore destroy unrelated, unrecoverable data. Rethrows on unrecoverable
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
