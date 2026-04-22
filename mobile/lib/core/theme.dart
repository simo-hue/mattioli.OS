import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Background: hsl(240 10% 2%) → #050608
  static const Color background = Color(0xFF050608);
  // Card: hsl(240 10% 3.9%) → #090A0F
  static const Color card = Color(0xFF090A0F);
  // Card slightly lighter for inner panels
  static const Color cardElevated = Color(0xFF0D0E14);
  // Border: hsl(240 3.7% 15.9%) → #272730
  static const Color border = Color(0xFF272730);
  // Border subtle (white/5)
  static const Color borderSubtle = Color(0x0DFFFFFF);
  // Border hover (white/10)
  static const Color borderHover = Color(0x1AFFFFFF);
  // Border active (white/20)
  static const Color borderActive = Color(0x33FFFFFF);
  // Foreground: hsl(0 0% 98%) → #FAFAFA
  static const Color foreground = Color(0xFFFAFAFA);
  // Muted foreground: hsl(240 5% 64.9%) → #A1A1AA
  static const Color mutedForeground = Color(0xFFA1A1AA);
  // Muted bg: hsl(240 3.7% 15.9%)
  static const Color muted = Color(0xFF272730);
  // Primary = foreground (white in dark mode)
  static const Color primary = Color(0xFFFAFAFA);
  // Success: hsl(142 70% 50%) → #26C252
  static const Color success = Color(0xFF26C252);
  // Destructive: hsl(0 62.8% 30.6%) → #7C1B1B
  static const Color destructive = Color(0xFFEF4444);
  // Tab active tint
  static const Color primaryTint = Color(0x33FAFAFA); // white/20
}

class AppTheme {
  static ThemeData darkTheme(Color? accentColor) {
    final Color primaryColor = accentColor ?? AppColors.primary;
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: AppColors.card,
        onSurface: AppColors.foreground,
        error: AppColors.destructive,
        outline: AppColors.border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.foreground),
        titleTextStyle: TextStyle(
          color: AppColors.foreground,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return AppColors.success;
          return AppColors.mutedForeground;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return AppColors.success.withValues(alpha: 0.5);
          return AppColors.border;
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dividerColor: AppColors.border,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(
          color: AppColors.foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        headlineLarge: GoogleFonts.inter(
          color: AppColors.foreground,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          color: AppColors.foreground,
          fontWeight: FontWeight.w600,
          fontSize: 22,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.inter(
          color: AppColors.foreground,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.inter(
          color: AppColors.foreground,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        bodyLarge: GoogleFonts.inter(
          color: AppColors.foreground,
          fontSize: 15,
        ),
        bodyMedium: GoogleFonts.inter(
          color: AppColors.mutedForeground,
          fontSize: 13,
        ),
        bodySmall: GoogleFonts.inter(
          color: AppColors.mutedForeground,
          fontSize: 11,
        ),
        labelSmall: GoogleFonts.inter(
          color: AppColors.mutedForeground,
          fontSize: 10,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Glass panel decoration (matches .glass-panel in PWA)
  static BoxDecoration glassPanelDecoration({double radius = 16}) {
    return BoxDecoration(
      color: AppColors.card.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.borderHover, width: 1),
    );
  }

  // Inner card decoration (matches .glass-card in PWA)
  static BoxDecoration glassCardDecoration({double radius = 12}) {
    return BoxDecoration(
      color: AppColors.card.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.borderHover, width: 1),
    );
  }
}
