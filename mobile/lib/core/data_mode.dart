import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_logger.dart';
import 'sentry_service.dart';
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
    final wasPrivate = state == AppDataMode.private;
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(_key, mode.name);
    AppLogger.setExternalReportingDisabled(mode == AppDataMode.private);
    state = mode;
    notifyListeners();

    // Leaving Private Mode: if the app started in Private Mode, Sentry was
    // never initialized. Late-init it now so crash reporting resumes — but only
    // with the user's previously-granted consent (SEC-4).
    if (wasPrivate && mode != AppDataMode.private) {
      final hasSentryConsent = prefs.getBool('has_sentry_consent') ?? true;
      if (hasSentryConsent) {
        await SentryService.ensureInitialized();
      }
    }
  }

  Future<void> enterPrivateMode() => setMode(AppDataMode.private);

  Future<void> enterSupabaseMode() => setMode(AppDataMode.supabase);
}

final activeDataModeProvider =
    NotifierProvider<ActiveDataModeNotifier, AppDataMode>(
      ActiveDataModeNotifier.new,
    );
