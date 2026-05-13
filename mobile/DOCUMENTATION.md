# DOCUMENTATION.md

## [2026-05-06 18:11]: UI - Bottom Nav Bar Cleanup
*Details*: Removed the colored background gradient (selection fill) from the dynamic island bottom navigation bar for a cleaner, more minimal appearance.
*Tech Notes*:
- Removed the `AnimatedPositioned` gradient container in `AppBottomNavBar`.
- Maintained the primary color for the active icon and label to ensure clear navigation state.

---

## [2026-05-06 20:20]: Statistics - Trend Tab Premium Overhaul
*Details*: Completely refactored the Trend tab to align with the new high-end analytics design language, focusing on dynamic data visualization and fluid interactions.
*Tech Notes*:
- **Performance Evolution Chart**: 
  - Migrated from a static custom painter to a professional `LineChart` (fl_chart).
  - Implemented a functional timeframe selector with 4 distinct mock datasets.
  - Added interactive tooltips and responsive axis scaling.
- **Trend Carousel Migration**:
  - **Confronto Temporale**: Converted from a static grid to a snapping carousel with pagination dots.
  - **Abitudini Critiche**: Standardized the existing carousel to match the premium viewport and interaction model of the rest of the app.
- **Code Optimization**: Removed the deprecated `_SmoothAreaChartPainter` and cleaned up redundant card builder methods.

---

## [2026-05-06 20:10]: Statistics - Functional Timeframe Selector
*Details*: Activated the timeframe selector in the "Wellness vs Output" chart, moving beyond a UI-only state to a fully data-driven implementation.
*Tech Notes*:
- **Dynamic Data Provider**: Implemented a state-aware switch that provides unique mock datasets for 7d, 14d, 30d, and "All" timeframes.
- **Responsive Axis Mapping**: The chart now dynamically calculates its `maxX` and date label intervals based on the selected range to ensure optimal readability.
- **Visual Feedback**: Added logic to show/hide data dots depending on the density of the chart (e.g., dots are hidden in 30d/All views to reduce clutter).

---

## [2026-05-06 20:00]: Statistics - 'Wellness vs Output' Professional Redesign
*Details*: Overhauled the primary mood analytics chart, renaming it to the more professional "Wellness vs Output" and upgrading its visual presentation.
*Tech Notes*:
- **Aesthetic Upgrade**: Implemented a `glassPanelDecoration` container with a larger corner radius (24px) and removed heavy shadows for a cleaner, modern look.
- **Chart Refinement**: 
  - Simplified axes with bold, focused labels.
  - Used a more vibrant and distinct color palette (Emerald for Mood, Amber for Energy, Primary for Output).
  - Enhanced line curves and smoothing for a more sophisticated "premium" feel.
- **UX Improvements**: Added interactive tooltips and refined the legend with compact, professional styling.

## [2026-05-06 17:45]: Habit Sorting and Label Cleanup
*Details*: Fixed the habit sorting functionality in the statistics page. Previously, the sorting selector was present but didn't actually sort the habits list. Also updated the labels in the sorting selector to replace underscores with spaces for a more professional appearance. Resolved a build error in `global_alerts_tab_widget.dart` caused by extra closing braces.
*Tech Notes*:
- Implemented `_sortedHabits` getter in `_GlobalHabitsTabWidgetState` to handle sorting based on `_sortBy`.
- Updated `ListView.separated` to use `_sortedHabits`.
- Applied `.replaceAll('_', ' ')` to translated labels in `_buildSortDropdown` and `_showSortPicker`.
- Fixed syntax error in `global_alerts_tab_widget.dart`.

**Current Status**:
- Implementation complete.
- Verification build in progress.

**Next Step**:
- Confirm build success and hand over to user.

## [2026-05-06 18:36]: Goals - Performance Analysis Crash Fix
*Details*: Fixed a crash and several range errors in the Goals "Analisi Performance" tab. Improved chart stability and year filtering logic.
*Tech Notes*:
- **Chart Robustness**: Added range checks to all `fl_chart` title widgets to prevent `RangeError` when values fall outside 0-12 (months) or year list bounds.
- **Empty Stack Protection**: Updated `BarChartRodStackItem` logic to skip items with zero value, preventing potential crashes in certain `fl_chart` versions.
- **Filtering Logic**: Refined the year selector in `MacroGoalsStatsView` to strictly filter by the selected year, excluding goals with null years when a specific year is chosen.

## [2026-05-06 18:38]: Goals - RadarChart Crash Fix
*Details*: Fixed a specific assertion error in `fl_chart`'s `RadarChart` that required at least 3 data entries.
*Tech Notes*:
- Added a check in `_buildCategoryRadarCard` to return a placeholder message if the number of unique categories with goals is less than 3, preventing the assertion failure.

## [2026-05-06 18:40]: Goals - Annual Progression Chart Optimization
*Details*: Upgraded the "Progressione Annuale" bar chart with interactive tooltips and a modern "track" background for a more premium look.
*Tech Notes*:
- **Interactivity**: Added `BarTouchData` with custom `BarTouchTooltipData` to display detailed breakdown of Active, Failed, and Completed goals on tap.
- **Visual Improvements**: 
  - Implemented `backDrawRodData` (track background) to enhance depth.
  - Refined grid styling with dashed lines and reduced opacity.
  - Improved axis labels and grid lines for clarity and professional appearance.
  - Adjusted bar width and corner radius for a more balanced aesthetic.

