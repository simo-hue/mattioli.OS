import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/secure_storage_utils.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPrefsProvider must be overridden in main.dart',
  );
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return SecureStorageUtils.storage;
});
