import 'package:flutter/material.dart';

abstract final class EvolveColors {
  static const background = Color(0xFF080B10);
  static const sidebar = Color(0xFF0A0E14);
  static const panel = Color(0xFF10151D);
  static const panelRaised = Color(0xFF141B25);
  static const panelSoft = Color(0xFF18212D);
  static const border = Color(0xFF222D3B);
  static const borderStrong = Color(0xFF334154);
  static const foreground = Color(0xFFF4F7FB);
  static const muted = Color(0xFF8B98AA);
  static const subtle = Color(0xFF5E6B7D);
  static const primary = Color(0xFF9AE6B4);
  static const primaryStrong = Color(0xFF55C881);
  static const cyan = Color(0xFF67D8E8);
  static const amber = Color(0xFFF4B860);
  static const violet = Color(0xFFB89AF4);
  static const rose = Color(0xFFF08BA8);
}

abstract final class EvolveTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    const scheme = ColorScheme.dark(
      primary: EvolveColors.primary,
      onPrimary: Color(0xFF092113),
      secondary: EvolveColors.cyan,
      surface: EvolveColors.panel,
      onSurface: EvolveColors.foreground,
      error: Color(0xFFFF7D7D),
      outline: EvolveColors.border,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: EvolveColors.background,
      splashColor: EvolveColors.primary.withValues(alpha: 0.06),
      highlightColor: EvolveColors.primary.withValues(alpha: 0.04),
      dividerColor: EvolveColors.border,
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          color: EvolveColors.foreground,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.4,
        ),
        headlineMedium: const TextStyle(
          color: EvolveColors.foreground,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineSmall: const TextStyle(
          color: EvolveColors.foreground,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: const TextStyle(
          color: EvolveColors.foreground,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: const TextStyle(
          color: EvolveColors.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(
          color: EvolveColors.foreground,
          fontSize: 14,
          height: 1.45,
        ),
        bodyMedium: const TextStyle(
          color: EvolveColors.muted,
          fontSize: 13,
          height: 1.45,
        ),
        bodySmall: const TextStyle(
          color: EvolveColors.subtle,
          fontSize: 12,
          height: 1.35,
        ),
        labelLarge: const TextStyle(
          color: EvolveColors.foreground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EvolveColors.panelRaised,
        hintStyle: const TextStyle(color: EvolveColors.subtle),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: _inputBorder(EvolveColors.border),
        enabledBorder: _inputBorder(EvolveColors.border),
        focusedBorder: _inputBorder(EvolveColors.primaryStrong),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: EvolveColors.panelSoft,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: TextStyle(color: EvolveColors.foreground, fontSize: 12),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
  }
}