## [2026-05-06 18:43]: Goals - Seasonality & Monthly History Optimization
*Details*: Upgraded the Seasonality (bar) and Monthly History (line) charts with interactive tooltips and premium aesthetics.
*Tech Notes*:
- **Seasonality Chart**: 
    - Added `BarTouchData` for detailed quarterly tooltips.
    - Implemented `backDrawRodData` (tracks) for visual consistency.
    - Improved axis labels and grid styling.
- **Monthly History Chart**:
    - Added `LineTouchData` with localized month names in tooltips.
    - Enhanced line visuals with a soft gradient fill (`BarAreaData`) and smoother curves.
    - Upgraded dot painters (markers) with contrasting strokes for better visibility.
    - Refined grid lines and bolded axis labels.

## [2026-05-06 18:45]: Goals - Layout & Chart Refinement
*Details*: Separated Seasonality and Monthly charts into sequential rows for better visibility and optimized the "Mensile" bar chart for single-year views.
*Tech Notes*:
- **Layout Change**: Removed `Row` containers that paired charts horizontally, placing them vertically in the `Column` for better readability on mobile screens.
- **Monthly Bar Chart (Single Year)**:
    - Added `BarTouchData` for interactive tooltips.
    - Implemented `backDrawRodData` (tracks) for visual depth.
    - Switched to `rodStackItems` for a cleaner "composed" look (Completed vs Total).
    - Improved grid and axis labels.

## [2026-05-06 18:46]: Goals - Interest Evolution Optimization
*Details*: Upgraded the "Evoluzione Interessi" chart with interactive tooltips, tracks, and consistent premium styling.
*Tech Notes*:
- **Interactivity**: Added `BarTouchData` to show a detailed breakdown of categories per year in a tooltip.
- **Visuals**: Implemented `backDrawRodData` (tracks) and refined bar width/radius for better aesthetic alignment.
- **Styling**: Improved axis labels and grid lines for clarity and professional appearance.

## [2026-05-07 10:15]: Core - Full White Mode Transition & Professional Theme Migration
*Details*: Implemented a comprehensive, professional White Mode and migrated all main screens/widgets from hardcoded dark colors to a dynamic, theme-aware system.
*Tech Notes*:
- **Dynamic Color System**: Updated `AppTheme` and `AppColors` to support both Light and Dark modes using `ThemeExtension` (`AppColorsExtension`).
- **Screen Migration**: Fully migrated `AppSettingsScreen`, `PersonalInfoScreen`, `PrivacySettingsScreen`, `NotificationSettingsScreen`, and `AuthScreen` to use `context.appColors`.
- **Contrast-Aware UI**: 
  - Implemented dynamic luminance-based text/icon colors for primary buttons and habit pickers.
  - Resolved "Black-on-Black" and "White-on-White" visibility issues in modals and charts.
- **Statistics Overhaul**: Migrated all statistics tabs (Trend, Mood, Performance, Calendario, Miglioramento, etc.) to use theme-aware backgrounds, cards, and borders.
- **Cleanup**: Removed deprecated settings items ("Sincro & Cloud", "Effetti Trasparenza", "Inizia di Lunedì", "Mostra Weekend") to streamline the UI.
- **Single Habit Info & Activity Grid**: Migrated `info_tab_widget.dart` to use `context.appColors`. Fixed the "black boxes" in the top stats (Completamento, Miglior Serie, etc.) and the "Attività Recente" section.
- **Global Stats Cleanup**: Migrated `global_habits_tab_widget.dart` and `global_trend_tab_widget.dart` to ensure consistent Light Mode aesthetics across all analytics views.
- **Premium Carousel Alignment**: Standardized the design of "Correlazioni Positive" and "Correlazioni Negative" cards to match the "Abitudini Chiave" section. Increased card radius to 20px, added elevation shadows, and optimized horizontal scroll snapping for a more fluid experience.
- **Specific Habit Stats Refinement**: Migrated the correlation sections in `habit_overview_tab_widget.dart` from vertical lists to horizontal carousels with pagination dots, ensuring a consistent premium look and feel across both global and specific analytics views.
- **Unified Analytics Selectors**: Replaced the standard dropdown timeframe selector in the "Mood & Energia" chart with the premium pill-style animated selector used in the Trend tab, improving visual consistency and UX across all analytics tabs.




**Current Status**:
- App launched successfully on simulator.
- Supabase configuration restored.

**Next Step**:
- Hand over to user for feature testing.

---

## [2026-05-07 18:31]: Core - Fixed Missing Supabase Configuration & App Launch
*Details*: Resolved a critical build error caused by the missing `lib/core/supabase_config.dart` file. Successfully launched the application on the iOS Simulator.
*Tech Notes*:
- **Configuration**: Created `lib/core/supabase_config.dart` using values found in the root `.env` file (`VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON`).
- **Verification**: Executed `flutter run`, which confirmed that Supabase initialization completes successfully with the provided credentials.
- **Status**: The app is currently running on the iPhone 17 Simulator.

---

