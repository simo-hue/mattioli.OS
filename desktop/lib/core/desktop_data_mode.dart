import 'dart:async';

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_sentry_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two mutually exclusive data modes for the desktop app.
enum DesktopDataMode {
  supabase,
  private;

  bool get isPrivate => this == DesktopDataMode.private;
}

/// Persists and exposes the active data mode.
///
/// Reads the saved value from [SharedPreferences] on build and writes back on
/// every mode change.  When entering Private mode, Sentry is disabled; when
/// leaving it, Sentry is re-enabled (if the user had granted crash-report
/// consent).
class ActiveDesktopDataModeNotifier extends Notifier<DesktopDataMode> {
  static const _key = 'active_data_mode';

  @override
  DesktopDataMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) return DesktopDataMode.supabase;
    final raw = prefs.getString(_key);
    final mode = raw == DesktopDataMode.private.name
        ? DesktopDataMode.private
        : DesktopDataMode.supabase;
    AppLogger.setExternalReportingDisabled(mode.isPrivate);
    return mode;
  }

  Future<void> setMode(DesktopDataMode mode) async {
    if (state == mode) return;
    final wasPrivate = state.isPrivate;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setString(_key, mode.name);
    AppLogger.setExternalReportingDisabled(mode.isPrivate);
    state = mode;

    // Sentry boundary: disable in Private mode, re-enable when leaving.
    if (mode.isPrivate) {
      await DesktopSentryService.setEnabled(false);
    } else if (wasPrivate) {
      final hasSentryConsent =
          prefs?.getBool('has_sentry_consent') ?? true;
      if (hasSentryConsent) {
        await DesktopSentryService.ensureInitialized();
      }
    }
  }

  Future<void> enterPrivateMode() => setMode(DesktopDataMode.private);

  Future<void> enterSupabaseMode() => setMode(DesktopDataMode.supabase);
}

final activeDesktopDataModeProvider =
    NotifierProvider<ActiveDesktopDataModeNotifier, DesktopDataMode>(
      ActiveDesktopDataModeNotifier.new,
    );
