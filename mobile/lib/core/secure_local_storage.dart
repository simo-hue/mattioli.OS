import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_logger.dart';

class SecureLocalStorage extends LocalStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: supabasePersistSessionKey);
    } catch (e, stack) {
      AppLogger.error('SecureLocalStorage.accessToken error. Clearing storage.', e, stack);
      try {
        await _storage.deleteAll();
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _storage.containsKey(key: supabasePersistSessionKey);
    } catch (e, stack) {
      AppLogger.error('SecureLocalStorage.hasAccessToken error. Clearing storage.', e, stack);
      try {
        await _storage.deleteAll();
      } catch (_) {}
      return false;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: supabasePersistSessionKey, value: persistSessionString);
    } catch (e, stack) {
      AppLogger.error('SecureLocalStorage.persistSession error. Clearing storage.', e, stack);
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: supabasePersistSessionKey);
    } catch (e, stack) {
      AppLogger.error('SecureLocalStorage.removePersistedSession error. Clearing storage.', e, stack);
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }
}