## [2026-05-12 14:23]: Auth - Diagnostic Error Message & Specific Mapping
*Details*: Updated the error mapping in `AuthProvider` to display the raw Supabase error message when an unhandled error occurs, and added a specific mapping for "signups not allowed".
*Tech Notes*:
- Modified `_mapAuthError` in `lib/providers/auth_provider.dart` to return `Si è verificato un errore: $supabaseMessage` instead of the generic message.
- Added specific mapping for `signups not allowed for this instance` to guide the user.

---

## [2026-05-12 15:45]: UI - Application Logo and Launcher Icon Implementation
*Details*: Added the application logo provided by the user, setting it up both as the in-app logo for the login/signup screen and as the official app icon for iOS.
*Tech Notes*:
- **Assets**: Created `assets/images/` directory and added `logo.png` and `app_icon.png`.
- **In-App Logo**: Updated `AuthScreen` to display the new logo instead of the placeholder `LucideIcons.layers` icon. Used `ClipRRect` for rounded corners.
- **Launcher Icons**: Added `flutter_launcher_icons` package and configured it in `pubspec.yaml` to generate iOS launcher icons.
- **Commands**: Ran `flutter pub get` and `dart run flutter_launcher_icons` to generate the icons.

---

## [2026-05-12 15:50]: UI - Updated AuthScreen Logo to Background Removed Version
*Details*: Replaced the logo in the login/signup screen with a background-removed version provided by the user, to prevent the black square from being visible on non-pure-black backgrounds.
*Tech Notes*:
- **Assets**: Updated `pubspec.yaml` to include the whole `assets/images/` folder instead of specific files, allowing automatic inclusion of new assets.
- **In-App Logo**: Updated `AuthScreen` to use `'assets/images/logo Background Removed.png'`.

---

## [2026-05-12 15:55]: Core - Total Rebranding to 'growth'
*Details*: Performed a full rebranding of the application, changing the name from "Mattioli.OS" to "growth" and updating the motto to "root deep, rise strong".
*Tech Notes*:
- **iOS Config**: Updated `CFBundleDisplayName` and `CFBundleName` in `Info.plist` to "growth".
- **App Title**: Updated `MaterialApp` title in `main.dart` and renamed the main app widget from `MattioliOSApp` to `GrowthApp`.
- **Notifications**: Updated notification titles in `notifications.dart`.
- **Localization**: Updated `app_title` in `localization.dart` for both Italian and English.
- **UI**: Updated the title and motto in `AuthScreen` and the modal title in `pro_features_modal.dart`.

---

## [2026-05-12 16:00]: Core - Capitalized Brand Name to 'Growth' across all files
*Details*: Ensured that the brand name is consistently written as "Growth" (capitalized) instead of "mattioli.OS" or lowercase "growth" across all files, including documentation.
*Tech Notes*:
- **UI & Code**: Capitalized "growth" to "Growth" in `AuthScreen`, `main.dart`, `notifications.dart`, `localization.dart`, and `pro_features_modal.dart`.
- **Documentation**: Replaced "Mattioli.OS" with "Growth" in `FINANCIAL_PLAN.md`, `BACKEND_ARCHITECTURE.md`, and `FLUTTER_COMMANDS.md`.

---

## [2026-05-12 16:05]: UI - First-time Login Name Prompt & Fallback Removal
*Details*: Implemented a popup prompt for users to enter their name on first login if it is missing. Removed the hardcoded fallback "Simone" to ensure a professional user experience.
*Tech Notes*:
- **Auth Notifier**: Added `updateProfileName` method to `AuthNotifier` in `auth_provider.dart` to update user metadata in Supabase.
- **UI**: Added `_checkProfileName` and `_showNameDialog` in `dashboard_screen.dart` to check and prompt for name after the first frame.
- **Cleanup**: Replaced `userProfile.firstName ?? 'Simone'` with `userProfile.displayName` in `_AppBar` to use the model's professional fallback system.

---

## [2026-05-12 16:10]: UI - Styled Name Prompt Dialog with Blur
*Details*: Redesigned the name prompt dialog to match the app's premium aesthetic. Added a background blur effect when the dialog is shown.
*Tech Notes*:
- **UI**: Replaced `AlertDialog` with a custom `Dialog` containing a styled `Container` in `dashboard_screen.dart`.
- **Effects**: Added `BackdropFilter` with blur effect in the dialog's builder.

---

## [2026-05-12 16:15]: UI - Fixed Button Text Visibility in Name Prompt
*Details*: Fixed an issue where the text in the "Inizia ora" button was not visible because both the button background and the text were white in certain themes.
*Tech Notes*:
- **UI**: Made the text color dynamic using `computeLuminance()` on the primary color in `dashboard_screen.dart`.

---

## [2026-05-12 16:20]: UI - Show Only First Name in Greeting
*Details*: Updated the greeting in the AppBar to show only the user's first name instead of the full name, making it more personal.
*Tech Notes*:
- **UI**: Changed `userProfile.displayName` to `userProfile.firstName ?? userProfile.displayName` in `dashboard_screen.dart`.

---

## [2026-05-12 16:30]: UI - LifeViewWidget Layout Adjustments
*Details*: Modified the "Life" panel to remove unnecessary text and reduce the height of the stats box for a more compact layout.
*Tech Notes*:
- **UI**: Removed the text showing birth year, end year, and total months in `life_view_widget.dart`.
- **Layout**: Reduced vertical padding in the stats block from 20 to 12 and decreased spacing above and below it.

