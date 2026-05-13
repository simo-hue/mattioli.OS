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

- [2026-05-13 08:05]: **Database View Integration for Habit Statistics**
  - *Details*: Optimized the habit statistics panel by using a Supabase view (`habit_stats`) to calculate metrics (streaks, rate) instead of doing it in memory.
  - *Tech Notes*:
    - Added `habitStatsProvider` (FutureProvider) in `goal_provider.dart`.
    - Added invalidation of `habitStatsProvider` in `cycleStatus` to refresh data on changes.
    - Updated `GlobalHabitsTabWidget` to use `habitStatsProvider` and handle async states.

- [2026-05-13 08:50]: **Single Habit Statistics Optimization & Security Fix**
  - *Details*: Optimized the single habit details view (`HabitOverviewTabWidget`) to use the database view for main stats. Also fixed a security issue in the database view by adding `security_invoker = true`.
  - *Tech Notes*:
    - Updated `habit_stats` view to include `security_invoker = true` and additional fields (`total_completions`, `missed_days`, `total_active_days`).
    - Updated `HabitOverviewTabWidget` to use `habitStatsProvider` and mapped the data.
    - Extracted `_calculateTrend30Days` and removed the heavy `_calculateStats` function.

- [2026-05-13 08:52]: **Habit Calendar Real Data Integration**
  - *Details*: Removed mock data from the "Trend" tab of single habits (`HabitCalendarioTabWidget`) and connected it to real data from `habitLogsProvider`.
  - *Tech Notes*:
    - Converted `HabitCalendarioTabWidget` to `ConsumerWidget`.
    - Implemented `_calculateYearlyData` to generate 365 days of status based on real logs.
    - Updated `_CalendarioAnnualeCard` to accept and display the calculated data.

- [2026-05-13 08:53]: **Habit Calendar Color Fix**
  - *Details*: Changed the completion color in `HabitCalendarioTabWidget` from the dynamic accent color (which appeared white) to a fixed solid green.
  - *Tech Notes*: Updated `habit_calendario_tab_widget.dart` to use `0xFF10B981` (Emerald Green) for `status == 1`.

- [2026-05-13 08:55]: **Habit Performance Real Data Integration**
  - *Details*: Removed mock data from the "Stats" tab of single habits (`HabitPerformanceTabWidget`) and connected it to real data from `habitLogsProvider`.
  - *Tech Notes*:
    - Converted `HabitPerformanceTabWidget` to `ConsumerWidget`.
    - Implemented `_calculatePerformance` to compute completion rates for each day of the week.
    - Added dynamic calculation of strongest and weakest days.

- [2026-05-13 08:57]: **Habit Alerts Real Data Integration**
  - *Details*: Removed mock data from the "Alert" tab of single habits (`HabitMiglioramentoTabWidget`) and connected it to real data from `habitLogsProvider`.
  - *Tech Notes*:
    - Converted `HabitMiglioramentoTabWidget` to `ConsumerWidget`.
    - Implemented `_calculateWorstNegativeStreak` to find the longest sequence of missed days.
    - Implemented `_calculateBrokenStreaks` to find the last 5 broken streaks.

- [2026-05-13 08:59]: **Habit Alerts Optimization**
  - *Details*: Further optimized `HabitMiglioramentoTabWidget` by combining calculations and sorting dates only once.
  - *Tech Notes*: Created `_calculateAlerts` to perform both analyses in a single loop over sorted dates.

- [2026-05-13 09:04]: **Mood Panel Real Data Integration**
  - *Details*: Removed mock data from both Global and Habit specific Mood tabs and connected them to Supabase via `moodCorrelationProvider`.
  - *Tech Notes*:
    - Expanded `MoodCorrelation` model and `moodCorrelationProvider` in `mood_provider.dart` to calculate averages and sensitivity.
    - Converted `GlobalMoodTabWidget` to `ConsumerStatefulWidget` and `HabitMoodTabWidget` to `ConsumerWidget`.
    - Implemented real-time correlation analysis between habits and mood/energy.

- [2026-05-13 09:10]: **Info Panel Real Data Integration**
  - *Details*: Removed mock data from the "Info" tab of the statistics screen (when "Tutti gli Habits" is selected) and connected it to real data from database and providers.
  - *Tech Notes*:
    - Converted `InfoTabWidget` to `ConsumerWidget`.
    - Calculated global completion rate, best streak, top performer, and critical day from `habitStatsProvider` and `habitLogsProvider`.
    - Replaced hardcoded `_AbitudiniChiaveSection` with `_TopHabitCorrelationsSection` which shows correlations for the top habits.
    - Replaced hardcoded `_CorrelazioniPositiveSection` and `_CorrelazioniNegativeSection` with a single dynamic `_CorrelationsSection` component that filters correlations for the top performer habit.

- [2026-05-13 09:20]: **Info Panel Optimizations**
  - *Details*: Implemented two optimizations for the Info panel:
    1.  **Critical Day**: Moved calculation to database via `get_global_critical_day` RPC.
    2.  **Correlations**: Moved calculation to database via `get_all_habit_correlations` RPC to avoid multiple network calls.
  - *Tech Notes*:
    - Added `globalCriticalDayProvider` and `allHabitCorrelationsProvider` in `goal_provider.dart`.
    - Refactored `InfoTabWidget`, `_TopHabitCorrelationsSection`, and `_CorrelationsSection` to use the new providers.
    - Created migration files in `migrations/` folder.

- [2026-05-13 09:25]: **Activity Grid Responsive Optimization**
  - *Details*: Made the activity grid in the "Attività Recente" section responsive to fit different screen widths without scrolling.
  - *Tech Notes*:
    - Replaced `SingleChildScrollView` with `LayoutBuilder`.
    - Calculated dot size and spacing dynamically based on `constraints.maxWidth`.

- [2026-05-13 09:30]: **Activity Grid Real Data Integration**
  - *Details*: Connected the activity grid in the "Attività Recente" section to real data from `habitLogsProvider`.
  - *Tech Notes*:
    - Converted `_AttivitaRecenteSection` to `ConsumerWidget`.
    - Generated a 7x18 grid representing the last 18 weeks.
    - Calculated completion counts for each day and mapped them to intensity levels (0-4).

- [2026-05-13 09:35]: **Translation Update**
  - *Details*: Updated Italian translation for 'Tutti gli Habits' to 'Tutte le abitudini'.
  - *Tech Notes*: Modified `lib/core/localization.dart`.

## Current Status
- **Next Step**: The statistics page is complete. Waiting for your feedback or next tasks.
