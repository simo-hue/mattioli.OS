import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notifications.dart';
import '../core/app_logger.dart';
import '../core/subscription_service.dart';
import '../core/secure_storage_utils.dart';
import '../core/data_mode.dart';
import '../core/private_local_database.dart';
import '../models/goal.dart';
import 'shared_prefs_provider.dart';
import 'auth_provider.dart';
import 'goal_provider.dart';

class AppLanguagePreference {
  static const system = 'system';
  static const italian = 'it';
  static const english = 'en';
  static const arabic = 'ar';
  static const spanish = 'es';
  static const german = 'de';

  static const supportedOverrides = [italian, english, spanish, german, arabic];

  /// Canonicalises a stored/typed language value.
  ///
  /// Delegates to [SettingsCodec.normalizeLanguage] — the shared parser — rather
  /// than keeping its own switch. The two implementations had already drifted:
  /// this one mapped the legacy label `'italiano'` to `system`, while macOS
  /// mapped it to `it`, so ONE synced value produced two different UI languages.
  /// The public API is kept because `localeOverrideFor`, `_loadFromPrefs`,
  /// `main.dart` and several screens call it.
  static String normalize(String? value) =>
      SettingsCodec.normalizeLanguage(value);

  static Locale? localeOverrideFor(String value) {
    final normalized = normalize(value);
    if (normalized == system) return null;
    return Locale(normalized);
  }
}

class AppSettings {
  final String themeMode;
  final Color accentColor;
  final String defaultCalendarView;
  final bool hapticFeedback;
  final String language;
  final bool timeFormat24h;

  // Pro / AI features (some local, some synced)
  final bool aiSuggestions;
  final bool isPro;
  final bool focusMode;
  final bool milestones;
  final bool deepWorkInsights;

  // Notifications
  final bool habitReminders;
  final bool goalDeadlines;
  final bool aiInsights;
  final bool weeklyReports;
  final bool eveningReview;

  // Auto-verified habits notifications (D11). Device-local (iOS-only) — kept in
  // SharedPreferences like [biometricLock] to avoid a settings-schema migration,
  // and not synced to Supabase. Nudges default on; celebration + failure summary
  // are opt-in.
  final bool verificationNudges;
  final bool verificationCelebrations;
  final bool verificationFailureSummary;

  // Privacy
  final bool biometricLock;

  // Notification Times
  final String morningBriefTime;
  final String eveningReviewTime;

  // Local UI State
  final String statsHabitFilter;

  const AppSettings({
    required this.themeMode,
    required this.accentColor,
    required this.defaultCalendarView,
    required this.hapticFeedback,
    required this.language,
    required this.timeFormat24h,
    required this.aiSuggestions,
    required this.isPro,
    required this.habitReminders,
    required this.goalDeadlines,
    required this.aiInsights,
    required this.weeklyReports,
    required this.focusMode,
    required this.milestones,
    required this.deepWorkInsights,
    required this.biometricLock,
    required this.eveningReview,
    required this.verificationNudges,
    required this.verificationCelebrations,
    required this.verificationFailureSummary,
    required this.morningBriefTime,
    required this.eveningReviewTime,
    required this.statsHabitFilter,
  });

  Locale? get localeOverride =>
      AppLanguagePreference.localeOverrideFor(language);

