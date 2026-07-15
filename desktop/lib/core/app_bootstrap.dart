import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  // Private mode never calls Supabase.initialize (see main.dart), so
  // `Supabase.instance.client` is uninitialized. Accessing it throws an
  // AssertionError in DEBUG (asserts on) but a LateInitializationError in
  // RELEASE (asserts stripped). Catching only AssertionError meant a Private-mode
  // user on a RELEASE build crashed the app root (EvolveDesktopApp watches this)
  // to a blank/grey screen. Catch ANY error and degrade to null — the app treats
  // null as "backend not configured" and routes straight into Private mode.
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});