---

## [2026-05-12 17:40]: Feature - Dynamic Date of Birth in Profile & Life View
*Details*: Added a date of birth field in the personal information settings with a Cupertino date picker (Apple style). The "Life" panel now calculates stats dynamically based on the user's actual date of birth instead of hardcoded values.
*Tech Notes*:
- **Model**: Added `dateOfBirth` field to `UserProfile` in `user_provider.dart`, reading from `date_of_birth` in Supabase user metadata.
- **UI**: Added `_buildDateField` and `_showDatePicker` (using `CupertinoDatePicker`) in `personal_info_screen.dart`.
- **Logic**: Updated `LifeViewWidget` to parse `dateOfBirth` and calculate `livedMonths` and `age` based on it, with a default fallback to 2003 if not set.

---

## [2026-05-12 17:45]: Cleanup - Removed Phone Number Field & Added SQL Migration
*Details*: Removed the phone number field from personal information settings as requested. Added an SQL migration script to add `date_of_birth` to the `profiles` table and updated the code to save it there as well.
*Tech Notes*:
- **UI**: Removed `_phoneController` and the phone text field from `personal_info_screen.dart`.
- **Database**: Added `date_of_birth` to the `profiles` table update in `personal_info_screen.dart`.
- **Docs**: Added the SQL script to `TO_SIMO_DO.md`.

---

## [2026-05-12 17:50]: Feature - Implemented Default View Setting
*Details*: Fixed the issue where the application ignored the default view setting on startup. Now it correctly opens the view selected in the preferences.
*Tech Notes*:
- **State Management**: Updated `CalendarViewNotifier` in `goal_provider.dart` to watch `settingsProvider` and initialize the state based on `defaultCalendarView`.
- **UI Mapping**: Changed the 'giorno' option to 'mese' in `app_settings_screen.dart` to match the actual view (Month view) and added fallback handling in the parser.

---

## [2026-05-12 17:55]: UI - Capitalized Tab Labels in Home Screen
*Details*: Capitalized the tab labels in the home screen (Mese, Settimana, Anno, Vita) to match the user's request and ensure language correctness.
*Tech Notes*:
- **UI**: Updated `ViewTabBar` to use capitalized keys ('Mese', 'Settimana', 'Anno', 'Vita') for translation, which map to capitalized strings in both Italian and English.

---

## [2026-05-12 18:00]: Feature - Custom Notification Times (Step 1)
*Details*: Implemented the ability for users to choose the time for "Morning Brief" and "Review Serale" notifications instead of having fixed times.
*Tech Notes*:
- **Model**: Added `morningBriefTime` and `eveningReviewTime` to `AppSettings` (defaulting to "09:00" and "21:00").
- **UI**: Added time picker rows in `notification_settings_screen.dart` that appear when the corresponding switch is ON.
- **Service**: Updated `NotificationService` to accept and parse time strings for scheduling.
- **Database**: Added an SQL migration script to `TO_SIMO_DO.md` to add the columns to the `profiles` table.

---

## [2026-05-12 18:05]: Feature - Per-Habit Reminders (Step 2)
*Details*: Implemented the ability to set a specific reminder time for each habit.
*Tech Notes*:
- **Model**: Added `reminderTime` field to `Goal` model.
- **UI**: Added a time picker in `HabitManagementModal` to set the reminder time when creating or editing a habit.
- **Service**: Added `scheduleHabitReminder` and `cancelHabitReminder` to `NotificationService`.
- **Provider**: Updated `GoalNotifier` to trigger scheduling on add/update/delete. Updated `SettingsProvider` to reschedule habit reminders on sync.
- **Database**: Added an SQL migration script to `TO_SIMO_DO.md` to add `reminder_time` column to `goals` table.

---

## [2026-05-12 18:10]: Fix - Resolved Build Errors in Step 2
*Details*: Fixed build errors introduced during the implementation of Step 2.
*Tech Notes*:
- **Import**: Added missing import of `goal_provider.dart` in `settings_provider.dart` to resolve `goalsProvider` not defined.
- **API**: Changed `_notifications.cancel(id.hashCode)` to `_notifications.cancel(id: id.hashCode)` in `notifications.dart` to match the `flutter_local_notifications` v21 API.

---

## [2026-05-12 18:15]: Feature - Apple-style Time Picker
*Details*: Changed the time picker in `HabitManagementModal` to use `CupertinoDatePicker` for a more premium, Apple-like feel.
*Tech Notes*:
- **UI**: Replaced `showTimePicker` with `showCupertinoModalPopup` and `CupertinoDatePicker` in `habit_management_modal.dart`. Wrapped `ColorPicker` in `Material` to support its widgets.
- **Format**: Forced 24h format in the Cupertino picker.

---

## [2026-05-12 18:20]: Feature - Apple-style Color Picker
*Details*: Changed the custom color picker in `HabitManagementModal` to open in a Cupertino modal sheet for a more integrated feel.
*Tech Notes*:
- **UI**: Replaced `showDialog` with `showCupertinoModalPopup` in `_showColorPicker` method in `habit_management_modal.dart`. Wrapped `ColorPicker` in `Material` to support its widgets.

