import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_logger.dart';

class SecureStorageUtils {
  const SecureStorageUtils._();

  static const FlutterSecureStorage storage = FlutterSecureStorage();

  static Future<String?> read(String key) => storage.read(key: key);

  static Future<bool> containsKey(String key) => storage.containsKey(key: key);

  static Future<void> delete(String key) => storage.delete(key: key);

  static Future<void> deleteAll() => storage.deleteAll();

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

      try {
        await storage.delete(key: key);
        await storage.write(key: key, value: value);
      } catch (retryError, retryStack) {
        AppLogger.error(
          '$context duplicate recovery failed for "$key"',
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
