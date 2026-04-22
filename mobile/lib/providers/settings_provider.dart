import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  final String? _themeMode;
  final Color? _accentColor;
  final bool? _glassEffects;
  final String? _defaultCalendarView;
  final bool? _startWeekOnMonday;
  final bool? _showWeekend;
  final bool? _hapticFeedback;
  final String? _language;
  final bool? _timeFormat24h;
  final bool? _aiSuggestions;
  final bool isPro;

  AppSettings({
    String? themeMode,
    Color? accentColor,
    bool? glassEffects,
    String? defaultCalendarView,
    bool? startWeekOnMonday,
    bool? showWeekend,
    bool? hapticFeedback,
    String? language,
    bool? timeFormat24h,
    bool? aiSuggestions,
    this.isPro = false,
  })  : _themeMode = themeMode,
        _accentColor = accentColor,
        _glassEffects = glassEffects,
        _defaultCalendarView = defaultCalendarView,
        _startWeekOnMonday = startWeekOnMonday,
        _showWeekend = showWeekend,
        _hapticFeedback = hapticFeedback,
        _language = language,
        _timeFormat24h = timeFormat24h,
        _aiSuggestions = aiSuggestions;

  String get themeMode => _themeMode ?? 'dark';
  Color get accentColor => _accentColor ?? const Color(0xFFFAFAFA);
  bool get glassEffects => _glassEffects ?? true;
  String get defaultCalendarView => _defaultCalendarView ?? 'giorno';
  bool get startWeekOnMonday => _startWeekOnMonday ?? true;
  bool get showWeekend => _showWeekend ?? true;
  bool get hapticFeedback => _hapticFeedback ?? true;
  String get language => _language ?? 'Italiano';
  bool get timeFormat24h => _timeFormat24h ?? true;
  bool get aiSuggestions => _aiSuggestions ?? false;

  AppSettings copyWith({
    String? themeMode,
    Color? accentColor,
    bool? glassEffects,
    String? defaultCalendarView,
    bool? startWeekOnMonday,
    bool? showWeekend,
    bool? hapticFeedback,
    String? language,
    bool? timeFormat24h,
    bool? aiSuggestions,
    bool? isPro,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      glassEffects: glassEffects ?? this.glassEffects,
      defaultCalendarView: defaultCalendarView ?? this.defaultCalendarView,
      startWeekOnMonday: startWeekOnMonday ?? this.startWeekOnMonday,
      showWeekend: showWeekend ?? this.showWeekend,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      language: language ?? this.language,
      timeFormat24h: timeFormat24h ?? this.timeFormat24h,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      isPro: isPro ?? this.isPro,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
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
  }

  void setAccentColor(Color color) {
    state = state.copyWith(accentColor: color);
  }

  void toggleAi(bool value) {
    if (state.isPro) {
      state = state.copyWith(aiSuggestions: value);
    }
  }
}

final settingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);