---

## [2026-05-12 18:25]: Feature - Time Picker respects 24h Setting
*Details*: Updated the Cupertino time picker to respect the "Formato 24h" setting from the app settings.
*Tech Notes*:
- **UI**: Read `timeFormat24h` from `settingsProvider` and passed it to `use24hFormat` in `CupertinoDatePicker`.

---

## [2026-05-12 18:30]: Fix - Resolved Missing Import in HabitManagementModal
*Details*: Fixed a build error where `settingsProvider` was not defined.
*Tech Notes*:
- **Import**: Added `import '../../providers/settings_provider.dart';` in `habit_management_modal.dart`.

---

## [2026-05-12 18:35]: Feature - Actionable Notifications (Step 3)
*Details*: Implemented 3 actions for habit reminders: Fatto (Done), Posticipa (Snooze), Salta (Skip).
*Tech Notes*:
- **Service**: Updated `NotificationService` to include actions in `AndroidNotificationDetails` and registered `DarwinNotificationCategory` for iOS.
- **Handler**: Added `_onNotificationResponse` to handle actions. "Fatto" updates Supabase directly. "Posticipa" schedules a new notification in 1 hour. "Salta" cancels the notification.
- **Payload**: Added structured payload `habit|id|title` to pass data to the handler.

---

## [2026-05-12 23:10]: Fix - Resolved Const Error in notifications.dart
*Details*: Fixed a build error on iOS where `iosSettings` was used in a const constructor but was not a constant expression.
*Tech Notes*:
- **Code**: Changed `const InitializationSettings` to `final InitializationSettings` in `NotificationService.init()`.

---

## [2026-05-12 23:20]: Fix - Resolved Mock Streak in DayDetailsModal
*Details*: Fixed a bug where the habit streak was hardcoded with a mock formula, causing incorrect values (3-5) for new habits.
*Tech Notes*:
- **UI**: Replaced `mockStreak` with a real calculation loop in `DayDetailsModal` that goes backwards from the selected date and counts consecutive 'done' statuses in `habitLogsProvider`.
- **Logic**: It stops the streak if it finds 'missed' or if the habit was active but not completed on a past day.

---

## [2026-05-12 23:25]: Feature - Optimized Streak Calculation & Security (Option A)
*Details*: Implemented the optimized streak logic requested by the user and added security restrictions.
*Tech Notes*:
- **Security**: Added a check in `DayDetailsModal` to prevent editing habits for days before yesterday.
- **DB Migration**: Appended instructions to `TO_SIMO_DO.md` to add `streak` column to `goal_logs`.
- **Provider**: Updated `cycleStatus` in `GoalNotifier` to query the latest log's streak and calculate the new streak based on the user's logic (increment on done, decrement on missed).

---

## [2026-05-12 23:35]: Feature - Daily Check-In Persistence & Dynamic Text
*Details*: Implemented persistence for the daily check-in (mood & energy) and made the button text dynamic ("Inserisci" vs "Aggiorna").
*Tech Notes*:
- **Provider**: Created `mood_provider.dart` with `dailyMoodsProvider` to sync with `daily_moods` table in Supabase.
- **UI**: Updated `DailyCheckInModal` to use the provider. It now loads existing values for today if they exist and changes the button text accordingly.
- **DB**: Noted that `daily_moods` table has constraints for scores 1-5, while UI uses 0-10. Provided SQL to update constraints.

---

## [2026-05-12 23:45]: Feature - Real Data for Weekly Trend
*Details*: Implemented real data calculation for the weekly trend in the statistics tab.
*Tech Notes*:
- **UI**: Updated `GlobalTrendTabWidget` to accept `goals` and `logs` as parameters.
- **Logic**: Calculates the completion percentage for the last 7 days by checking active habits and logs.
- **Comparison**: Compares the current week's average with the previous week's average to calculate the delta and trend direction.
- **Critical Habits**: Calculates the drop in completion rate for each habit (current week vs previous week) and displays them sorted by the biggest drop.
- **Comparison Carousel**: Calculates the real completion rate for the current and previous week for each habit.
- **Timeframes**: Added real data calculations for Month, Year, and All timeframes. Month shows last 30 days. Year shows last 12 months with Italian names. All shows up to 10 points spanning the entire history.

---

## [2026-05-13 09:15]: Statistics - Real Data for Alerts Tab
*Details*: Removed mock data from the "Alert" tab in the "Tutti gli Habits" view and connected it to real database data via `habitStatsProvider` and `habitLogsProvider`.
*Tech Notes*:
- **Aree di Miglioramento**: Now displays the top 3 habits with the lowest success rates. It also dynamically calculates the "worst day of the week" for each habit based on historical logs.
- **Analisi Fallimenti**: Shows habits with the highest "worst streak" and calculates a monthly frequency of missed days.
- **Pattern di Recupero**: Calculates the average number of days it takes the user to return to a habit after a miss.
- **Confronto Performance**: Compares best and worst streaks for each habit, highlighting the gap.
- **State Management**: Migrated `GlobalAlertsTabWidget` to a `ConsumerWidget` to access Riverpod providers.

---

