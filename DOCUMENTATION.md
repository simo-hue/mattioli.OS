# Project Documentation

## Recent Changes

- [2026-04-27 12:15]: **Meticulous Global Accent Color Refactor**
  - *Details*: Performed a comprehensive audit and refactor of the entire Flutter application to ensure 100% visual coherence with the selected Accent Color. Replaced all hardcoded "Success Green" (0xFF10B981) and "Productivity Purple" (0xFF8B5CF6) with dynamic `Theme.of(context).colorScheme.primary`.
  - *Tech Notes*: 
    - Updated `HabitCalendarWidget` to use a dynamic HSL hue calculation for the completion gradient.
    - Standardized chart colors in `GlobalTrendTabWidget`, `HabitMoodTabWidget`, `GlobalMoodTabWidget`, and `MacroGoalsStatsView`.
    - Refactored stat cards and badges in `InfoTabWidget`, `DayDetailsModal`, and `HabitOverviewTabWidget`.
    - Updated modal actions and borders in `HabitManagementModal`.

- [2026-04-27 11:30]: **Chart Timeframe Selectors Coherence**
  - *Details*: Updated the timeframe selectors in the statistics charts to use the accent color for the selected state instead of neutral muted colors.

- [2026-04-27 11:15]: **Charts Accent Color Integration**
  - *Details*: Integrated the global accent color into the `_SmoothAreaChartPainter` for the Global Trend view.

- [2026-04-27 11:00]: **Global Accent Color Implementation**
  - *Details*: Fixed the issue where the accent color was not applied globally. Standardized the use of `Theme.of(context).colorScheme.primary` across settings, personal info, and navigation.

- [2026-05-06 17:31]: **AppBar Search Icon Removal**
  - *Details*: Removed the magnifying glass (search) icon from the dashboard AppBar to simplify the interface as requested.
  - *Tech Notes*: Modified `dashboard_screen.dart` to remove the `Icons.search_rounded` container and associated spacing.

- [2026-05-07 10:45]: **Dynamic User Greeting and Profile Avatar**
  - *Details*: Updated the dashboard AppBar to dynamically display the user's first name and profile picture from their Supabase profile. Previously, these were hardcoded to "Simone" and a static GitHub URL.
  - *Tech Notes*: Integrated `userProfileProvider` into `dashboard_screen.dart`. Replaced hardcoded strings and URLs with dynamic values from the watched provider.

- [2026-05-07 11:30]: **Professional Light Mode (White Mode) Implementation**
  - *Details*: Implemented a comprehensive and professional White Mode (Light Mode) across the entire application. Designed a premium light palette (Slate/Zinc) and migrated all UI components to a theme-aware architecture using `ThemeExtension`.
  - *Tech Notes*:
    - Created `AppColorsExtension` in `theme.dart` to provide semantic color access (e.g., `context.appColors.background`).
    - Implemented `AppTheme.lightTheme` with refined typography (Google Fonts Inter) and a soft Slate palette.
    - Updated `main.dart` to support dynamic switching between `theme` and `darkTheme` based on `settingsProvider`.
    - Refactored high-visibility screens and widgets including `AppSettingsScreen`, `HomeScreen`, `ProfileScreen`, `StatisticsScreen`, `MacroGoalsScreen`, `BottomNavBar`, and `HabitCalendarWidget`.
    - Ensured no "white-on-white" text bugs by auditing and replacing hardcoded `AppColors` with theme-aware values.

- [2026-05-07 11:50]: **Cleanup: Removal of SINCRO & CLOUD Section**
  - *Details*: Completely removed the "SINCRO & CLOUD" category and its sub-elements from the settings menu and localization files to streamline the interface and code.
  - *Tech Notes*:
    - Deleted the section in `app_settings_screen.dart`.
    - Removed related translation keys in `localization.dart`.

- [2026-05-07 18:27]: **Project Build and Dependency Sync**
  - *Details*: Executed the full project build. Resolved a "vite: command not found" error by performing a clean `npm install`.
  - *Tech Notes*:
    - Installed 541 packages.
    - Successfully ran `vite build` followed by `node scripts/generate-static-routes.js`.
    - Generated 6 static routes (features, faq, tech, philosophy, get-started, creator).

- [2026-05-13 07:45]: **Habit Statistics Real Data Integration**
  - *Details*: Removed mock data from the "Abitudini" tab in the statistics screen and connected it to real data from the database. Calculated current streak, best streak, completion rate, missed days, and 30-day trend dynamically.
  - *Tech Notes*:
    - Converted `HabitOverviewTabWidget` to `ConsumerWidget` to access `goalsProvider` and `habitLogsProvider`.
    - Implemented `_calculateStats` and `_calculateCorrelations` helper functions.
    - Updated `_TopStatsGrid`, `_TrendUltimi30Giorni`, and `_CorrelazioniSection` to accept dynamic data.
    - Handled frequency and active days for streak calculations.

- [2026-05-13 07:55]: **Global Habits Statistics Real Data Integration**
  - *Details*: Removed mock data from the global "Abitudini" tab (list of all habits) and connected it to real data from the database.
  - *Tech Notes*:
    - Converted `GlobalHabitsTabWidget` to `ConsumerStatefulWidget`.
    - Implemented `_calculateHabits` and `_calculateHabitStats` to compute BEST, WORST, SERIE, and RATE for each habit.
    - Replaced hardcoded `_habits` list with dynamic calculation.

## Current Status
- **Next Step**: Verify the changes in the app and address other mock panels in statistics if needed.
