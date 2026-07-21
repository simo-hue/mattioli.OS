import 'dart:ui' as ui;

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_sync/evolve_sync.dart';
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

  /// What the OS currently reports. Only [SettingsCodec.resolveIsDark] is
  /// allowed to decide what to DO with it.
  static bool get _platformIsDark =>
      ui.PlatformDispatcher.instance.platformBrightness == Brightness.dark;

  /// The one place a stored `theme_mode` string becomes a [ThemeMode], via the
  /// shared codec. Desktop used to say "anything that is not 'light' is dark"
  /// while mobile said "anything that is not 'dark' is light", so the `'system'`
  /// the schema explicitly permits rendered a dark Mac next to a light iPhone.
  static ThemeMode themeModeFor(String? stored) =>
      SettingsCodec.resolveIsDark(stored, platformIsDark: _platformIsDark)
      ? ThemeMode.dark
      : ThemeMode.light;

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

    final mode = themeModeFor(themeMode);
    return DesktopAppearance(
      themeMode: mode,
      accentColor: _parseColor(storedAccent),
    );
  }

  void setThemeMode(ThemeMode mode) {
    // The accent is NOT recomputed here. Coercing it on a theme flip persisted a
    // NEW colour and pushed it to every other device — so merely switching to
    // dark mode on the Mac silently changed the accent on the iPhone. Legibility
    // is now a paint-time concern ([readableAccent]); the stored value is
    // whatever the user actually chose.
    state = state.copyWith(themeMode: mode);
    _persist();
  }

  void setAccentColor(Color color) {
    state = state.copyWith(accentColor: color);
    _persist();
  }

  /// Applies a theme/accent pair that was READ from the synced store.
  ///
  /// A null argument means "the store has no opinion", so the current value is
  /// kept rather than coerced to a default — an absent `theme_mode` must not
  /// flip the user's Mac to whatever the fallback happens to be.
  ///
  /// This deliberately does NOT persist. It used to, and that made a pure read
  /// path a write path: `'system'` was coerced to `'dark'`, written back, and
  /// then pushed to every other device — the setting the user chose was
  /// destroyed by the act of reading it. The prefs mirror is written by the
  /// paths that actually own a change (`setThemeMode` / `setAccentColor`) and by
  /// the settings-page hydration, never here.
  void applyProfile({String? themeMode, String? accentColor}) {
    final mode = themeMode == null ? state.themeMode : themeModeFor(themeMode);
    // Applied VERBATIM. Running the legibility guard here made the same synced
    // accent render differently on the two devices — the orange-on-iPhone /
    // yellow-on-Mac symptom — because each device coerced the shared value
    // against its OWN theme. A synced value must be stored as sent; see
    // [readableAccent] for where legibility is handled instead.
    state = DesktopAppearance(
      themeMode: mode,
      accentColor: _parseColor(accentColor, fallback: state.accentColor),
    );
    // Deliberately does NOT write the local prefs mirror.
    //
    // The cost is a brief flash: on the next launch `build()` reads the stale
    // mirror and shows the old appearance until the launch sync re-applies the
    // synced value. That is a frame or two, and it self-heals every session.
    //
    // The alternative — persisting here — was measured and rejected: it makes a
    // read path write shared state, which cross-contaminated unrelated tests in
    // the full-suite run. A pure apply that flashes briefly is a better trade
    // than a read path with side effects, which is the exact shape of the bug
    // this method already had once (it used to persist a COERCED value and push
    // it to every device).
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

  /// The accent to PAINT WITH for [brightness] — never the accent to store.
  ///
  /// Split from the stored value deliberately: an accent that is illegible in
  /// one theme is still the user's choice, and rewriting it on a theme change
  /// both destroys that choice and (once synced) changes the colour on every
  /// other device. Substituting at paint time keeps the stored value stable and
  /// identical everywhere, which is the whole point of syncing it.
  static Color readableAccent(Color color, Brightness brightness) =>
      _ensureVisibleAccent(
        color,
        brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
      );

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
