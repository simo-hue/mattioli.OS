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




- [2026-05-14 17:41]: **Tutorial Completion Flow Update**
  - *Details*: Added a full-screen motivational dialog at the end of the tutorial before setting has_seen_tutorial to true and navigating to home.
  - *Tech Notes*: Modified dashboard_screen.dart to include _showEndTutorialScreen(), updated onFinish and onSkip handlers of TutorialCoachMark.

- [2026-05-14 17:45]: **Tutorial Flow Bugfix**
  - *Details*: Fixed an issue where the final motivational screen was appearing prematurely after the first tutorial step (Home). It now correctly appears only after completing the entire flow (Home -> Goals -> Statistics).
  - *Tech Notes*: Reverted dashboard_screen.dart's _showTutorial to navigate to MacroGoalsScreen. Updated StatisticsScreen's onFinishTutorial callback in _getPage to trigger the final _showEndTutorialScreen.

- [2026-05-14 18:25]: **AI Chat Premium Experience Upgrade**
  - *Details*: Upgraded the AI chat implementation to make it a "killer feature" with professional UI/UX, context-aware responses, and animations.
  - *Tech Notes*:
    - Replaced static typing dots with a custom `_BouncingDot` widget with staggered bounce animations.
    - Upgraded the fallback response engine to use real data from `macroGoalsProvider`, `goalsProvider`, and `habitLogsProvider` for context-aware answers.
    - Added variable delays to message simulation to feel more natural.
    - Added `_FadeInSlide` wrapper widget to animate message bubbles on entrance.
    - Redesigned the "suggested prompts" as compact chips in a grid layout.
    - Added a "Coach Card" in the empty state above suggested prompts.
    - Upgraded the AppBar with an AI avatar, gradient ring, and online status indicator.
    - Added a long-press action on message bubbles to copy text to the clipboard with haptic feedback and a toast message.
    - Fixed missing imports and constructor issues in `ai_chat_screen.dart`.

- [2026-05-14 18:32]: **AI Chat: Removal of Goals Pills**
  - *Details*: Removed the horizontally scrollable list of goals pills below the AppBar as requested by the user.
  - *Tech Notes*: Removed the `Container` containing the `ListView.builder` for goals chips and the unused `goalsState` variable in `ai_chat_screen.dart`.

- [2026-05-14 18:35]: **AI Chat: Collapsible Suggested Prompts**
  - *Details*: Made the suggested prompts always active (not just in empty state) and added a toggle to collapse/expand them like a dropdown.
  - *Tech Notes*: Added `_showPrompts` state variable, separated Coach Card from prompts, and wrapped prompts in a collapsible `Column` with a `GestureDetector` header in `ai_chat_screen.dart`.

- [2026-05-14 18:40]: **AI Chat: Dynamic and Contextual Suggestions**
  - *Details*: Replaced hardcoded suggested prompts with dynamic ones based on the time of day and the user's current goals and habits status.
  - *Tech Notes*: Implemented `_getDynamicSuggestions` method that reads from `macroGoalsProvider`, `goalsProvider`, and `habitLogsProvider` to generate a pool of relevant prompts, and picks 4 deterministically based on message count to ensure stability between rebuilds.

- [2026-05-15 16:00]: **Dynamic Habit Notifications**
  - *Details*: Implemented a dynamic message generator for habit notifications to avoid "notification fatigue" and make messages more engaging by including the habit name.
  - *Tech Notes*:
    - Added `_getHabitMessage(String title)` helper method in `NotificationService`.
    - Created a list of 15 varied messages (motivational, direct, identity-focused, etc.) all including the habit title.
    - Updated `scheduleHabitReminder` and `_snoozeHabit` to use this method for generating the notification body.

- [2026-05-15 16:20]: **Fix Snooze Notification Bug**
  - *Details*: Fixed a bug where snooze notifications would not appear. The issue was that `matchDateTimeComponents` was set to `DateTimeComponents.time`, making it a daily recurring notification instead of a one-off notification.
  - *Tech Notes*: Removed `matchDateTimeComponents: DateTimeComponents.time` from `_notifications.zonedSchedule` in the `_snoozeHabit` method.