  AppSettings copyWith({
    String? themeMode,
    Color? accentColor,
    String? defaultCalendarView,
    bool? hapticFeedback,
    String? language,
    bool? timeFormat24h,
    bool? aiSuggestions,
    bool? isPro,
    bool? habitReminders,
    bool? goalDeadlines,
    bool? aiInsights,
    bool? weeklyReports,
    bool? focusMode,
    bool? milestones,
    bool? deepWorkInsights,
    bool? biometricLock,
    bool? eveningReview,
    bool? verificationNudges,
    bool? verificationCelebrations,
    bool? verificationFailureSummary,
    String? morningBriefTime,
    String? eveningReviewTime,
    String? statsHabitFilter,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      defaultCalendarView: defaultCalendarView ?? this.defaultCalendarView,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      language: language ?? this.language,
      timeFormat24h: timeFormat24h ?? this.timeFormat24h,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      isPro: isPro ?? this.isPro,
      habitReminders: habitReminders ?? this.habitReminders,
      goalDeadlines: goalDeadlines ?? this.goalDeadlines,
      aiInsights: aiInsights ?? this.aiInsights,
      weeklyReports: weeklyReports ?? this.weeklyReports,
      focusMode: focusMode ?? this.focusMode,
      milestones: milestones ?? this.milestones,
      deepWorkInsights: deepWorkInsights ?? this.deepWorkInsights,
      biometricLock: biometricLock ?? this.biometricLock,
      eveningReview: eveningReview ?? this.eveningReview,
      verificationNudges: verificationNudges ?? this.verificationNudges,
      verificationCelebrations:
          verificationCelebrations ?? this.verificationCelebrations,
      verificationFailureSummary:
          verificationFailureSummary ?? this.verificationFailureSummary,
      morningBriefTime: morningBriefTime ?? this.morningBriefTime,
      eveningReviewTime: eveningReviewTime ?? this.eveningReviewTime,
      statsHabitFilter: statsHabitFilter ?? this.statsHabitFilter,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  final NotificationService _notificationService = NotificationService();

  /// Canonical seed accent, kept identical to [SettingsCodec.defaultAccentColor]
  /// (`#FFFFFF`) — the `profiles.accent_color` DEFAULT. The Dart side used to
  /// seed `#FAFAFA` instead, so an untouched profile hydrated to a different
  /// colour depending on which side supplied the value.
  /// `test/settings_codec_test.dart` guards the two against drifting apart.
  static const Color defaultAccentColor = Color(0xFFFFFFFF);

  static const List<Color> premiumAccentColors = [
    defaultAccentColor, // Default White (== SettingsCodec.defaultAccentColor)
    Color(0xFFEAB308), // Amber/Gold
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFF97316), // Orange
  ];

  /// Substitute used when an accent would be invisible on a light background.
  static const Color _darkAccentFallback = Color(0xFF09090B); // Zinc 950

  /// The surfaces the accent has to stay legible against (AppColors.background
  /// for each theme).
  static const Color _lightBackground = Color(0xFFFFFFFF);
  static const Color _darkBackground = Color(0xFF09090B);

  /// Below this WCAG contrast ratio against the background the accent is not
  /// "low contrast", it is *gone* — white on white. 1.5 sits far under the 3.0
  /// AA large-text bar on purpose: this guard exists to prevent invisibility,
  /// not to police the user's taste.
  static const double _minAccentContrast = 1.5;

  /// Whether [_loadPrivateSettings] has finished. Until it has, `state` is the
  /// DEFAULT seed, not the user's stored settings — which is exactly why the old
  /// write-everything save was destructive.
  bool _privateLoaded = false;

  /// Synced keys the user changed BEFORE the load resolved. The load re-applies
  /// them on top of the loaded values, so a toggle flipped during a cold start
  /// is not silently snapped back a few frames later.
  final Set<String> _preloadEdits = <String>{};

  @override
  AppSettings build() {
    final dataMode = ref.watch(activeDataModeProvider);
    // 1. Caricamento sincrono iniziale da SharedPreferences (Offline-First)
    final state = dataMode == AppDataMode.private
        ? _defaultSettings().copyWith(
            isPro: true,
            // Seed the biometric lock synchronously so the lock engages on the
            // very first frame — the private settings row loads asynchronously
            // and would otherwise leave the app briefly unlocked on launch.
            biometricLock:
                ref.read(sharedPrefsProvider).getBool('pref_biometric_lock') ??
                false,
          )
        : _loadFromPrefs();

    if (dataMode == AppDataMode.private) {
      _loadPrivateSettings();
    } else {
      // Carica le impostazioni sicure in modo asincrono per garantire coerenza UI
      _loadSecureSettings();
    }

    // 2. Ascolta i cambi di autenticazione: se l'utente fa login, sincronizziamo da Supabase e RevenueCat
    ref.listen(authProvider, (previous, next) {
      if (next.dataMode == AppDataMode.supabase &&
          next.isLoggedIn &&
          next.user != null) {
        unawaited(_syncAccount(next.user!.id));
      }
    });

    // Sincronizzazione iniziale se già loggato al riavvio dell'app
    final authState = ref.read(authProvider);
    if (dataMode == AppDataMode.supabase &&
        authState.isLoggedIn &&
        authState.user != null) {
      unawaited(_syncAccount(authState.user!.id));
    }

    return state;
  }

  /// Pulls the account's server settings, then lets RevenueCat re-assert the
  /// entitlement. Ordered, not concurrent: `profiles.is_pro` is a mirror the
  /// webhook maintains, so RevenueCat — the actual source of truth, and the
  /// only one that sees a purchase before the webhook lands — must have the
  /// last word, or a briefly-stale row would strand a paying user on free.
  /// Neither call rethrows, so a failure in one never blocks the other.
  Future<void> _syncAccount(String userId) async {
    await _syncFromSupabase(userId);
    await ref.read(subscriptionServiceProvider).init(userId);
  }

  Future<void> _loadSecureSettings() async {
    try {
      final secureStorage = ref.read(secureStorageProvider);

      final biometricLockVal = await secureStorage.read(
        key: 'pref_biometric_lock',
      );
      final aiSuggestionsVal = await secureStorage.read(
        key: 'pref_ai_suggestions',
      );
      final isProVal = await secureStorage.read(key: 'pref_is_pro');
      final focusModeVal = await secureStorage.read(key: 'pref_focus_mode');
      final milestonesVal = await secureStorage.read(key: 'pref_milestones');
      final deepWorkInsightsVal = await secureStorage.read(
        key: 'pref_deep_work_insights',
      );

      state = state.copyWith(
        biometricLock: biometricLockVal != null
            ? biometricLockVal == 'true'
            : state.biometricLock,
        aiSuggestions: aiSuggestionsVal != null
            ? aiSuggestionsVal == 'true'
            : state.aiSuggestions,
        isPro: isProVal != null ? isProVal == 'true' : state.isPro,
        focusMode: focusModeVal != null
            ? focusModeVal == 'true'
            : state.focusMode,
        milestones: milestonesVal != null
            ? milestonesVal == 'true'
            : state.milestones,
        deepWorkInsights: deepWorkInsightsVal != null
            ? deepWorkInsightsVal == 'true'
            : state.deepWorkInsights,
      );
    } catch (e, stack) {
      AppLogger.error(
        'Errore nel caricamento delle impostazioni sicure in SettingsProvider',
        e,
        stack,
      );
    }
  }

  Future<void> _loadPrivateSettings() async {
    try {
      final store = ref.read(privateLocalDatabaseProvider);
      final row = await store.loadSettingsRow();
      // Two reads, two responsibilities: the profiles row still carries the
      // DEVICE-LOCAL columns (biometric lock), while every setting that travels
      // between devices comes from the shared SyncedSettingsStore — per-key rows
      // first, legacy profiles columns only as a fallback.
      final synced = await store.loadSyncedSettings();
      var loaded = _applySyncedSettings(_privateBaseSettings(row), synced);

      // Anything the user changed while this load was in flight wins over what
      // the load found. Those edits are ALREADY persisted (the write path fires
      // immediately); re-applying them here is purely so the visible state does
      // not snap back to the stored value a few frames after the tap.
      if (_preloadEdits.isNotEmpty) {
        final live = _syncedSettingsMap(state);
        loaded = _applySyncedSettings(loaded, {
          for (final e in live.entries)
            if (_preloadEdits.contains(e.key)) e.key: e.value,
        });
      }
      state = loaded;

      final prefs = ref.read(sharedPrefsProvider);
      // Mirror the biometric lock flag into SharedPreferences so the next cold
      // start can read it synchronously before the DB row loads (see build()).
      await prefs.setBool('pref_biometric_lock', state.biometricLock);
      // Mirror the language too. main.dart applies `pref_language` to slang
      // BEFORE the first frame, and Private mode never wrote that key (only the
      // cloud `_saveToPrefs` did) — so a private cold start rendered in a stale
      // cloud-era language, or the device locale, until this load resolved and
      // the whole UI visibly re-languaged. This is a one-way cache of a value
      // whose source of truth stays the private DB; it is not a settings leak
      // into the cloud store, and nothing ever reads it back in private mode.
      await prefs.setString('pref_language', state.language);
      // Deliberately NOT syncNotifications() here. This is a cold-start restore,
      // not a user gesture, and every schedule* call opens with
      // requestPermissions() — so re-syncing here fires the iOS permission alert
      // unprompted on the first Private-mode launch, which is exactly what the
      // deferred-prompt design (NOTIF-3) exists to avoid. Reminders are daily
      // repeats that iOS keeps pending across launches, and the cloud branch of
      // build() never re-syncs either; the prompt belongs to the notification
      // settings toggles and the habit add/edit path that already own it.
    } catch (e, stack) {
      AppLogger.error('[Settings] Private settings load error', e, stack);
      state = state.copyWith(isPro: true);
    } finally {
      // Set even on failure. Leaving this false would keep treating every later
      // write as "pre-load" forever, which is the wrong shape of caution: the
      // per-key diff is what protects the stored settings, not this flag.
      _privateLoaded = true;
      _preloadEdits.clear();
    }
  }

  // ── Modificatori ──────────────────────────────────────────────────────────

  void resetToDefaults() {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      final defaults = _defaultSettings().copyWith(isPro: true);
      state = defaults;
      _savePrivateDeviceLocal(defaults);
      // The ONE place a full write is right: the user explicitly asked for every
      // setting to go back to its default, so stamping all of them is the intent
      // rather than an accident of a stale in-memory snapshot.
      unawaited(_writeSyncedSettings(_syncedSettingsMap(defaults)));
      syncNotifications();
      return;
    }

    final prefs = ref.read(sharedPrefsProvider);
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('pref_')) {
        prefs.remove(key);
      }
    }
    state = _loadFromPrefs();
  }

  void updateSettings(AppSettings newSettings) {
    final previous = state;
    // Deliberately NO accent rewrite on a theme change. It used to happen here,
    // and because the accent is a SYNCED value the rewrite did not stay on this
    // phone: flipping the theme for a moment replaced the user's chosen colour
    // and pushed the replacement to every other device — and flipping back
    // pushed a third colour, since each mode's fallback is unreadable in the
    // other. Readability is now settled where it belongs, at render time, by
    // [readableAccent]; the stored value keeps being whatever the user picked.
    state = newSettings.copyWith(
      language: AppLanguagePreference.normalize(newSettings.language),
      morningBriefTime:
          SettingsCodec.normalizeTimeOfDay(newSettings.morningBriefTime) ??
              SettingsCodec.defaultMorningBriefTime,
      eveningReviewTime:
          SettingsCodec.normalizeTimeOfDay(newSettings.eveningReviewTime) ??
              SettingsCodec.defaultEveningReviewTime,
    );
    _persist(previous);
    syncNotifications();
  }

  void setAccentColor(Color color) {
    final previous = state;
    // Clamped only HERE: an explicit pick, made on this device, in this moment,
    // is the one point where correcting an invisible colour is honest and
    // visible to the user rather than a silent mutation of a synced value.
    state = state.copyWith(
      accentColor: _ensureSafeAccentColor(color, state.themeMode),
    );
    _persist(previous);
  }

  /// The accent as it should be PAINTED for [themeMode] — never as it is stored.
  ///
  /// Returns [color] untouched unless it is genuinely unreadable (contrast under
  /// [_minAccentContrast] against that theme's background, i.e. white-on-white
  /// territory), in which case the canonical seed for the opposite end is used.
  /// Callers pass [platformIsDark] because only they can see the platform
  /// brightness; `'system'` is resolved through [SettingsCodec.resolveIsDark] so
  /// a theme value written by macOS renders the same on both.
  static Color readableAccent(
    Color color,
    String? themeMode, {
    required bool platformIsDark,
  }) {
    final isDark = SettingsCodec.resolveIsDark(
      themeMode,
      platformIsDark: platformIsDark,
    );
    final background = isDark ? _darkBackground : _lightBackground;
    if (_contrastRatio(color, background) >= _minAccentContrast) return color;
    return isDark ? defaultAccentColor : _darkAccentFallback;
  }

  /// WCAG 2.x relative-contrast ratio, 1.0 (identical) to 21.0 (black/white).
  static double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  Color _ensureSafeAccentColor(Color color, String mode) => readableAccent(
        color,
        mode,
        platformIsDark: _platformIsDark(),
      );

  static bool _platformIsDark() =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark;

  void toggleAi(bool value) {
    if (state.isPro ||
        ref.read(activeDataModeProvider) == AppDataMode.private) {
      final previous = state;
      state = state.copyWith(aiSuggestions: value);
      _persist(previous);
      syncNotifications();
    }
  }

  /// Routes a just-applied state change to the right store.
  ///
  /// [previous] is what the state was BEFORE the change — the private branch
  /// needs it to work out which settings actually moved.
  void _persist(AppSettings previous) {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      state = state.copyWith(isPro: true);
      _savePrivateDeviceLocal(state, previous: previous);
      _savePrivateSynced(previous, state);
    } else {
      _saveToPrefs(state);
      _syncToSupabase(state);
    }
  }

  // ── Persistenza Locale (SharedPreferences) ────────────────────────────────

  AppSettings _loadFromPrefs() {
    final prefs = ref.read(sharedPrefsProvider);

    return AppSettings(
      themeMode: prefs.getString('pref_theme_mode') ?? 'dark',
      accentColor: _accentFromHex(prefs.getString('pref_accent_color')),
      defaultCalendarView:
          prefs.getString('pref_default_calendar_view') ??
          (Platform.isMacOS || Platform.isWindows || Platform.isLinux
              ? 'mese'
              : 'settimana'),
      hapticFeedback: prefs.getBool('pref_haptic_feedback') ?? true,
      language: AppLanguagePreference.normalize(
        prefs.getString('pref_language'),
      ),
      timeFormat24h: prefs.getBool('pref_time_format_24h') ?? true,

      aiSuggestions: prefs.getBool('pref_ai_suggestions') ?? false,
      isPro: prefs.getBool('pref_is_pro') ?? false,
      focusMode: prefs.getBool('pref_focus_mode') ?? false,
      milestones: prefs.getBool('pref_milestones') ?? true,
      deepWorkInsights: prefs.getBool('pref_deep_work_insights') ?? false,

      habitReminders: prefs.getBool('notif_habit_reminders') ?? true,
      goalDeadlines: prefs.getBool('notif_goal_deadlines') ?? true,
      aiInsights: prefs.getBool('notif_ai_insights') ?? false,
      weeklyReports: prefs.getBool('notif_weekly_reports') ?? false,
      eveningReview: prefs.getBool('notif_evening_review') ?? true,
      verificationNudges: prefs.getBool('notif_verification_nudges') ?? true,
      verificationCelebrations:
          prefs.getBool('notif_verification_celebrations') ?? false,
      verificationFailureSummary:
          prefs.getBool('notif_verification_failure_summary') ?? false,

      biometricLock: prefs.getBool('pref_biometric_lock') ?? false,

      morningBriefTime: SettingsCodec.normalizeTimeOfDay(
            prefs.getString('notif_morning_brief_time'),
          ) ??
          SettingsCodec.defaultMorningBriefTime,
      eveningReviewTime: SettingsCodec.normalizeTimeOfDay(
            prefs.getString('notif_evening_review_time'),
          ) ??
          SettingsCodec.defaultEveningReviewTime,
      statsHabitFilter: prefs.getString('pref_stats_habit_filter') ?? 'active',
    );
  }

  AppSettings _defaultSettings() {
    return AppSettings(
      themeMode: 'dark',
      accentColor: defaultAccentColor,
      defaultCalendarView: Platform.isMacOS || Platform.isWindows || Platform.isLinux
          ? 'mese'
          : 'settimana',
      hapticFeedback: true,
      language: AppLanguagePreference.system,
      timeFormat24h: true,
      aiSuggestions: false,
      isPro: false,
      focusMode: false,
      milestones: true,
      deepWorkInsights: false,
      habitReminders: true,
      goalDeadlines: true,
      aiInsights: false,
      weeklyReports: false,
      eveningReview: true,
      verificationNudges: true,
      verificationCelebrations: false,
      verificationFailureSummary: false,
      biometricLock: false,
      morningBriefTime: SettingsCodec.defaultMorningBriefTime,
      eveningReviewTime: SettingsCodec.defaultEveningReviewTime,
      statsHabitFilter: 'active',
    );
  }

  // ── Private mode: synced settings ─────────────────────────────────────────
  //
  // Every setting that travels between the iPhone and the Mac goes through the
  // shared [SyncedSettingsStore] against [PrivateDbSchema.syncedSettingKeys].
  // The two maps below are the ONLY translation between `AppSettings` and those
  // canonical keys, and they are exact inverses — a key that appears in one and
  // not the other is a setting that would save but never load back.

  static String _accentToHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';

  static Color _accentFromHex(String? hex) {
    final normalized = SettingsCodec.normalizeAccentColor(hex);
    if (normalized == null) return defaultAccentColor;
    return Color(int.parse('ff${normalized.substring(1)}', radix: 16));
  }

  /// [s] as canonical synced keys.
  ///
  /// A deliberate SUBSET of [PrivateDbSchema.syncedSettingKeys]:
  /// `pref_glass_effects`, `pref_start_week_on_monday`, `pref_show_weekend` and
  /// `tutorial_completed` have no iOS field, so iOS has no value for them worth
  /// writing — emitting an invented default would push macOS's real setting away,
  /// which is the exact failure this whole refactor removes.
  Map<String, String?> _syncedSettingsMap(AppSettings s) {
    String b(bool v) => SyncedSettingsStore.encodeBool(v);
    return {
      'language': AppLanguagePreference.normalize(s.language),
      'theme_mode': SettingsCodec.normalizeThemeMode(s.themeMode),
      'accent_color': _accentToHex(s.accentColor),
      'pref_default_calendar_view': s.defaultCalendarView,
      'pref_haptic_feedback': b(s.hapticFeedback),
      'pref_time_format_24h': b(s.timeFormat24h),
      'pref_ai_suggestions': b(s.aiSuggestions),
      'pref_focus_mode': b(s.focusMode),
      'pref_milestones': b(s.milestones),
      'pref_deep_work_insights': b(s.deepWorkInsights),
      'notif_habit_reminders': b(s.habitReminders),
      'notif_goal_deadlines': b(s.goalDeadlines),
      'notif_ai_insights': b(s.aiInsights),
      'notif_weekly_reports': b(s.weeklyReports),
      'notif_evening_review': b(s.eveningReview),
      'morning_brief_time':
          SettingsCodec.normalizeTimeOfDay(s.morningBriefTime) ??
              SettingsCodec.defaultMorningBriefTime,
      'evening_review_time':
          SettingsCodec.normalizeTimeOfDay(s.eveningReviewTime) ??
              SettingsCodec.defaultEveningReviewTime,
    };
  }

  /// Layers [values] onto [base]. A key that is absent — or present but null,
  /// i.e. explicitly unset — leaves [base]'s value standing, which is what makes
  /// [base] the place app defaults live.
  AppSettings _applySyncedSettings(
    AppSettings base,
    Map<String, String?> values,
  ) {
    bool? b(String key) => values.containsKey(key)
        ? SyncedSettingsStore.decodeBool(values[key])
        : null;
    String? s(String key) {
      final v = values[key];
      return (v == null || v.isEmpty) ? null : v;
    }

    return base.copyWith(
      language: values.containsKey('language')
          ? AppLanguagePreference.normalize(values['language'])
          : null,
      themeMode: s('theme_mode') == null
          ? null
          : SettingsCodec.normalizeThemeMode(values['theme_mode']),
      accentColor: s('accent_color') == null
          ? null
          : _accentFromHex(values['accent_color']),
      defaultCalendarView: s('pref_default_calendar_view'),
      hapticFeedback: b('pref_haptic_feedback'),
      timeFormat24h: b('pref_time_format_24h'),
      aiSuggestions: b('pref_ai_suggestions'),
      focusMode: b('pref_focus_mode'),
      milestones: b('pref_milestones'),
      deepWorkInsights: b('pref_deep_work_insights'),
      habitReminders: b('notif_habit_reminders'),
      goalDeadlines: b('notif_goal_deadlines'),
      aiInsights: b('notif_ai_insights'),
      weeklyReports: b('notif_weekly_reports'),
      eveningReview: b('notif_evening_review'),
      morningBriefTime:
          SettingsCodec.normalizeTimeOfDay(values['morning_brief_time']),
      eveningReviewTime:
          SettingsCodec.normalizeTimeOfDay(values['evening_review_time']),
    );
  }

  /// Defaults + the DEVICE-LOCAL half of Private mode: the `profiles` columns
  /// that never sync (biometric lock) and the SharedPreferences-only flags.
  /// Synced values are layered on top by [_applySyncedSettings].
  AppSettings _privateBaseSettings(Map<String, dynamic> row) {
    bool boolValue(String key, bool fallback) {
      final value = row[key];
      if (value is bool) return value;
      if (value is int) return value == 1;
      return fallback;
    }

    final prefs = ref.read(sharedPrefsProvider);
    return _defaultSettings().copyWith(
      // Private mode unlocks Pro locally; it is never gated on a server row.
      isPro: true,
      biometricLock: boolValue('biometric_lock', false),
      // Device-local (SharedPreferences), never part of the synced settings.
      verificationNudges: prefs.getBool('notif_verification_nudges') ?? true,
      verificationCelebrations:
          prefs.getBool('notif_verification_celebrations') ?? false,
      verificationFailureSummary:
          prefs.getBool('notif_verification_failure_summary') ?? false,
      statsHabitFilter: prefs.getString('pref_stats_habit_filter') ?? 'active',
    );
  }

  /// The device-local half of a Private-mode save. Never syncs.
  ///
  /// [previous] lets the `profiles` write be skipped when the biometric flag did
  /// not move: `updateSettingsRow` re-stamps `is_pro`/`sentry_consent` and bumps
  /// `updated_at` (marking the whole profile row dirty for sync), so calling it
  /// on every unrelated toggle was pure noise on the wire.
  void _savePrivateDeviceLocal(AppSettings s, {AppSettings? previous}) {
    final prefs = ref.read(sharedPrefsProvider);
    // UI-only preferences live in SharedPreferences to avoid a schema migration.
    prefs.setString('pref_stats_habit_filter', s.statsHabitFilter);
    // Mirror the biometric lock flag for a synchronous first-frame read on the
    // next cold start (the private DB row loads asynchronously).
    prefs.setBool('pref_biometric_lock', s.biometricLock);
    // See _loadPrivateSettings: main.dart applies this before the first frame.
    prefs.setString('pref_language', AppLanguagePreference.normalize(s.language));
    // Auto-verification notification prefs are device-local (iOS-only).
    prefs.setBool('notif_verification_nudges', s.verificationNudges);
    prefs.setBool('notif_verification_celebrations', s.verificationCelebrations);
    prefs.setBool(
      'notif_verification_failure_summary',
      s.verificationFailureSummary,
    );

    if (previous != null && previous.biometricLock == s.biometricLock) return;
    unawaited(
      _guarded(
        () => ref.read(privateLocalDatabaseProvider).updateSettingsRow({
          'biometric_lock': s.biometricLock ? 1 : 0,
        }),
        '[Settings] Private device-local write failed',
      ),
    );
  }

  /// The synced half of a Private-mode save: ONLY the keys that actually moved.
  ///
  /// This is the fix for the all-columns clobber. `build()` seeds state from
  /// `_defaultSettings()` synchronously while `_loadPrivateSettings()` is still
  /// in flight, so a toggle tapped in that window used to write DEFAULTS across
  /// all ~20 settings columns — silently reverting, on both devices, settings
  /// that only macOS even has UI for. Diffing means a toggle writes exactly one
  /// key, whatever the rest of the in-memory snapshot happens to be.
  void _savePrivateSynced(AppSettings previous, AppSettings next) {
    final before = _syncedSettingsMap(previous);
    final after = _syncedSettingsMap(next);
    final changed = <String, String?>{
      for (final e in after.entries)
        if (before[e.key] != e.value) e.key: e.value,
    };
    if (changed.isEmpty) return;
    // Remember pre-load edits so the in-flight load re-applies them instead of
    // snapping the UI back to the stored value (see _loadPrivateSettings).
    if (!_privateLoaded) _preloadEdits.addAll(changed.keys);
    unawaited(_writeSyncedSettings(changed));
  }

  Future<void> _writeSyncedSettings(Map<String, String?> values) => _guarded(
        () => ref.read(privateLocalDatabaseProvider).writeSyncedSettings(values),
        '[Settings] Private synced settings write failed',
      );

  Future<void> _guarded(Future<void> Function() action, String context) async {
    try {
      await action();
    } catch (e, stack) {
      AppLogger.error(context, e, stack);
    }
  }

  void _saveToPrefs(AppSettings s) {
    final prefs = ref.read(sharedPrefsProvider);

    prefs.setString('pref_theme_mode', s.themeMode);
    prefs.setString('pref_accent_color', _accentToHex(s.accentColor));
    prefs.setString('pref_default_calendar_view', s.defaultCalendarView);
    prefs.setBool('pref_haptic_feedback', s.hapticFeedback);
    prefs.setString(
      'pref_language',
      AppLanguagePreference.normalize(s.language),
    );
    prefs.setBool('pref_time_format_24h', s.timeFormat24h);

    prefs.setBool('pref_ai_suggestions', s.aiSuggestions);
    // is_pro is read-only from server, but we cache it
    prefs.setBool('pref_is_pro', s.isPro);
    prefs.setBool('pref_focus_mode', s.focusMode);
    prefs.setBool('pref_milestones', s.milestones);
    prefs.setBool('pref_deep_work_insights', s.deepWorkInsights);

    prefs.setBool('notif_habit_reminders', s.habitReminders);
    prefs.setBool('notif_goal_deadlines', s.goalDeadlines);
    prefs.setBool('notif_ai_insights', s.aiInsights);
    prefs.setBool('notif_weekly_reports', s.weeklyReports);
    prefs.setBool('notif_evening_review', s.eveningReview);
    prefs.setBool('notif_verification_nudges', s.verificationNudges);
    prefs.setBool(
        'notif_verification_celebrations', s.verificationCelebrations);
    prefs.setBool(
        'notif_verification_failure_summary', s.verificationFailureSummary);

    prefs.setBool('pref_biometric_lock', s.biometricLock);

    // Scrittura su SecureStorage per sicurezza (evita manipolazioni su dispositivi rooted)
    SecureStorageUtils.tryWrite(
      'pref_biometric_lock',
      s.biometricLock.toString(),
      context: '[Settings] biometric_lock',
    );
    SecureStorageUtils.tryWrite(
      'pref_ai_suggestions',
      s.aiSuggestions.toString(),
      context: '[Settings] ai_suggestions',
    );
    SecureStorageUtils.tryWrite(
      'pref_is_pro',
      s.isPro.toString(),
      context: '[Settings] is_pro',
    );
    SecureStorageUtils.tryWrite(
      'pref_focus_mode',
      s.focusMode.toString(),
      context: '[Settings] focus_mode',
    );
    SecureStorageUtils.tryWrite(
      'pref_milestones',
      s.milestones.toString(),
      context: '[Settings] milestones',
    );
    SecureStorageUtils.tryWrite(
      'pref_deep_work_insights',
      s.deepWorkInsights.toString(),
      context: '[Settings] deep_work_insights',
    );

    prefs.setString('notif_morning_brief_time', s.morningBriefTime);
    prefs.setString('notif_evening_review_time', s.eveningReviewTime);
    prefs.setString('pref_stats_habit_filter', s.statsHabitFilter);
  }

  // ── Sincronizzazione Supabase (Profiles) ──────────────────────────────────

  Future<void> _syncFromSupabase(String userId) async {
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        final serverSettings = state.copyWith(
          themeMode: data['theme_mode'] ?? state.themeMode,
          accentColor: data['accent_color'] != null
              ? _accentFromHex(data['accent_color'] as String?)
              : state.accentColor,
          defaultCalendarView:
              data['pref_default_calendar_view'] ?? state.defaultCalendarView,
          hapticFeedback: data['pref_haptic_feedback'] ?? state.hapticFeedback,
          language: AppLanguagePreference.normalize(
            data['language']?.toString() ?? state.language,
          ),
          timeFormat24h: data['pref_time_format_24h'] ?? state.timeFormat24h,
          // The server column is authoritative, not merely a grant: it is
          // written only by the RevenueCat webhook, so OR-ing it with the local
          // flag would make a legitimate expiry or refund unable to revoke Pro
          // for the rest of the session. Offline (or with no profile row) this
          // whole block never runs and the cached entitlement stands, and
          // RevenueCat re-asserts the truth right after — see _syncAccount.
          isPro: data['is_pro'] ?? false,
          habitReminders: data['notif_habit_reminders'] ?? state.habitReminders,
          goalDeadlines: data['notif_goal_deadlines'] ?? state.goalDeadlines,
          aiInsights: data['notif_ai_insights'] ?? state.aiInsights,
          weeklyReports: data['notif_weekly_reports'] ?? state.weeklyReports,
          eveningReview: data['notif_evening_review'] ?? state.eveningReview,
          // Biometric lock is a per-device security preference: a Face ID lock
          // set on THIS phone must not be silently disabled by a stale value —
          // or a value from another device — pulled from the server. Keep the
          // local value authoritative instead of letting the server win.
          biometricLock: state.biometricLock,
          morningBriefTime:
              data['morning_brief_time'] ?? state.morningBriefTime,
          eveningReviewTime:
              data['evening_review_time'] ?? state.eveningReviewTime,
        );

        state = serverSettings;
        _saveToPrefs(state);
      }
    } catch (e, stack) {
      AppLogger.error(
        '[Settings] Errore nel download impostazioni da Supabase',
        e,
        stack,
      );
    }
  }

  Future<void> _syncToSupabase(AppSettings s) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .from('profiles')
          .update({
            'theme_mode': s.themeMode,
            'accent_color': _accentToHex(s.accentColor),
            'pref_default_calendar_view': s.defaultCalendarView,
            'pref_haptic_feedback': s.hapticFeedback,
            'language': s.language,
            'pref_time_format_24h': s.timeFormat24h,
            // is_pro non lo inviamo per sicurezza, è gestito dal server
            'notif_habit_reminders': s.habitReminders,
            'notif_goal_deadlines': s.goalDeadlines,
            'notif_ai_insights': s.aiInsights,
            'notif_weekly_reports': s.weeklyReports,
            'notif_evening_review': s.eveningReview,
            'biometric_lock': s.biometricLock,
            'morning_brief_time': s.morningBriefTime,
            'evening_review_time': s.eveningReviewTime,
          })
          .eq('id', user.id);
    } catch (e, stack) {
      AppLogger.error(
        '[Settings] Errore nell\'upload impostazioni su Supabase',
        e,
        stack,
      );
      // Silenzioso, l'utente continuerà a usare le SharedPreferences locali
      // al prossimo riavvio l'app riproverà a sincronizzare se necessario
    }
  }

  // ── Notifiche ─────────────────────────────────────────────────────────────

  void syncNotifications() => unawaited(_runNotificationSync());

  Future<void> _runNotificationSync() async {
    // Snapshot every input before the first await. The schedules below are
    // awaited one at a time, which leaves the provider room to be disposed
    // (data-mode switch) part-way through — and a disposed Ref throws on both
    // `state` and `ref.read`.
    final settings = state;
    var goals = const <Goal>[];
    try {
      goals = ref.read(goalsProvider);
    } catch (e, stack) {
      AppLogger.error(
        '[Settings] Errore nella lettura delle abitudini',
        e,
        stack,
      );
    }

    try {
      await _notificationService.cancelAll();
      if (settings.focusMode) return;

      // Every schedule is awaited in turn. scheduleHabitReminder's iOS
      // pending-cap guard (NOTIF-4) reads the live pending count, so firing
      // these concurrently would have every call read the same near-zero count
      // taken just after cancelAll and pass — leaving iOS to silently drop
      // everything past 64. Awaiting is what makes the guard observe the count
      // it is guarding, and it counts the two briefs (which have no guard of
      // their own) against the cap.
      if (settings.habitReminders) {
        await _notificationService.scheduleDailyHabitReminder(
          timeStr: settings.morningBriefTime,
        );
      }

      if (settings.eveningReview) {
        await _notificationService.scheduleEveningReview(
          timeStr: settings.eveningReviewTime,
        );
      }

      // Schedule specific habit reminders
      for (final goal in goals) {
        if (goal.reminderTime != null) {
          await _notificationService.scheduleHabitReminder(
            goal.id,
            goal.title,
            goal.reminderTime,
            frequencyDays: goal.frequencyDays,
          );
        }
      }
    } catch (e, stack) {
      AppLogger.error(
        '[Settings] Errore nella schedulazione promemoria abitudini',
        e,
        stack,
      );
    }

    if (settings.aiInsights && settings.isPro) {
      // Placeholder for AI scheduling
    }

    if (settings.weeklyReports && settings.isPro) {
      // Placeholder for weekly scheduling
    }
  }
}

final settingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
