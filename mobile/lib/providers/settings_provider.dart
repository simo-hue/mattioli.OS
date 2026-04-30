import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notifications.dart';
import 'shared_prefs_provider.dart';
import 'auth_provider.dart';

class AppSettings {
  final String themeMode;
  final bool glassEffects;
  final Color accentColor;
  final String defaultCalendarView;
  final bool startWeekOnMonday;
  final bool showWeekend;
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

  const AppSettings({
    required this.themeMode,
    required this.glassEffects,
    required this.accentColor,
    required this.defaultCalendarView,
    required this.startWeekOnMonday,
    required this.showWeekend,
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
  });

  AppSettings copyWith({
    String? themeMode,
    bool? glassEffects,
    Color? accentColor,
    String? defaultCalendarView,
    bool? startWeekOnMonday,
    bool? showWeekend,
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
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      glassEffects: glassEffects ?? this.glassEffects,
      accentColor: accentColor ?? this.accentColor,
      defaultCalendarView: defaultCalendarView ?? this.defaultCalendarView,
      startWeekOnMonday: startWeekOnMonday ?? this.startWeekOnMonday,
      showWeekend: showWeekend ?? this.showWeekend,
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

  void updateSettings(AppSettings newSettings) {
    state = newSettings;
    _saveToPrefs(state);
    _syncToSupabase(state);
    _syncNotifications();
  }

  void setAccentColor(Color color) {
    state = state.copyWith(accentColor: color);
    _saveToPrefs(state);
    _syncToSupabase(state);
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
      glassEffects: prefs.getBool('pref_glass_effects') ?? true,
      defaultCalendarView: prefs.getString('pref_default_calendar_view') ?? 'settimana',
      startWeekOnMonday: prefs.getBool('pref_start_week_on_monday') ?? true,
      showWeekend: prefs.getBool('pref_show_weekend') ?? true,
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
    );
  }

  void _saveToPrefs(AppSettings s) {
    final prefs = ref.read(sharedPrefsProvider);
    
    String toHex(Color color) => '#${color.value.toRadixString(16).substring(2, 8).toUpperCase()}';

    prefs.setString('pref_theme_mode', s.themeMode);
    prefs.setString('pref_accent_color', toHex(s.accentColor));
    prefs.setBool('pref_glass_effects', s.glassEffects);
    prefs.setString('pref_default_calendar_view', s.defaultCalendarView);
    prefs.setBool('pref_start_week_on_monday', s.startWeekOnMonday);
    prefs.setBool('pref_show_weekend', s.showWeekend);
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
    prefs.setBool('pref_anonymous_analytics', s.anonymousAnalytics);
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
          glassEffects: data['pref_glass_effects'] ?? state.glassEffects,
          defaultCalendarView: data['pref_default_calendar_view'] ?? state.defaultCalendarView,
          startWeekOnMonday: data['pref_start_week_on_monday'] ?? state.startWeekOnMonday,
          showWeekend: data['pref_show_weekend'] ?? state.showWeekend,
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
        );

        state = serverSettings;
        _saveToPrefs(state);
      }
    } catch (e) {
      debugPrint('[Settings] Errore nel download impostazioni da Supabase: $e');
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
        'pref_glass_effects': s.glassEffects,
        'pref_default_calendar_view': s.defaultCalendarView,
        'pref_start_week_on_monday': s.startWeekOnMonday,
        'pref_show_weekend': s.showWeekend,
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
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('[Settings] Errore nell\'upload impostazioni su Supabase: $e');
      // Silenzioso, l'utente continuerà a usare le SharedPreferences locali
      // al prossimo riavvio l'app riproverà a sincronizzare se necessario
    }
  }

  // ── Notifiche ─────────────────────────────────────────────────────────────

  void _syncNotifications() {
    _notificationService.cancelAll().then((_) {
      if (state.focusMode) return;

      if (state.habitReminders) {
        _notificationService.scheduleDailyHabitReminder();
      }

      if (state.eveningReview) {
        _notificationService.scheduleEveningReview();
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
