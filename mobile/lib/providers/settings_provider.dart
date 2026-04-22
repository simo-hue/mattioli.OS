import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notifications.dart';

class AppSettings {
  final String? _themeMode;
  final bool? _glassEffects;
  final Color? _accentColor;
  final String? _defaultCalendarView;
  final bool? _startWeekOnMonday;
  final bool? _showWeekend;
  final bool? _hapticFeedback;
  final String? _language;
  final bool? _timeFormat24h;
  final bool? _aiSuggestions;
  final bool? _isPro;

  // New Notification Settings
  final bool? _habitReminders;
  final bool? _goalDeadlines;
  final bool? _aiInsights;
  final bool? _weeklyReports;
  final bool? _focusMode;

  // New Privacy Settings
  final bool? _biometricLock;
  final bool? _anonymousAnalytics;

  AppSettings({
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
    bool? biometricLock,
    bool? anonymousAnalytics,
  })  : _themeMode = themeMode,
        _glassEffects = glassEffects,
        _accentColor = accentColor,
        _defaultCalendarView = defaultCalendarView,
        _startWeekOnMonday = startWeekOnMonday,
        _showWeekend = showWeekend,
        _hapticFeedback = hapticFeedback,
        _language = language,
        _timeFormat24h = timeFormat24h,
        _aiSuggestions = aiSuggestions,
        _isPro = isPro,
        _habitReminders = habitReminders,
        _goalDeadlines = goalDeadlines,
        _aiInsights = aiInsights,
        _weeklyReports = weeklyReports,
        _focusMode = focusMode,
        _biometricLock = biometricLock,
        _anonymousAnalytics = anonymousAnalytics;

  String get themeMode => _themeMode ?? 'dark';
  bool get glassEffects => _glassEffects ?? true;
  Color get accentColor => _accentColor ?? const Color(0xFFFFFFFF);
  String get defaultCalendarView => _defaultCalendarView ?? 'settimana';
  bool get startWeekOnMonday => _startWeekOnMonday ?? true;
  bool get showWeekend => _showWeekend ?? true;
  bool get hapticFeedback => _hapticFeedback ?? true;
  String get language => _language ?? 'Italiano';
  bool get timeFormat24h => _timeFormat24h ?? true;
  bool get aiSuggestions => _aiSuggestions ?? false;
  bool get isPro => _isPro ?? false;

  bool get habitReminders => _habitReminders ?? true;
  bool get goalDeadlines => _goalDeadlines ?? true;
  bool get aiInsights => _aiInsights ?? false;
  bool get weeklyReports => _weeklyReports ?? false;
  bool get focusMode => _focusMode ?? false;

  bool get biometricLock => _biometricLock ?? false;
  bool get anonymousAnalytics => _anonymousAnalytics ?? true;

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
    bool? biometricLock,
    bool? anonymousAnalytics,
  }) {
    return AppSettings(
      themeMode: themeMode ?? _themeMode,
      glassEffects: glassEffects ?? _glassEffects,
      accentColor: accentColor ?? _accentColor,
      defaultCalendarView: defaultCalendarView ?? _defaultCalendarView,
      startWeekOnMonday: startWeekOnMonday ?? _startWeekOnMonday,
      showWeekend: showWeekend ?? _showWeekend,
      hapticFeedback: hapticFeedback ?? _hapticFeedback,
      language: language ?? _language,
      timeFormat24h: timeFormat24h ?? _timeFormat24h,
      aiSuggestions: aiSuggestions ?? _aiSuggestions,
      isPro: isPro ?? _isPro,
      habitReminders: habitReminders ?? _habitReminders,
      goalDeadlines: goalDeadlines ?? _goalDeadlines,
      aiInsights: aiInsights ?? _aiInsights,
      weeklyReports: weeklyReports ?? _weeklyReports,
      focusMode: focusMode ?? _focusMode,
      biometricLock: biometricLock ?? _biometricLock,
      anonymousAnalytics: anonymousAnalytics ?? _anonymousAnalytics,
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
    return AppSettings(
      themeMode: 'dark',
      accentColor: premiumAccentColors[0],
      glassEffects: true,
      defaultCalendarView: 'giorno',
      startWeekOnMonday: true,
      showWeekend: true,
      hapticFeedback: true,
      language: 'Italiano',
      timeFormat24h: true,
      aiSuggestions: false,
    );
  }

  void updateSettings(AppSettings newSettings) {
    state = newSettings;
    _syncNotifications();
  }

  void setAccentColor(Color color) {
    state = state.copyWith(accentColor: color);
  }

  void toggleAi(bool value) {
    if (state.isPro) {
      state = state.copyWith(aiSuggestions: value);
      _syncNotifications();
    }
  }

  void _syncNotifications() {
    // Basic logic to sync with OS notifications
    _notificationService.cancelAll().then((_) {
      // If Focus Mode is ON, we might skip all or some (depending on implementation)
      // For now, if focusMode is on, we skip all as a simple implementation
      if (state.focusMode) return;

      if (state.habitReminders) {
        _notificationService.scheduleDailyHabitReminder();
      }
      
      // Goal deadlines, AI insights etc could be added here
      if (state.aiInsights && state.isPro) {
        // Placeholder for AI scheduling
      }
      
      if (state.weeklyReports) {
        // Placeholder for weekly scheduling
      }
    });
  }
}

final settingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);
