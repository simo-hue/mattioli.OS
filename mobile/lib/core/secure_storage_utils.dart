import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_logger.dart';

class SecureStorageUtils {
  static const FlutterSecureStorage storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<String?> read(String key) {
    return storage.read(key: key);
  }

  static Future<bool> containsKey(String key) {
    return storage.containsKey(key: key);
  }

  static Future<void> delete(String key) {
    return storage.delete(key: key);
  }

  static Future<void> deleteAll() {
    return storage.deleteAll();
  }

  static Future<void> write(
    String key,
    String value, {
    String context = 'SecureStorage',
    bool clearAllOnDuplicateFailure = false,
  }) async {
    try {
      await storage.write(key: key, value: value);
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
        await storage.delete(key: key);
        await storage.write(key: key, value: value);
      } catch (retryError, retryStack) {
        AppLogger.error(
          clearAllOnDuplicateFailure
              ? '$context duplicate recovery failed for "$key"; clearing secure storage and retrying.'
              : '$context duplicate recovery failed for "$key".',
          retryError,
          retryStack,
        );
        if (!clearAllOnDuplicateFailure) {
          rethrow;
        }
        await storage.deleteAll();
        await storage.write(key: key, value: value);
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