## [2026-05-13 09:25]: Statistics - Database Acceleration for Alerts Tab
*Details*: Offloaded heavy calculations (worst day of week and recovery time) from the client to Supabase using a PL/pgSQL function.
*Tech Notes*:
- **Database**: Created `get_habit_analytics` function in Supabase (executed manually by user).
- **Provider**: Added `habitAnalyticsProvider` in `goal_provider.dart` to call the RPC.
- **UI**: Updated `GlobalAlertsTabWidget` to use the new provider, removing expensive in-memory loops over logs.

---

## [2026-05-13 09:35]: Statistics - Database Acceleration for Global Trends
*Details*: Offloaded trend calculations (weekly, monthly, annual, all-time) from the client to Supabase using a PL/pgSQL function.
*Tech Notes*:
- **Database**: Created `get_global_trend` function in Supabase returning double the points for delta calculation.
- **Provider**: Added `globalTrendProvider` in `goal_provider.dart` (FutureProvider.family).

---

## [2026-05-13 09:45]: Statistics - Database Acceleration for Best and Critical Habits
*Details*: Offloaded calculations for best habits (by timeframe) and critical habits (by drop in performance) to Supabase using two new functions.
*Tech Notes*:
- **Database**: Created `get_critical_habits` and `get_best_habits` functions in Supabase.
- **Provider**: Added `criticalHabitsProvider` and `bestHabitsProvider` in `goal_provider.dart`.
- **UI**: Converted `_MiglioriAbitudiniSection` and `_AbitudiniCriticheSection` to `ConsumerStatefulWidget` and connected them to the new providers, removing all complex in-memory loops.

---

## [2026-05-13 09:55]: Statistics - Database Acceleration for Individual Habit Stats
*Details*: Offloaded calculations for individual habit performance by day and habit alerts (worst negative streak and broken streaks) to Supabase.
*Tech Notes*:
- **Database**: Created `get_habit_performance_by_day` and `get_habit_alerts` functions in Supabase.
- **Provider**: Added `habitPerformanceProvider` and `habitAlertsProvider` in `goal_provider.dart` (both are family providers taking `goalId`).
- **UI**: Updated `HabitPerformanceTabWidget` and `HabitMiglioramentoTabWidget` to use the new providers, removing all heavy in-memory loops over logs.
- **UI**: Updated `_buildTrendChartSection` in `GlobalTrendTabWidget` to use the RPC data, removing complex in-memory loops.

---

## [2026-05-13 10:05]: Statistics - Database Acceleration for Habit Calendar
*Details*: Offloaded generation of the 365-day grid for the habit calendar to Supabase.
*Tech Notes*:
- **Database**: Created `get_habit_yearly_grid` function in Supabase.
- **Provider**: Added `habitYearlyGridProvider` in `goal_provider.dart` (family provider taking `goalId`).
- **UI**: Updated `HabitCalendarioTabWidget` to use the new provider, removing the in-memory loop over 365 days and dependencies on `habitLogsProvider` and `goalsProvider`.

---

## [2026-05-13 10:15]: Statistics - Database Acceleration for Habit Overview (Correlations)
*Details*: Offloaded calculation of habit correlations and 30-day trend to Supabase.
*Tech Notes*:
- **Database**: Created `get_habit_correlations` function in Supabase. Reused `get_habit_yearly_grid` for the 30-day trend.
- **Provider**: Added `habitCorrelationsProvider` in `goal_provider.dart` (family provider taking `goalId`).
- **UI**: Updated `HabitOverviewTabWidget` to use `habitCorrelationsProvider` and `habitYearlyGridProvider` (taking last 30 items), removing all heavy in-memory loops over logs and dependency on `habitLogsProvider`.

---

## [2026-05-13 10:20]: Statistics - Fixes for get_global_trend
*Details*: Fixed ambiguous column reference and operator not exists (interval > integer) errors in the `get_global_trend` SQL function.
*Tech Notes*:
- **Database**: Renamed temporary column `date` to `edate` in the `earliest_date` CTE to avoid collision with the return column `date`.
- **Database**: Added explicit cast `::date` to `CURRENT_DATE - INTERVAL '30 days'` to avoid implicit conversion to timestamp and subsequent interval comparison error.

---

## [2026-05-13 10:25]: Statistics - Fixes for Trend Tab and 0% Issue
*Details*: Fixed 0% issue in `get_global_trend` and ambiguous column reference in `get_critical_habits` and `get_best_habits`.
*Tech Notes*:
- **Database**: Added `::date` cast to `gl.date` in `get_global_trend` to match the generated dates and avoid 0% results due to time component.
- **Database**: Reconstructed `get_critical_habits` and `get_best_habits` with explicit table aliases and qualified names to avoid `goal_id` ambiguity.

---

## [2026-05-13 10:30]: Statistics - Fix for Skipped Habits in Global Trend
*Details*: Excluded 'skipped' logs from `active_count` in `get_global_trend` to avoid counting them as missed.
*Tech Notes*:
- **Database**: Added `FILTER (WHERE gl.status IS NULL OR gl.status != 'skipped')` to `COUNT(ag.goal_id)` in `day_stats` CTE.

---

## [2026-05-13 10:35]: Statistics - Fix for Year Timeframe in Global Trend
*Details*: Fixed `relation "date_range" does not exist` error in the `year` branch of `get_global_trend`.
*Tech Notes*:
- **Database**: Ensured that the `year` branch uses `day_range` instead of `date_range` and that all references are consistent.

