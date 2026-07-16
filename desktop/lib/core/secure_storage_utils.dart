import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_logger.dart';
import 'dev_device_local_store.dart';

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

  /// DEBUG-only file-backed replacement for the device-local Keychain tier (see
  /// [DevDeviceLocalStore]). Only ever referenced from inside the `kDebugMode`
  /// branch of [readDeviceLocal] / [writeDeviceLocal] / [deleteDeviceLocal], so
  /// release builds const-fold that branch away and tree-shake this field —
  /// and [DevDeviceLocalStore] — out entirely.
  static final DevDeviceLocalStore _devDeviceLocalStore = DevDeviceLocalStore();

  /// True only while running under `flutter test` (the runner sets FLUTTER_TEST).
  /// Used ONLY to keep the debug escape hatch OFF during tests, so the existing
  /// device-local tests keep exercising the real (channel-mocked) Keychain path
  /// instead of the file store. Never affects release: the outer [kDebugMode]
  /// gate is const-false there, so this is never evaluated in a release build.
  static final bool _isFlutterTest =
      Platform.environment.containsKey('FLUTTER_TEST');

  static bool _devDeviceLocalStoreWarned = false;

  /// One-time debug breadcrumb making it obvious that the file-backed dev
  /// keystore is active (and, by its absence, that release never takes this
  /// path).
  static void _warnDevDeviceLocalStoreOnce() {
    if (_devDeviceLocalStoreWarned) return;
    _devDeviceLocalStoreWarned = true;
    AppLogger.warning(
      '[SecureStorage] DEBUG build: Private-mode device-local secrets (the '
      'SQLCipher DB key + owner id) are read/written from a PLAINTEXT dev file '
      'instead of the Keychain, so a local `flutter run` keeps the same '
      'encrypted DB across restarts. This escape hatch is compiled out of '
      'release builds (gated on kDebugMode).',
    );
  }

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
  ///
  /// In DEBUG builds only, routes to the file-backed [_devDeviceLocalStore] so a
  /// local `flutter run` survives the unstable ad-hoc Team ID (see
  /// [DevDeviceLocalStore]). `kDebugMode` is a compile-time const, so the file
  /// branch is tree-shaken out of release builds — release reads the Keychain
  /// byte-for-byte as before.
  static Future<String?> readDeviceLocal(String key) {
    if (kDebugMode && !_isFlutterTest) {
      _warnDevDeviceLocalStoreOnce();
      return _devDeviceLocalStore.read(key);
    }
    return _deviceLocalStorage.read(key: key);
  }

  /// Delete a Private-Mode device-local secret (see [_deviceLocalStorage]).
  /// DEBUG-only file-backed in dev; real Keychain in release (see
  /// [readDeviceLocal]).
  static Future<void> deleteDeviceLocal(String key) {
    if (kDebugMode && !_isFlutterTest) {
      _warnDevDeviceLocalStoreOnce();
      return _devDeviceLocalStore.delete(key);
    }
    return _deviceLocalStorage.delete(key: key);
  }

  /// Write a Private-Mode device-local secret (see [_deviceLocalStorage]) with
  /// scoped -25299 recovery (never `deleteAll`). DEBUG-only file-backed in dev
  /// (the -25299 recovery is Keychain-specific and does not apply); real
  /// Keychain in release (see [readDeviceLocal]).
  static Future<void> writeDeviceLocal(
    String key,
    String value, {
    String context = 'SecureStorage(device-local)',
  }) {
    if (kDebugMode && !_isFlutterTest) {
      _warnDevDeviceLocalStoreOnce();
      return _devDeviceLocalStore.write(key, value);
    }
    return writeScoped(_deviceLocalStorage, key, value, context: context);
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
