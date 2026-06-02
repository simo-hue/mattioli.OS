import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopAppearance {
  const DesktopAppearance({required this.themeMode, required this.accentColor});

  final ThemeMode themeMode;
  final Color accentColor;

  DesktopAppearance copyWith({ThemeMode? themeMode, Color? accentColor}) {
    return DesktopAppearance(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

final desktopAppearanceControllerProvider =
    NotifierProvider<DesktopAppearanceController, DesktopAppearance>(
      DesktopAppearanceController.new,
    );

class DesktopAppearanceController extends Notifier<DesktopAppearance> {
  static const defaultAccent = Color(0xFFFAFAFA);

  @override
  DesktopAppearance build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    final themeMode =
        preferences?.getString('pref_theme_mode') ??
        ((preferences?.getBool('desktop_dark_mode') ?? true)
            ? 'dark'
            : 'light');
    final storedAccent =
        preferences?.getString('pref_accent_color') ??
        _legacyAccent(preferences?.getInt('accent_color'));

    final mode = themeMode == 'light' ? ThemeMode.light : ThemeMode.dark;
    return DesktopAppearance(
      themeMode: mode,
      accentColor: _ensureVisibleAccent(_parseColor(storedAccent), mode),
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(
      themeMode: mode,
      accentColor: _ensureVisibleAccent(state.accentColor, mode),
    );
    _persist();
  }

  void setAccentColor(Color color) {
    state = state.copyWith(
      accentColor: _ensureVisibleAccent(color, state.themeMode),
    );
    _persist();
  }

  void applyProfile({String? themeMode, String? accentColor}) {
    final mode = themeMode == 'light' ? ThemeMode.light : ThemeMode.dark;
    state = DesktopAppearance(
      themeMode: mode,
      accentColor: _ensureVisibleAccent(
        _parseColor(accentColor, fallback: state.accentColor),
        mode,
      ),
    );
    _persist();
  }

  void _persist() {
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences == null) return;
    final isDark = state.themeMode != ThemeMode.light;
    final color = _toHex(state.accentColor);
    preferences
      ..setString('pref_theme_mode', isDark ? 'dark' : 'light')
      ..setString('pref_accent_color', color)
      ..setBool('desktop_dark_mode', isDark)
      ..setInt('accent_color', state.accentColor.toARGB32());
  }

  static Color _ensureVisibleAccent(Color color, ThemeMode mode) {
    final luminance = color.computeLuminance();
    if (mode == ThemeMode.light && luminance > 0.9) {
      return const Color(0xFF09090B);
    }
    if (mode != ThemeMode.light && luminance < 0.1) {
      return defaultAccent;
    }
    return color;
  }

  static Color _parseColor(String? value, {Color fallback = defaultAccent}) {
    if (value == null || value.isEmpty) return fallback;
    try {
      final normalized = value.replaceFirst('#', '');
      final argb = normalized.length == 6 ? 'FF$normalized' : normalized;
      return Color(int.parse(argb, radix: 16));
    } on FormatException {
      return fallback;
    }
  }

  static String _toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';

  static String? _legacyAccent(int? value) {
    if (value == null) return null;
    return '#${value.toRadixString(16).padLeft(8, '0').substring(2, 8)}';
  }
}
