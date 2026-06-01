import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final backendConfiguredProvider = Provider<bool>((ref) => false);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!ref.watch(backendConfiguredProvider)) return null;
  return Supabase.instance.client;
});
