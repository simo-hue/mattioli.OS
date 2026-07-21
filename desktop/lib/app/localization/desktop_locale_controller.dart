import 'dart:ui';

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final desktopLocaleControllerProvider =
    NotifierProvider<DesktopLocaleController, Locale?>(
      DesktopLocaleController.new,
    );

class DesktopLocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return _localeFor(preferences?.getString('pref_language'));
  }

  void setLanguage(String language) {
    final normalized = SettingsCodec.normalizeLanguage(language);
    final preferences = ref.read(sharedPreferencesProvider);
    preferences?.setString('pref_language', normalized);
    state = _localeFor(normalized);
  }

  /// Applies a `language` value READ from the synced store. No-op when it
  /// resolves to the language already active, so a sync pull that carried an
  /// unchanged value doesn't churn the locale (and the prefs mirror) on every
  /// re-hydration.
  void applyProfile(String? language) {
    final normalized = SettingsCodec.normalizeLanguage(language);
    if (_localeFor(normalized) == state) return;
    setLanguage(normalized);
  }

  static Locale? _localeFor(String? value) {
    // ONE parser, shared with mobile: the two apps disagreed on the legacy
    // labels ('italiano' meant 'it' here and 'system' there), so one stored
    // value produced two different UI languages.
    final language = SettingsCodec.normalizeLanguage(value);
    return language == SettingsCodec.languageSystem ? null : Locale(language);
  }
}
