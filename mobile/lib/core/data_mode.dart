import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_logger.dart';
import '../providers/shared_prefs_provider.dart';

enum AppDataMode {
  supabase,
  private;

  bool get isPrivate => this == AppDataMode.private;
}

class ActiveDataModeNotifier extends Notifier<AppDataMode> with ChangeNotifier {
  static const _key = 'active_data_mode';

  @override
  AppDataMode build() {
    final prefs = ref.read(sharedPrefsProvider);
    final raw = prefs.getString(_key);
    final mode = raw == AppDataMode.private.name
        ? AppDataMode.private
        : AppDataMode.supabase;
    AppLogger.setExternalReportingDisabled(mode == AppDataMode.private);
    return mode;
  }

  Future<void> setMode(AppDataMode mode) async {
    if (state == mode) return;
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(_key, mode.name);
    AppLogger.setExternalReportingDisabled(mode == AppDataMode.private);
    state = mode;
    notifyListeners();
  }

  Future<void> enterPrivateMode() => setMode(AppDataMode.private);

  Future<void> enterSupabaseMode() => setMode(AppDataMode.supabase);
}

final activeDataModeProvider =
    NotifierProvider<ActiveDataModeNotifier, AppDataMode>(
      ActiveDataModeNotifier.new,
    );
