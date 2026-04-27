# DOCUMENTATION

## [2026-04-27 12:28]: Fixed Build Errors and Localization
*Details*: Fixed several compilation errors that prevented `flutter run` from executing. These included undefined variables in calendar widgets, invalid `const` usage with dynamic localizations, and missing `context` in helper methods. Also resolved duplicate key warnings in the localization system.
*Tech Notes*:
- Fixed `lib/ui/widgets/habit_calendar_widget.dart`: Declared `bgColor` and `borderColor` as local variables.
- Fixed `lib/ui/widgets/statistics/info_tab_widget.dart`, `habit_miglioramento_tab_widget.dart`, `habit_calendario_tab_widget.dart`: Removed invalid `const` on widgets containing `context.l10n.translate`.
- Fixed `lib/ui/widgets/statistics/habit_miglioramento_tab_widget.dart` and `habit_mood_tab_widget.dart`: Passed `BuildContext` to helper methods to allow access to `context.l10n` and `Theme.of(context)`.
- Fixed `lib/core/localization.dart`: Removed duplicate keys `mood`, `energy`, `positive_correlations`, and `negative_correlations`.
- Verified fix with `flutter build ios --simulator --debug`.
