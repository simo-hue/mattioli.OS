import 'package:flutter/material.dart';

class AppColors {
  // --- DARK MODE (Original) ---
  static const Color background = Color(0xFF050608);
  static const Color card = Color(0xFF090A0F);
  static const Color cardElevated = Color(0xFF0D0E14);
  static const Color border = Color(0xFF272730);
  static const Color borderSubtle = Color(0x0DFFFFFF);
  static const Color borderHover = Color(0x1AFFFFFF);
  static const Color borderActive = Color(0x33FFFFFF);
  static const Color foreground = Color(0xFFFAFAFA);
  static const Color mutedForeground = Color(0xFFA1A1AA);
  static const Color muted = Color(0xFF272730);
  static const Color primary = Color(0xFFFAFAFA);
  static const Color success = Color(0xFF26C252);
  static const Color destructive = Color(0xFFEF4444);
  static const Color primaryTint = Color(0x33FAFAFA);

  // --- LIGHT MODE ---
  static const Color lightBackground = Color(0xFFF9FAFB); // Slate 50
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardElevated = Color(0xFFF3F4F6); // Gray 100
  static const Color lightBorder = Color(0xFFE5E7EB); // Gray 200
  static const Color lightBorderSubtle = Color(0x0F000000); // black/6
  static const Color lightBorderHover = Color(0x1A000000); // black/10
  static const Color lightBorderActive = Color(0x33000000); // black/20
  static const Color lightForeground = Color(0xFF0F172A); // Slate 900
  static const Color lightMutedForeground = Color(0xFF64748B); // Slate 500
  static const Color lightMuted = Color(0xFFF1F5F9); // Slate 100
  static const Color lightPrimary = Color(0xFF0F172A);
  static const Color lightPrimaryTint = Color(0x1A0F172A);
}

