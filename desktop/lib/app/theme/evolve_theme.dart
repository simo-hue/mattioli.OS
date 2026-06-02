import 'package:flutter/material.dart';

abstract final class EvolveColors {
  static const background = Color(0xFF050608);
  static const sidebar = Color(0xFF050608);
  static const panel = Color(0xFF090A0F);
  static const panelRaised = Color(0xFF0D0E14);
  static const panelSoft = Color(0xFF171820);
  static const border = Color(0xFF272730);
  static const borderStrong = Color(0xFF3F3F46);
  static const foreground = Color(0xFFFAFAFA);
  static const muted = Color(0xFFA1A1AA);
  static const subtle = Color(0xFF71717A);
  static const primary = Color(0xFFFAFAFA);
  static const primaryStrong = Color(0xFFFAFAFA);

  static const lightBackground = Color(0xFFF9FAFB);
  static const lightSidebar = Color(0xFFFFFFFF);
  static const lightPanel = Color(0xFFFFFFFF);
  static const lightPanelRaised = Color(0xFFF3F4F6);
  static const lightPanelSoft = Color(0xFFF1F5F9);
  static const lightBorder = Color(0xFFE5E7EB);
  static const lightBorderStrong = Color(0xFFCBD5E1);
  static const lightForeground = Color(0xFF0F172A);
  static const lightMuted = Color(0xFF64748B);
  static const lightSubtle = Color(0xFF94A3B8);

  static const cyan = Color(0xFF3B82F6);
  static const amber = Color(0xFFEAB308);
  static const violet = Color(0xFF8B5CF6);
  static const rose = Color(0xFFEC4899);
}

class EvolvePalette extends ThemeExtension<EvolvePalette> {
  const EvolvePalette({
    required this.background,
    required this.sidebar,
    required this.panel,
    required this.panelRaised,
    required this.panelSoft,
    required this.border,
    required this.borderStrong,
    required this.foreground,
    required this.muted,
    required this.subtle,
  });

  final Color background;
  final Color sidebar;
  final Color panel;
  final Color panelRaised;
  final Color panelSoft;
  final Color border;
  final Color borderStrong;
  final Color foreground;
  final Color muted;
  final Color subtle;

  @override
  EvolvePalette copyWith({
    Color? background,
    Color? sidebar,
    Color? panel,
    Color? panelRaised,
    Color? panelSoft,
    Color? border,
    Color? borderStrong,
    Color? foreground,
    Color? muted,
    Color? subtle,
  }) {
    return EvolvePalette(
      background: background ?? this.background,
      sidebar: sidebar ?? this.sidebar,
      panel: panel ?? this.panel,
      panelRaised: panelRaised ?? this.panelRaised,
      panelSoft: panelSoft ?? this.panelSoft,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      foreground: foreground ?? this.foreground,
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
    );
  }

  @override
  EvolvePalette lerp(covariant EvolvePalette? other, double t) {
    if (other == null) return this;
    return EvolvePalette(
      background: Color.lerp(background, other.background, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelRaised: Color.lerp(panelRaised, other.panelRaised, t)!,
      panelSoft: Color.lerp(panelSoft, other.panelSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
    );
  }
}

extension EvolveThemeContext on BuildContext {
  EvolvePalette get evolveColors =>
      Theme.of(this).extension<EvolvePalette>()!;

  Color get evolveAccent => Theme.of(this).colorScheme.primary;
}

abstract final class EvolveTheme {
  static const _darkPalette = EvolvePalette(
    background: EvolveColors.background,
    sidebar: EvolveColors.sidebar,
    panel: EvolveColors.panel,
    panelRaised: EvolveColors.panelRaised,
    panelSoft: EvolveColors.panelSoft,
    border: EvolveColors.border,
    borderStrong: EvolveColors.borderStrong,
    foreground: EvolveColors.foreground,
    muted: EvolveColors.muted,
    subtle: EvolveColors.subtle,
  );

  static const _lightPalette = EvolvePalette(
    background: EvolveColors.lightBackground,
    sidebar: EvolveColors.lightSidebar,
    panel: EvolveColors.lightPanel,
    panelRaised: EvolveColors.lightPanelRaised,
    panelSoft: EvolveColors.lightPanelSoft,
    border: EvolveColors.lightBorder,
    borderStrong: EvolveColors.lightBorderStrong,
    foreground: EvolveColors.lightForeground,
    muted: EvolveColors.lightMuted,
    subtle: EvolveColors.lightSubtle,
  );

  static ThemeData dark([Color accentColor = EvolveColors.primary]) =>
      _theme(Brightness.dark, accentColor, _darkPalette);

  static ThemeData light([Color accentColor = EvolveColors.lightForeground]) =>
      _theme(Brightness.light, accentColor, _lightPalette);

  static ThemeData _theme(
    Brightness brightness,
    Color accentColor,
    EvolvePalette palette,
  ) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
      primary: accentColor,
      surface: palette.panel,
      error: const Color(0xFFEF4444),
    ).copyWith(
      onPrimary: _foregroundFor(accentColor),
      secondary: accentColor,
      outline: palette.border,
      onSurface: palette.foreground,
    );

    return base.copyWith(
      colorScheme: scheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.background,
      splashColor: accentColor.withValues(alpha: 0.06),
      highlightColor: accentColor.withValues(alpha: 0.04),
      dividerColor: palette.border,
      textTheme: base.textTheme.copyWith(
        displaySmall: TextStyle(
          color: palette.foreground,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.4,
        ),
        headlineMedium: TextStyle(
          color: palette.foreground,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineSmall: TextStyle(
          color: palette.foreground,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          color: palette.foreground,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          color: palette.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: palette.foreground,
          fontSize: 14,
          height: 1.45,
        ),
        bodyMedium: TextStyle(color: palette.muted, fontSize: 13, height: 1.45),
        bodySmall: TextStyle(color: palette.subtle, fontSize: 12, height: 1.35),
        labelLarge: TextStyle(
          color: palette.foreground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.panelRaised,
        hintStyle: TextStyle(color: palette.subtle),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: _inputBorder(palette.border),
        enabledBorder: _inputBorder(palette.border),
        focusedBorder: _inputBorder(accentColor),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.panelSoft,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: TextStyle(color: palette.foreground, fontSize: 12),
      ),
    );
  }

  static Color _foregroundFor(Color color) =>
      color.computeLuminance() > 0.45 ? const Color(0xFF09090B) : Colors.white;

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
  }
}
