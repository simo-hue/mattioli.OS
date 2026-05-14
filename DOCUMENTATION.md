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

- [2026-05-13 18:40]: **Bottom Navigation Bar Width Adjustment**
  - *Details*: Modified the bottom floating island (navigation bar) to be as wide as the upper parts (like the calendar box) in the home screen.
  - *Tech Notes*: Changed the horizontal margin of `AppBottomNavBar` in `bottom_nav_bar.dart` from `24` to `16` to match the padding used in `dashboard_screen.dart`.

- [2026-05-13 18:45]: **Apple-Style Time Picker in Notification Settings**
  - *Details*: Replaced the default Material time picker with a custom Apple-style Cupertino time picker for "Promemoria Abitudini" and "Review Serale" in the notification settings screen.
  - *Tech Notes*:
    - Added `flutter/cupertino.dart` import.
    - Implemented `_showAppleStyleTimePicker` helper method using `showCupertinoModalPopup` and `CupertinoDatePicker`.
    - Updated `onTap` handlers for time selection rows to use the new method.

- [2026-05-13 18:48]: **Removal of Unimplemented Notification Sections**
  - *Details*: Removed the "Obiettivi & Performance" section from the notification settings screen because the features ("Scadenze Obiettivi" and "Milestones") were not actually implemented in the app.
  - *Tech Notes*: Removed the section header and card containing the switches from `notification_settings_screen.dart`.

- [2026-05-13 18:52]: **Implementation of Change Password Feature**
  - *Details*: Implemented a professional "Cambia Password" modal in the Privacy and Security screen. It verifies the current password and updates to a new one using Supabase.
  - *Tech Notes*:
    - Added `dart:ui` and `supabase_flutter` imports to `privacy_settings_screen.dart`.
    - Added `_showChangePasswordModal` and `_buildPasswordField` methods.
    - Used `signInWithPassword` for current password verification and `updateUser` for setting the new password.
    - Added UI validation for matching passwords and minimum length (8 chars).

- [2026-05-13 19:01]: **Implementation of Data Export Feature**
  - *Details*: Implemented the "Esporta Dati" feature in the Privacy and Security screen. It gathers settings, habits, and macro goals and shares them as a JSON file.
  - *Tech Notes*:
    - Added `share_plus: ^13.1.0` dependency.
    - Added `_exportData` method in `privacy_settings_screen.dart`.
    - Gathered data from `settingsProvider`, `goalsProvider`, and `macroGoalsProvider`.
    - Used `XFile.fromData` and `Share.shareXFiles` to share the file.

- [2026-05-13 19:12]: **Implementation of Granular Delete/Reset Flow**
  - *Details*: Separated the "Elimina Account & Dati" action into two choices: "Resetta i Dati" and "Elimina l'Account". Each action has its own confirmation dialog.
  - *Tech Notes*:
    - Added `_showDeleteOrResetModal`, `_buildOptionCard`, `_showConfirmationDialog`, `_resetData`, and `_deleteAccount` methods.
    - Fixed `use_build_context_synchronously` warnings by adding `context.mounted` checks.

- [2026-05-13 19:25]: **Fix Button Text Contrast in Confirmation Dialog**
  - *Details*: Fixed an issue where the text of the "Conferma" button was invisible (white on white) during the "Reset Dati" flow.
  - *Tech Notes*: Added a check for the luminance of the primary color to determine whether to use black or white text for the non-destructive action button.

- [2026-05-13 19:36]: **Implementation of Full Data Reset (Local & Cloud)**
  - *Details*: Fixed an issue where "Resetta i Dati" only deleted data in Supabase but not in the local state. Now it clears local state and cache for goals, logs, macro goals, and resets settings to defaults.
  - *Tech Notes*:
    - Added `clearAll()` to `GoalsNotifier` and `HabitLogsNotifier` in `goal_provider.dart`.
    - Added `clearAll()` to `MacroGoalsNotifier` in `macro_goals_provider.dart`.
    - Added `resetToDefaults()` to `AppSettingsNotifier` in `settings_provider.dart`.
    - Called these methods in `_resetData` in `privacy_settings_screen.dart`.

- [2026-05-13 22:06]: **Habit Calendar Swipe Animation Upgrade**
  - *Details*: Replaced the amateurish 3D flip animation in the calendar with a premium finger-following PageView that supports parallax and scale effects.
  - *Tech Notes*:
    - Replaced `GestureDetector` and `AnimatedSwitcher` with `PageView.builder` in `HabitCalendarWidget`.
    - Added `PageController` with an infinite-like mapping using a base page (1200).
    - Implemented real-time transform effects (scale, opacity, translation) based on page offset in `AnimatedBuilder`.
    - Maintained state synchronization and chevron navigation.

- [2026-05-13 22:08]: **Fix Type Cast Error in Calendar**
  - *Details*: Fixed a runtime type error where `_Map<dynamic, dynamic>` was passed to a widget expecting `Map<String, String>`.
  - *Tech Notes*: Added `Map<String, String>.from` cast to `dayRecord` in `HabitCalendarWidget`.

