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
  /// Canonical seed accent, kept identical to [SettingsCodec.defaultAccentColor]
  /// (`#FFFFFF`) — the `profiles.accent_color` DEFAULT, what
  /// `DesktopPrivateDb.seedProfile` writes, and what mobile seeds. Desktop
  /// seeded `#FAFAFA` instead, so an untouched profile hydrated to a different
  /// colour depending on which side supplied the value: the picker offered
  /// seven swatches with no checkmark on any of them, and tapping the white one
  /// pushed `#FAFAFA` to the iPhone, where white then rendered unselected and
  /// the accent fell into the Pro-locked "Custom" cell.
  /// `test/accent_parity_test.dart` guards the two against drifting apart.
  static const defaultAccent = Color(0xFFFFFFFF);

  /// What the OS currently reports.
  ///
  /// Used ONLY to resolve the legacy `desktop_dark_mode` bool at write time.
  /// It is deliberately not used to decide [ThemeMode] any more: a bare
  /// `PlatformDispatcher` read inside a Notifier registers no dependency, and
  /// nothing in this app observes `platformBrightness`, so resolving here
  /// happened once at launch and never again — macOS flipped to dark at sunset,
  /// the iPhone followed, and the Mac stayed light until it was relaunched.
  static bool get _platformIsDark =>
      ui.PlatformDispatcher.instance.platformBrightness == Brightness.dark;

  /// The one place a stored `theme_mode` string becomes a [ThemeMode], via the
  /// shared codec. Desktop used to say "anything that is not 'light' is dark"
  /// while mobile said "anything that is not 'dark' is light", so the `'system'`
  /// the schema explicitly permits rendered a dark Mac next to a light iPhone.
  ///
  /// `'system'` maps to [ThemeMode.system] and is NOT pre-resolved here. That
  /// is the whole point: `ThemeMode.system` is the only value that makes
  /// `MaterialApp` re-resolve when the OS appearance changes, and `'system'` is
  /// what every user who never picked a theme has — `normalizeThemeMode`
  /// returns it for null/unset/unrecognised input.
  static ThemeMode themeModeFor(String? stored) =>
      switch (SettingsCodec.normalizeThemeMode(stored)) {
        SettingsCodec.themeDark => ThemeMode.dark,
        SettingsCodec.themeLight => ThemeMode.light,
        _ => ThemeMode.system,
      };

  /// The inverse of [themeModeFor]: the canonical string both apps store.
  ///
  /// Used wherever the prefs mirror or the synced payload is written, so a
  /// three-valued mode can never be flattened into a two-valued one on its way
  /// out.
  static String themeCodeFor(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => SettingsCodec.themeDark,
    ThemeMode.light => SettingsCodec.themeLight,
    ThemeMode.system => SettingsCodec.themeSystem,
  };

  /// Whether [mode] renders dark right now — for the legacy `desktop_dark_mode`
  /// bool and for anything that genuinely needs a yes/no, never for deciding
  /// what to store.
  static bool resolvesDark(ThemeMode mode) =>
      SettingsCodec.resolveIsDark(
        themeCodeFor(mode),
        platformIsDark: _platformIsDark,
      );

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
    // Three-valued, or `_persist` destroys "follow system" — and it runs on
    // `setAccentColor` too, so merely picking a colour used to pin the user to
    // whichever theme the OS happened to be showing at that moment.
    final code = themeCodeFor(state.themeMode);
    // The LEGACY bool needs a yes/no, so 'system' is resolved for that key
    // alone. `build()` prefers `pref_theme_mode`, so this never decides the
    // mode for a device that has written it once.
    final isDark = resolvesDark(state.themeMode);
    final color = _toHex(state.accentColor);
    preferences
      ..setString('pref_theme_mode', code)
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

  /// The SHARED codec, not a private parser.
  ///
  /// This used to hand-roll `int.parse` over the raw string, which disagreed
  /// with mobile's [SettingsCodec.normalizeAccentColor] on every spelling the
  /// schema permits (`accent_color TEXT NOT NULL DEFAULT '#FFFFFF'` carries no
  /// CHECK, unlike `theme_mode`). The dangerous case was silent rather than
  /// loud: `int.parse` TRIMS, so `' #FF9500'` was 7 characters after the `#`
  /// was stripped — the `length == 6` guard declined to prepend the alpha,
  /// `int.parse` succeeded anyway, and the Mac seated an ALPHA-0 accent. It
  /// then became `ColorScheme.primary`/`secondary`, the checkbox fill and the
  /// focus ring, so the user got invisible buttons on macOS while the iPhone
  /// rendered the correct colour from the identical stored string, with no
  /// error and nothing in the log to pull on.
  ///
  /// The [fallback] parameter is the one deliberate difference from mobile:
  /// `applyProfile` passes the live accent so "the store has no opinion" keeps
  /// the current colour instead of snapping to [defaultAccent]. Do not collapse
  /// it.
  static Color _parseColor(String? value, {Color fallback = defaultAccent}) {
    final normalized = SettingsCodec.normalizeAccentColor(value);
    if (normalized == null) return fallback;
    return Color(int.parse('FF${normalized.substring(1)}', radix: 16));
  }

  /// `padLeft` before `substring`, matching `dashboardColorToHex`.
  ///
  /// Without it any colour whose leading alpha nibble is zero produces a
  /// 6-character `toRadixString(16)` and `substring(2, 8)` throws RangeError —
  /// an uncaught crash on an ordinary settings interaction, since `_persist`
  /// runs on every `setThemeMode`/`setAccentColor`. [_parseColor] now prevents
  /// such a colour from being constructed at all; this is the second line.
  static String _toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8).toUpperCase()}';

  static String? _legacyAccent(int? value) {
    if (value == null) return null;
    return '#${value.toRadixString(16).padLeft(8, '0').substring(2, 8)}';
  }
}