---

## [2026-05-13 10:40]: Statistics - Fix for Empty Days in Global Trend
*Details*: Ensured that `get_global_trend` returns rows for all days even if no habits are active, to avoid short lists and single points in Flutter.
*Tech Notes*:
- **Database**: Used `LEFT JOIN` between `date_range` and `active_goals` in `day_stats` CTE for `week` and `month` branches.

---

## [2026-05-13 10:45]: Statistics - Fix for Ambiguous Column in Correlations
*Details*: Fixed `column reference "goal_id" is ambiguous` error in `get_habit_correlations`.
*Tech Notes*:
- **Database**: Removed `goal_id` alias in the final select and ensured all references are qualified.

---

## [2026-05-13 10:50]: Statistics - UI Fix for Trend Box
*Details*: Updated colors and legend in `_TrendUltimi30Giorni` in `habit_overview_tab_widget.dart`.
*Tech Notes*:
- **UI**: Set completed to green, missed to red, and unlogged/skipped to grey. Added third option to legend and used `Wrap` to avoid overflow.

---

## [2026-05-13 10:55]: Statistics - Smooth Transitions and Caching in Global Trend
*Details*: Implemented in-memory caching and smooth transitions in `GlobalTrendTabWidget` to avoid loading spinners when switching timeframes.
*Tech Notes*:
- **State Management**: Added `ref.keepAlive()` to `globalTrendProvider`.
- **UI**: Added `_lastValidData` state to `GlobalTrendTabWidget` to show the previous chart while loading.

---

## [2026-05-13 11:00]: Statistics - Caching Applied to All Stats Providers
*Details*: Added `ref.keepAlive()` to all remaining statistics providers to prevent unnecessary re-fetching.
*Tech Notes*:
- **State Management**: Added `ref.keepAlive()` to `habitAnalyticsProvider`, `criticalHabitsProvider`, `bestHabitsProvider`, `habitPerformanceProvider`, `habitAlertsProvider`, `habitYearlyGridProvider`, and `habitCorrelationsProvider`.

---

## [2026-05-13 12:50]: Goals - Completion Color Standardized to Green
*Details*: Replaced the primary/white color with green (`#10B981`) for completion and success metrics across all charts in the Goals Performance view to ensure consistency.
*Tech Notes*:
- Updated `_buildKpiCard`, `_buildHighlightCard`, `_buildAreaChartCard`, `_buildQuarterlyBarCard`, `_buildMonthlyComposedCard`, `_buildGlobalYearProgressionCard`, and `_buildQuarterSeasonalityCard` to use `const Color(0xFF10B981)` for completed states and success percentages instead of `Theme.of(context).colorScheme.primary`.

## [2026-05-13 13:00]: Goals - Performance Analysis Database Integration (RPC & Caching)
*Details*: Removed mock data from the "Analisi Performance" view for Macro Goals and connected it to real database data via a new Supabase RPC and Riverpod caching.
*Tech Notes*:
- **Database**: Created `get_macro_goals_stats` function in Supabase (to be executed by user).
- **Provider**: Added `macroGoalsStatsProvider` in `macro_goals_stats_provider.dart` (FutureProvider.family) with `ref.keepAlive()` for caching.
- **UI**: Updated `MacroGoalsStatsView` to use the new provider, refactoring all charts (Area, Radar, Pie, Bar, Line) to use the JSON data structure returned by the RPC instead of client-side calculations on `List<MacroGoal>`.
- **UI**: Respected user's title change in `_buildMonthlyComposedCard` ("Completamenti" and "Mensili").

## [2026-05-13 13:05]: Goals - Fix SQL Syntax Error in RPC
*Details*: Fixed a syntax error in the `get_macro_goals_stats` SQL function where `ORDER BY` was used at the end of a subquery with `jsonb_agg`.
*Tech Notes*:
- **Database**: Moved `ORDER BY` inside the `jsonb_agg` function (e.g., `jsonb_agg(... ORDER BY year)`) to comply with Postgres rules for aggregate functions.
- **File**: Updated `/Users/simo/Downloads/DEV/mattioli.OS/migrations/20260513_add_get_macro_goals_stats.sql`.
- **Action**: Requested user to rerun the script.

---

## [2026-05-13 13:20]: Goals - Custom Categories and UI Refactor
*Details*: Implemented custom categories for long-term goals, removing hardcoded defaults and adding a premium color picker. Fixed category assignment issues.
*Tech Notes*:
- **Database**: The user executed the migration to add `macro_goal_categories` table and `category_id` to `long_term_goals`.
- **Model**: Updated `MacroGoal` to support `categoryId`.
- **Provider**: Created `macroGoalCategoriesProvider` to manage custom categories.
- **UI (`AddGoalBar`)**:
  - Updated to fetch categories from DB.
  - Added "Crea nuova categoria" option.
  - Implemented a premium dialog with a curated palette of 5 colors (reduced from 12 and then to 5 as requested) and a custom color picker (via `flutter_colorpicker`) for category creation.
  - Fixed assignment bug (now sets `category_id` instead of `category_key`).
- **UI (`GoalItemWidget`)**:
  - Updated "Cambia categoria" sheet to use custom categories.
  - Updated color resolution to support both custom categories and legacy hardcoded ones.