- [2026-05-13 22:10]: **Removal of Anonymous Analytics Setting**
  - *Details*: Removed the "Analytics Anonimi" option from the Privacy and Security settings screen as requested by the user.
  - *Tech Notes*: Deleted the `_buildSwitchRow` for `anonymousAnalytics` in `privacy_settings_screen.dart`.

- [2026-05-13 22:57]: **Fix Overflow in Macro Goals Stats View**
  - *Details*: Fixed a "Right Overflowed" error in the "Anno Più Produttivo" card on the Macro Goals statistics view.
  - *Tech Notes*: Wrapped the title text in an `Expanded` widget and added `overflow: TextOverflow.ellipsis` in `_buildHighlightCard` within `macro_goals_stats_view.dart`.

- [2026-05-13 22:59]: **Fix Squeezed Chart Card in Macro Goals Stats View**
  - *Details*: Fixed an issue where the "Attività Trim." card would shrink to the width of its title when there was no data (e.g., when a specific year with no data was selected).
  - *Tech Notes*:
    - Added `width: double.infinity` to `Container` in `_buildCardBase` to ensure all cards take full width.
    - Updated `_buildQuarterlyBarCard` to show "Nessun dato" when the stats list is empty.

- [2026-05-13 23:08]: **Implement Permissions Management Action**
  - *Details*: Implemented the "Gestione Permessi" button in the Privacy and Security screen to open the app's system settings.
  - *Tech Notes*:
    - Added `permission_handler` dependency.
    - Updated `onTap` in `privacy_settings_screen.dart` to call `openAppSettings()`.

- [2026-05-14 10:50]: **Habit Calendar Size Optimization**
  - *Details*: Reduced the size of the "Calendario Annuale" grid items and spacing to prevent vertical scrolling in the single habit trend tab.
  - *Tech Notes*:
    - Modified `habit_calendario_tab_widget.dart`.
    - Reduced circle size from 11 to 7.
    - Reduced spacing and runSpacing from 6 to 3 in `Wrap`.
    - Reduced padding and font sizes in the card to make it more compact.
    - Updated `_buildLegendItem` to use smaller dots and fonts.

- [2026-05-14 11:05]: **Habit Calendar Full Width Optimization**
  - *Details*: Replaced the `Wrap` with a `LayoutBuilder` and `GridView.count` to make the calendar dots fill the available width of the card, removing the empty space on the right.
  - *Tech Notes*:
    - Modified `habit_calendario_tab_widget.dart`.
    - Calculated `columns` dynamically based on `maxWidth`.
    - Used `GridView.count` with `shrinkWrap: true` and `physics: NeverScrollableScrollPhysics()`.

- [2026-05-14 11:10]: **Habit Calendar Stats Card Addition**
  - *Details*: Added a summary card with completed, missed, and rate stats below the calendar to fill the empty space on the screen.
  - *Tech Notes*:
    - Modified `habit_calendario_tab_widget.dart`.
    - Created `_CalendarioStatsCard` widget.
    - Updated `HabitCalendarioTabWidget` to include the new card.

- [2026-05-14 11:15]: **Habit Calendar Height Increase**
  - *Details*: Increased the size of the calendar dots by reducing the number of columns (changing divisor from 10 to 14), making the calendar taller to better utilize screen space.
  - *Tech Notes*:
    - Modified `habit_calendario_tab_widget.dart`.
    - Changed divisor in `LayoutBuilder` from 10 to 14.

- [2026-05-14 11:20]: **Habit Calendar Size Tuning (Goldilocks)**
  - *Details*: Reduced the divisor from 14 to 12 in the calendar width calculation to make it slightly shorter, ensuring that both the calendar and the stats card fit on the screen without scrolling or being hidden under the bottom bar.
  - *Tech Notes*:
    - Modified `habit_calendario_tab_widget.dart`.
    - Changed divisor in `LayoutBuilder` from 14 to 12.

## Current Status
- **Next Step**: Waiting for user verification of the tuned calendar size.


- [2026-05-14 17:41]: **Tutorial Completion Flow Update**
  - *Details*: Added a full-screen motivational dialog at the end of the tutorial before setting has_seen_tutorial to true and navigating to home.
  - *Tech Notes*: Modified dashboard_screen.dart to include _showEndTutorialScreen(), updated onFinish and onSkip handlers of TutorialCoachMark.

- [2026-05-14 17:45]: **Tutorial Flow Bugfix**
  - *Details*: Fixed an issue where the final motivational screen was appearing prematurely after the first tutorial step (Home). It now correctly appears only after completing the entire flow (Home -> Goals -> Statistics).
  - *Tech Notes*: Reverted dashboard_screen.dart's _showTutorial to navigate to MacroGoalsScreen. Updated StatisticsScreen's onFinishTutorial callback in _getPage to trigger the final _showEndTutorialScreen.