/// Custom Theme Extension for professional color management
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color background;
  final Color card;
  final Color cardElevated;
  final Color border;
  final Color borderSubtle;
  final Color borderHover;
  final Color borderActive;
  final Color foreground;
  final Color mutedForeground;
  final Color muted;
  final Color primary;
  final Color success;
  final Color destructive;
  final Color primaryTint;

  const AppColorsExtension({
    required this.background,
    required this.card,
    required this.cardElevated,
    required this.border,
    required this.borderSubtle,
    required this.borderHover,
    required this.borderActive,
    required this.foreground,
    required this.mutedForeground,
    required this.muted,
    required this.primary,
    required this.success,
    required this.destructive,
    required this.primaryTint,
  });

  @override
  AppColorsExtension copyWith({
    Color? background,
    Color? card,
    Color? cardElevated,
    Color? border,
    Color? borderSubtle,
    Color? borderHover,
    Color? borderActive,
    Color? foreground,
    Color? mutedForeground,
    Color? muted,
    Color? primary,
    Color? success,
    Color? destructive,
    Color? primaryTint,
  }) {
    return AppColorsExtension(
      background: background ?? this.background,
      card: card ?? this.card,
      cardElevated: cardElevated ?? this.cardElevated,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderHover: borderHover ?? this.borderHover,
      borderActive: borderActive ?? this.borderActive,
      foreground: foreground ?? this.foreground,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      muted: muted ?? this.muted,
      primary: primary ?? this.primary,
      success: success ?? this.success,
      destructive: destructive ?? this.destructive,
      primaryTint: primaryTint ?? this.primaryTint,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderHover: Color.lerp(borderHover, other.borderHover, t)!,
      borderActive: Color.lerp(borderActive, other.borderActive, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      success: Color.lerp(success, other.success, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
    );
  }
}

extension AppThemeX on BuildContext {
  AppColorsExtension get appColors => Theme.of(this).extension<AppColorsExtension>()!;
}

class AppTheme {
  static const AppColorsExtension darkColors = AppColorsExtension(
    background: AppColors.background,
    card: AppColors.card,
    cardElevated: AppColors.cardElevated,
    border: AppColors.border,
    borderSubtle: AppColors.borderSubtle,
    borderHover: AppColors.borderHover,
    borderActive: AppColors.borderActive,
    foreground: AppColors.foreground,
    mutedForeground: AppColors.mutedForeground,
    muted: AppColors.muted,
    primary: AppColors.primary,
    success: AppColors.success,
    destructive: AppColors.destructive,
    primaryTint: AppColors.primaryTint,
  );

  static const AppColorsExtension lightColors = AppColorsExtension(
    background: AppColors.lightBackground,
    card: AppColors.lightCard,
    cardElevated: AppColors.lightCardElevated,
    border: AppColors.lightBorder,
    borderSubtle: AppColors.lightBorderSubtle,
    borderHover: AppColors.lightBorderHover,
    borderActive: AppColors.lightBorderActive,
    foreground: AppColors.lightForeground,
    mutedForeground: AppColors.lightMutedForeground,
    muted: AppColors.lightMuted,
    primary: AppColors.lightPrimary,
    success: AppColors.success,
    destructive: AppColors.destructive,
    primaryTint: AppColors.lightPrimaryTint,
  );

  static ThemeData lightTheme(Color? accentColor) {
    final Color primaryColor = accentColor ?? AppColors.lightPrimary;
    // Inter is bundled (see pubspec `fonts:`), so this is a plain family
    // application — no package, no download. See core/fonts.dart.
    final baseTextTheme =
        ThemeData.light().textTheme.apply(fontFamily: 'Inter');

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: primaryColor,
      extensions: [lightColors],
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor,
        surface: AppColors.lightCard,
        onSurface: AppColors.lightForeground,
        error: AppColors.destructive,
        outline: AppColors.lightBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.lightForeground),
        titleTextStyle: TextStyle(
          color: AppColors.lightForeground,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.success;
          return AppColors.lightMutedForeground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.success.withValues(alpha: 0.5);
          return AppColors.lightBorder;
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      dividerColor: AppColors.lightBorder,
      textTheme: baseTextTheme.copyWith(
        displayLarge: const TextStyle(fontFamily: 'Inter', color: AppColors.lightForeground, fontWeight: FontWeight.w700, letterSpacing: -1.0),
        headlineLarge: const TextStyle(fontFamily: 'Inter', color: AppColors.lightForeground, fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -0.5),
        headlineMedium: const TextStyle(fontFamily: 'Inter', color: AppColors.lightForeground, fontWeight: FontWeight.w600, fontSize: 22, letterSpacing: -0.3),
        titleLarge: const TextStyle(fontFamily: 'Inter', color: AppColors.lightForeground, fontWeight: FontWeight.w600, fontSize: 18, letterSpacing: -0.2),
        titleMedium: const TextStyle(fontFamily: 'Inter', color: AppColors.lightForeground, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: const TextStyle(fontFamily: 'Inter', color: AppColors.lightForeground, fontSize: 15),
        bodyMedium: const TextStyle(fontFamily: 'Inter', color: AppColors.lightMutedForeground, fontSize: 13),
        bodySmall: const TextStyle(fontFamily: 'Inter', color: AppColors.lightMutedForeground, fontSize: 11),
        labelSmall: const TextStyle(fontFamily: 'Inter', color: AppColors.lightMutedForeground, fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData darkTheme(Color? accentColor) {
    final Color primaryColor = accentColor ?? AppColors.primary;
    // Inter is bundled (see pubspec `fonts:`), so this is a plain family
    // application — no package, no download. See core/fonts.dart.
    final baseTextTheme =
        ThemeData.dark().textTheme.apply(fontFamily: 'Inter');

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: primaryColor,
      extensions: [darkColors],
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
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.success;
          return AppColors.mutedForeground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.success.withValues(alpha: 0.5);
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
        displayLarge: const TextStyle(fontFamily: 'Inter', color: AppColors.foreground, fontWeight: FontWeight.w700, letterSpacing: -1.0),
        headlineLarge: const TextStyle(fontFamily: 'Inter', color: AppColors.foreground, fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -0.5),
        headlineMedium: const TextStyle(fontFamily: 'Inter', color: AppColors.foreground, fontWeight: FontWeight.w600, fontSize: 22, letterSpacing: -0.3),
        titleLarge: const TextStyle(fontFamily: 'Inter', color: AppColors.foreground, fontWeight: FontWeight.w600, fontSize: 18, letterSpacing: -0.2),
        titleMedium: const TextStyle(fontFamily: 'Inter', color: AppColors.foreground, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: const TextStyle(fontFamily: 'Inter', color: AppColors.foreground, fontSize: 15),
        bodyMedium: const TextStyle(fontFamily: 'Inter', color: AppColors.mutedForeground, fontSize: 13),
        bodySmall: const TextStyle(fontFamily: 'Inter', color: AppColors.mutedForeground, fontSize: 11),
        labelSmall: const TextStyle(fontFamily: 'Inter', color: AppColors.mutedForeground, fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w500),
      ),
    );
  }

  // Glass panel decoration
  static BoxDecoration glassPanelDecoration(BuildContext context, {double radius = 16}) {
    final colors = context.appColors;
    return BoxDecoration(
      color: colors.card.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colors.borderHover, width: 1),
    );
  }

  // Inner card decoration
  static BoxDecoration glassCardDecoration(BuildContext context, {double radius = 12}) {
    final colors = context.appColors;
    return BoxDecoration(
      color: colors.card.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colors.borderHover, width: 1),
    );
  }
}