- **UI (`MacroGoalsStatsView`)**:
  - Updated pie chart, radar chart ("Performance Categorie"), and legend to resolve colors and labels using custom categories.
  - Updated evolution chart to use custom categories (limited to top 6).

---

## [2026-05-13 13:30]: Goals - Update RPC for Custom Categories
*Details*: Updated the `get_macro_goals_stats` RPC to use `COALESCE(category_id::text, category_key)` so it counts custom categories correctly while maintaining backward compatibility with legacy hardcoded keys.
*Tech Notes*:
- **Database**: Updated `get_macro_goals_stats` function in Supabase.
- **File**: `migrations/20260513_add_get_macro_goals_stats.sql`.
- **Action**: Requested user to rerun the script.

---

## [2026-05-13 15:00]: Core - Analysis of iOS Notification Icon Issue
*Details*: Investigated the issue where the notification icon shows a default icon on a physical device but the correct app icon on the simulator.
*Tech Notes*:
- Verified that `AppIcon.appiconset` contains all required sizes for iOS (20x20 to 1024x1024).
- Confirmed that on iOS, the notification icon is handled by the system and uses the App Icon. There is no separate configuration in `flutter_local_notifications`.
- Concluded that the issue is likely due to iOS caching on the physical device.
- Added troubleshooting steps to `TO_SIMO_DO.md` for the user to follow (Uninstall, Restart, Clean).

---

## [2026-05-13 15:05]: UI - Raised Floating Bottom Navigation Bar
*Details*: Raised the floating bottom navigation bar to make it look more premium and prevent interference with the home indicator on iOS.
*Tech Notes*:
- Modified `lib/ui/widgets/bottom_nav_bar.dart`.
- Changed the bottom margin from a minimal fixed value to `bottomPadding + 16`, ensuring it floats 16 pixels above the safe area.

---

## [2026-05-13 15:15]: Core - Notification Actions & Background Handling
*Details*: Fixed the issue where clicking notification actions (Fatto, Salta, Posticipa) did nothing. Implemented background handling for notifications and database integration for actions.
*Tech Notes*:
- Added `@pragma('vm:entry-point')` top-level function `notificationTapBackground` in `notifications.dart` to handle actions when the app is in background or terminated.
- Updated `_snoozeHabit` to snooze for 10 minutes instead of 1 hour.
- Updated `_skipHabit` to mark the habit as 'missed' in the database (Supabase) instead of just cancelling the notification.
- Consistent with existing code, streaks are not updated in direct database writes from notifications (added TODO note in code).

---

## [2026-05-13 15:21]: UI - Delete Habit Confirmation Dialog
*Details*: Added a confirmation dialog with a blur effect before deleting a habit in the management modal, to prevent accidental deletions.
*Tech Notes*:
- Implemented `_showDeleteConfirmation` in `HabitManagementModal` using `showDialog` and `BackdropFilter` with blur.
- Used `AppColors.destructive` and styled the dialog to match the app's premium aesthetic.

---

## [2026-05-13 15:23]: UI - Habit Edit Scroll Animation
*Details*: Added a smooth scroll-to-top animation when the user clicks the edit button for a habit, making it clearer that the app has reacted and is ready for editing.
*Tech Notes*:
- **Animation**: Added `ScrollController` and used `animateTo` in `HabitManagementModal`.

---

## [2026-05-12 15:24]: UI - Habit Edit Button Text
*Details*: Changed the button text in `HabitManagementModal` to "Aggiorna" when editing an existing habit.

---

## [2026-05-12 15:26]: UI - Habit Edit Buttons Row Layout
*Details*: Placed "Aggiorna" and "Annulla" buttons on the same row when editing a habit.

---

## [2026-05-13 22:15]: Core - Biometric Lock & Pro Status UI
*Details*: Implemented biometric lock on app startup and updated the UI to reflect Pro status with a gold border and badge.

---

## [2026-05-13 22:30]: Feature - Mock Subscription Management
*Details*: Implemented a professional mock subscription management screen allowing users to "buy" and "cancel" the Pro plan.

---

## [2026-05-13 22:33]: Fix - Compilation Error in SubscriptionScreen
*Details*: Fixed a compilation error caused by a missing icon in the `lucide_icons_flutter` package.

---

## [2026-05-13 22:38]: UI - Profile Screen Spacing Optimization
*Details*: Reduced the height of settings items and the logout button in the Profile screen to ensure all content fits on the screen without scrolling.

---

## [2026-05-13 22:40]: Fix - LocaleDataException in SubscriptionScreen
*Details*: Fixed an error where locale data was not initialized for Italian date formatting.
*Tech Notes*:
- Added `initializeDateFormatting('it', null)` in `main.dart` and imported `package:intl/date_symbol_data_local.dart`.

---

## [2026-05-13 22:42]: UI - Subscription Cancel Dialog Redesign
*Details*: Redesigned the "Disdici Abbonamento" dialog to match the app's premium aesthetic, using a blur effect and custom styled buttons.
*Tech Notes*:
- Replaced `AlertDialog` with a custom `Dialog` wrapped in `BackdropFilter` (blur 10).
- Styled the content with an alert icon, bold title, and custom row buttons.
- Added `import 'dart:ui';` in `subscription_screen.dart`.
