import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/app_logger.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden in main.dart');
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final biometricLockProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  try {
    final val = await storage.read(key: 'pref_biometric_lock');
    return val == 'true';
  } catch (e, stack) {
    AppLogger.error('biometricLockProvider error (likely KeyStore corruption). Clearing storage.', e, stack);
    try {
      await storage.deleteAll();
    } catch (_) {}
    return false; // Assumiamo che il blocco sia disattivo per non bloccare l'utente
  }
});
