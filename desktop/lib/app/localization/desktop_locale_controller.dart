import 'dart:ui';

import 'package:evolve_desktop/core/app_bootstrap.dart';
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
    final normalized = _normalize(language);
    final preferences = ref.read(sharedPreferencesProvider);
    preferences?.setString('pref_language', normalized);
    state = _localeFor(normalized);
  }

  static String _normalize(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'it' || 'italiano' => 'it',
      'en' || 'english' => 'en',
      'es' || 'espanol' => 'es',
      'de' || 'deutsch' => 'de',
      'ar' || 'arabic' => 'ar',
      _ => 'system',
    };
  }

  static Locale? _localeFor(String? value) {
    final language = _normalize(value);
    return language == 'system' ? null : Locale(language);
  }
}
