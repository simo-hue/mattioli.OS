import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notifications.dart';
import '../core/app_logger.dart';
import 'shared_prefs_provider.dart';
import 'auth_provider.dart';
import 'goal_provider.dart';

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
  final bool anonymousAnalytics;

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
    required this.anonymousAnalytics,
    required this.eveningReview,
    required this.morningBriefTime,
    required this.eveningReviewTime,
  });

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
    bool? anonymousAnalytics,
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
      anonymousAnalytics: anonymousAnalytics ?? this.anonymousAnalytics,
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
    // 1. Caricamento sincrono iniziale da SharedPreferences (Offline-First)
    final state = _loadFromPrefs();

    // 2. Ascolta i cambi di autenticazione: se l'utente fa login, sincronizziamo da Supabase
    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        _syncFromSupabase(next.user!.id);
      }
    });

    // Sincronizzazione iniziale se già loggato al riavvio dell'app
    final authState = ref.read(authProvider);
    if (authState.isLoggedIn && authState.user != null) {
      _syncFromSupabase(authState.user!.id);
    }

    return state;
  }

  // ── Modificatori ──────────────────────────────────────────────────────────

  void resetToDefaults() {
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
    AppSettings finalSettings = newSettings;

    // Smart visibility check: adjust accent color if theme mode changes
    if (newSettings.themeMode != state.themeMode) {
      final safeAccent = _ensureSafeAccentColor(newSettings.accentColor, newSettings.themeMode);
      finalSettings = newSettings.copyWith(accentColor: safeAccent);
    }

    state = finalSettings;
    _saveToPrefs(state);
    _syncToSupabase(state);
    _syncNotifications();
  }

  void setAccentColor(Color color) {
    final safeColor = _ensureSafeAccentColor(color, state.themeMode);
    state = state.copyWith(accentColor: safeColor);
    _saveToPrefs(state);
    _syncToSupabase(state);
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
    if (state.isPro) {
      state = state.copyWith(aiSuggestions: value);
      _saveToPrefs(state);
      _syncToSupabase(state);
      _syncNotifications();
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
      defaultCalendarView: prefs.getString('pref_default_calendar_view') ?? 'settimana',
      hapticFeedback: prefs.getBool('pref_haptic_feedback') ?? true,
      language: prefs.getString('pref_language') ?? 'Italiano',
      timeFormat24h: prefs.getBool('pref_time_format_24h') ?? true,
      
      aiSuggestions: prefs.getBool('pref_ai_suggestions') ?? false,
      isPro: prefs.getBool('pref_is_pro') ?? true, // Default to true in dev
      focusMode: prefs.getBool('pref_focus_mode') ?? false,
      milestones: prefs.getBool('pref_milestones') ?? true,
      deepWorkInsights: prefs.getBool('pref_deep_work_insights') ?? false,
      
      habitReminders: prefs.getBool('notif_habit_reminders') ?? true,
      goalDeadlines: prefs.getBool('notif_goal_deadlines') ?? true,
      aiInsights: prefs.getBool('notif_ai_insights') ?? false,
      weeklyReports: prefs.getBool('notif_weekly_reports') ?? false,
      eveningReview: prefs.getBool('notif_evening_review') ?? true,
      
      biometricLock: prefs.getBool('pref_biometric_lock') ?? false,
      anonymousAnalytics: prefs.getBool('pref_anonymous_analytics') ?? true,
      
      morningBriefTime: prefs.getString('notif_morning_brief_time') ?? '09:00',
      eveningReviewTime: prefs.getString('notif_evening_review_time') ?? '21:00',
    );
  }

  void _saveToPrefs(AppSettings s) {
    final prefs = ref.read(sharedPrefsProvider);
    
    String toHex(Color color) => '#${color.value.toRadixString(16).substring(2, 8).toUpperCase()}';

    prefs.setString('pref_theme_mode', s.themeMode);
    prefs.setString('pref_accent_color', toHex(s.accentColor));
    prefs.setString('pref_default_calendar_view', s.defaultCalendarView);
    prefs.setBool('pref_haptic_feedback', s.hapticFeedback);
    prefs.setString('pref_language', s.language);
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
    // Anche nello storage sicuro per evitare manipolazioni
    ref.read(secureStorageProvider).write(key: 'pref_biometric_lock', value: s.biometricLock.toString());
    
    prefs.setBool('pref_anonymous_analytics', s.anonymousAnalytics);
    
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
            return Color(int.parse(hexString.replaceFirst('#', 'ff'), radix: 16));
          } catch (_) {
            return premiumAccentColors[0];
          }
        }

        final serverSettings = state.copyWith(
          themeMode: data['theme_mode'] ?? state.themeMode,
          accentColor: data['accent_color'] != null ? parseColor(data['accent_color']) : state.accentColor,
          defaultCalendarView: data['pref_default_calendar_view'] ?? state.defaultCalendarView,
          hapticFeedback: data['pref_haptic_feedback'] ?? state.hapticFeedback,
          language: data['language'] ?? state.language,
          timeFormat24h: data['pref_time_format_24h'] ?? state.timeFormat24h,
          isPro: data['is_pro'] ?? state.isPro,
          habitReminders: data['notif_habit_reminders'] ?? state.habitReminders,
          goalDeadlines: data['notif_goal_deadlines'] ?? state.goalDeadlines,
          aiInsights: data['notif_ai_insights'] ?? state.aiInsights,
          weeklyReports: data['notif_weekly_reports'] ?? state.weeklyReports,
          eveningReview: data['notif_evening_review'] ?? state.eveningReview,
          biometricLock: data['biometric_lock'] ?? state.biometricLock,
          anonymousAnalytics: data['anonymous_analytics'] ?? state.anonymousAnalytics,
          morningBriefTime: data['morning_brief_time'] ?? state.morningBriefTime,
          eveningReviewTime: data['evening_review_time'] ?? state.eveningReviewTime,
        );

        state = serverSettings;
        _saveToPrefs(state);
      }
    } catch (e, stack) {
      AppLogger.error('[Settings] Errore nel download impostazioni da Supabase', e, stack);
    }
  }

  Future<void> _syncToSupabase(AppSettings s) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      String toHex(Color color) => '#${color.value.toRadixString(16).substring(2, 8).toUpperCase()}';

      await supabase.from('profiles').update({
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
        'anonymous_analytics': s.anonymousAnalytics,
        'morning_brief_time': s.morningBriefTime,
        'evening_review_time': s.eveningReviewTime,
      }).eq('id', user.id);
    } catch (e, stack) {
      AppLogger.error('[Settings] Errore nell\'upload impostazioni su Supabase', e, stack);
      // Silenzioso, l'utente continuerà a usare le SharedPreferences locali
      // al prossimo riavvio l'app riproverà a sincronizzare se necessario
    }
  }

  // ── Notifiche ─────────────────────────────────────────────────────────────

  void _syncNotifications() {
    _notificationService.cancelAll().then((_) {
      if (state.focusMode) return;

      if (state.habitReminders) {
        _notificationService.scheduleDailyHabitReminder(timeStr: state.morningBriefTime);
      }

      if (state.eveningReview) {
        _notificationService.scheduleEveningReview(timeStr: state.eveningReviewTime);
      }
      
      // Schedule specific habit reminders
      try {
        final goals = ref.read(goalsProvider);
        for (final goal in goals) {
          if (goal.reminderTime != null) {
            _notificationService.scheduleHabitReminder(goal.id, goal.title, goal.reminderTime);
          }
        }
      } catch (e, stack) {
        AppLogger.error('[Settings] Errore nella schedulazione promemoria abitudini', e, stack);
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

final settingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);
