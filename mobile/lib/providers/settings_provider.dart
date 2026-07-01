import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notifications.dart';
import '../core/app_logger.dart';
import '../core/subscription_service.dart';
import '../core/secure_storage_utils.dart';
import '../core/data_mode.dart';
import '../core/private_local_database.dart';
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

  static String normalize(String? value) {
    final normalized = value?.trim().toLowerCase();

    switch (normalized) {
      case null:
      case '':
      case system:
      case 'iphone':
      case 'ios':
      case 'device':
      case 'italiano':
      case 'english':
        return system;
      case italian:
      case 'it_it':
        return italian;
      case english:
      case 'en_us':
      case 'en_gb':
        return english;
      case arabic:
      case 'ar_sa':
      case 'ar_ae':
      case 'arabic':
      case 'العربية':
        return arabic;
      case spanish:
      case 'es_es':
      case 'es_mx':
      case 'spanish':
      case 'spagnolo':
      case 'espanol':
      case 'español':
        return spanish;
      case german:
      case 'de_de':
      case 'de_at':
      case 'de_ch':
      case 'german':
      case 'tedesco':
      case 'deutsch':
        return german;
      default:
        return system;
    }
  }

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

  // Privacy
  final bool biometricLock;

  // Notification Times
  final String morningBriefTime;
  final String eveningReviewTime;

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
    required this.morningBriefTime,
    required this.eveningReviewTime,
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
    String? morningBriefTime,
    String? eveningReviewTime,
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
      morningBriefTime: morningBriefTime ?? this.morningBriefTime,
      eveningReviewTime: eveningReviewTime ?? this.eveningReviewTime,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  final NotificationService _notificationService = NotificationService();

  static const List<Color> premiumAccentColors = [
    Color(0xFFFAFAFA), // Default White
    Color(0xFFEAB308), // Amber/Gold
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFF97316), // Orange
  ];

  @override
  AppSettings build() {
    final dataMode = ref.watch(activeDataModeProvider);
    // 1. Caricamento sincrono iniziale da SharedPreferences (Offline-First)
    final state = dataMode == AppDataMode.private
        ? _defaultSettings().copyWith(isPro: true)
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
        _syncFromSupabase(next.user!.id);
        ref.read(subscriptionServiceProvider).init(next.user!.id);
      }
    });

    // Sincronizzazione iniziale se già loggato al riavvio dell'app
    final authState = ref.read(authProvider);
    if (dataMode == AppDataMode.supabase &&
        authState.isLoggedIn &&
        authState.user != null) {
      _syncFromSupabase(authState.user!.id);
      ref.read(subscriptionServiceProvider).init(authState.user!.id);
    }

    return state;
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
      final row = await ref
          .read(privateLocalDatabaseProvider)
          .loadSettingsRow();
      state = _settingsFromPrivateRow(row);
      syncNotifications();
    } catch (e, stack) {
      AppLogger.error('[Settings] Private settings load error', e, stack);
      state = state.copyWith(isPro: true);
    }
  }

  // ── Modificatori ──────────────────────────────────────────────────────────

  void resetToDefaults() {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      final defaults = _defaultSettings().copyWith(isPro: true);
      state = defaults;
      _saveToPrivate(defaults);
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
    AppSettings finalSettings = newSettings.copyWith(
      language: AppLanguagePreference.normalize(newSettings.language),
    );

    // Smart visibility check: adjust accent color if theme mode changes
    if (finalSettings.themeMode != state.themeMode) {
      final safeAccent = _ensureSafeAccentColor(
        finalSettings.accentColor,
        finalSettings.themeMode,
      );
      finalSettings = finalSettings.copyWith(accentColor: safeAccent);
    }

    state = finalSettings;
    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      state = state.copyWith(isPro: true);
      _saveToPrivate(state);
    } else {
      _saveToPrefs(state);
      _syncToSupabase(state);
    }
    syncNotifications();
  }

  void setAccentColor(Color color) {
    final safeColor = _ensureSafeAccentColor(color, state.themeMode);
    state = state.copyWith(accentColor: safeColor);
    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      state = state.copyWith(isPro: true);
      _saveToPrivate(state);
    } else {
      _saveToPrefs(state);
      _syncToSupabase(state);
    }
  }

  /// Robust check to prevent "invisible" UI elements (e.g. white accent on white background)
  Color _ensureSafeAccentColor(Color color, String mode) {
    final double luminance = color.computeLuminance();

    if (mode == 'light') {
      // If switching to Light Mode, ensure the accent color is dark enough
      // luminance > 0.9 is basically white or very pale yellow
      if (luminance > 0.9) {
        return const Color(0xFF09090B); // Zinc 950 (Rich Black)
      }
    } else {
      // If switching to Dark Mode, ensure the accent color is light enough
      // luminance < 0.1 is very dark grey or black
      if (luminance < 0.1) {
        return const Color(0xFFFAFAFA); // Zinc 50 (Off White)
      }
    }
    return color;
  }

  void toggleAi(bool value) {
    if (state.isPro ||
        ref.read(activeDataModeProvider) == AppDataMode.private) {
      state = state.copyWith(aiSuggestions: value);
      if (ref.read(activeDataModeProvider) == AppDataMode.private) {
        state = state.copyWith(isPro: true);
        _saveToPrivate(state);
      } else {
        _saveToPrefs(state);
        _syncToSupabase(state);
      }
      syncNotifications();
    }
  }

  // ── Persistenza Locale (SharedPreferences) ────────────────────────────────

  AppSettings _loadFromPrefs() {
    final prefs = ref.read(sharedPrefsProvider);

    // Helper per leggere colori in esadecimale
    Color parseColor(String? hexString) {
      if (hexString == null || hexString.isEmpty) return premiumAccentColors[0];
      try {
        final buffer = StringBuffer();
        if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
        buffer.write(hexString.replaceFirst('#', ''));
        return Color(int.parse(buffer.toString(), radix: 16));
      } catch (e) {
        return premiumAccentColors[0];
      }
    }

    return AppSettings(
      themeMode: prefs.getString('pref_theme_mode') ?? 'dark',
      accentColor: parseColor(prefs.getString('pref_accent_color')),
      defaultCalendarView:
          prefs.getString('pref_default_calendar_view') ?? 'settimana',
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

      biometricLock: prefs.getBool('pref_biometric_lock') ?? false,

      morningBriefTime: prefs.getString('notif_morning_brief_time') ?? '09:00',
      eveningReviewTime:
          prefs.getString('notif_evening_review_time') ?? '21:00',
    );
  }

  AppSettings _defaultSettings() {
    return AppSettings(
      themeMode: 'dark',
      accentColor: premiumAccentColors[0],
      defaultCalendarView: 'settimana',
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
      biometricLock: false,
      morningBriefTime: '09:00',
      eveningReviewTime: '21:00',
    );
  }

  AppSettings _settingsFromPrivateRow(Map<String, dynamic> row) {
    Color parseColor(String? hexString) {
      if (hexString == null || hexString.isEmpty) return premiumAccentColors[0];
      try {
        final buffer = StringBuffer();
        if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
        buffer.write(hexString.replaceFirst('#', ''));
        return Color(int.parse(buffer.toString(), radix: 16));
      } catch (_) {
        return premiumAccentColors[0];
      }
    }

    bool boolValue(String key, bool fallback) {
      final value = row[key];
      if (value is bool) return value;
      if (value is int) return value == 1;
      return fallback;
    }

    return AppSettings(
      themeMode: row['theme_mode'] as String? ?? 'dark',
      accentColor: parseColor(row['accent_color'] as String?),
      defaultCalendarView:
          row['pref_default_calendar_view'] as String? ?? 'settimana',
      hapticFeedback: boolValue('pref_haptic_feedback', true),
      language: AppLanguagePreference.normalize(row['language'] as String?),
      timeFormat24h: boolValue('pref_time_format_24h', true),
      aiSuggestions: boolValue('pref_ai_suggestions', false),
      isPro: true,
      habitReminders: boolValue('notif_habit_reminders', true),
      goalDeadlines: boolValue('notif_goal_deadlines', true),
      aiInsights: boolValue('notif_ai_insights', false),
      weeklyReports: boolValue('notif_weekly_reports', false),
      focusMode: boolValue('pref_focus_mode', false),
      milestones: boolValue('pref_milestones', true),
      deepWorkInsights: boolValue('pref_deep_work_insights', false),
      biometricLock: boolValue('biometric_lock', false),
      eveningReview: boolValue('notif_evening_review', true),
      morningBriefTime: row['morning_brief_time'] as String? ?? '09:00',
      eveningReviewTime: row['evening_review_time'] as String? ?? '21:00',
    );
  }

  void _saveToPrivate(AppSettings s) {
    String toHex(Color color) =>
        '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';

    ref.read(privateLocalDatabaseProvider).updateSettingsRow({
      'theme_mode': s.themeMode,
      'accent_color': toHex(s.accentColor),
      'pref_default_calendar_view': s.defaultCalendarView,
      'pref_haptic_feedback': s.hapticFeedback ? 1 : 0,
      'language': AppLanguagePreference.normalize(s.language),
      'pref_time_format_24h': s.timeFormat24h ? 1 : 0,
      'pref_ai_suggestions': s.aiSuggestions ? 1 : 0,
      'pref_focus_mode': s.focusMode ? 1 : 0,
      'pref_milestones': s.milestones ? 1 : 0,
      'pref_deep_work_insights': s.deepWorkInsights ? 1 : 0,
      'notif_habit_reminders': s.habitReminders ? 1 : 0,
      'notif_goal_deadlines': s.goalDeadlines ? 1 : 0,
      'notif_ai_insights': s.aiInsights ? 1 : 0,
      'notif_weekly_reports': s.weeklyReports ? 1 : 0,
      'notif_evening_review': s.eveningReview ? 1 : 0,
      'biometric_lock': s.biometricLock ? 1 : 0,
      'morning_brief_time': s.morningBriefTime,
      'evening_review_time': s.eveningReviewTime,
      'is_pro': 1,
      'sentry_consent': 0,
    });
  }

  void _saveToPrefs(AppSettings s) {
    final prefs = ref.read(sharedPrefsProvider);

    String toHex(Color color) =>
        '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';

    prefs.setString('pref_theme_mode', s.themeMode);
    prefs.setString('pref_accent_color', toHex(s.accentColor));
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
        // Applica i dati dal server allo stato locale
        Color parseColor(String hexString) {
          try {
            return Color(
              int.parse(hexString.replaceFirst('#', 'ff'), radix: 16),
            );
          } catch (_) {
            return premiumAccentColors[0];
          }
        }

        final serverSettings = state.copyWith(
          themeMode: data['theme_mode'] ?? state.themeMode,
          accentColor: data['accent_color'] != null
              ? parseColor(data['accent_color'])
              : state.accentColor,
          defaultCalendarView:
              data['pref_default_calendar_view'] ?? state.defaultCalendarView,
          hapticFeedback: data['pref_haptic_feedback'] ?? state.hapticFeedback,
          language: AppLanguagePreference.normalize(
            data['language']?.toString() ?? state.language,
          ),
          timeFormat24h: data['pref_time_format_24h'] ?? state.timeFormat24h,
          isPro: state.isPro || (data['is_pro'] ?? false),
          habitReminders: data['notif_habit_reminders'] ?? state.habitReminders,
          goalDeadlines: data['notif_goal_deadlines'] ?? state.goalDeadlines,
          aiInsights: data['notif_ai_insights'] ?? state.aiInsights,
          weeklyReports: data['notif_weekly_reports'] ?? state.weeklyReports,
          eveningReview: data['notif_evening_review'] ?? state.eveningReview,
          biometricLock: data['biometric_lock'] ?? state.biometricLock,
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
      String toHex(Color color) =>
          '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';

      await supabase
          .from('profiles')
          .update({
            'theme_mode': s.themeMode,
            'accent_color': toHex(s.accentColor),
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

  void syncNotifications() {
    _notificationService.cancelAll().then((_) {
      if (state.focusMode) return;

      if (state.habitReminders) {
        _notificationService.scheduleDailyHabitReminder(
          timeStr: state.morningBriefTime,
        );
      }

      if (state.eveningReview) {
        _notificationService.scheduleEveningReview(
          timeStr: state.eveningReviewTime,
        );
      }

      // Schedule specific habit reminders
      try {
        final goals = ref.read(goalsProvider);
        for (final goal in goals) {
          if (goal.reminderTime != null) {
            _notificationService.scheduleHabitReminder(
              goal.id,
              goal.title,
              goal.reminderTime,
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

      if (state.aiInsights && state.isPro) {
        // Placeholder for AI scheduling
      }

      if (state.weeklyReports && state.isPro) {
        // Placeholder for weekly scheduling
      }
    });
  }
}

final settingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
