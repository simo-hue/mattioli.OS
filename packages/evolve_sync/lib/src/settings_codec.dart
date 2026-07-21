/// Canonical encodings for settings that travel between devices.
///
/// Every one of these lives here rather than in either app because the two
/// clients previously each had their OWN parser, and they disagreed:
///
///  * `theme_mode` — desktop resolved anything that was not `'light'` to DARK,
///    mobile resolved anything that was not `'dark'` to LIGHT. The schema CHECK
///    permits `'system'`, so the same stored string rendered a dark Mac and a
///    light iPhone. Worse, desktop re-persisted its coerced value on load, so a
///    read path mutated a synced column and pushed the coercion to every device.
///  * `language` — both apps accept legacy display labels, but disagreed on
///    them: `'italiano'` meant `'it'` on macOS and `'system'` on iOS.
///
/// A shared value needs a shared parser. Two parsers for one wire format is not
/// a style problem, it is a divergence waiting for an input neither author
/// tested.
class SettingsCodec {
  SettingsCodec._();

  // ── theme_mode ────────────────────────────────────────────────────────────

  static const String themeDark = 'dark';
  static const String themeLight = 'light';
  static const String themeSystem = 'system';

  /// The only values the `profiles.theme_mode` CHECK accepts.
  static const List<String> themeModes = [themeDark, themeLight, themeSystem];

  /// Parse a stored `theme_mode` into a canonical value.
  ///
  /// Unknown input resolves to [themeSystem] rather than to a concrete theme:
  /// guessing dark-or-light is what made the two apps disagree, and "follow the
  /// device" is the one answer that is defensible on both.
  static String normalizeThemeMode(String? value) {
    switch (value?.trim().toLowerCase()) {
      case themeDark:
      case 'scuro':
      case 'true': // legacy: a boolean "dark mode" switch
        return themeDark;
      case themeLight:
      case 'chiaro':
      case 'false':
        return themeLight;
      default:
        return themeSystem;
    }
  }

  /// Whether [value] should render dark, given what the OS currently reports.
  ///
  /// The SINGLE place either app is allowed to answer that question. Callers
  /// pass [platformIsDark] because only they can see the platform brightness;
  /// the decision itself stays here.
  static bool resolveIsDark(String? value, {required bool platformIsDark}) {
    switch (normalizeThemeMode(value)) {
      case themeDark:
        return true;
      case themeLight:
        return false;
      default:
        return platformIsDark;
    }
  }

  // ── language ──────────────────────────────────────────────────────────────

  static const String languageSystem = 'system';
  static const List<String> languageCodes = ['it', 'en', 'es', 'de', 'ar'];

  /// Parse a stored `language` into `'system'` or a supported code.
  ///
  /// Accepts the legacy display labels older builds wrote (`'italiano'`,
  /// `'english'`, …) and — unlike the two previous implementations — maps them
  /// CONSISTENTLY to their real code. Mobile used to send `'italiano'` to
  /// `'system'` while macOS sent it to `'it'`, so one stored value produced two
  /// different UI languages.
  static String normalizeLanguage(String? value) {
    final v = value?.trim().toLowerCase();
    switch (v) {
      case null:
      case '':
      case languageSystem:
      case 'device':
      case 'ios':
      case 'iphone':
      case 'macos':
        return languageSystem;
      case 'it':
      case 'it_it':
      case 'italiano':
      case 'italian':
        return 'it';
      case 'en':
      case 'en_us':
      case 'en_gb':
      case 'english':
      case 'inglese':
        return 'en';
      case 'es':
      case 'es_es':
      case 'spanish':
      case 'spagnolo':
      case 'espanol':
      case 'español':
        return 'es';
      case 'de':
      case 'de_de':
      case 'german':
      case 'tedesco':
      case 'deutsch':
        return 'de';
      case 'ar':
      case 'ar_sa':
      case 'arabic':
      case 'arabo':
        return 'ar';
      default:
        return languageSystem;
    }
  }

  // ── time-of-day ───────────────────────────────────────────────────────────

  /// Canonical defaults for the two daily briefs.
  ///
  /// These match the `profiles` schema DEFAULTs. macOS's field initialisers used
  /// to say `08:00`/`20:30`, which won whenever SharedPreferences was empty —
  /// so a first-launch Mac moved the iPhone's briefs 60 and 30 minutes earlier
  /// the first time any notification toggle was touched.
  static const String defaultMorningBriefTime = '09:00';
  static const String defaultEveningReviewTime = '21:00';

  /// Both apps store times as `'HH:mm'`. Returns null for anything that is not,
  /// so a malformed value falls back to a default instead of scheduling a brief
  /// at an unintended hour.
  static String? normalizeTimeOfDay(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  // ── accent colour ─────────────────────────────────────────────────────────

  /// Canonical seed accent, matching the `profiles.accent_color` DEFAULT.
  ///
  /// The DB seeded `#FFFFFF` while the Dart default was `#FAFAFA`, so an
  /// untouched profile hydrated to a different colour depending on which side
  /// supplied the value.
  static const String defaultAccentColor = '#FFFFFF';

  /// `'#RRGGBB'`, uppercased, or null if unparseable. Accepts `'#AARRGGBB'` and
  /// a bare hex string so a value written by either app round-trips.
  static String? normalizeAccentColor(String? value) {
    var v = value?.trim().toUpperCase();
    if (v == null || v.isEmpty) return null;
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 8) v = v.substring(2); // drop alpha
    if (v.length != 6 || !RegExp(r'^[0-9A-F]{6}$').hasMatch(v)) return null;
    return '#$v';
  }
}
