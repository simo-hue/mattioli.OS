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
    } catch (e, stack) {
      AppLogger.error(
        'SecureLocalStorage.accessToken error. Clearing auth session.',
        e,
        stack,
      );
      try {
        await SecureStorageUtils.delete(supabasePersistSessionKey);
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await SecureStorageUtils.containsKey(supabasePersistSessionKey);
    } catch (e, stack) {
      AppLogger.error(
        'SecureLocalStorage.hasAccessToken error. Clearing auth session.',
        e,
        stack,
      );
      try {
        await SecureStorageUtils.delete(supabasePersistSessionKey);
      } catch (_) {}
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
        clearAllOnDuplicateFailure: true,
      );
    } catch (e, stack) {
      AppLogger.error(
        'SecureLocalStorage.persistSession error. Clearing auth session.',
        e,
        stack,
      );
      try {
        await SecureStorageUtils.delete(supabasePersistSessionKey);
      } catch (_) {}
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await SecureStorageUtils.delete(supabasePersistSessionKey);
    } catch (e, stack) {
      AppLogger.error(
        'SecureLocalStorage.removePersistedSession error. Clearing auth session.',
        e,
        stack,
      );
      try {
        await SecureStorageUtils.delete(supabasePersistSessionKey);
      } catch (_) {}
    }
  }
}
