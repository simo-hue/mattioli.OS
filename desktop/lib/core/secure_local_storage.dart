import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_logger.dart';
import 'secure_storage_utils.dart';

class SecureLocalStorage extends LocalStorage {
  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    try {
      return await SecureStorageUtils.read(supabasePersistSessionKey);
    } catch (error, stack) {
      AppLogger.error('Unable to restore the Supabase session', error, stack);
      await _clearSession();
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await SecureStorageUtils.containsKey(supabasePersistSessionKey);
    } catch (error, stack) {
      AppLogger.error('Unable to inspect the Supabase session', error, stack);
      await _clearSession();
      return false;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await SecureStorageUtils.write(
        supabasePersistSessionKey,
        persistSessionString,
        context: 'SecureLocalStorage.persistSession',
      );
    } catch (error, stack) {
      AppLogger.error('Unable to persist the Supabase session', error, stack);
      await _clearSession();
    }
  }

  @override
  Future<void> removePersistedSession() => _clearSession();

  Future<void> _clearSession() async {
    try {
      await SecureStorageUtils.delete(supabasePersistSessionKey);
    } catch (error, stack) {
      AppLogger.error('Unable to clear the Supabase session', error, stack);
    }
  }
}