- [2026-05-15 16:35]: **Fix Consent Screen Checkbox Tick Visibility**
  - *Details*: Fixed an issue where the checkmark in the "Termini e Privacy Policy" checkbox was invisible (white on white) in the consent screen.
  - *Tech Notes*: Changed `checkColor` from `Colors.white` to `activeTextColor` (which dynamically switches between black and white based on the primary color's luminance) in `consent_screen.dart`.

- [2026-05-17 16:00]: **Mobile Application Rebranding to 'Evolve'**
  - *Details*: Rebranded the entire mobile application from "Growth" to "Evolve" and updated the application's motto to "better each day, become who you're meant to be".
  - *Tech Notes*:
    - Updated `CFBundleDisplayName` and `CFBundleName` in `Info.plist` to "evolve".
    - Updated `MaterialApp` title in `main.dart` and renamed the main app widget from `GrowthApp` to `EvolveApp`.
    - Updated notification titles in `notifications.dart` to use 'Evolve • '.
    - Updated `app_title` in `localization.dart` for both Italian and English.
    - Updated the title and motto in `AuthScreen`, the welcome screens in `dashboard_screen.dart`, all tier texts in `subscription_screen.dart`, and the premium header modal in `pro_features_modal.dart`.
    - Updated "Growth" to "Evolve" in documentation files: `FINANCIAL_PLAN.md`, `BACKEND_ARCHITECTURE.md`, and `FLUTTER_COMMANDS.md`.

- [2026-05-17 16:15]: **Comprehensive System Locale Detection & Global Multi-Language Support**
  - *Details*: Added dynamic iPhone/system language detection at application startup. Translated all login screens, onboarding pages, and tutorial sections into English and Italian dynamically.
  - *Tech Notes*:
    - Updated `settings_provider.dart` to import `dart:ui` and dynamically fallback to the iPhone's language (using `PlatformDispatcher.instance.locale`) on first startup.
    - Updated `localization.dart` to add comprehensive translations for the Auth/Login screen, onboarding steps, and tutorials (Goals, Stats, and Dashboard). Removed duplicates and cleaned unused imports.
    - Migrated hardcoded Italian strings in `auth_screen.dart`, `dashboard_screen.dart`, `macro_goals_screen.dart`, and `statistics_screen.dart` to use `context.l10n.translate(...)`.
    - Validated formatting and clean compilation via `flutter analyze` with 0 warnings or errors.

- [2026-05-17 16:18]: **Rebranding Motto Layout Update**
  - *Details*: Set the login screen motto "better each day. become who you're meant to be" on two separate lines for a better layout design.
  - *Tech Notes*:
    - Modified `auth_screen.dart` to split the text with `\n` after the dot.

- [2026-05-17 16:21]: **Fully Responsive & Non-Scrollable Login Layout**
  - *Details*: Redesigned the authentication screen to fit 100% within the screen height without scrolling on standard and compact devices, while preserving scrollability only when the soft keyboard is visible.
  - *Tech Notes*:
    - Dynamically computed compact sizing parameters (logo size, margins, field spacing, and button height) based on `MediaQuery.sizeOf(context).height`.
    - Automatically reduced spacing and layout paddings for heights below 780dp.

- [2026-05-17 16:23]: **Ultra-Compact Legal Links Layout**
  - *Details*: Further optimized vertical spacing and reduced font sizes for legal links and toggles on smaller screens. 
  - *Tech Notes*:
    - Set font size for legal links to 10.0 and vertical paddings to 2.0 when `isCompact` is active.
    - Reduced bottom padding of the `SingleChildScrollView` to prevent any scroll behavior when the keyboard is closed.

- [2026-05-17 16:24]: **Premium Typographic Motto Design**
  - *Details*: Redesigned the login motto with a highly elegant and professional dual-font typography (Plus Jakarta Sans + Playfair Display) to create a premium visual experience.
  - *Tech Notes*:
    - Set the first part "better each day." to uppercase, custom letter-spaced Plus Jakarta Sans in primary theme color.
    - Set the second part "become who you're meant to be" to beautiful semi-bold italic Playfair Display.

- [2026-05-17 16:28]: **Bold Uppercase Title & Uniform Serif Motto Styling**
  - *Details*: Styled the Evolve app logo title to "EVOLVE" in all-caps, ultra-bold, with generous letter spacing. Harmonized the motto to be entirely formatted in elegant Playfair Display italic.
  - *Tech Notes*:
    - Updated 'Evolve' title to 'EVOLVE' in `auth_screen.dart` with `FontWeight.w900` and `letterSpacing: 2.0`.
    - Formatted both lines of the motto "better each day.\nbecome who you're meant to be" using the `Playfair Display` semi-bold italic layout.

- [2026-05-17 16:29]: **Motto Exclamation Mark Update**
  - *Details*: Added an exclamation mark to the end of the second line of the motto to give it an inspiring, energetic touch.
  - *Tech Notes*:
    - Updated the motto text to `"better each day.\nbecome who you're meant to be!"` in `auth_screen.dart`.

- [2026-05-18 10:00]: **Elegant iOS Public Landing App Store Legal Set (Privacy & Terms)**
  - *Details*: Built a stunning, cohesive "minimal tech" legal suite including GDPR-compliant Privacy Policy and Terms of Service pages required for iOS App Store distribution of the Evolve mobile application.
  - *Tech Notes*:
    - Created `src/pages/PrivacyPolicy.tsx` with side-scrolling navigation, clear data disclosures (local SharedPreferences, private Supabase RLS instances, zero data brokering, Sentry consents, and local-first Ollama AI coach settings).
    - Created `src/pages/TermsOfService.tsx` detailing software licensing, MIT open-source disclaimers, account security, IP parameters, and a vital Wellness Correlation Index limitation of liability.
    - Created a highly reusable premium component `src/components/PublicFooter.tsx` containing glowing purple layouts, legal links, and an App Store promotional card.
    - Refactored `src/pages/LandingPage.tsx`, `src/pages/FeaturesPage.tsx`, `src/pages/PhilosophyPage.tsx`, `src/pages/TechPage.tsx`, and `src/pages/FAQ.tsx` to integrate the unified footer and include App Store download calls.
    - Configured pathways `/privacy` and `/terms` inside `src/App.tsx`. Verified build success (`npm run build`).

- [2026-05-18 12:05]: **Total Companion Site Visual Rebranding to EVOLVE**
  - *Details*: Fully rebranded the companion web app's visual structure from "mattioli.OS" to "EVOLVE" to match the premium App Store name and look, while keeping the functional git pathing unchanged.
  - *Tech Notes*:
    - Rebranded `src/components/PublicHeader.tsx` and `src/components/PublicFooter.tsx` with mono-spaced, tracked-wide uppercase "EVOLVE" logos.
    - Updated SEO `<title>` and social card meta headers inside `index.html`.
    - Modified onboarding and setup texts inside `src/pages/GetStartedPage.tsx` and `src/pages/TechPage.tsx` to showcase the companion PWA and native iOS Evolve app.
    - Rebranded developer bio paragraphs and manifesto headers inside `src/pages/CreatorPage.tsx` and `src/pages/PhilosophyPage.tsx`.
    - Rewrote FAQ entries inside `src/pages/FAQ.tsx` emphasizing the native iOS App Store release of Evolve alongside the PWA.
    - Refactored legal disclaimers, trademark ownership parameters, and contact queries to `support@evolve.app` inside `src/pages/PrivacyPolicy.tsx` and `src/pages/TermsOfService.tsx`.
    - Rebranded dashboard footer widgets inside `src/pages/Index.tsx` and the authentication logo inside `src/pages/Auth.tsx`.
    - Ran and validated complete compilation build (`npm run build`) successfully.

- [2026-05-18 15:30]: **Comprehensive Mobile App Documentation & Overwrite**
  - *Details*: Created a highly thorough, complete description of the Evolve app and overwrote the generic mobile README.md with it.
  - *Tech Notes*:
    - Documented product vision, motto, target audience, and complete technical mobile stack (Flutter, Riverpod, Go Router, FL Chart, etc.).
    - Documented database acceleration (Supabase, RPC functions like get_global_trend, get_habit_analytics, get_habit_correlations, get_macro_goals_stats, RLS rules).
    - Fully detailed key features: actionable notifications, multitemporal goals, Memento Mori life view, context-aware AI chat coach, and 3-stage tutorial.

- [2026-05-18 16:15]: **iOS Auto-Renewable Subscriptions & RevenueCat SDK Suite Integration**
  - *Details*: Fully integrated RevenueCat SDK suite (`purchases_flutter` and `purchases_ui_flutter`) with dynamic product offerings, full entitlement checking for "Evolve Pro", cloud Paywall rendering, and Customer Center interface.
  - *Tech Notes*:
    - Installed `purchases_flutter` and `purchases_ui_flutter` (v10.1.0) and confirmed clean workspace build.
    - Set Evolve's actual RevenueCat API key `test_fhgjUvndzwYEVcjbmswbQTiWWuX` in [revenuecat_config.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/core/revenuecat_config.dart).
    - Upgraded [subscription_service.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/core/subscription_service.dart) to check the entitlement `'Evolve Pro'`.
    - Added full support for Monthly, Yearly, and Lifetime (`lifetime`) packages with the modern `Purchases.purchase(PurchaseParams.package(package))` method.
    - Embedded `RevenueCatUI.presentPaywall()` for beautiful native graphical paywall rendering in the cloud.
    - Embedded `RevenueCatUI.presentCustomerCenter()` for full in-app compliant subscription management, billing modifications, and refund processes.
    - Upgraded [subscription_screen.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/subscription_screen.dart) as a dynamic vertical selector for the three plans with interactive selection states, custom indicators, custom cloud Paywall triggers, a Flexible text layout strategy that completely prevents RenderFlex row overflows on compact screens, explicit red SnackBar feedback when a transaction is aborted or fails, and a beautiful premium glassmorphic celebration popup dialog that triggers a deep haptic sensation upon successful subscription activations.
    - Updated [pro_features_modal.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/widgets/pro_features_modal.dart) to cleanly redirect the "Ottieni Pro" button directly to the live [SubscriptionScreen](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/subscription_screen.dart) routing, completely replacing the deprecated "Coming Soon" popup placeholders.
    - Updated [habit_management_modal.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/widgets/habit_management_modal.dart) to redirect the "Sblocca Evolve Pro" button and save actions directly to [SubscriptionScreen](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/subscription_screen.dart), solving a bug where clicking the button with an empty name text field did nothing.
    - Created and deployed the secure [revenuecat-webhook/index.ts](file:///Users/simo/Downloads/DEV/mattioli.OS/supabase/functions/revenuecat-webhook/index.ts) Supabase Edge Function to securely synchronize active subscription entitlements with the `is_pro` field in the Supabase database.
    - Configured [config.toml](file:///Users/simo/Downloads/DEV/mattioli.OS/supabase/config.toml) to disable gateway-level JWT verification for the webhook, allowing custom Bearer token authorization checks.
    - Cleanly excised the "Lifetime" package variables, selectors, and card UI elements from [subscription_screen.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/subscription_screen.dart) to focus Evolve Pro exclusively on standard recurring **Monthly** and **Yearly** subscription models.

- [2026-05-18 21:35]: **App Tracking Transparency & Custom Onboarding Prompt Fix**
  - *Details*: Resolved the iOS App Store rejection regarding custom tracking prompts and App Tracking Transparency (ATT). Since the app has no tracking/advertising code (Sentry diagnostics and Supabase database/auth do not count as tracking), we removed the Sentry switch from the initial `ConsentScreen` onboarding. This completely removes the "custom prompt" that Apple's review flagged.
  - *Tech Notes*:
    - Changed `hasSentryConsent` default value from `false` to `true` inside `consent_provider.dart` and `main.dart` so Sentry is enabled by default for new installations.
    - Modified `consent_screen.dart` to completely remove the custom "Miglioramento App (Sentry)" consent switch card and its layout structures, while making `_sentryConsent` `final` with a value of `true`.
    - Maintained the full "Invia Segnalazioni Crash" toggle switch in `PrivacySettingsScreen` under "Gestione Dati", keeping user opt-out options perfectly functional without conflicting with Apple's onboarding guidelines.
    - Validated all Dart changes with `flutter analyze` ensuring exactly zero errors, warnings, or info logs.

- [2026-05-18 21:50]: **Sign in with Apple Design & UX Compliance Fix**
  - *Details*: Resolved the iOS App Store rejection regarding the "Sign in with Apple" flow. Apple requires that name and email are harvested automatically from the authentication framework and that users are NOT prompted with secondary custom registration or profile name screens. We updated our Apple auth flow to capture the name automatically on first registration, and modified the main dashboard name checker to completely bypass the blocking name dialogue for Apple users.
  - *Tech Notes*:
    - Updated `signInWithApple()` in `auth_provider.dart` to check if `credential.givenName` or `credential.familyName` is provided, construct the full name, and asynchronously save it to the Supabase Auth user metadata via `supabase.auth.updateUser` right after the user signs in with their ID token.
    - Modified `_checkProfileName()` inside `dashboard_screen.dart` to check the current Riverpod `authProvider` state's OAuth provider. If the provider is `'apple'`, the screen bypasses the `_showNameDialog()` entirely, preventing any secondary name entry screens from blocking the user.
    - Validated all changes with `flutter analyze` returning 0 errors or warnings.

- [2026-05-18 21:55]: **Monetization and Device Capability Compliance Fix (Guideline 4.10)**
  - *Details*: Resolved the iOS App Store rejection regarding monetizing native device features (biometrics / Face ID / Touch ID). Apple prohibits locking built-in iOS capabilities behind subscriptions. We resolved this by opening up the biometric lock feature to all users for free, replacing the biometric security items in the premium menus with an "Unlimited Habits" premium list item.
  - *Tech Notes*:
    - Modified `privacy_settings_screen.dart` to remove the `isLocked` flag from the biometric lock switch and excised the `settings.isPro` validation from the `onChanged` event handler. The biometric lock is now completely free.
    - Updated `pro_features_modal.dart` to replace the "Advanced Biometric Security" premium feature item with "Unlimited Habits" (which corresponds to our free-tier habit count limitation).
    - Updated `subscription_screen.dart` to replace the "Biometric Protection" premium row with "Unlimited Habits".
    - Removed the unused `pro_features_modal.dart` import from `privacy_settings_screen.dart` to keep static analysis perfect.
    - Verified all files are compiling with zero errors or warnings via `flutter analyze`.

- [2026-05-18 22:00]: **Monetization Architecture & Dynamic Paywall Screenshot Fallback (Production-Ready)**
  - *Details*: Implemented a 100% production-ready, enterprise-grade fallback system to resolve the App Store Connect "chicken-and-egg" screenshot requirement. When live store products are not yet active or are unreachable due to network drops, the paywall immediately renders a beautiful interactive mock pricing layout, preventing blank states or loaders. Added standard pull-to-refresh reload capabilities and fully resolved all static analysis linter warnings.
  - *Tech Notes*:
    - Upgraded [subscription_screen.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/subscription_screen.dart) to automatically render mock packages (`Mensile €4,99` and `Annuale €29,99`) if dynamic offerings return null.
    - Integrated standard `RefreshIndicator` with `AlwaysScrollableScrollPhysics` in the main body, allowing the user/reviewer to pull-to-refresh to pull active products instantly.
    - Programmed a dynamic background re-fetch in the Mock package purchase click. If the network recovered or products became active on Apple, it automatically merges the user to the real StoreKit transaction flow in real-time. If it still fails, it shows a clean connection warning.
    - Captured the `ScaffoldMessenger` reference before the async gaps to completely eliminate static analysis warnings (`use_build_context_synchronously`).
    - Verified all files compile cleanly with zero errors/warnings via `flutter analyze`.

- [2026-05-18 22:05]: **Pod Integration & Native Dynamic Library Fix (objective_c.framework)**
  - *Details*: Resolved the native runtime crash `Failed to load dynamic library objective_c.framework/objective_c` during local execution (`flutter run`). This dynamic library loading issue occurs when CocoaPods has stale caches after the addition of FFI-heavy plugins (like `purchases_flutter`).
  - *Tech Notes*:
    - Performed a deep build cache wipe using `flutter clean`.
    - Wiped and rebuilt all CocoaPods targets using `pod deintegrate` and a clean `pod install`.
    - Fully resolved Xcode link variables and verified that Cocoapods mapped all 29 pods (including RevenueCat, Google Sign-In, and Sentry) successfully with exit code 0.

- [2026-05-18 22:15]: **Clean Custom Paywall Integration & RevenueCat UI Removal**
  - *Details*: Fully decoupled the custom in-app native premium screen (`SubscriptionScreen`) from RevenueCat's dynamic cloud UI paywall wrapper. This eliminates any hybrid transitions or secondary redirects, ensuring that the app's visual identity remains perfectly consistent, clean, and professional.
  - *Tech Notes*:
    - Excised the secondary "Mostra Paywall Grafico di RevenueCat" button and its text styling assets from [subscription_screen.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/subscription_screen.dart) for both mock and active layouts.
    - Confirmed that all premium buttons throughout the app (Profile, Habit Limit trigger, and Feature modals) map directly and exclusively to the custom native paywall.
    - Verified all files compile cleanly with 0 errors/warnings via `flutter analyze`.

- [2026-05-18 22:20]: **Pro Benefit Update: Sincronizzazione Cloud Replaced with Obiettivi Illimitati**
  - *Details*: Replaced the "Sincronizzazione Cloud" entry in the Pro benefits list with "Obiettivi Illimitati" (Unlimited Goals). This keeps the monetization features perfectly focused on core user-facing functionality and is consistent with the "Abitudini Illimitate" design logic.
  - *Tech Notes*:
    - Updated [subscription_screen.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/subscription_screen.dart) at line 308 to display `LucideIcons.target` for the icon, "Obiettivi Illimitati" as the title, and "Crea tutti i tuoi macro obiettivi senza limiti." as the benefit description.
    - Verified compile safety with `flutter analyze` returning 0 errors/warnings.

- [2026-05-18 22:25]: **Dual-Layer Dynamic Pricing & StoreKit Direct Query Integration**
  - *Details*: Fully automated the connection between App Store Connect and the paywall interface. If active offerings are not published yet, the app initiates a secondary query directly to Apple StoreKit using `Purchases.getProducts(...)` to pull localized pricing dynamically, completely replacing static values with live data and only keeping static values as a secure third-layer offline fallback.
  - *Tech Notes*:
    - Added `_mockMonthlyPrice` and `_mockYearlyPrice` state variables in [subscription_screen.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/subscription_screen.dart).
    - Upgraded `_loadOfferings()` to perform a direct query for `com.simo.evolve.pro.monthly` and `com.simo.evolve.pro.yearly` via `Purchases.getProducts` if the initial dynamic offerings call fails or returns empty.
    - Mapped the retrieved `product.priceString` values directly into the fallback pricing cards.
    - Verified all files compile cleanly with 0 errors/warnings via `flutter analyze`.

- [2026-05-18 22:30]: **Privacy Policy URL Alignment**
  - *Details*: Updated all legal/Privacy Policy links across the mobile application to point to the new brand link requested by the user.
  - *Tech Notes*:
    - Replaced the old link with `https://simo-hue.github.io/evolve/privacy.html` in:
      - [consent_screen.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/consent_screen.dart) at line 205.
      - [auth_screen.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/auth_screen.dart) at lines 429 and 452.
      - [subscription_screen.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/subscription_screen.dart) at line 645.
    - Verified compilation with `flutter analyze` returning 0 errors/warnings.

## Current Status

- **Immediate Next Step**: Compile a new iOS release build via `flutter build ipa --release` in the `mobile` directory, archive and upload it in Xcode, and resubmit it for App Store Review. Ensure that "App Privacy" settings are configured with NO tracking, make sure that both of Evolve's subscription products (Monthly and Yearly) are associated with the new app submission and submitted for review together with the build, and paste the three English review note sections (ATT fix, Sign in with Apple compliance fix, and Biometric lock monetization fix) from `TO_SIMO_DO.md` into the Review Notes in App Store Connect.
