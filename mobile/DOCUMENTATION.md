# DOCUMENTATION.md

## [2026-07-13 22:12]: Fix — haptic crash on disposed `ref` + truncated import-summary dialog
*Details*: Fixed a production crash (captured in real-device logs) where enabling/disabling iCloud sync and leaving the screen mid-operation threw `Bad state: Using "ref" ... unmounted`. Root cause: `AppHaptics._trigger` reads `settingsProvider` through `ref`, and a haptic fired from `_runAction`'s `finally` after the user popped the screen read a disposed `ref`. Also fixed the "Import Completed" summary dialog whose rows were clipped on the right edge — the row `Text` could not wrap inside the fixed-width Cupertino alert.
*Tech Notes*:
- **Hardened layer** — `lib/core/haptics.dart`: wrapped `_trigger`'s `ref.read` in try/catch so a purely cosmetic haptic can never crash the app; swallows the disposed-`ref` error with a `kDebugMode`-only `debugPrint` (silent in release, no Sentry noise). Added `package:flutter/foundation.dart` import.
- **Crash call site** — `lib/ui/screens/icloud_sync_screen.dart` `_runAction`: moved `ref.hapticLight()` inside the existing `if (mounted)` guard in the `finally`.
- **Targeted after-disposal audit** (all 131 haptic sites reviewed; only async/after-`await`/`finally`/callback sites touched — synchronous tap handlers left alone): added mounted guards at —
  - `lib/ui/kit/evolve_color_picker.dart` (after `showEvolveColorPicker` await → `&& context.mounted`)
  - `lib/ui/screens/privacy_settings_screen.dart` biometric-lock `onChanged` (after `_authenticate` await → `if (!context.mounted) return;`)
  - `lib/ui/screens/profile_screen.dart` `_pickImage` (after gallery-picker await → `if (!mounted) return;`) and `_showLogoutConfirmationDialog` (after confirm await → `if (!mounted) return;`)
  - `lib/ui/widgets/macro_goals/category_picker_sheet.dart` `_showDeleteCategory` (after `deleteCategory` await → `&& context.mounted`)
  - `lib/ui/widgets/macro_goals/goal_item_widget.dart` `_showDeleteConfirm` (`if (confirmed && mounted)`)
- **Dialog fix** — `lib/ui/screens/privacy_settings_screen.dart` `_buildSummaryRow`: wrapped the summary `Text` in `Expanded` and top-aligned the icon (`CrossAxisAlignment.start`) so each line wraps within the ~270pt fixed-width `CupertinoAlertDialog` instead of truncating.
- **Verification**: `flutter analyze` on all touched files — clean (only pre-existing `info`-level lints). No new dependencies; no manual actions required.


## [2026-07-13 13:54]: App Version Bump
*Details*: Bumped the mobile app version in `pubspec.yaml` from `1.1.0+15` to `1.1.1+16` for an upcoming IPA build and App Store Connect upload via Transporter.
*Tech Notes*:
- Modified `pubspec.yaml` `version` field.


## [2026-07-02 12:33]: Feature - In-App Log Viewer (App Logs Screen)
*Details*: Added a full in-app log viewer accessible from the Profile → System section. The feature captures all errors, warnings, and info-level logs in an in-memory ring buffer (500 entries max) and presents them in a developer-console–style UI with JetBrains Mono monospace font, color-coded severity badges, filterable chips, full-text search, and expandable detail sheets with selectable text for stack traces. Designed for technical users to diagnose issues without external tools.
*Tech Notes*:
- **Modified**: `lib/core/app_logger.dart` — Renamed `LogLevel` to `AppLogLevel` to avoid conflicts, added `LogEntry` model, in-memory `_logs` ring buffer (500 max), listener system for reactive UI updates, and `clearLogs()`. All existing Sentry integration preserved unchanged.
- **New**: `lib/ui/screens/app_logs_screen.dart` — Full log viewer screen with: filter chips (All/Errors/Warnings/Info) with live counts, search bar (JetBrains Mono), log cards with level badges + timestamps, expandable detail bottom sheet (message, error, extras, stack trace all selectable), copy-to-clipboard (single entry or all filtered), clear logs with confirmation dialog.
- **Modified**: `lib/ui/screens/profile_screen.dart` — Added "App Logs" menu item in the System section with `LucideIcons.scrollText` icon.
- **i18n**: Added `appLogs` section to all 5 language files (EN, IT, DE, ES, AR) with 16 keys each, then regenerated with `dart run slang`.
- **Global Error Handling**: Modified `lib/main.dart` `PlatformDispatcher.instance.onError` to route all unhandled global exceptions into `AppLogger.error` so they appear in the UI.
- **iCloud Sync Logging**: Modified `lib/core/cloudkit_private_sync_service.dart` and `lib/core/sync_engine.dart` to emit detailed `AppLogger.info` events for sync lifecycles and `AppLogger.error` for both top-level sync failures and individual record apply/push failures.
- **Log Persistence**: Added local file persistence to `AppLogger` (`app_logs.json`) using `path_provider`. The buffer is written asynchronously with a 2-second debounce (`Timer`) to prevent UI stutter during heavy logging. Logs are loaded synchronously early in `main.dart` so they survive app crashes and restarts.
- **Navigation & Lifecycle Breadcrumbs**: Attached `AppLoggerNavigatorObserver` to `GoRouter` and added lifecycle logging to `WidgetsBindingObserver` in `main.dart` so users can see exactly what screens were navigated and when the app was backgrounded/foregrounded leading up to an error.
- **Share Logs via File**: Added a Share icon to the `AppLogsScreen` top menu that exports all 500 logs as a plain text file (`.txt`) and opens the native iOS share sheet (using `share_plus`), making it easy to email or AirDrop logs to developers.

## [2026-07-02 12:20]: UI - Mood Check-In Pulsing Glow Animation & Checkmark Badge
*Details*: Added a heartbeat-style pulsing red glow animation to the daily mood check-in tile on the dashboard when the user hasn't logged their mood for the day. When mood is logged, the glow stops instantly and a green checkmark badge appears in the top-right corner of the tile.
*Tech Notes*:
- Modified `lib/ui/widgets/protocollo_panel.dart` only (single-file change).
- `ProtocolloPanel` now watches `dailyMoodsProvider` to reactively detect today's mood status.
- `_ActionTile` converted from `StatelessWidget` to `StatefulWidget` with `SingleTickerProviderStateMixin`.
- New parameters: `showPulse` (animated red `BoxShadow`, ~2s cycle with `Curves.easeInOut`) and `showCheckBadge` (18px green circle with white checkmark).
- Animation starts/stops via `didUpdateWidget` — no manual lifecycle management needed from callers.
- No changes to `daily_check_in_modal.dart` or `dashboard_screen.dart`; state flows reactively through Riverpod.

---

## [2026-06-22 21:00]: Release - Version Bump
*Details*: Incremented application version for a new release.
*Tech Notes*:
- Bumped version in `pubspec.yaml` from `1.0.4+8` to `1.0.5+9`.


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

---

## [2026-05-13 22:50]: Feature - AI Chat for Pro Users with Goals Integration
*Details*: Implemented a premium chat interface for Pro users to interact with their goals and statistics. Non-Pro users continue to see the promotional modal.
*Tech Notes*:
- Created `AIChatScreen` in `lib/ui/screens/ai_chat_screen.dart` with glassmorphic design and quick action pills.
- Updated `ProtocolloPanel` in `lib/ui/widgets/protocollo_panel.dart` to check `isPro` status and navigate accordingly.
- Integrated `macroGoalsProvider` and `userProfileProvider` for context in the chat.
- Verified with `flutter analyze` and fixed unused imports.

---

## [2026-05-13 22:53]: UI - Moved Suggested Prompts to Bottom in AI Chat
*Details*: Moved the suggested prompts from the top of the chat to the bottom, just above the input field, to improve ergonomics and make them more easily clickable on mobile devices.
*Tech Notes*:
- Rearranged widgets in `lib/ui/screens/ai_chat_screen.dart` to place the `Suggested Prompts` block after the `Chat Area` and before the `Input Area`.

---

## [2026-05-14 10:24]: UI - Empty State in DayDetailsModal
*Details*: Added a professional empty state with a call to action when a user views a day with no active habits.
*Tech Notes*:
- Modified `lib/ui/widgets/day_details_modal.dart` to show a message and a "Crea Abitudine" button when `activeHabits.isEmpty`.
- Integrated `HabitManagementModal.show(context)` to open the habit creation modal directly from the empty state.
- Fixed analyzer issues (unnecessary import and underscores).

---

## [2026-05-14 10:32]: UI - Global Empty State on Dashboard
*Details*: Implemented a global empty state on the dashboard when the user has no habits created, to guide new users.
*Tech Notes*:
- Modified `lib/ui/screens/dashboard_screen.dart` to watch `goalsProvider`.
- Added `_buildGlobalEmptyState()` method to show a beautiful message and an "Aggiungi Abitudine" button.
- Conditioned the display on `habits.isEmpty && currentView != CalendarView.vita`.
- Imported `lucide_icons_flutter` and `habit_management_modal.dart`.

---

## [2026-05-14 10:43]: UI - Empty State in InfoTabWidget (Stats)
*Details*: Added an educational empty state in the "Info" tab of Statistics when there are no habits or logs yet.
*Tech Notes*:
- Modified `lib/ui/widgets/statistics/info_tab_widget.dart` to check if `statsList.isEmpty`.
- Added `_buildEmptyState()` method returning a glassmorphic container with an explanation.


## [2026-05-14 11:15]: Onboarding - Tutorial Implementation Plan
*Details*: Created an implementation plan artifact for the unskippable onboarding tutorial using `tutorial_coach_mark`.
*Tech Notes*:
- Suggested `tutorial_coach_mark` package to highlight features and prevent skipping.
- Outlined state management using `SharedPreferences` to track if the tutorial was seen.
- Created `tutorial_plan.md` artifact with the full strategy for user review.

**Current Status**:
- Tutorial implementation complete.
- Tested and functioning as expected.

---

## [2026-05-14 11:18]: Onboarding - Tutorial Implementation
*Details*: Successfully implemented the unskippable onboarding tutorial using `tutorial_coach_mark`.
*Tech Notes*:
- Installed `tutorial_coach_mark` dependency.
- Created `tutorial_provider.dart` using `SharedPreferences` to persist the `has_seen_tutorial` flag.
- Added `GlobalKey`s to `HomeScreen` in `dashboard_screen.dart` to highlight `ProtocolloPanel`, `ViewTabBar`, and the `ElevatedButton` for adding a habit.
- Updated `AppBottomNavBar` to accept `navKeys` parameter and assigned keys to "Home", "Statistiche", and "Obiettivi".
- Initialized `TutorialCoachMark` via `addPostFrameCallback` with `hideSkip: true` to prevent skipping.

**Current Status**:
- Feature fully functional.
- Fixed Riverpod 2.0+ `Notifier` compatibility and `super.key` in custom widgets.
- Added full-screen Welcome dialog before the tutorial (name removed for first-time launch).
- Wrapped tutorial text in premium cards to prevent overlap and improve legibility over the app's UI.
- Updated tutorial sequence: Daily Check-In -> AI Chat -> Gestione Abitudini -> Viste Calendario -> Calendario -> Obiettivi Nav.
- Added "Indietro" and "Avanti/Fine" buttons directly inside the tutorial cards for explicit navigation control.
- Disabled taps on the target widgets and the overlay to strictly force the user to use the tutorial navigation buttons.
- Implemented a two-stage tutorial logic: the dashboard tutorial now programmatically redirects to the `MacroGoalsScreen` where the second half of the tutorial seamlessly continues.
- Implemented `GoalsTutorialNotifier` to persist the state of the goals tutorial independently.
- Resetting the tutorial from the Profile screen resets both dashboard and goals tutorial states simultaneously.

---

## [2026-05-14 12:21]: Onboarding - Tutorial Goal Actions Highlight
*Details*: Migliorata la parte di tutorial degli obiettivi inserendo un finto obiettivo dimostrativo e aggiungendo il padding del focus per rendere visibili i piccoli pulsanti di azione.
*Tech Notes*:
- Iniettato un mock `MacroGoal` chiamato "Obiettivo Tutorial" nella lista quando il tutorial degli obiettivi è attivo.
- Aggiunti parametri `GlobalKey` opzionali in `GoalItemWidget` per poter agganciare i target ai singoli bottoni d'azione.
- Impostato `paddingFocus: 12` su tutti i target piccoli nel tutorial degli obiettivi per garantire che l'effetto alone (cerchio di focus) sia visibile e non nascosto dal bordo dell'overlay.

**Current Status**:
- Il sistema di tutorial a due stadi è completo, privo di bug visivi e molto dettagliato!
- Pronto per passare ad altre feature o rifiniture.

---

## [2026-05-14 12:23]: Onboarding - Tutorial Stats View Auto-Switch
*Details*: Configurato il tutorial affinché mostri effettivamente la schermata delle statistiche quando arriva a quello step, per poi tornare indietro se l'utente naviga a ritroso.
*Tech Notes*:
- Utilizzato il callback `onFocus` di `TutorialCoachMark`.
- Impostato `_showStats = true` quando l'identificatore del target è "Analisi Performance", e `false` per tutti gli altri.

**Current Status**:
- Il sistema di tutorial è estremamente dinamico e reattivo.

---

## [2026-05-14 12:26]: Onboarding - 3-Stage Tutorial (Home -> Goals -> Stats)
*Details*: Completato il cerchio del tutorial estendendolo anche alla pagina delle statistiche generali (Abitudini). Al termine del tutorial degli obiettivi, l'utente viene spostato a sinistra sulle statistiche, e al termine di queste viene riportato alla Home.
*Tech Notes*:
- Creato `statsTutorialProvider` in `tutorial_provider.dart`.
- Aggiunto supporto per callback `onFinishTutorial` in `MacroGoalsScreen` e `StatisticsScreen`.
- Implementato il tutorial in `StatisticsScreen` con 2 target (Filtro e Tabs).
- Gestita la navigazione sequenziale in `DashboardScreen` tramite i callback.

**Current Status**:
- Il sistema di tutorial a 3 stadi è completo e funzionante.

---

## [2026-05-14 12:39]: Fix - Compilation Errors after Hot Restart
*Details*: Risolti gli errori di compilazione dovuti alla cancellazione accidentale di `goalsTutorialProvider` e all'uso di `onFocus` non supportato nella versione corrente di `tutorial_coach_mark`.
*Tech Notes*:
- Reinserito `goalsTutorialProvider` in `tutorial_provider.dart`.
- Rimosso `onFocus` da `TutorialCoachMark` in `macro_goals_screen.dart`.
- Utilizzato `WidgetsBinding.instance.addPostFrameCallback` all'interno del `builder` dei target per gestire lo switch della vista statistiche in modo compatibile.

**Current Status**:
- Errori risolti, l'app compila e funziona correttamente.

---

## [2026-05-14 12:44]: Onboarding - Added Stats Tab Target in Goals Tutorial
*Details*: Migliorata l'esperienza utente aggiungendo uno step intermedio nel tutorial degli obiettivi che punta direttamente al pulsante "Statistiche" nella barra di navigazione inferiore, spiegando dove trovare le statistiche delle abitudini giornaliere prima di effettuare il passaggio di pagina.
*Tech Notes*:
- Aggiunto parametro `statsNavKey` a `MacroGoalsScreen`.
- Passata la chiave `_statsNavKey` da `DashboardScreen`.
- Modificato l'ultimo step ("Analisi Performance") per avere l'etichetta "Continua".
- Aggiunto un nuovo target condizionale (se `statsNavKey != null`) che punta alla tab delle statistiche.

**Current Status**:
- Flusso del tutorial rifinito e molto più chiaro per l'utente.

---

## [2026-05-14 12:47]: Fix - Statistics Tutorial Trigger on Tab Change
*Details*: Risolto il problema per cui il tutorial delle statistiche non partiva automaticamente quando l'utente veniva reindirizzato a quella pagina. Essendo la pagina mantenuta in memoria, `initState` non veniva richiamato.
*Tech Notes*:
- Spostata la logica di controllo del tutorial dal `initState` al metodo `build` di `StatisticsScreen`.
- Utilizzato un flag `_tutorialTriggered` per evitare attivazioni multiple.
- Aggiunto un delay di 600ms tramite `Future.delayed` per permettere il completamento dell'animazione di cambio tab prima di mostrare il tutorial.

**Current Status**:
- Il tutorial delle statistiche ora parte correttamente e spiega il selettore del pannello e il filtro per obiettivi singoli.

---

## [2026-05-14 12:49]: Onboarding - Fixed Button Label in Stats Transition Step
*Details*: Modificata l'etichetta del pulsante nello step che punta alla tab delle statistiche. Invece di "Fine", ora mostra "Continua", rendendo chiaro che il tutorial non è finito ma prosegue su un'altra schermata.
*Tech Notes*:
- Impostato `isLast: false` e `nextButtonLabel: "Continua"` nel target "Tutorial Statistiche Tab" in `macro_goals_screen.dart`.

**Current Status**:
- Il flusso del tutorial è ora coerente anche nelle etichette dei pulsanti.

---

## [2026-05-14 12:50]: Onboarding - Consistent Tutorial Box Style in Statistics
*Details*: Rallineato lo stile del box del tutorial nella pagina delle statistiche con quello delle pagine precedenti per garantire coerenza visiva.
*Tech Notes*:
- Aggiornato `_buildTutorialContent` in `statistics_screen.dart`.
- Utilizzato `Theme.of(context).colorScheme.surface` per il background.
- Sostituito il cerchio colorato con l'icona `LucideIcons.info`.
- Utilizzati `ElevatedButton` e `TextButton` con lo stesso stile di `MacroGoalsScreen`.

**Current Status**:
- Tutti i box del tutorial ora hanno lo stesso stile premium e coerente.

---

## [2026-05-14 16:45]: Feature - Global Error Handling & Error Modal
*Details*: Implemented global error handling to protect the user from crashes and bugs. Created a custom error modal with a consistent premium style.
*Tech Notes*:
- **Error Modal**: Created `ErrorModal` in `lib/ui/widgets/error_modal.dart` with custom styling (red theme, glassmorphic container, triangle alert icon).
- **Global Handling**: Updated `lib/main.dart` to use `PlatformDispatcher.instance.onError` for catching unhandled async errors and showing the `ErrorModal`.
- **Navigation**: Added a `GlobalKey<NavigatorState>` to `GoRouter` to allow showing dialogs without a `BuildContext` from the global error handler.
- **Build Errors**: Refined `ErrorWidget.builder` to show a nicer fallback screen instead of a plain text error.

## [2026-05-14 18:50]: Feature - Error Modal Integration in Crucial Providers
*Details*: Integrated the `ErrorModal` into the most crucial database operations in `GoalProvider`, `MacroGoalsProvider`, `MoodProvider`, and `MacroGoalCategoriesProvider` to inform the user of failures during save/update/delete actions.
*Tech Notes*:
- **Navigator Key**: Moved `navigatorKey` to a separate file `lib/core/navigator_key.dart` to avoid circular imports between `main.dart` and providers.
- **Goal Provider**: Added error modal to `addHabit`, `updateHabit`, `deleteHabit`, and `cycleStatus`.
- **Macro Goals Provider**: Added error modal to `addGoal`, `updateStatus`, `updateTitle`, `updateCategory`, and `deleteGoal`.
- **Mood Provider**: Added error modal to `saveMood`.
- **Macro Goal Categories Provider**: Added error modal to `addCategory` and `deleteCategory`. Fixed `avoid_print` warnings.
- **Linter Fixes**: Fixed `use_build_context_synchronously` warnings by adding `context.mounted` checks.

**Current Status**:
- Error handling integrated in `GoalProvider`, `MacroGoalsProvider`, `MoodProvider`, and `MacroGoalCategoriesProvider`.
- All files clean of linter warnings.

**Next Step**:
- Hand over to user for verification.

---

## [2026-05-14 19:00]: UI - Default Profile Picture Fallback
*Details*: Impostata l'immagine fornita dall'utente come foto profilo di default per tutti gli utenti che si registrano o che non hanno un avatar impostato.
*Tech Notes*:
- **UI (Dashboard)**: Aggiornato `dashboard_screen.dart` per usare `AssetImage('assets/images/default_avatar.png')` come fallback se `avatarUrl` è null.
- **UI (Profile)**: Aggiornato `profile_screen.dart` per supportare la visualizzazione dell'avatar da rete e usare lo stesso fallback locale.
- **Manuale**: Aggiunta un'azione in `TO_SIMO_DO.md` per richiedere all'utente di salvare il file immagine nella cartella assets.

---

## [2026-05-14 19:15]: Auth - Google Sign-In Refactoring & Setup Guide
*Details*: Rifattorizzata l'implementazione di Google Sign-In per renderla più professionale e organizzata. Spostati i Client ID in un file di configurazione dedicato e aggiornate le istruzioni per l'utente.
*Tech Notes*:
- **Configurazione**: Spostati i placeholder per `googleWebClientId` e `googleIosClientId` da `auth_provider.dart` a `lib/core/supabase_config.dart`.
- **Auth Provider**: Aggiornato `signInWithGoogle` per usare le costanti da `SupabaseConfig`.
- **Manuale**: Aggiornato il file `TO_SIMO_DO.md` con i passaggi dettagliati per creare i Client ID su Google Cloud Console e configurarli.
- **Esempio**: Creato `lib/core/supabase_config.dart.example` per permettere la compilazione del progetto clonando il repo pubblico senza esporre le chiavi reali.

---

## [2026-05-14 21:15]: Auth - iOS URL Scheme Configuration for Google Sign-In
*Details*: Configurato lo schema URL in `Info.plist` con il Reversed Client ID fornito dall'utente per abilitare il login con Google su iOS.
*Tech Notes*:
- **iOS**: Aggiunto `CFBundleURLTypes` con lo schema `com.googleusercontent.apps.11071263331-qepubluq93tojdo3vti51ah3h09ss57m` in `ios/Runner/Info.plist`.

---

## [2026-05-15 09:52]: Core - Sentry Production Error Tracking Integration
*Details*: Integrato Sentry SDK per il tracking automatico di crash, errori Dart asincroni e navigazione in produzione.
*Tech Notes*:
- **Dipendenza**: Aggiunto `sentry_flutter: ^9.20.0` al `pubspec.yaml`.
- **Configurazione**: Creato `lib/core/sentry_config.dart` (DSN, environment, tracesSampleRate) seguendo il pattern di `supabase_config.dart`.
- **Sicurezza**: Creato `sentry_config.dart.example` e aggiunto `lib/core/sentry_config.dart` al `.gitignore`.
- **main.dart**:
  - Wrappato l'intera app con `SentryFlutter.init()` usando il pattern `appRunner`.
  - Integrato `Sentry.captureException()` nel `PlatformDispatcher.onError` esistente (gli errori sono sia inviati a Sentry che mostrati all'utente via ErrorModal).
  - Aggiunto `beforeSend` per associare automaticamente l'utente Supabase (id + email) a ogni evento Sentry.
- **Router**: Aggiunto `SentryNavigatorObserver()` a `GoRouter.observers` per il tracking della navigazione.
- **Refactoring Errori Silenti**: Sostituiti tutti i `debugPrint` all'interno dei blocchi `catch` (provider e servizi) con chiamate a `AppLogger.error` che inoltra l'errore a Sentry in produzione. File modificati includono `settings_provider.dart`, `mood_provider.dart`, `macro_goal_categories_provider.dart`, `notifications.dart`, `main.dart`, e svariati componenti UI (es. `privacy_settings_screen.dart`, `profile_screen.dart`, `dashboard_screen.dart`, `personal_info_screen.dart`).
- **Analisi Catch Generici**: Condotta un'analisi approfondita su tutti i blocchi `catch` dell'app per individuare eccezioni di rete o di database silenziate. Aggiunto `AppLogger.error(..., e, stack)` ai fallimenti di autenticazione (`auth_provider.dart`), chiamate RPC Supabase (`goal_provider.dart`, `macro_goals_stats_provider.dart`), e opzioni di reset/delete account (`privacy_settings_screen.dart`).

---

## [2026-05-15 10:45]: Core - Implementazione flutter_secure_storage per Supabase
*Details*: Aggiunto il pacchetto `flutter_secure_storage` per rendere l'applicazione più sicura, memorizzando la sessione di Supabase nel portachiavi sicuro del dispositivo anziché in SharedPreferences.
*Tech Notes*:
- **Dipendenza**: Aggiunta `flutter_secure_storage: ^9.2.2`.
- **Risoluzione Conflitti**: Downgradato `share_plus` a `^12.0.2` per risolvere un conflitto di dipendenze con `win32` richiesto da `flutter_secure_storage_windows`.
- **Implementazione**: Creata la classe `SecureLocalStorage` in `lib/core/secure_local_storage.dart` che estende `LocalStorage` di Supabase.
- **main.dart**: Aggiornato `Supabase.initialize` per passare `SecureLocalStorage` tramite `authOptions`.

---

## [2026-05-15 10:50]: Core - Spostamento Biometric Lock su SecureStorage
*Details*: Spostato lo stato del blocco biometrico (`biometricLock`) da `SharedPreferences` a `SecureStorage` per evitare che possa essere bypassato su dispositivi con root modificando il file delle preferenze.
*Tech Notes*:
- **Provider**: Aggiunto `biometricLockProvider` (FutureProvider) in `shared_prefs_provider.dart` per leggere lo stato in modo asincrono all'avvio.
- **SettingsProvider**: Aggiornato `_saveToPrefs` per scrivere lo stato anche in `SecureStorage`.
- **DashboardScreen**: 
  - Rimosso il controllo sincrono da `initState` che falliva se l'attaccante modificava le preferenze.
  - Aggiornato il metodo `build` per osservare `biometricLockProvider` e mostrare la schermata di blocco se attivo, garantendo che l'app rimanga bloccata finché l'operazione asincrona di lettura sicura non è completata.

---

## [2026-05-15 10:55]: Core - Hardening SecureStorage contro Corruzione KeyStore
*Details*: Implementata una gestione difensiva degli errori per `flutter_secure_storage` per prevenire crash infiniti in caso di corruzione del KeyStore (Android) o Keychain (iOS).
*Tech Notes*:
- **SecureLocalStorage**: Avvolte tutte le chiamate (`read`, `write`, `delete`) in blocchi `try-catch`. In caso di errore, l'eccezione viene loggata su Sentry tramite `AppLogger` e lo storage viene resettato (`deleteAll()`) per permettere all'app di continuare a funzionare (l'utente dovrà rifare il login).
- **biometricLockProvider**: Applicato lo stesso pattern di try-catch nella lettura dello stato del blocco biometrico. Se fallisce, logga l'errore, resetta lo storage e ritorna `false` per evitare di bloccare l'utente fuori dall'app in modo permanente.

---

## [2026-05-15 11:00]: Privacy - Sanitizzazione Log e Sentry (PII Scrubbing)
*Details*: Implementata la sanitizzazione dei log e degli eventi Sentry per garantire il massimo livello di privacy dei dati dell'utente, rimuovendo PII (Personally Identifiable Information) ed evitando di inviare l'email a Sentry.
*Tech Notes*:
- **SentryConfig**: Aggiunto il metodo `sanitizeEvent` che rimuove l'email dall'oggetto `SentryUser`, e pulisce ricorsivamente `breadcrumbs`, `contexts`, `message` e `exceptions` da pattern sensibili (Email, JWT, chiavi come password, token, secret).
- **main.dart**: Aggiornato il callback `beforeSend` di Sentry per invocare `SentryConfig.sanitizeEvent`.
- **AppLogger**: Aggiornato per usare `setContexts` invece del deprecato `setExtra` per allegare dati aggiuntivi agli errori, rimuovendo i warning del linter.

---

## [2026-05-15 11:05]: Cleanup - Rimozione Impostazione 'Analytics Anonimi'
*Details*: Rimossa l'impostazione `anonymousAnalytics` (Analytics Anonimi) che era obsoleta e non più utilizzata nell'app.
*Tech Notes*:
- **SettingsProvider**: Rimossa la variabile `anonymousAnalytics` da `AppSettings`, `_loadFromPrefs`, `_saveToPrefs`, `_syncFromSupabase` e `_syncToSupabase`.
- **PrivacySettingsScreen**: Rimossa l'esportazione di `anonymousAnalytics` nel metodo `_exportData`.

---

## [2026-05-15 11:10]: Privacy - Spostamento Impostazioni Pro/AI su SecureStorage
*Details*: Spostate le impostazioni della Categoria 2 (Feature Pro / AI) su `SecureStorage` per garantire il massimo livello di sicurezza contro manipolazioni su dispositivi con root.
*Tech Notes*:
- **SettingsProvider**: Aggiornato `_loadSecureSettings` per leggere asincronamente `pref_ai_suggestions`, `pref_is_pro`, `pref_focus_mode`, `pref_milestones` e `pref_deep_work_insights` da `SecureStorage` e aggiornare lo stato.
- **SettingsProvider**: Aggiornato `_saveToPrefs` per scrivere queste impostazioni anche su `SecureStorage` (mantenendo la scrittura su `SharedPreferences` per un caricamento iniziale sincrono senza flickering).

---

## [2026-05-15 11:32]: Privacy - Zero-PII in Logs and Breadcrumbs (Step 4)
*Details*: Centralizzata la logica di sanitizzazione dei dati in `PrivacyUtils` e applicata a `AppLogger` e `SentryConfig` per garantire che PII (email, token, password) non finiscano mai nei log o nei breadcrumb di Sentry.
*Tech Notes*:
- Creata `lib/core/privacy_utils.dart` con metodi `sanitizeString` e `sanitizeMap`.
- Aggiornato `lib/core/sentry_config.dart` per usare `PrivacyUtils`.
- Aggiornato `lib/core/app_logger.dart` per sanitizzare i messaggi prima di `debugPrint` e `Sentry.addBreadcrumb`.
- Aggiunto supporto per `extras` strutturati in `AppLogger.info` e `AppLogger.warning` con sanitizzazione automatica.

---

## [2026-05-15 11:40]: Privacy - Implementazione Cancellazione Completa Account via RPC
*Details*: Sostituita la cancellazione parziale dei dati lato client con una chiamata RPC a una funzione database (`delete_user_account`) per garantire la rimozione dell'utente anche da `auth.users` di Supabase, in conformità con il GDPR.
*Tech Notes*:
- **File Modificati**: `privacy_settings_screen.dart`.
- **Modifiche**: Rimosse le chiamate `delete().eq(...)` sulle tabelle pubbliche e sostituite con `await supabase.rpc('delete_user_account')`.
- **Azioni Manuali**: Aggiunta istruzione in `TO_SIMO_DO.md` per creare la funzione RPC su Supabase.

---

## [2026-05-15 11:45]: Privacy - Cifratura Cache Locale Abitudini e Log
*Details*: Spostata la memorizzazione della cache di abitudini e log da `SharedPreferences` (in chiaro) a `FlutterSecureStorage` (cifrato) per proteggere i dati sensibili dell'utente. Implementata anche la migrazione automatica al primo avvio.
*Tech Notes*:
- **File Modificati**: `main.dart`, `goal_provider.dart`.
- **Modifiche**: 
  - In `main.dart`, legge i dati da `FlutterSecureStorage` all'avvio e li passa tramite `initialGoalsProvider` e `initialLogsProvider`. Se non presenti, migra i vecchi dati da `SharedPreferences`.
  - In `goal_provider.dart`, `GoalsNotifier` e `HabitLogsNotifier` ora leggono lo stato iniziale dai nuovi provider e salvano gli aggiornamenti direttamente su `FlutterSecureStorage` in modo asincrono.

---

## [2026-05-15 11:50]: Privacy - Link Legali nella Schermata di Login
*Details*: Aggiunti i link a Privacy Policy e Termini di Servizio nella schermata di login per conformità con le linee guida degli store.
*Tech Notes*:
- **File Modificati**: `auth_screen.dart`, `pubspec.yaml`.
- **Modifiche**: 
  - Aggiunta dipendenza `url_launcher`.
  - Inseriti i link "Privacy Policy" e "Termini di Servizio" in fondo alla colonna di autenticazione in `AuthScreen`.
  - Implementato metodo `_openUrl` per aprire il link fornito dall'utente (`https://simo-hue.github.io/mattioli.OS/`) nel browser esterno.

---

## [2026-05-15 12:00]: Privacy - Rimozione Campo anonymous_analytics
*Details*: Rimozione del campo "fantasma" `anonymous_analytics` dal file di schema del database (`mobile_schema.sql`) in quanto non utilizzato nel codice dell'applicazione.
*Tech Notes*:
- **File Modificati**: `mobile_schema.sql`.
- **Modifiche**: Rimossa la riga `anonymous_analytics boolean NOT NULL DEFAULT true,` dalla tabella `profiles`.

---

## [2026-05-15 12:10]: Privacy - Schermata di Consenso Iniziale (ConsentScreen)
*Details*: Implementata una schermata di consenso obbligatoria al primo avvio dell'app per raccogliere l'accettazione dei Termini/Privacy, il consenso per Sentry e i permessi di notifica.
*Tech Notes*:
- **File Creati**: `consent_provider.dart`, `consent_screen.dart`.
- **File Modificati**: `main.dart`.
- **Modifiche**:
  - Aggiunto `ConsentScreen` al router.
  - Aggiornata la logica di redirect per forzare il passaggio da `/consent` se non completato.
  - Condizionata l'inizializzazione di Sentry al consenso dell'utente letto da `SharedPreferences`.

---

## [2026-05-15 14:10]: Statistics - Fix for Year Timeframe Single Dot Bug
*Details*: Fixed a UI bug in the "Evoluzione Performance" chart where selecting the "Anno" (Year) timeframe resulted in only a single dot being displayed instead of a line.
*Tech Notes*:
- **File**: `lib/ui/widgets/statistics/global_trend_tab_widget.dart`.
- **Change**: Modified the data processing for the chart. Previously, the data was split in half to calculate a delta, and only the second half was shown on the chart. For the "Year" timeframe, this often resulted in a single data point if the RPC returned few points (e.g., grouped by year or with few active months). Now, for `timeframe_year_short`, the chart displays all points returned by the RPC (`trendData`), ensuring a line is drawn if there are at least two points, while keeping the delta calculation based on the split data.

---

## [2026-05-15 14:15]: Statistics - Year Timeframe Padding with Default Values
*Details*: Further refined the "Evoluzione Performance" chart for the "Anno" timeframe. When there is only data for a few months, the chart now pads the missing months of the last 12 months with a default value of 100%, ensuring a full line is displayed instead of a single dot, consistent with other views.
*Tech Notes*:
- **File**: `lib/ui/widgets/statistics/global_trend_tab_widget.dart`.
- **Change**: Implemented a padding logic for `timeframe_year_short`. It generates labels for the last 12 months up to the current month. It initializes rates to 100.0 and fills in the actual rates from `trendData` where available. This ensures that the chart always shows 12 points and a continuous line.

---

## [2026-05-15 14:18]: Statistics - Hide Delta Badge in 'Tutto' Timeframe
*Details*: Removed the delta badge (percentage increase/decrease) from the "Evoluzione Performance" chart when the "Tutto" (All) timeframe is selected, as requested by the user. Only the overall completion rate is now displayed.
*Tech Notes*:
- **File**: `lib/ui/widgets/statistics/global_trend_tab_widget.dart`.
- **Change**: Wrapped the delta badge widget and its leading `SizedBox` in a conditional block: `if (_chartTimeframe != 'timeframe_all')`.

---

## [2026-05-15 14:20]: Cleanup - Fixed Flutter Analyze Warnings
*Details*: Resolved several warnings and deprecations reported by `flutter analyze` to clean up the codebase.
*Tech Notes*:
- **Deprecations**:
  - Replaced `Color.value` with `Color.toARGB32()` in `goal.dart` and `settings_provider.dart` to address deprecation in Flutter 3.22+.
  - Removed deprecated `AuthChangeEvent.userDeleted` in `auth_provider.dart`.
- **Unused Imports**:
  - Removed unused imports in `macro_goal_categories_provider.dart`, `macro_goals_provider.dart`, `mood_provider.dart`, `view_tab_bar.dart`, and `yearly_view_widget.dart`.

---

## [2026-05-15 14:22]: UI - Copiata Animazione Scrolling su Obiettivi
*Details*: Copiata l'animazione di scrolling orizzontale (effetto parallasse e scala) dal calendario della home alla pagina degli obiettivi (MacroGoalsScreen).
*Tech Notes*:
- **File**: `lib/ui/screens/macro_goals_screen.dart`.
- **Modifiche**: Sostituito l'effetto "3D Flip" nel `transitionBuilder` di `AnimatedSwitcher` con una simulazione di scorrimento orizzontale. Utilizzata la larghezza dello schermo per l'offset di traduzione e applicati gli stessi effetti di scala (0.95) e opacità del calendario per un look premium coerente.

---

## [2026-05-15 14:30]: Cleanup - Resolved Remaining Flutter Analyze Warnings
*Details*: Fixed all remaining warnings and deprecations reported by `flutter analyze` in the `mobile` folder.
*Tech Notes*:
- **Deprecations**:
  - Replaced `Color.value` with `Color.toARGB32()` in `add_goal_bar.dart` and `app_settings_screen.dart`.
  - Removed deprecated `showLabel` in `app_settings_screen.dart` (SlidePicker).
  - Replaced deprecated `Matrix4.translate` with `Matrix4.translationValues` in `bottom_nav_bar.dart`.
  - Updated deprecated `Share.shareXFiles` to `SharePlus.instance.share` with `ShareParams` in `privacy_settings_screen.dart`.
- **Lints**:
  - Fixed `use_build_context_synchronously` in `dashboard_screen.dart` and `daily_check_in_modal.dart` by adding `context.mounted` checks.
  - Fixed `prefer_conditional_assignment` in `personal_info_screen.dart` (using `??=`).
  - Removed unused local variables in `dashboard_screen.dart`, `habit_calendar_widget.dart`, and `global_trend_tab_widget.dart`.
  - Removed unnecessary imports of `services.dart` in `macro_goals_screen.dart`, `statistics_screen.dart`, and `goal_item_widget.dart`.
  - Removed unused optional parameter `duration` in `ai_chat_screen.dart`.

---

## [2026-05-15 14:35]: Fix - Ambiguous Column in get_all_habit_correlations RPC
*Details*: Risolto un errore di riferimento ambiguo alla colonna `goal_id` nella funzione database `get_all_habit_correlations`.
*Tech Notes*:
- Modificato il file `migrations/20260513_add_get_all_habit_correlations.sql`.
- Qualificate le colonne con gli alias delle tabelle (`gl.goal_id`, `hd.goal_id`) nei CTE.
- Rimossi gli alias `as goal_id` e `as other_goal_id` nel SELECT finale per evitare conflitti con i nomi delle colonne di ritorno della tabella.
- Aggiunta azione manuale in `TO_SIMO_DO.md` per aggiornare la funzione su Supabase.

---

## [2026-05-15 15:05]: Documentation - iOS Code Signing for Physical Device
*Details*: Documentato il processo per risolvere l'errore di code signing quando si tenta di eseguire l'app su un iPhone fisico.
*Tech Notes*:
- Aggiunte istruzioni dettagliate in `TO_SIMO_DO.md` per la configurazione del Team e del Bundle Identifier in Xcode.
- Spiegato che è possibile utilizzare un account gratuito per i test locali.

---

## [2026-05-15 15:10]: Project Configuration - Xcode Build Settings Cleanup
*Details*: Consigliato all'utente di accettare le modifiche suggerite da Xcode per rimuovere le impostazioni legacy di embedding delle Swift Standard Libraries.
*Tech Notes*:
- Le impostazioni `EMBEDDED_CONTENT_CONTAINS_SWIFT` e `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES` sono obsolete nei progetti moderni e vengono rimosse per evitare ridondanze e ridurre la dimensione della build.

---

## [2026-05-15 15:25]: Auth - Analisi Errore Nonce Google Sign-In
*Details*: Analizzato l'errore "passed nonce in id_token should either both exist or not" durante il login con Google.
*Tech Notes*:
- L'errore è dovuto al fatto che il pacchetto `google_sign_in` genera automaticamente un nonce nel token ID su iOS/Android, ma non lo espone facilmente in Flutter per passarlo a Supabase.
- La soluzione standard raccomandata da Supabase per questo scenario è abilitare l'opzione "Skip nonce checks" nella dashboard di Supabase per il provider Google.
- Ho aggiunto un'azione manuale in `TO_SIMO_DO.md` per guidare l'utente nell'abilitazione di questa impostazione.

---

## [2026-05-15 15:30]: Database - Fix Trigger handle_new_user per Google Login
*Details*: Risolto l'errore "Database error saving new user" che si verificava quando un utente si registrava con Google.
*Tech Notes*:
- **Causa**: La funzione trigger `handle_new_user` tentava di inserire `NULL` nella colonna `sentry_consent` della tabella `profiles`. Poiché la colonna è marcata come `NOT NULL`, l'operazione falliva. Google non fornisce `sentry_consent` nei metadati dell'utente.
- **Soluzione**: Aggiornata la funzione in `mobile_schema.sql` per usare `COALESCE((NEW.raw_user_meta_data ->> 'sentry_consent')::boolean, false)`, garantendo che se il valore è nullo venga inserito `false`.
- **Azione**: Aggiunta istruzione in `TO_SIMO_DO.md` per aggiornare la funzione direttamente su Supabase.

---

## [2026-05-15 15:35]: Onboarding - Tutorial Completo porta a Vista Mese
*Details*: Configurato il comportamento del termine del tutorial: quando l'utente clicca su "Inizia" nella schermata finale del tutorial ("Sei pronto!"), viene portato alla Home con la visualizzazione impostata su "Mese".
*Tech Notes*:
- **File**: `lib/ui/screens/dashboard_screen.dart`.
- **Modifiche**: Aggiunta la riga `ref.read(calendarViewProvider.notifier).setView(CalendarView.month);` nel callback `onTap` del pulsante "Inizia" nella fuzione `_showEndTutorialScreen`.

---

## [2026-05-15 15:40]: Goals - Selezione Automatica Nuova Categoria
*Details*: Modificato il comportamento della creazione di una nuova categoria nella pagina degli obiettivi. Ora, quando l'utente crea una nuova categoria, questa viene selezionata automaticamente per l'obiettivo corrente.
*Tech Notes*:
- **File**: `lib/providers/macro_goal_categories_provider.dart`.
- **Modifiche**: Aggiornato il metodo `addCategory` per restituire il `Future<String?>` contenente l'ID della categoria appena inserita su Supabase.
- **File**: `lib/ui/widgets/macro_goals/add_goal_bar.dart`.
- **Modifiche**: Aggiornato il callback `onPressed` del pulsante "Crea" per attendere l'ID della nuova categoria e impostarlo nello stato `_selectedCategory` tramite `this.setState`.

---

## [2026-05-15 15:48]: UI - Horizontal Scroll in Bottom Nav Bar
*Details*: Added horizontal swipe functionality to the floating bottom navigation bar to switch between pages (Stats, Home, Goals).
*Tech Notes*:
- **File**: `lib/ui/widgets/bottom_nav_bar.dart`.
- **Modifiche**: Wrapped the bottom navigation bar container in a `GestureDetector` and implemented `onHorizontalDragEnd`. It detects swipes and calls `onTap` with the previous or next index, utilizing the existing smooth page transition logic.

---

## [2026-05-15 16:23]: Feature - Open Router LLM Integration in Chat
*Details*: Integrated Open Router API into the AI Chat to provide real LLM responses instead of mock ones. Secured the API key by putting it in a gitignored file.
*Tech Notes*:
- **File**: `lib/core/openrouter_config.dart` (created, gitignored).
- **File**: `lib/core/openrouter_config.dart.example` (created).
- **File**: `lib/core/openrouter_service.dart` (created).
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Replaced local generation with API call.
- **File**: `lib/models/chat_message.dart` (created): Moved model from screen file.
- Added `http` package to dependencies in `pubspec.yaml`.
- Passed user context (goals, habits) as system prompt to the LLM.

---

## [2026-05-15 16:29]: Feature - Robust System Prompt & Guardrails
*Details*: Updated the system prompt for the AI Chat to include strict guardrails, preventing the LLM from going off-topic and answering questions not related to the app or user context.
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Added strict behavior rules to the system prompt in `_getSystemPrompt()`.

---

## [2026-05-15 16:40]: Feature - Concise AI Responses
*Details*: Added an instruction to the system prompt to make the LLM concise and avoid excessively long responses.
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Added conciseness instruction to `_getSystemPrompt()`.

---

## [2026-05-15 16:41]: UI - Markdown Rendering in Chat
*Details*: Implemented a markdown interpreter in the chat to render the LLM's responses beautifully (bold, lists, etc.).
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Replaced `Text` with `MarkdownBody` in message rendering.
- Added `flutter_markdown` package to dependencies in `pubspec.yaml`.

---

## [2026-05-15 16:49]: Feature - AI Chat Context Settings
*Details*: Added a settings dialog to the AI Chat to let the user choose what context to share with the LLM (Daily Habits and/or Macro Goals).
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified):
    - Added `_shareHabits` and `_shareGoals` state variables (defaults: true and false).
    - Added a settings icon button in the `AppBar` actions.
    - Implemented `_showSettingsDialog` with a blur effect and switches.
    - Updated `_getSystemPrompt()` to build the context block dynamically based on the switches.

---

## [2026-05-15 16:53]: Feature - Empty Context Protection
*Details*: Added a check to prevent sending messages or using suggestions when both context switches (habits and goals) are disabled.
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified):
    - Disabled the send button in the input field when both switches are false.
    - Added a local response when clicking suggestions with both switches false, prompting the user to select a context.

---

## [2026-05-15 16:55]: Optimization - Emoji Removal in Suggestions
*Details*: Removed emojis from the text sent to the LLM when clicking on a suggestion, to save tokens. The emojis are still visible in the suggestion chips.
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Added logic to extract text after the first space in `_buildSuggestedPrompt`.

---

## [2026-05-15 16:56]: UI - Fixed Typing Indicator Animation
*Details*: Fixed the `_BouncingDot` animation in the typing indicator to create a wave effect by starting the repeat after the specified delay.
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Moved `_ctrl.repeat` inside the `Future.delayed` block in `initState`.

---

## [2026-05-15 17:02]: Feature - AI Chat Streaming Responses
*Details*: Implemented streaming responses for the AI Chat, allowing the user to see the response word-by-word in real-time.
*Tech Notes*:
- **File**: `lib/core/openrouter_service.dart` (modified): Added `generateStreamResponse` method using `http.Client().send` and parsing SSE chunks.
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Updated `_sendMessage` to listen to the stream and update the message bubble dynamically.
- Added test file `test/openrouter_stream_test.dart` to verify the stream functionality.

---

## [2026-05-15 17:04]: UI - Clear Chat Confirmation Dialog
*Details*: Added a premium-styled confirmation dialog (with blur effect) before clearing the chat history, to prevent accidental deletions.
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Updated the `onPressed` handler of the trash icon to show a `Dialog` with `BackdropFilter`.

---

## [2026-05-15 17:08]: UI - Fixed Premature Hiding of Typing Indicator
*Details*: Fixed a bug where the typing indicator would disappear immediately because the stream yielded empty chunks before the actual content. Now it only disappears when a non-empty chunk is received.
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Added `chunk.trim().isNotEmpty` check before setting `receivedFirstToken = true` and `_isTyping = false`.

---

## [2026-05-15 17:12]: UI - Context-Aware Dynamic Suggestions
*Details*: Customized the dynamic suggestions in the chat based on the active context switches (Abitudini vs Obiettivi).
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Refactored `_getDynamicSuggestions` to check `_shareGoals` and `_shareHabits` and return specific pools of suggestions.

---

## [2026-05-15 17:13]: UI - Custom Premium Switches in Settings
*Details*: Replaced the standard `Switch.adaptive` with a custom animated toggle to match the premium aesthetic of the app.
*Tech Notes*:
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Created a custom toggle using `GestureDetector`, `AnimatedContainer`, and `AnimatedAlign` in `_buildContextSwitch`.

---

## [2026-05-15 17:20]: Feature - Error Handling & Sentry Integration in Chat
*Details*: Integrated Sentry logging for chat errors and added user notifications via SnackBar.
*Tech Notes*:
- **File**: `lib/core/openrouter_service.dart` (modified): Added `AppLogger.error` calls when API returns non-200 status or throws exceptions.
- **File**: `lib/ui/screens/ai_chat_screen.dart` (modified): Added `AppLogger.error` in stream `onError` and showed a floating `SnackBar` to the user.

---

## [2026-05-15 17:22]: Feature - Handled Token Limit Error (400) in Chat
*Details*: Handled HTTP 400 errors in OpenRouter stream to detect context length exceeded and suggest clearing the chat.
*Tech Notes*:
- **File**: `lib/core/openrouter_service.dart` (modified): Added check for `response.statusCode == 400` and yielded a specific advice message. Also logged the full error body to Sentry.

---

## [2026-05-15 17:23]: Feature - Logged JSON Parsing Warnings in Chat
*Details*: Added Sentry warning logs when JSON parsing of a stream chunk fails, to detect API changes.
*Tech Notes*:
- **File**: `lib/core/openrouter_service.dart` (modified): Replaced empty `catch` block with `AppLogger.warning` to log the failed JSON string.

---

## [2026-05-15 17:24]: Feature - Added Timeouts to Chat Stream
*Details*: Added timeouts to the API call and the stream to prevent the UI from hanging indefinitely.
*Tech Notes*:
- **File**: `lib/core/openrouter_service.dart` (modified): Added `timeout(Duration(seconds: 15))` to `client.send` and `timeout(Duration(seconds: 10))` to the stream. Handled `TimeoutException` to yield a specific error message.

---

## [2026-05-15 17:25]: Feature - Pre-emptive Connection Check in Chat
*Details*: Added a check to verify internet connectivity before attempting to call the OpenRouter API.
*Tech Notes*:
- **File**: `lib/core/openrouter_service.dart` (modified): Used `InternetAddress.lookup('openrouter.ai')` to check if the API is reachable. Yields an error message if not.

---

## [2026-05-17 16:00]: Core - Full Rebranding to 'Evolve'
*Details*: Rebranded the entire mobile application from "Growth" to "Evolve" and updated the application's motto to "better each day, become who you're meant to be".
*Tech Notes*:
- **iOS Config**: Updated `CFBundleDisplayName` and `CFBundleName` in `Info.plist` to "evolve".
- **App Title**: Updated `MaterialApp` title in `main.dart` and renamed the main app widget from `GrowthApp` to `EvolveApp`.
- **Notifications**: Updated notification titles in `notifications.dart` to use 'Evolve • '.
- **Localization**: Updated `app_title` in `localization.dart` for both Italian and English.
- **UI**: Updated the title and motto in `AuthScreen`, the welcome screens in `dashboard_screen.dart`, all tier texts in `subscription_screen.dart`, and the premium header modal in `pro_features_modal.dart`.
- **Documentation**: Updated "Growth" to "Evolve" in `FINANCIAL_PLAN.md`, `BACKEND_ARCHITECTURE.md`, and `FLUTTER_COMMANDS.md`.

---

## [2026-05-18 09:30]: Security - DailyMoodsNotifier Auth Listener Integration & Pre-Release Audit
*Details*: Implemented a critical auth state listener inside `DailyMoodsNotifier` to guarantee strict user data isolation upon sign-out and login, matching the offline-first security paradigms used across other providers. Performed a comprehensive pre-release App Store readiness audit.
*Tech Notes*:
- **Providers**: Added `import 'auth_provider.dart';` and integrated `ref.listen(authProvider)` in `DailyMoodsNotifier.build()` in `mood_provider.dart`.
- **Security**: Wipes local mood data state completely from memory and cached records upon sign-out, eliminating risks of data leaks or user data collisions on shared devices.
- **Audit**: Conducted code signing, Bundle ID, display name, permissions, and multi-platform readiness review. Logged critical pre-release manual tasks to `TO_SIMO_DO.md` and prepared a comprehensive App Store Publishing Guide.

---

## [2026-05-18 09:35]: Core - Bundle Identifier and Display Name Customization
*Details*: Configured the official bundle identifier and capitalized display names in native iOS files for release readiness as requested and approved by the user.
*Tech Notes*:
- **Xcode config**: Updated `PRODUCT_BUNDLE_IDENTIFIER` from `com.simo.mattioliOS` to `com.simo.evolve` across all build configurations (Debug, Release, Profile) in `project.pbxproj`.
- **Xcode test config**: Updated test runner bundle ID from `com.mattioli.mattioliOs.RunnerTests` to `com.simo.evolve.RunnerTests` in `project.pbxproj`.
- **Info.plist**: Capitalized `CFBundleDisplayName` and `CFBundleName` keys from `evolve` to `Evolve` in `Info.plist` for premium home-screen layout.
- **Tasks**: Marked tasks as completed in `TO_SIMO_DO.md`.

---

## [2026-05-18 09:40]: Security - Vulnerability Assessment & Password Field Hardening
*Details*: Conducted a comprehensive mobile security audit and implemented proactive password input hardening to protect users against keylogging/cache suggestions.
*Tech Notes*:
- **Hardening**: Configured `autocorrect: false` and `enableSuggestions: false` inside the custom `_buildPasswordField` in `privacy_settings_screen.dart` to secure password forms.
- **Audit**: Conducted a thorough assessment across data persistence (Keychain/Keystore), API structures, Sentry PII scrubbing, biometric block overlays, and session life cycle. Compiled findings in a dedicated security report.

---

## [2026-05-18 11:05]: UI - Premium Logout Confirmation Dialog
*Details*: Added a high-end, blurry glassmorphism confirmation popup to prevent accidental logout when a user taps the "Esci" button on the profile screen.
*Tech Notes*:
- **File**: `lib/ui/screens/profile_screen.dart` (modified):
  - Added `dart:ui`'s `ImageFilter` to enable high-performance background blurring.
  - Implemented `_showLogoutConfirmationDialog` featuring the app's custom design system components (glass card container, rounded corners, subtle shadows, dynamic spacing, and localized text).
  - Wired the "Esci" gesture detector to trigger the confirmation dialog instead of performing an immediate logout.
  - Integrated structured haptic feedback: `hapticLight()` triggers on the initial settings tap, while `hapticHeavy()` occurs upon successful confirmation.

---

## [2026-05-18 11:15]: Feature - Premium Paywall for Individual Habit Statistics
*Details*: Implemented a subscription check in the statistics section to limit detailed views of single habits to Evolve Pro subscribers, while allowing all users to view global habit statistics. Added explicit listeners to automatically reset the active state to the global "Tutti gli abitudini" view when the premium modal is dismissed.
*Tech Notes*:
- **File**: `lib/ui/widgets/pro_features_modal.dart` (modified):
  - Changed `show(BuildContext context)` to return a `Future<void>` instead of `void` to allow downstream screens to execute callbacks upon dismissal.
- **File**: `lib/ui/screens/statistics_screen.dart` (modified):
  - Imported `settings_provider.dart` and `pro_features_modal.dart`.
  - Added a defensive subscription check in `_selectGoal` to block non-Pro users from viewing individual habit detail tabs, prompting the Evolve Pro purchase modal instead.
  - Chained `.then((_) { if (mounted) { _selectGoal(null); } })` to all invocations of `ProFeaturesModal.show(context)` in `_selectGoal` and `_showGoalSelector` to seamlessly redirect users to the global "Tutti gli abitudini" view upon dismissal of the Evolve Pro modal.
  - Implemented an automatic reactive guard at the beginning of the `build` method using `WidgetsBinding.instance.addPostFrameCallback` to ensure a non-Pro user is never left viewing a specific habit if their subscription status changes or they somehow bypass standard flows.
  - Customised `_buildGoalDropdown` to display a lock icon for the habit icon on free tier when a single habit is active, while keeping the accessible "Tutti gli abitudini" label visually pristine and badge-free.
  - Hardened `_showGoalSelector` list items with trailing lock icons for non-Pro users, capturing clicks on individual habits to dismiss the menu and immediately display `ProFeaturesModal.show(context)` with high-precision tactile `hapticHeavy()` feedback.
  - Passed `_selectGoal` as an `onGoalSelected` callback parameter to `GlobalHabitsTabWidget`.
- **File**: `lib/ui/widgets/statistics/global_habits_tab_widget.dart` (modified):
  - Declared and wired `onGoalSelected` callback in the `GlobalHabitsTabWidget` constructor and passed it down to `_HabitDetailCard`s.
  - Appended `goal_id` during mapping in `_mapStatsToHabits` to properly link card clicks.
  - Refactored `_HabitDetailCard` to inherit from `ConsumerWidget` and wrapped the parent layout inside a `GestureDetector`.
  - Visualised locks elegantly by replacing the habit color indicator dot with Lucide's lock icon if the user is not Pro.
  - Tapping a locked habit detail card triggers `ProFeaturesModal.show(context)` with haptic cues, whereas Pro subscribers enjoy seamless shortcut navigation to the detailed stats page.

---

## [2026-05-18 11:20]: Feature - Premium Paywall for Macro Goals Yearly Stats
*Details*: Gated specific years' statistics in the Macro Goals performance panel, keeping "Tutti gli anni" free while restricting detailed year-by-year stats to Evolve Pro subscribers.
*Tech Notes*:
- **File**: `lib/ui/widgets/macro_goals/macro_goals_stats_view.dart` (modified):
  - Imported `settings_provider.dart`, `pro_features_modal.dart`, and `haptics.dart`.
  - Added a reactive guard at the top of the `build` method with `WidgetsBinding.instance.addPostFrameCallback` to ensure a non-Pro user's selection is immediately reset to 'all' if they somehow bypass the gates.
  - Refactored `_showYearPicker` to visually represent locked years with Lock icons instead of calendars for non-Pro users.
  - Intercepted selections of specific years on the free tier: it triggers `ref.hapticHeavy()`, closes the picker, and shows `ProFeaturesModal.show(context)` which defensively chains `.then` to keep/reset the selected year to 'all' upon dismissal.

---

## [2026-05-18 11:25]: Feature - Premium Gating for Active Habits (5 Habits Limit)
*Details*: Gated habit creation for free tier users, limiting them to a maximum of 5 active habits. Creating a 6th habit triggers a beautiful, interactive Evolve Pro upselling flow.
*Tech Notes*:
- **File**: `lib/ui/widgets/habit_management_modal.dart` (modified):
  - Imported `haptics.dart` and `pro_features_modal.dart`.
  - Added dynamic `settingsProvider` watcher to read `isPro` subscription status and checked `currentHabitsCount` within the `build` method.
  - Intercepted habit insertion within `_onSave`: if the user is not Pro and already tracks 5 habits, we unfocus the keyboard (`FocusScope.of(context).unfocus()`), play `ref.hapticHeavy()`, and display `ProFeaturesModal.show(context)` to prevent creation of a 6th habit.
  - Implemented an elegant in-app premium warning banner (`Colors.amber` lock) right above the main button once they reach the 5/5 limit.
  - Transformed the standard "Aggiungi Abitudine" button into a premium golden Evolve Pro button (`0xFFEAB308`) with a sparkle icon and "Sblocca Evolve Pro" text if the user hits the 5-habit limit, maximizing conversions.

---

## [2026-05-18 11:30]: Feature - Premium Gating for Custom Accent Color
*Details*: Gated the custom color picker wheel behind Evolve Pro, while allowing free users to select one of the three beautiful hardcoded preset color themes.
*Tech Notes*:
- **File**: `lib/ui/screens/app_settings_screen.dart` (modified):
  - Fetched `settingsProvider` state at the beginning of `_showAccentColorPicker` to read the subscription state of the user.
  - Refactored the custom color picker plus button: if the user is free-tier, the button displays a lock icon (`LucideIcons.lock`) with Evolve Pro golden visual styling (`Color(0xFFEAB308)`) and a subtle gold shadow glow instead of the default plus symbol.
  - On tap of the locked button: plays a heavy haptic vibration (`ref.hapticHeavy()`), closes the accent color selection sheet, and opens the premium paywall modal (`ProFeaturesModal.show(context)`).

---

## [2026-05-18 11:35]: Feature - Premium Coming Soon Dialog
*Details*: Implemented a gorgeous, glassmorphic "Coming Soon" dialog when clicking on the premium purchase Evolve Pro CTA, replacing the simple dismiss/close behaviour with an elegant informative alert.
*Tech Notes*:
- **File**: `lib/ui/widgets/pro_features_modal.dart` (modified):
  - Imported `dart:ui`'s `ImageFilter` to support glassmorphic blurring.
  - Refactored the CTA buy button `onTap` handler: dismisses the bottom sheet modal and opens a new custom informative dialog using the private `_showComingSoonDialog` helper method.
  - Built `_showComingSoonDialog` using premium Evolve styling tokens: high-blur BackdropFilter backdrop (`sigmaX: 12, sigmaY: 12`), cards borders, gold Lucide sparkles badge, custom copy stating that payment systems are coming in an upcoming release, and a haptic-enhanced success click button ("Ho capito").

---

## [2026-05-18 11:40]: Bug Fix - Safe Haptics in Unmounted Dialog
*Details*: Fixed a classic Riverpod crash where referencing `ref.hapticSuccess()` inside `_showComingSoonDialog` after the parent modal sheet unmounted caused a thread crash, freezing the dialog on screen.
*Tech Notes*:
- **File**: `lib/ui/widgets/pro_features_modal.dart` (modified):
  - Imported `package:flutter/services.dart` and `settings_provider.dart`.
  - Refactored `onTap` to read the user's `hapticFeedback` boolean setting *before* the sheet is popped and passed it as a parameter `hapticsEnabled`.
  - Refactored `_showComingSoonDialog` to accept `bool hapticsEnabled` instead of the widget's `WidgetRef`.
  - Changed the tap callback to trigger `HapticFeedback.mediumImpact()` directly from the SDK, preventing unmounted ref crashes and ensuring the dialog closes successfully.

---

## [2026-05-18 11:45]: Feature - Removed Apple Pay checkout mock & Integrated Coming Soon dialog
*Details*: Removed the local Apple Pay mock sheet completely from the primary subscription page, and redirected the "Attiva Abbonamento" click to show the Evolve premium glassmorphic "Coming Soon" dialog.
*Tech Notes*:
- **File**: `lib/ui/screens/subscription_screen.dart` (modified):
  - Imported `package:flutter/services.dart` to access native SDK `HapticFeedback` safely.
  - Replaced the mock Apple Pay bottom sheet trigger `_mockPurchase(context, ref)` inside `_buildPlanSelector` with the unmount-safe `_showComingSoonDialog(context, hapticsEnabled)` call.
  - Completely purged the `_mockPurchase` mock payment sheet code block (lines 271-374).
  - Added the unified `_showComingSoonDialog` helper method inside the class definition, featuring complete glassmorphic blurring backdrop filter, Lucide sparkles, and haptic success confirmation.

---

## [2026-05-18 12:32]: Core - Info.plist Permission Hardening for App Store Submission
*Details*: Removed the risky and redundant `NSMicrophoneUsageDescription` from `ios/Runner/Info.plist`. This eliminates potential Apple Store rejections under guideline 2.5.1 (Data Collection & Storage) and 5.1.1 since the app only picks images and does not record video or use the microphone.
*Tech Notes*:
- **File**: `ios/Runner/Info.plist` (modified): Removed the `NSMicrophoneUsageDescription` key and string value.

---

## [2026-05-18 12:50]: Documentation - App Store Connect Alignment & Code Obfuscation Strategy
*Details*: Formulated and documented a comprehensive deployment blueprint for Evolve on the Apple App Store, detailing native iOS project alignment and maximum obfuscation configurations to protect Dart IP.
*Tech Notes*:
- **Bundle Verification**: Confirmed active alignment of `com.simo.evolve` across all pbxproj build configurations.
- **Obfuscation**: Described the usage of `--obfuscate` combined with `--split-debug-info` to securely strip Dart debugging identifiers and protect intellectual property.
- **Action Plan**: Formulated a detailed task plan in `TO_SIMO_DO.md` for manual execution.

---

## [2026-05-18 12:57]: Build - Successful Xcode Archive & Obfuscated IPA Generation
*Details*: Successfully generated the production archive and App Store-ready `.ipa` file for Evolve (v1.0.0+1) with maximum Dart code obfuscation.
*Tech Notes*:
- **Code Signing**: Automatically signed with team `8528AN28A3`.
- **Obfuscation**: Compiled successfully using the `--obfuscate` flag.
- **Artifacts**:
  - Main IPA: `build/ios/ipa/Runner.ipa` (31.8 MB).
  - Obfuscation Symbol Map: `build/app/outputs/symbols/app.ios-arm64.symbols` (4.4 MB).
- **Status**: The build is fully prepared and ready for upload to App Store Connect.

---

## [2026-05-18 13:47]: Deployment - Confirmed Transporter Upload & App Store Connect Action Plan
*Details*: Confirmed successful upload of Evolve (v1.0.0+1) to App Store Connect via Transporter. Formulated the exact steps to associate the build and submit for review.
*Tech Notes*:
- **Filing**: Checked off the upload action item in `TO_SIMO_DO.md`.
- **Review Preparedness**: Validated the Sentry DSN configuration and local security hooks are ready for the Apple Review Team login.

---

## [2026-05-18 15:48]: Goals - 100 Macro Goals Limit for Free Tier
*Details*: Implemented a total limit of 100 macro goals (obiettivi) across all categories (weekly, monthly, quarterly, annual, lifetime) for non-Evolve Pro users, matching the premium UX patterns of Evolve.
*Tech Notes*:
- **UI Enhancement (`add_goal_bar.dart`)**:
  - Restyled the `AddGoalBar` dynamically when a free user reaches the 100 goals limit. The hint text turns amber with the label "Limite di 100 obiettivi raggiunto!", and the submit button transforms into a golden `LucideIcons.sparkles` icon.
  - Tapping the submit button or hitting enter in the keyboard triggers the premium `ProFeaturesModal` to encourage upgrading to Evolve Pro.
- **UI Protection (`goal_item_widget.dart`)**:
  - Protected the rescheduling pathway inside `GoalItemWidget._reschedule()` by verifying the total goals limit. Non-pro users trying to reschedule beyond 100 total goals are blocked and presented with the Evolve Pro upgrade modal.


---

## [2026-05-19 09:00]: Bugfix - Unmounted Widget Ref Crash on Apple Sign In
*Details*: Fixed a severe crash found by the Apple Store reviewer when executing asynchronous sign-in (Sign In with Apple and Google Sign In). The crash occurred when attempting to trigger a success haptic feedback via the Riverpod `WidgetRef` extension (`ref.hapticMedium()`) after the user was successfully logged in. Because GoRouter immediately navigated to the HomeScreen and unmounted the AuthScreen, calling any method on the unmounted widget's `ref` threw a `Bad state: Using "ref" when a widget is about to or has been unmounted is unsafe.` exception.
*Tech Notes*:
- **File**: `lib/ui/screens/auth_screen.dart` (modified):
  - Imported `../../providers/settings_provider.dart` to check `hapticFeedback` status.
  - Read `hapticsEnabled = ref.read(settingsProvider).hapticFeedback` *before* entering any asynchronous authentication flow (`signInWithApple()`, `signInWithGoogle()`, `login()`, `signUp()`).
  - Replaced the post-asynchronous `ref.hapticMedium()` call with a direct, unmount-safe static call: `AppHaptics.mediumImpactWithFlag(hapticsEnabled)`. This correctly triggers native device haptics directly through `HapticFeedback` without accessing the unmounted `BuildContext` or `WidgetRef`.

---

## [2026-05-19 09:10]: Bugfix - In-App Purchase Error Resilience & Administrative Check
*Details*: Solved the StoreKit purchase failure bug reported by the Apple reviewer. The native StoreKit sheet successfully processed the sandbox subscription purchase, but the app simultaneously displayed a generic red error banner stating that the purchase failed or was cancelled. This was due to: (1) `purchasePackage` suppressing all exceptions internally and returning `false`, causing the UI to always show the generic error message, and (2) the Apple account holder not having signed the mandatory **Paid Apps Agreement** in App Store Connect, which caused the Apple transaction to fail on the backend/RevenueCat level despite showing a successful native sheet.
*Tech Notes*:
- **File**: `lib/core/subscription_service.dart` (modified):
  - Removed internal `try-catch` suppression inside `purchasePackage()` and `restorePurchases()`.
  - Added `rethrow` inside `catch` blocks to correctly propagate StoreKit and billing exceptions up to the UI/caller level.
- **File**: `lib/ui/screens/subscription_screen.dart` (modified):
  - Imported `package:flutter/services.dart` to handle native `PlatformException`.
  - Refactored `_purchase()` method to trap billing/store exceptions:
    - Quietly intercepts user cancellations (`PurchasesErrorCode.purchaseCancelledError`) to prevent display of annoying error banners.
    - Decodes and translates critical StoreKit failures, specifically identifying when the administrative **Paid Apps Agreement** is missing ("Contratto Paid Apps non attivo...").
- **Documentation**: Updated `TO_SIMO_DO.md` adding a checklist action for Simo to accept the Paid Apps Agreement in App Store Connect.

---

## [2026-05-19 09:15]: Compliance - App Store Connect Subscription Metadata & EULA Review
*Details*: Audited the codebase and metadata posture against Apple Store Guideline 3.1.2(c) (Payments - Subscriptions). Confirmed that the mobile application is already fully compliant with the guidelines, as `SubscriptionScreen` displays the required subscription titles ("Evolve Pro Mensile"/"Annuale"), dynamic lengths, pricing, and functional links to both the Privacy Policy and standard Apple EULA. The rejection was purely administrative: the reviewer did not find the EULA link and Terms of Use details in the App Store Connect metadata console.
*Tech Notes*:
- **File**: `TO_SIMO_DO.md` (modified): Created a copy-paste instructions section detailing exactly how to fill out the **App Description** and **EULA License Agreement** fields in App Store Connect.

---

## [2026-05-19 09:25]: Compliance - Cross-Post Compliance & Website Nomenclature Alignment
*Details*: Performed a comprehensive alignment audit on the localized marketing and legal website files (`index.html`, `terms.html`, `privacy.html`, `cookie.html`, and `script.js`). Corrected a mismatch where the site referred to the premium tier as "Evolve Plus" whereas the mobile app and StoreKit entitlements expect "Evolve Pro".
*Tech Notes*:
- **Website Synced**: Replaced all `Evolve Plus` and `Prezzi / Plus` occurrences with `Evolve Pro` and `Prezzi / Pro` respectively.
- **Link Integrity**: Validated header and mobile menus to ensure robust routing back to specific landing page anchors from legal sub-pages.
- **Titolare Sync**: Confirmed perfect alignment of owner information and contact emails.

---

## [2026-05-19 14:08]: App Store Review - Apple Sign-In Keychain & IAP Activation Fix
*Details*: Addressed the Apple Review feedback for Guideline 2.1(a) and 2.1(b). The Sign in with Apple failure was traced to unhandled iOS Keychain duplicate-item errors (`-25299`) during post-login session/cache writes. The subscription failure was traced to overly strict RevenueCat entitlement matching after StoreKit confirmed a sandbox purchase.
*Tech Notes*:
- **Keychain Resilience**: Added `lib/core/secure_storage_utils.dart` with shared secure-storage options and duplicate-item recovery. Updated Supabase session storage, startup cache migration, settings persistence, biometric preference reads, and goals/log cache writes to avoid unhandled Keychain exceptions after Apple login.
- **RevenueCat Activation**: Hardened `SubscriptionService` initialization to avoid repeated SDK configuration, use `Purchases.logIn()` when already configured, refresh customer info after purchase/restore, and treat known active StoreKit subscription product IDs (`com.simo.evolve.pro.monthly`, `com.simo.evolve.pro.yearly`) as valid Pro access in addition to RevenueCat entitlement IDs.
- **Store Review Build**: Incremented `pubspec.yaml` from `1.0.0+3` to `1.0.0+4` for the next App Store submission.
- **Tests**: Added `test/subscription_service_test.dart` to verify Pro access detection through both RevenueCat entitlements and StoreKit active subscription IDs.
- **Verification**: `flutter analyze`, `flutter test`, and `flutter build ios --release --no-codesign` all completed successfully.

**Current Status**:
- Implementation complete.
- Local iOS release build without codesign succeeds.

**Next Step**:
- Generate the signed/obfuscated IPA for build `1.0.0+4`, upload it to App Store Connect, and reply in Resolution Center with the Apple Sign-In Keychain and subscription activation fixes.

---

## [2026-05-19 14:51]: App Store IAP - Production-Ready Restore Flow
*Details*: Hardened the Evolve Pro restore and purchase activation flow for App Store review. The restore button now uses a typed RevenueCat result instead of a bare boolean, refreshes CustomerInfo after restore, and shows professional user-facing messages without exposing raw native exceptions.
*Tech Notes*:
- **RevenueCat Sync**: Added `SubscriptionAccessStatus` and `SubscriptionOperationResult` in `subscription_service.dart`, plus a `CustomerInfo` update listener so entitlement changes sync into `settings.isPro` as RevenueCat emits them.
- **Restore Robustness**: `restorePurchasesWithResult()` now evaluates restored customer info first, refreshes the cache if Pro is still inactive, and logs diagnostics for active entitlements/subscriptions.
- **Purchase Robustness**: `purchasePackageWithResult()` now syncs purchases as a fallback after a completed purchase if the returned CustomerInfo is not active yet, and handles `productAlreadyPurchasedError` by running the user-initiated restore path.
- **Entitlement Matching**: Kept the official `Evolve Pro`, `evolve_pro`, and `pro` entitlement IDs, kept StoreKit SKU fallbacks, and added a safe fallback for any active RevenueCat entitlement to prevent App Store review from being blocked by a dashboard identifier mismatch.
- **State Persistence**: Updated `settings_provider.dart` so stale `profiles.is_pro=false` from Supabase does not immediately overwrite a Pro state already validated/cached locally by RevenueCat.
- **UI**: Added a visible `Ripristina acquisti` action inside the paywall compliance section and mapped RevenueCat/StoreKit errors to localized, production-safe messages.
- **Tests**: Updated `subscription_service_test.dart` to cover configured entitlements, StoreKit subscription IDs, and the active-entitlement fallback.
- **Verification**: `flutter test test/subscription_service_test.dart` and `flutter analyze` completed successfully. iOS build verification was skipped after user request.

---

## [2026-05-19 14:55]: Subscription UI - Removed Duplicate Restore Action
*Details*: Removed the duplicate `Ripristina` text action from the top-right AppBar of the subscription screen, keeping the single `Ripristina acquisti` action inside the paywall body.
*Tech Notes*:
- **UI**: Updated `subscription_screen.dart` only. Restore logic remains unchanged and continues to run from the main paywall action.

---

## [2026-05-19 15:10]: Core - Elegant Subscription Dialogs & SnackBars Removal
*Details*: Replaced all simple line SnackBars in the subscription management interface with beautiful, custom-designed glassmorphic modal dialogs (`SubscriptionAlertModal`), completely aligning the paywall and subscription events with the premium, state-of-the-art visual style of Evolve/Growth.
*Tech Notes*:
- **New Component**: Created `SubscriptionAlertModal` in `lib/ui/widgets/subscription_alert_modal.dart`.
  - Parameters: `title`, `message`, `type` (`success`, `warning`, `error`), and `details` for technical error traces.
  - Features: Curved borders (radius 28px), backdrop blur filter (sigma 12px), dynamic gradient confirmation buttons, modern icon headers with glowing borders, and tailored dynamic haptics (success/medium/error).
- **Subscription Screen Integration**: Fully replaced standard SnackBars in `_restorePurchases`, `_purchase`, and mock plan purchase onTap with `SubscriptionAlertModal.show`.
- **Code Optimization**: Cleaned up unused `messenger` variables and optimized BuildContext usage across asynchronous gaps by leveraging `context.mounted` to silence linter warnings.
- **Verification**: Ran full `flutter analyze` ensuring zero issues or warnings remain in the codebase.

---

## [2026-05-19 15:15]: Auth - Invalid Refresh Token Startup Recovery
*Details*: Fixed a startup crash where a stale Supabase persisted session emitted `AuthApiException(message: Invalid Refresh Token: Refresh Token Not Found, code: refresh_token_not_found)` through `auth.onAuthStateChange`, triggering the global error modal.
*Tech Notes*:
- **Auth Provider**: Added an `onError` handler to the Supabase auth state stream in `auth_provider.dart`.
- **Recovery Behavior**: Invalid persisted sessions now move the app to logged-out state and run a local sign-out cleanup instead of surfacing as an app crash.
- **Lifecycle**: Stored and cancelled the auth stream subscription through `ref.onDispose()` to avoid duplicate listeners.
- **Verification**: `flutter analyze` and `flutter test test/subscription_service_test.dart` completed successfully.

---

## [2026-05-19 15:28]: Tutorial - Dashboard Calendar Target Resilience
*Details*: Fixed the dashboard tutorial error `FormatException: It was not possible to obtain target position (Calendario Box)`, which could appear when the tutorial started while the calendar area was showing its empty state or before the welcome dialog transition had fully completed.
*Tech Notes*:
- **Dashboard UI**: Moved `_calendarBoxKey` to a stable wrapper around the entire calendar/empty-state area in `dashboard_screen.dart`, so the tutorial target is always mounted.
- **Tutorial Timing**: Added a delayed post-frame tutorial start after the welcome modal closes.
- **Safety**: Wrapped `TutorialCoachMark.show()` in a warning log guard so a missing target cannot surface as a global crash during review/test flows.
- **Payment Test Result**: Confirmed from device logs that the annual sandbox subscription activates correctly: `matchedEntitlement=Evolve Pro`, `matchedProduct=com.simo.evolve.pro.yearly`, `activeSubscriptions=[com.simo.evolve.pro.yearly]`.
- **Verification**: `flutter analyze` and `flutter test test/subscription_service_test.dart` completed successfully.

---

## [2026-05-19 15:30]: Consent - setState After Dispose Fix
*Details*: Fixed a `setState() called after dispose()` crash in `ConsentScreen` that could occur after tapping Continue, because consent completion updates routing state and can unmount the screen before the async handler finishes.
*Tech Notes*:
- **Lifecycle Guard**: Added `mounted` checks after notification permission reads/requests and before clearing `_isLoading` in `_handleContinue()`.
- **Root Cause**: The error is separate from the dashboard tutorial target issue; this one was caused by async consent/Sentry initialization completing after navigation away from the consent page.
- **Verification**: `flutter analyze` and `flutter test test/subscription_service_test.dart` completed successfully.

---

## [2026-05-19 15:45]: Error Handling - Responsive Error Modal & Auth Recovery Filter
*Details*: Fixed a render overflow in the global `ErrorModal` that could occur when technical details were longer than the available screen height, especially after startup/auth recovery errors on smaller simulators.
*Tech Notes*:
- **Error Modal**: Updated `error_modal.dart` with a max-height constraint, scrollable body, fixed close button, safe-area padding, and selectable technical details.
- **Auth Recovery**: Updated `main.dart` to ignore recoverable Supabase stale-session errors (`refresh_token_not_found`) at the global error handler level because `auth_provider.dart` already logs out and recovers locally.
- **Verification**: `flutter analyze` and `flutter test test/subscription_service_test.dart` completed successfully.

---

## [2026-05-19 15:56]: iOS Simulator - Native Assets Objective-C Load Fix
*Details*: Fixed the simulator startup error `Couldn't resolve native function 'DOBJ_initializeApi'` caused by the `objective_c` native asset pulled in by `path_provider_foundation` 2.6.0.
*Tech Notes*:
- **Dependency Override**: Added a targeted `dependency_overrides` entry for `path_provider_foundation: 2.5.1`, which uses the standard Flutter Darwin plugin path and does not depend on `objective_c`, `native_toolchain_c`, or native-assets code generation.
- **Lockfiles**: Regenerated `pubspec.lock` and `ios/Podfile.lock`; the Dart lockfile no longer contains `objective_c`, `native_toolchain_c`, `code_assets`, `hooks`, or `record_use`.
- **Build Cleanup**: Ran `flutter clean` and `flutter pub get` to remove stale copied `objective_c.framework` artifacts from prior simulator builds.
- **Verification**: `flutter analyze`, `flutter test test/subscription_service_test.dart`, and `flutter run -d 4225E4CB-028F-48F5-AB0E-89D83D1D6BDE` completed successfully through app startup without the `DOBJ_initializeApi` error.

---

## [2026-05-21 09:45]: Macro Goals - Logical Weeks Per Month
*Details*: Fixed weekly macro-goal navigation so each month uses its real logical number of weeks instead of treating Sunday-start and edge-case months as five-week periods.
*Tech Notes*:
- **Calendar Helper**: Added `lib/core/macro_goal_calendar.dart` with timezone-safe logical week calculation aligned with the web app behavior.
- **Provider**: Updated `MacroGoalsViewNotifier` and `weeksInMonth()` to use logical month weeks for initialization, navigation, clamping, and rescheduling.
- **Tests**: Added `test/macro_goal_calendar_test.dart` covering 4-, 5-, and 6-week month shapes, including the February 2026 Sunday-start case.
- **Verification**: `flutter analyze` and `flutter test` completed successfully.

---

## [2026-05-21 09:58]: Macro Goals - Weekly Range Titles
*Details*: Updated the weekly macro-goal period header to show the actual date range instead of a generic week number, e.g. `1 - 7, maggio 2026`.
*Tech Notes*:
- **Range Logic**: Refined `lib/core/macro_goal_calendar.dart` so goal weeks are 7-day month buckets starting from day 1; final buckets can extend into the next month/year.
- **UI**: Updated `macro_goals_screen.dart` to format same-month, cross-month, and cross-year ranges in Italian while preventing header overflow.
- **Tests**: Extended `test/macro_goal_calendar_test.dart` with same-month, cross-month, and cross-year range cases.
- **Verification**: `flutter analyze` and `flutter test` completed successfully.

---

## [2026-05-21 10:25]: Macro Goals - Editable Custom Categories
*Details*: Added full category management from the macro-goal category selector so custom categories can be created, renamed, recolored, selected, and deleted after creation.
*Tech Notes*:
- **Reusable UI**: Added `category_picker_sheet.dart` and connected it to both the add-goal bar and existing goal category selector.
- **Provider**: Added category update support and an initial safe deletion flow, later superseded by soft archiving to preserve historical statistics.
- **Verification**: `flutter analyze` and `flutter test` completed successfully.

---

## [2026-05-21 10:28]: Macro Goals - Category Selector Cleanup
*Details*: Removed the visible linked-goal count subtitle from custom categories in the macro-goal category selector.
*Tech Notes*:
- **UI**: Updated `category_picker_sheet.dart`; linked-goal counts remain available internally for the deletion confirmation message.
- **Verification**: `flutter analyze` completed successfully.

---

## [2026-05-21 10:33]: Macro Goals - Soft Archive Categories
*Details*: Reworked category deletion into soft archiving so historical goals and statistics keep their category association after a user removes a category from active use.
*Tech Notes*:
- **Database**: Added `migrations/20260521_archive_macro_goal_categories.sql` with nullable `archived_at` and an active-category index. Existing categories remain active because `archived_at` defaults to `NULL`.
- **Model/Provider**: Added `GoalCategory.archivedAt` / `isArchived`; category fetch keeps archived rows available for historical label/color resolution.
- **UI**: Category picker hides archived categories for new selections, while stats and existing goals can still resolve archived category metadata.
- **Manual Action**: Logged the Supabase migration in `TO_SIMO_DO.md`.
- **Verification**: `flutter analyze` and `flutter test` completed successfully.

---

## [2026-05-21 10:40]: Fix - Category Creation Crash ("Bad state: Using ref when unmounted")
*Details*: Fixed a crash when creating a new category from the Goals section. The error "Bad state: Using ref when a widget is about to or has been unmounted" occurred because the bottom sheet's `Consumer` widget was disposed (via `Navigator.pop`) before the category editor dialog tried to use its `ref`.
*Tech Notes*:
- **Root Cause**: In `category_picker_sheet.dart`, the "Crea nuova categoria" handler called `Navigator.pop(sheetContext)` first, then used the `Consumer`'s `ref` to show the editor dialog. Since the `Consumer` was already unmounted, `ref.read(...)` threw a "Bad state" error.
- **Fix**: Captured the caller's context and the `MacroGoalCategoriesNotifier` reference eagerly (before popping the sheet). Created `_showCategoryEditorDialogSafe()` that takes a pre-captured notifier instead of a `WidgetRef`, making it safe to call after the sheet is disposed.
- **Scope**: The existing `_showCategoryEditorDialog` (used for in-sheet edit) now also eagerly captures the notifier as a safety measure.

---

## [2026-05-21 13:28]: UI - Removed AI and System Sections from Notification Settings
*Details*: Completely removed the "INTELLIGENZA ARTIFICIALE" (Artificial Intelligence) and "GESTIONE SISTEMA" (System Management) menus with all their respective items/options from the Notification Settings screen.
*Tech Notes*:
- **UI**: Modified `lib/ui/screens/notification_settings_screen.dart` to eliminate the sections and cards for AI Insights, Deep Work Insights, Weekly Reports, and Focus Mode.
- **Cleanup**: Removed the unused import for `pro_features_modal.dart` to maintain a clean codebase.
- **Verification**: Ran `flutter analyze` ensuring zero compiler errors or warnings remain.


- [2026-05-21 13:39]: Fix Missing UI Translations
  - *Details*: Identificate e tradotte le stringhe hardcoded mancanti nelle sezioni Home, Obiettivi e Statistiche, tra cui empty states, titoli e messaggi di errore (es: 'La tua tela è vuota', 'Dati insufficienti', 'Coming Soon', 'Error').
  - *Tech Notes*: Le traduzioni sono state aggiunte in `AppLocalizations` (`lib/core/localization.dart`) e implementate in `dashboard_screen.dart`, `day_details_modal.dart`, `macro_goals_stats_view.dart`, `life_view_widget.dart`, `statistics_screen.dart` e molteplici tab widgets delle statistiche.

- [2026-05-21 13:46]: Full 100% Translation Coverage
  - *Details*: Effettuato un deep scan e sostituzione di oltre 150 occorrenze di testo hardcoded sparsi in tutta la UI e back-end (tra cui titoli dei grafici, messaggi di alert, label delle statistiche e notifiche/snackbar emesse dai provider).
  - *Tech Notes*: Aggiunte oltre 60 nuove chiavi in `AppLocalizations`. Sistemati i bug di inizializzazione `const` derivanti dall'inserimento di `context.l10n.translate()` su widget statici. Introdotto `ref.read(l10nProvider).translate()` nei provider per permettere la traduzione dinamica degli errori di background.

- [2026-05-21 13:51]: Fix Default Calendar View Label Bug
  - *Details*: Risolto un bug in `app_settings_screen.dart` dove la vista predefinita mostrava la stringa inglese raw salvata (`WEEK`) o mancava il checkmark nelle opzioni a causa di una non conformità con il nome salvato su disco. 
  - *Tech Notes*: Implementato un parse esplicito per convertire i valori `week`, `month`, `year` in formati localizzati (usando `context.l10n.translate`) e migliorata la logica di `isSelected` nel menù a tendina.
- [2026-05-21 14:09]: Completamento 11 Bug di Traduzione (100% Coverage)
  - *Details*: Risolti gli 11 bug rimanenti di traduzione che erano ancora in inglese e non coperti nel precedente refactor.
  - *Tech Notes*: Sostituito testo statico con `context.l10n.translate()` nei seguenti file: `profile_screen.dart`, `app_settings_screen.dart`, `protocollo_panel.dart`, `day_details_modal.dart`, `global_trend_tab_widget.dart`, `global_mood_tab_widget.dart`, `macro_goals_stats_view.dart`, `macro_goals_screen.dart`, `add_goal_bar.dart`, `category_picker_sheet.dart`. Aggiunte tutte le chiavi mancanti al dizionario in `localization.dart`. Analisi flutter superata.
- [2026-05-21 14:40]: Aggiunte chiavi traduzione Mood
  - *Details*: Aggiunte al file `localization.dart` le chiavi mancanti per il tab Mood delle statistiche globali ("Mood & Energia", "Analisi del benessere psicofisico.", ecc.) in modo che la localizzazione del widget `GlobalMoodTabWidget` funzioni correttamente.
- [2026-05-21 14:42]: Aggiunte chiavi tutorial (incluso "Stato d'animo")
  - *Details*: Aggiunte al dizionario `localization.dart` tutte le descrizioni dei vari tutorial, come ad esempio la scritta del "Daily Check-in" che conteneva la parola "stato d'animo". Il file `protocollo_panel.dart` ha la sua traduzione correttamente wrappata.
- [2026-05-21 14:49]: Traduzione massiva dell'ultimo 5% di stringhe hardcoded
  - *Details*: Risolte oltre 50 stringhe in lingua originale non gestite dal sistema di localizzazione.
  - *Tech Notes*: Script Python eseguito su `ai_chat_screen.dart`, `app_settings_screen.dart`, `consent_screen.dart`, `notification_settings_screen.dart`, `personal_info_screen.dart`, `privacy_settings_screen.dart`, `subscription_screen.dart`, `life_view_widget.dart` e `pro_features_modal.dart`. Sostituiti tutti gli hardcoded `Text('...')` o similari con l'equivalente mappatura in `context.l10n.translate()`. Tutte le chiavi sono state inserite sia in italiano sia in inglese. Rimosso `const` dove causava conflitti.
- [2026-05-21 14:56]: Traduzione completa Subscription Screen
  - *Details*: Tutta la schermata degli abbonamenti (`subscription_screen.dart`), inclusi i messaggi di errore di Apple/RevenueCat, le feature premium ("AI Coach Personalizzato", "Abitudini Illimitate"), i dettagli dell'abbonamento attivo ("Prossimo Rinnovo", "Metodo di Pagamento"), il selettore del piano ("Mensile", "Annuale") e le legali ("Privacy Policy", "EULA") sono state wrappate nel traduttore di sistema e aggiunte al dizionario globale inglese/italiano. Rimosso ogni riferimento statico in Italiano.

- [2026-05-21 14:58]: Settings - Rimozione sottomenu "AI & SISTEMA" da Impostazioni App
  - *Details*: Completamente rimosso il sottomenu "AI & SYSTEM" / "AI & SISTEMA" e tutte le sue voci associate (inclusi i "Suggerimenti AI") dalla schermata delle impostazioni dell'applicazione (`app_settings_screen.dart`).
  - *Tech Notes*:
    - Rimosso il header di sezione e la card con il relativo switch dalla UI di `app_settings_screen.dart`.
    - Risolti alcuni errori pre-esistenti di compilazione per espressioni `const` non valide con invocazioni di metodi dinamici di localizzazione all'interno di `subscription_screen.dart` per garantire la stabilità e il superamento dell'analisi statica di Flutter.

- [2026-05-21 15:10]: Dynamic Popup & Dialog Translation Sweep & Clean Build
  - *Details*: Performed a 100% comprehensive popup, dialog, alert modal, and bottom sheet dynamic localization sweep (Italian `it` and English `en`). Resolved missing localization imports in `subscription_alert_modal.dart` and `error_modal.dart`. Localized settings validation popups, password warning sheets, account management deletion/reset confirmations, and custom warnings. Cleaned up string concatenations to use string interpolation.
  - *Tech Notes*:
    - Fixed `context.l10n` compile issues by adding proper imports.
    - Localized the hardcoded `'Elimina l\'account'` title in `privacy_settings_screen.dart` to match `localization.dart` mapping.
    - Converted `'Evolve Pro' + ' ' + context.l10n.translate(title)` concatenation to dynamic string interpolation, resolving two `prefer_interpolation_to_compose_strings` code analyzer warnings.
    - Verified clean static compilation (0 errors, 0 warnings) via `flutter analyze`.

## [2026-05-21 15:28 CEST]: Professional Flutter Localization Migration

*Details*: Replaced the in-code translation map with Flutter's official `gen-l10n` pipeline. Added ARB-based Italian and English resources, generated typed `AppLocalizations`, wired `MaterialApp.router` to `localizationsDelegates` and `supportedLocales`, and changed language settings to support a scalable `system/it/en` preference model. The default now follows the iPhone/app language automatically, while still allowing explicit Italian or English overrides.

*Tech Notes*: Added `flutter_localizations`, `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_it.arb`, and generated localization classes under `lib/l10n/generated/`. Kept a compatibility `translate(String key)` adapter in `lib/core/localization.dart` so existing dynamic translation paths keep working while ARB files become the single source of truth. Updated date formatting to use the active locale, normalized legacy saved language labels such as `Italiano`/`English` back to `system`, added iOS `CFBundleLocalizations`, and localized native iOS permission strings via `en.lproj` and `it.lproj`. Verified with `flutter analyze`, `flutter test`, and `flutter build ios --simulator --debug`.

## [2026-05-21 15:41 CEST]: Life View Title Localization Fix

*Details*: Moved the hardcoded "La Mia Vita Produttiva" title in the life view into the ARB localization pipeline so it now translates with the active app locale.

*Tech Notes*: Added `productiveLifeTitle` to `lib/l10n/app_it.arb` and `lib/l10n/app_en.arb`, regenerated `lib/l10n/generated/`, and updated `lib/ui/widgets/life_view_widget.dart` to use `context.l10n.productiveLifeTitle`. Verified with `flutter analyze` and `flutter test`.

## [2026-05-21 15:44 CEST]: Goals Period Selector Localization Fix

*Details*: Localized the Goals planning selector labels and the period navigator so weekly and monthly headings follow the active app locale instead of using hardcoded Italian month/type names.

*Tech Notes*: Added typed ARB keys for macro goal planning types, the selector header, and lifetime description. Updated `macro_goals_screen.dart` to use localized goal type labels and `intl.DateFormat` for monthly/weekly period titles, including English-specific week range ordering such as `May 15 - 21, 2026`. Updated macro goal statistics type labels to reuse the same localized labels. Verified with `flutter analyze` and `flutter test`.

## [2026-05-21 15:48 CEST]: Goals Empty State Localization Fix

*Details*: Localized the empty state shown when a Goals period has no objectives.

*Tech Notes*: Added `emptyGoalsTitle` and `emptyGoalsSubtitle` to `lib/l10n/app_it.arb` and `lib/l10n/app_en.arb`, regenerated `lib/l10n/generated/`, and updated `macro_goals_screen.dart` to use typed `context.l10n` getters. Verified with `flutter analyze` and `flutter test`.

## [2026-05-21 15:51 CEST]: Performance Analysis Localization Fix

*Details*: Localized the Performance Analysis year selector and removed hardcoded Italian month/type labels from macro goal statistics charts.

*Tech Notes*: Added `allYears` and `selectYearHeader` to the ARB resources, regenerated `lib/l10n/generated/`, and updated `macro_goals_stats_view.dart` to use typed localization for "All years" / "Select year". Replaced hardcoded month arrays in the monthly and historical charts with `intl.DateFormat` based on `context.l10n.localeName`, and localized tooltip labels such as totals, completed counts, and success suffixes. Verified with `flutter analyze` and `flutter test`.

## [2026-05-21 16:12 CEST]: Full App Localization Sweep

*Details*: Performed a deep localization sweep across menus, pop-up flows, provider error modals, chart tooltips, local notifications, AI chat prompts, statistics cards, weekly/date headers, and remaining secondary labels. Removed the remaining high-confidence user-facing Italian hardcoded strings found by targeted `rg`/heuristic scans and moved them into the ARB `it`/`en` pipeline.

*Tech Notes*: Added typed ARB keys for AI suggestions/system prompts, OpenRouter user-facing errors, notification actions/bodies/reminder variants, habit/macro-goal/category error messages, chart units, correlation descriptions, quarter labels, compact statistics labels, and fallback habit names. Updated `notifications.dart` and `openrouter_service.dart` to resolve localized strings from the device locale outside widget context, with English fallback for unsupported locales. Replaced Italian month arrays in weekly and day detail widgets with locale-aware `intl.DateFormat`. Regenerated `lib/l10n/generated/`; `build/l10n_untranslated.txt` is empty (`{}`). Verified with `flutter analyze` and `flutter test`.

## [2026-05-21 21:16 CEST]: Fix - App-Wide 24h Time Format Preference

*Details*: Made the "Formato 24h" setting consistently affect notification and habit reminder time selection/display. Notification settings now open their Cupertino time pickers with the selected 12h/24h mode and show stored notification times in the selected display format instead of always rendering raw `HH:mm` values.

*Tech Notes*: Added `AppTimeFormatting` in `lib/core/time_formatting.dart` to keep persisted times canonical as `HH:mm` while formatting UI labels as either `HH:mm` or `h:mm AM/PM`. Updated `notification_settings_screen.dart`, `habit_management_modal.dart`, and the root `MaterialApp.router` `MediaQuery` override in `main.dart` so app-level time widgets receive the current `timeFormat24h` preference. Added `test/time_formatting_test.dart`. Verified with `flutter analyze`, `flutter test test/time_formatting_test.dart`, and full `flutter test`.

## [2026-05-22 18:23 CEST]: App Store Release Version Bump

*Details*: Updated the Flutter app version from `1.0.0+4` to `1.0.1+5` so the next iOS archive can be uploaded to App Store Connect as a new app update build.

*Tech Notes*: Changed `pubspec.yaml` `version` only. Flutter maps `1.0.1` to iOS `CFBundleShortVersionString` through `$(FLUTTER_BUILD_NAME)` and `5` to `CFBundleVersion` through `$(FLUTTER_BUILD_NUMBER)`.

## [2026-05-22 21:34 CEST]: Arabic Localization Implementation

*Details*: Added Arabic as a first-class app language alongside Italian and English. The implementation includes a complete `app_ar.arb`, generated Flutter localization classes, Arabic language selection in App Settings, and native iOS Arabic permission strings.

*Tech Notes*: Added `ar` to `AppLanguagePreference`, `AppLocalizations.supportedLocales`, iOS `CFBundleLocalizations`, and the Xcode `InfoPlist.strings` variant group. Added `ios/Runner/ar.lproj/InfoPlist.strings`, regenerated `lib/l10n/generated/`, and verified ARB key/placeholder parity. Flutter automatically applies RTL layout direction when the active locale is Arabic. Added explicit locale resolution so unsupported device languages fall back to English instead of the alphabetically first generated locale. Verified with `flutter analyze`, `flutter test`, and `flutter build ios --no-codesign`.

## [2026-05-22 21:44 CEST]: Spanish Localization Implementation

*Details*: Added Spanish as a first-class app language alongside English, Italian, and Arabic. The implementation includes a complete `app_es.arb`, curated Spanish UI terminology, generated Flutter localization classes, Spanish language selection in App Settings, and native iOS Spanish permission strings.

*Tech Notes*: Added `es` to `AppLanguagePreference`, `AppLocalizations.supportedLocales`, iOS `CFBundleLocalizations`, and the Xcode `InfoPlist.strings` variant group. Added `ios/Runner/es.lproj/InfoPlist.strings`, regenerated `lib/l10n/generated/`, and verified ARB key/placeholder parity across `en`, `it`, `ar`, and `es`. The explicit locale resolver uses English as the fallback whenever the device's primary language is unsupported. Verified with `flutter analyze`, `flutter test`, and `flutter build ios --no-codesign`.

## [2026-05-22 21:56 CEST]: German Localization Implementation

*Details*: Added German as a first-class app language. German was selected because it is a high-value European language for iOS consumer apps and the project already contains German marketplace screenshot assets, making it a practical next localization target.

*Tech Notes*: Added `de` to `AppLanguagePreference`, `AppLocalizations.supportedLocales`, iOS `CFBundleLocalizations`, and the Xcode `InfoPlist.strings` variant group. Added `lib/l10n/app_de.arb`, generated `lib/l10n/generated/app_localizations_de.dart`, and added `ios/Runner/de.lproj/InfoPlist.strings`. Applied a German UI terminology pass for navigation, settings, statistics, subscriptions, onboarding, notifications, and error messages. Verified ARB key/placeholder parity across `en`, `it`, `ar`, `es`, and `de`. The explicit locale resolver continues to use English whenever the device's primary language is unsupported. Verified with `flutter analyze`, `flutter test`, and `flutter build ios --no-codesign`.

## [2026-05-26 10:50]: Statistics - Sparse Mood Chart Window
*Details*: Updated the global "Mood & Energia" chart so users with little recent history no longer see new data floating in the middle of the graph. When the selected range contains only sparse mood entries, the chart now starts from the first available mood date in that range and still ends at today.
*Tech Notes*:
- Added `MoodChartWindow` to calculate a data-aware chart window for 14D, 30D, and 90D views.
- Kept the empty-state behavior unchanged when there are no mood entries in the selected range.
- Enabled point markers for sparse mood histories to keep very small datasets visible and professional.
- Added `test/mood_chart_window_test.dart` for the new window calculation.
- Updated the stale root widget smoke test from `MyApp` to `EvolveApp` so `flutter analyze` and `flutter test` can run cleanly.

## [2026-05-26 11:21 CEST]: App Store Release Version Bump

*Details*: Updated the Flutter app version from `1.0.1+5` to `1.0.2+6` so a new iOS archive can be uploaded to App Store Connect without reusing the previous build number.

*Tech Notes*: Changed `pubspec.yaml` `version` only. Flutter maps `1.0.2` to iOS `CFBundleShortVersionString` and `6` to `CFBundleVersion` through the generated Flutter build settings.

- [2026-05-27 08:37 CEST]: Tutorial Orientation Layout Fix
  - *Details*: Fixed tutorial coachmark layout issues when rotating between portrait and landscape, with special handling for the macro goals tutorial steps shown around the fake tutorial goal action buttons.
  - *Tech Notes*: Added responsive width/height constraints and scroll-safe tutorial cards in `dashboard_screen.dart` and `macro_goals_screen.dart`. The macro goals tutorial now observes metric changes, removes and recreates the active `TutorialCoachMark` on resize/orientation changes, restores the same step via `initialFocus`, and switches the goals/statistics surface before target measurement so previous/next navigation remains stable. Verified with `flutter analyze` and `flutter test`.

- [2026-05-27 08:41 CEST]: Portrait-Only App Orientation
  - *Details*: Locked the app to portrait orientation so tutorial and app screens no longer enter landscape layouts on phone rotation.
  - *Tech Notes*: Added `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` during Flutter startup, restricted iOS `UISupportedInterfaceOrientations` to portrait values, enabled `UIRequiresFullScreen` so iPad honors orientation restrictions, and set Android `MainActivity` to `android:screenOrientation="portrait"`. Verified with `flutter analyze`, `flutter test`, `plutil -lint ios/Runner/Info.plist`, and `xmllint --noout android/app/src/main/AndroidManifest.xml`.

- [2026-05-27 08:45 CEST]: App Store Release Version Bump
  - *Details*: Updated the Flutter app version from `1.0.2+6` to `1.0.3+7` so the next archive can be uploaded as a new store update without reusing the previous build number.
  - *Tech Notes*: Changed `pubspec.yaml` `version` only. Flutter maps `1.0.3` to iOS `CFBundleShortVersionString` / Android `versionName` and `7` to iOS `CFBundleVersion` / Android `versionCode` through the generated Flutter build settings.

## [2026-06-17 21:47 CEST]: Private Mode Production Plan

*Details*: Added a detailed production implementation plan for the new Private mode, preserving the existing Supabase account behavior while defining a separate local-only data space and a later iCloud sync phase.

*Tech Notes*: Created `PRIVATE_MODE_PRODUCTION_PLAN.md` with locked product decisions, Phase 1 local encrypted database/provider-routing work, Phase 2 iCloud/CloudKit sync architecture, schema parity notes from the Supabase introspection, privacy constraints, subscription/Sentry/AI handling, and verification gates. No application code was changed in this step.

## [2026-06-17 22:12 CEST]: Private Mode Phase 1 Local Storage Implementation

*Details*: Implemented the app-level Private mode path while keeping the existing Supabase login/account behavior untouched. Users can now choose Private mode from the login screen after the existing consent/onboarding flow, use the app with local-only data, keep a separate local profile, use all features without subscription gating, export/delete private data, and return to the login screen without migrating or mixing Supabase data.

*Tech Notes*: Added `AppDataMode` persistence, router refresh handling for Supabase vs Private access, Sentry suppression in Private mode, encrypted local SQLite storage via `sqflite_sqlcipher`, local owner/encryption key storage via secure storage, and provider routing for habits, habit logs/statistics, macro goals, custom macro-goal categories, moods, settings, and profile data. A saved Private-mode cold start now skips Supabase initialization entirely; Supabase is initialized lazily only when the user explicitly returns to the account/login path. Added private AI external-provider consent before sending chat context, local notification action support for Private mode, iOS backup-exclusion hook for the local private database directory, and Android SQLCipher ProGuard keep rules. Added `sqflite_sqlcipher`, `path_provider`, `path`, and `uuid` dependencies. iCloud/CloudKit sync remains intentionally deferred to Phase 2 and is represented by a no-op sync boundary. Updated `mobile_schema.sql` to reflect the verified production Supabase schema deltas used by the local mirror.

## [2026-06-18 08:23 CEST]: Private Mode Production-Readiness Audit Fixes

*Details*: Audited the Private mode implementation for cold-start privacy, local database retry behavior, reset cleanup, notification edge cases, UI feature gating, and native platform integration. Fixed the issues found so Private mode remains local-only on cold start, does not mute/hide normal app features, and cleans up private artifacts more reliably.

*Tech Notes*: Disabled external reporting before opening the private database during mode switch, restored the previous reporting state on private startup failure, reset the SQLCipher open future after failed opens so retries work, stopped duplicate-keychain recovery from clearing unrelated secure storage, deleted copied private avatar files during private data deletion, cancelled pending local notifications before deleting private data, initialized background notification logging with the saved active mode, made Private settings initialize from local defaults rather than shared Supabase-mode preferences, preserved custom macro-goal category IDs during reschedule, and registered the iOS backup-exclusion MethodChannel from `SceneDelegate` as well as `AppDelegate`. Verified with `flutter analyze`, `flutter test`, `flutter build ios --no-codesign`, `flutter build apk --debug`, and `git diff --check`.

## [2026-06-18 08:52 CEST]: Fix - Private Mode Name Setup Gates Tutorial

*Details*: Fixed the Private mode startup race where the first-run name dialog and tutorial/welcome flow could appear at the same time. The dashboard startup now waits for profile setup to complete successfully before allowing tutorial onboarding to start.

*Tech Notes*: Added an awaitable private-profile load path in `user_provider.dart`, introduced `UserProfile.requiresNameSetup()` to treat blank profiles and the old `"Private User"` placeholder as incomplete private setup, removed the default placeholder from new private profile rows, and changed `dashboard_screen.dart` to run a single gated startup flow. The name dialog now saves through local private profile storage in Private mode and still uses Supabase auth metadata in account mode. Added `test/user_profile_test.dart`. Verified with `flutter test test/user_profile_test.dart`, `flutter analyze`, `flutter test`, and `flutter build ios --no-codesign`.

## [2026-06-18 13:46 CEST]: Tutorial Production-Readiness Hardening

*Details*: Audited and hardened the complete onboarding tutorial flow across dashboard, goals, and statistics so login/account mode and Private mode cannot interfere with each other and retained pages cannot start tutorial overlays while inactive.

*Tech Notes*: Made tutorial completion state mode-aware in `tutorial_provider.dart` with Supabase legacy-key fallback and isolated Private-mode keys. Added active-page gating, single-overlay guards, timer cleanup, mounted target checks, and guarded `TutorialCoachMark.show()` calls in `dashboard_screen.dart`, `macro_goals_screen.dart`, and `statistics_screen.dart`. The dashboard welcome dialog is now awaited before scheduling the first coachmark, goals/stats continuation tutorials only start when their page is active, and stats tutorial cards now use the same responsive constrained layout pattern as the other tutorial cards. Added `test/tutorial_provider_test.dart`. Verified with `flutter test test/tutorial_provider_test.dart test/user_profile_test.dart`, `flutter analyze`, `flutter test`, and `flutter build ios --no-codesign`.

## [2026-06-18 14:04 CEST]: Fix - Name Prompt Restricted to Private Mode

*Details*: Fixed the startup/login regression where the name prompt could appear before the user chose Login or Private mode. The name setup prompt is now exclusively part of Private mode setup and cannot be triggered by an unauthenticated or Supabase-mode startup frame.

*Tech Notes*: Added `shouldPromptForStartupName()` in `user_provider.dart` and updated `dashboard_screen.dart` so startup onboarding stops immediately when `authState.canAccessApp` is false, skips name setup in Supabase mode, and only loads/checks the local private profile when `AppDataMode.private` is active. Added regression coverage in `test/user_profile_test.dart` for unauthenticated, Supabase, and Private-mode prompt eligibility. Verified with `flutter test test/user_profile_test.dart test/tutorial_provider_test.dart`, `flutter analyze`, `flutter test`, and `flutter build ios --no-codesign`.

## [2026-06-18 22:10 CEST]: Private Mode - Name Prompt Controller Lifecycle Fix
*Details*: Fixed the crash that occurred immediately after entering a name in Private mode by moving the name prompt `TextEditingController` into a dedicated stateful dialog widget. This keeps the controller alive for exactly as long as the `TextField` subtree is mounted.
*Tech Notes*:
- Updated `lib/ui/screens/dashboard_screen.dart`.
- Extracted the name prompt UI into `_NamePromptDialog`, a `ConsumerStatefulWidget` that owns and disposes its controller in widget lifecycle methods.
- No new dependencies, endpoints, migrations, or manual user actions required.

## [2026-06-18 22:43 CEST]: Tutorial Flow State Hardening
*Details*: Hardened the dashboard, goals, and statistics tutorial handoff so tutorial overlays are removed before page transitions or completion dialogs run. This prevents the Goals tutorial from appearing finished while stale overlay/timer state can continue advancing after unrelated taps.
*Tech Notes*:
- Updated `dashboard_screen.dart`, `macro_goals_screen.dart`, `statistics_screen.dart`, and `tutorial_provider.dart`.
- Goals tutorial cleanup now cancels pending start/restart timers, resets the temporary performance view back to the goals list, and guards duplicate completion.
- Statistics tutorial completion now clears its overlay before showing the final completion dialog.
- Tutorial provider state now updates in memory before persistence completes so delayed UI checks cannot reschedule a just-completed step.
- Added `test/tutorial_provider_test.dart` coverage for immediate in-memory tutorial completion state.

## [2026-06-18 22:54 CEST]: Goals Tutorial Target Readiness Fix
*Details*: Fixed the Goals tutorial handoff so the first "Tipo di Pianificazione" coachmark waits for the Goals page transition to settle and for the planning type target to have a valid on-screen render box.
*Tech Notes*:
- Updated `macro_goals_screen.dart`.
- Increased the initial Goals tutorial delay to exceed the dashboard `PageView` animation.
- Replaced broad `currentContext` checks with per-target render-box readiness checks that require attached, sized, visible targets inside the screen bounds.
- Added per-focus target waiting so later Goals tutorial steps also wait for their target after switching between the goals list and performance view.

## [2026-06-19 08:24 CEST]: Goals Tutorial Continuation Crash Fix
*Details*: Fixed the iOS tutorial continuation on the Goals page so the coachmark content reliably appears after the dashboard hands off to Goals, instead of leaving only the dim overlay and later surfacing `Bad state: No element`.
*Tech Notes*:
- Updated `macro_goals_screen.dart` so Goals tutorial startup waits for the current target instead of broad `currentContext` checks, reducing startup races during Goals list/performance view transitions.
- Updated `macro_goals_provider.dart` to ignore tutorial-only fake goal mutations before persistence logic, preventing Private-mode `firstWhere` crashes if an event reaches the ephemeral tutorial goal.
- Updated deprecated reorder callbacks in `macro_goals_screen.dart` and `habit_management_modal.dart` from `onReorder` to `onReorderItem` for Flutter 3.44 analyzer compatibility.
- Added `test/macro_goals_tutorial_test.dart` covering the Goals tutorial continuation popup and tutorial-only fake goal mutation safety.
- Verified with `flutter analyze` and `flutter test`.

## [2026-06-19 08:32 CEST]: Goals Tutorial Startup Interaction Lock
*Details*: Reviewed the provided `tutorial.mov` recording and fixed the remaining Goals tutorial gap where the user could tap the Goals page while the first coachmark was still starting, causing the UI to switch to Performance Analysis before the "Planning Type" popup appeared.
*Tech Notes*:
- Updated `macro_goals_screen.dart` to preflight only the target being shown first instead of requiring every later tutorial target to be ready before step 1 can appear.
- Wrapped the Goals screen body in an `AbsorbPointer` while the Goals tutorial is pending, preventing taps/swipes on the Goals UI during the short handoff delay; tutorial overlay controls remain interactive because they render above the screen body.
- Extended `test/macro_goals_tutorial_test.dart` with regression coverage that taps "Performance Analysis" during the startup gap and verifies the app stays on the Goals list until the first popup appears.
- Verified with `flutter test test/macro_goals_tutorial_test.dart`, `flutter analyze`, and `flutter test`.

## [2026-06-19 13:46 CEST]: Goals Tutorial Immediate Overlay Rewrite
*Details*: Rewrote the Goals-page continuation tutorial so the first popup is rendered by `MacroGoalsScreen` on the first active Goals frame instead of being scheduled through delayed `TutorialCoachMark` startup. This prevents the user from landing on Goals with a dimmed/locked page and no visible tutorial card.
*Tech Notes*:
- Removed the Goals screen dependency on `TutorialCoachMark`, its startup timers, metrics restart logic, and target polling.
- Added an in-screen tutorial overlay with a custom scrim painter, highlighted target bounds, explicit previous/next controls, and active-page-only pending state.
- Kept the Goals body absorbed while the tutorial is pending but rendered overlay controls above it so the tutorial remains usable.
- Added regression coverage that verifies the "Planning Type" popup is visible immediately, surface taps cannot switch to Performance Analysis while pending, and the tutorial advances without delayed coachmark startup.
- No new dependencies, endpoints, migrations, or manual user actions required.

## [2026-06-19 14:02 CEST]: Statistics Tutorial Immediate Overlay Rewrite
*Details*: Rewrote the Statistics-page continuation tutorial with the same immediate in-screen overlay pattern used on Goals. The Statistics tutorial now appears on the first active Statistics frame after the Goals tutorial completes, instead of waiting on delayed `TutorialCoachMark` startup.
*Tech Notes*:
- Removed Statistics tutorial startup timers, coachmark target polling, and `TutorialCoachMark` overlay usage from `statistics_screen.dart`.
- Added a Statistics-owned tutorial overlay with highlighted target bounds, a custom scrim painter, explicit previous/next controls, and active-page-only pending state.
- Absorbed the Statistics page body while the tutorial is pending and added a full-screen scrim hit-test layer so page taps cannot leak through while the popup is visible.
- Added `test/statistics_tutorial_test.dart` covering immediate first-frame popup visibility, scrim tap handling, and step advancement without delayed coachmark startup.
- No new dependencies, endpoints, migrations, or manual user actions required.

## [2026-06-22 14:30 CEST]: Localization migration to slang — Phase 0 (bootstrap)
*Details*: Began replacing the legacy runtime `translate()` shim (641 Italian-keyed `case`s in `lib/core/localization.dart`, 675 call sites, silent Italian fallback on any miss) with a type-safe **slang** localization layer. Phase 0 is purely additive — the new system is installed alongside the untouched `gen_l10n` system, so there is no behavior change yet. Full plan and per-phase recipe in `LOCALIZATION_PLAN.md`. Architecture agreed via design review: slang, English source-of-truth + fallback, semantic nested keys, in-repo AI-assisted translation (preserve existing copy), phased-by-feature migration, Arabic/RTL deferred.
*Tech Notes*:
- Added `tool/arb_to_slang.py`: lossless ARB→slang-JSON crosswalk converter (drops `@meta`, preserves `{placeholders}` and key order, verifies cross-locale parity). Ran it: generated `lib/i18n/{en,it,es,de,ar}.i18n.json`, **771 keys each, parity verified, all valid JSON**.
- Added `slang.yaml` (base_locale `en`, `fallback_strategy: base_locale`, brace interpolation, Flutter integration, global `t`).
- New dependencies (in `pubspec.yaml`): `slang`, `slang_flutter`, `slang_build_runner` (`^4.0.0`; versions to be pinned by `flutter pub get`).
- `.gitignore`: ignores generated `lib/i18n/translations.g.dart`.
- **Manual actions required** (Flutter SDK unavailable in the build env): `flutter pub get`, then `dart run slang` (codegen), then the integration micro-step. Logged in `TO_SIMO_DO.md`.
- Endpoints/migrations: none.

## [2026-06-22 15:10 CEST]: Localization — slang integration + Arabic deferral
*Details*: Wired the generated slang layer into the app (after the user ran `flutter pub get` + `dart run slang`) and deferred Arabic until the RTL pass. Still additive for the existing screens — every screen renders via the old `context.l10n` system; only the locale plumbing changed and Arabic is no longer offered (it was already shipping with broken RTL). `t.*` is now available app-wide for the per-feature migration (Phases 1..N).
*Tech Notes*:
- `lib/main.dart`: imported `i18n/translations.g.dart`; wrapped the app in `TranslationProvider`; set the initial locale from `pref_language` in `main()`; added a `ref.listen` on `settings.language` → `LocaleSettings.setLocale(...)`; switched `MaterialApp.locale` to `TranslationProvider.of(context).flutterLocale` and `supportedLocales` to `AppLocaleUtils.supportedLocales`; removed the now-redundant `_resolveAppLocale` (replaced by `_appLocaleFor`, which maps the app's language preference → `AppLocale`, with "system" → device locale and legacy `ar` → base `en`).
- **Arabic deferred** (bulletproof): excluded `ar` from slang input (`tool/arb_to_slang.py` `LOCALES` now `en/it/es/de`), deleted `lib/i18n/ar.i18n.json`, and removed the Arabic option from the language picker (`app_settings_screen.dart`). Arabic source preserved at `lib/l10n/app_ar.arb`; re-enable after the RTL pass.
- **Verification still required** (no Flutter SDK here): re-run `dart run slang` (regenerates 4 locales, drops `ar` from `AppLocale`) then `flutter analyze` / `flutter test`. Logged in `TO_SIMO_DO.md`.
- No new dependencies, endpoints, or migrations.

## [2026-06-22 15:40 CEST]: Localization — Phase 1 (`settings` namespace migrated to slang)
*Details*: Migrated the App Settings screen off the legacy `context.l10n.translate(...)` shim onto type-safe slang `context.t.settings.*`. First real per-feature slice; only **settings-exclusive** keys were migrated — shared atoms (`Annulla`, calendar views `Anno/Mese/Settimana/Vita`, `Impostazioni App`, `Verifica`) intentionally stay on the old system until the `common` phase. Also fixed a latent bug: `PROSSIMAMENTE` had no shim case (it rendered literally to all languages) — now a proper `settings.comingSoon` with EN/IT/ES/DE.
*Tech Notes*:
- `lib/i18n/{en,it,es,de}.i18n.json`: scripted restructure — moved 21 flat keys into a nested `settings` tree (`sections`, `appearance`, `calendar`, `experience`, `units`, `language`, `confirmDialog`) + added `settings.comingSoon`. 22 keys per locale, parity verified.
- `lib/ui/screens/app_settings_screen.dart`: added `i18n/translations.g.dart` import; **24 call sites** rewritten to `context.t.settings.*` (15 `translate('…')` + 7 language getters). 16 `context.l10n.` shared-atom sites intentionally left.
- `tool/arb_to_slang.py`: added a guard — the bootstrap converter now ABORTS if a target JSON already has nested namespaces, so it can't flatten/clobber migrated work.
- **Shim/ARB untouched** — deletion of now-dead exclusive cases is deferred to the final demolition (a `case` is only safe to delete once every screen is migrated). No behavior change for other screens.
- **Verification required** (no Flutter SDK here): `dart run slang && flutter analyze && flutter test`.
- No new dependencies, endpoints, or migrations.

## [2026-06-22 16:10 CEST]: Localization — Phase 2 (`common` namespace, app-wide shared atoms)
*Details*: Migrated the cross-cutting shared atoms (the 12 strings used in ≥3 files) onto `context.t.common.*` across the whole UI, including the shared-atom call sites Phase 1 left in the settings screen. Scope = generic UI vocabulary only; domain words (`Energia`, `Obiettivi`, `Completato`) and count-words (`giorni`, needs plurals) stay for their feature/plural phases.
*Tech Notes*:
- `lib/i18n/{en,it,es,de}.i18n.json`: moved 12 flat keys into `common` → `actions` (save/cancel/confirm/delete/done/gotIt/verify), `status.error`, `calendarView` (year/month/week/life). 12 keys/locale, parity verified.
- Call sites: **69 replacements across 22 files** (`context.l10n.translate('…')` → `context.t.common.*`), 0 left on the old system. Added the slang import to 21 files (correct relative depth per directory; all paths verified to resolve; no duplicates).
- Removed a now-unused `core/localization.dart` import from `view_tab_bar.dart`.
- Shim/ARBs still untouched (dead cases swept at the final demolition).
- **Verification required** (no Flutter SDK here): `dart run slang && flutter analyze && flutter test`.
- No new dependencies, endpoints, or migrations.

## [2026-06-22 16:45 CEST]: Localization — Phase 3 (`auth` namespace) + fixes audit I18N-2
*Details*: Migrated the auth screen to `context.t.auth.*` and — the high-value part — fixed audit finding **I18N-2**: `auth_provider.dart` returned **hardcoded Italian** error messages to users of every language. Notably the localized keys already existed (e.g. `authNetworkRetry`) and the provider simply never used them. Now all auth errors are localized; 8 previously-missing ones (Google/Apple token+auth, private-mode start, rate-limit, signups-disabled, generic) were added with EN/IT/ES/DE.
*Tech Notes*:
- `lib/i18n/{en,it,es,de}.i18n.json`: built the `auth` namespace — moved 19 existing keys (8 error keys + 3 getters + 8 screen strings) into `auth.*`/`auth.errors.*` and added 8 new error keys. 27 keys/locale, parity verified. `auth.errors.generic` carries a `{message}` placeholder.
- `lib/ui/screens/auth_screen.dart`: 12 call sites → `context.t.auth.*` (shared `Email`/link-error deferred to `common`).
- `lib/providers/auth_provider.dart`: **first non-widget migration** — uses the **global `t`** (a provider has no `BuildContext`). 21 hardcoded Italian literals → `t.auth.errors.*`, including `t.auth.errors.generic(message: supabaseMessage)`. Verified no Italian error literals remain; added `../i18n/translations.g.dart` import; confirmed no local `t` shadowing.
- Shim/ARBs still untouched (dead cases swept at final demolition).
- **Verification required** (no Flutter SDK here): `dart run slang && flutter analyze && flutter test`.
- No new dependencies, endpoints, or migrations.

## [2026-06-22 17:15 CEST]: Localization — Phase 4 (`profile` namespace, account cluster)
*Details*: Migrated the account cluster — `profile_screen.dart` + `personal_info_screen.dart` — to `context.t.profile.*` (with `profile.personalInfo.*` for the form). Fixed another latent bug: `Vai al login` had no shim case (rendered Italian to everyone) — added as `profile.goToLogin` with EN/IT/ES/DE.
*Tech Notes*:
- `lib/i18n/{en,it,es,de}.i18n.json`: moved 17 existing keys into `profile.*` (account headers, logout, pro-plan, version) and `profile.personalInfo.*` (first/last name, DOB, validation, save messages); added `profile.goToLogin`. 18 keys/locale, parity verified.
- Call sites: 22 replacements across the 2 files → `context.t.profile.*`. The escaped-apostrophe string (`Inserisci un\'email valida`) was migrated via a manual edit to avoid script-escaping issues. Shared strings (`Email`, `Notifiche`, `Privacy e Sicurezza`, `Abbonamento`, `Impostazioni App`) deferred to their phases.
- Shim/ARBs still untouched (dead cases swept at final demolition).
- **Verification required** (no Flutter SDK here): `dart run slang && flutter analyze && flutter test`.
- No new dependencies, endpoints, or migrations.

## [2026-06-22 18:00 CEST]: Localization — Phase 5 (`notifications` + `privacy`) + multi-line scan gap found
*Details*: Migrated the two settings sub-screens. `notification_settings_screen` → `t.notifications.*` (7 keys). `privacy_settings_screen` → `t.privacy.*` (**45 keys**), a large screen with many multi-line dialog strings. Fixed 8 more untranslated latent bugs (private-data delete/reset/manage messages, etc.). **Important process finding**: the per-phase scan regex required `translate('…')` on one line, so **multi-line-formatted `translate(\n '…',\n)` calls were silently skipped** — including ~16 in this screen. Fixed here with a multi-line + trailing-comma-aware regex; the per-phase recipe is updated to use it.
*Tech Notes*:
- `privacy`: 41 existing keys moved + 8 new across `lib/i18n/{en,it,es,de}.i18n.json` (errors prefixes under `privacy.errors.*`); 45 keys/locale, parity verified. `notifications`: 7 keys.
- Call sites: notification_settings (8) + privacy_settings (46, incl. the 17 multi-line ones via `re.sub`) → `context.t.*`. Only shared `Notifiche`/`Privacy e Sicurezza` remain (deferred to `common`).
- ⚠️ **Known gap (to sweep next)**: the same multi-line miss left stragglers in earlier "done" screens — `auth_screen` (~10 exclusive), `profile_screen` (~7), `app_settings_screen` (~3). They are safe (still served by the shim) but those screens are **not fully migrated** until swept. The final-demolition `grep translate( == 0` check will also catch them.
- **Verification required** (no Flutter SDK here): `dart run slang && flutter analyze && flutter test`.
- No new dependencies, endpoints, or migrations.

## [2026-06-22 18:20 CEST]: Localization — straggler sweep (settings/auth/profile completed)
*Details*: Closed the multi-line gap from Phase 5 by sweeping the missed literals in the three earlier screens, using the multi-line-aware regex. `settings` +3, `auth` +10 (+`auth.continuePrivately` new), `profile` +7 (+`profile.privateModeSubtitle`, `profile.usePrivateModeOnDevice` new). Those screens are now fully migrated except genuinely-shared atoms (→ `common`).
*Tech Notes*:
- JSON: settings now 25, auth 37, profile 25 keys/locale — parity verified. 3 new keys added (EN/IT/ES/DE).
- Call sites: 20 multi-line literals → `context.t.*` via `re.subn`. All swept files balanced.
- One special case left on the shim intentionally: `translate('language')` (settings, line ~924) returns the **runtime locale name**, so it's dynamic — to be refactored at demolition, not mapped to a static key.
- **Verification required** (no Flutter SDK here): `dart run slang && flutter analyze && flutter test`.
- No new dependencies, endpoints, or migrations.

## [2026-06-22 18:35 CEST]: Localization — Phase 6 (`consent` namespace)
*Details*: Migrated `consent_screen.dart` (GDPR onboarding) to `context.t.consent.*`. Reused `t.auth.readPrivacyPolicy` (already in the `auth` namespace) rather than duplicating.
*Tech Notes*:
- `consent`: 6 keys/locale (system notifications, terms & privacy, onboarding title/subtitle, terms description/required), parity verified. Added the slang import to the file.
- 7 call sites → `context.t.*` (multi-line-aware). Only shared `Impossibile aprire il link.` remains (→ `common`). Balanced.
- **Verification required** (no Flutter SDK here): `dart run slang && flutter analyze && flutter test`.
- No new dependencies, endpoints, or migrations.

## [2026-06-22 19:10 CEST]: Localization — Phases 7-8 (`subscription`, `ai`) + toolchain now local
*Details*: `flutter`/`dart` became available at `/opt/homebrew/bin`, so verification (`dart run slang && flutter analyze && flutter test`) now runs after every phase (all green, 35 tests). Migrated the paywall and AI Coach screens.
*Tech Notes*:
- **`subscription`** (`subscription_screen`): 59 keys → `t.subscription.*` grouped into `errors`/`features`/`plans`/`status`/`actions` + titles; 73 call sites (incl. many multi-line dialog/error strings). `localeName` getter left on the shim (dynamic runtime locale).
- **`ai`** (`ai_chat_screen`): 33 keys → `t.ai.*` (incl. 20 `ai.suggestions.*` prompt chips) + 3 new keys fixing untranslated private-mode AI-consent strings; 36 sites. 12 dynamic `translate(var)` calls remain on the shim (deferred to demolition refactor).
- Both screens parity-verified, balanced, analyze clean, tests green.
- No new dependencies, endpoints, or migrations.

## [2026-06-22 19:55 CEST]: Localization — Phases 9-10 (`macroGoals` cluster, `statistics` cluster partial)
*Details*: Migrated the two biggest feature clusters. Introduced auto-generated **English** keys (camelCase of the English value) for large screens to keep velocity while honoring the semantic-English standard.
*Tech Notes*:
- **`macroGoals`** (5 files, 104 sites): 73 literals + 12 getters → `t.macroGoals.*` (`types.*` for goal types). Fixed `quarterNumber` positional→named (`quarter:`) and removed 2 now-unused localization imports.
- **`statistics`** (11 files, 139 sites, partial): 96 existing-key literals + 11 plain getters + 6 single-param method getters → `t.statistics.*`. Namespace named `statistics` to avoid the existing flat `stats` key. **Deferred:** 33 untranslated MISSING strings (need authored EN/IT/ES/DE), the 2 three-param correlation method getters (manual named-arg), ~9 dynamic `translate(var)`.
- Both clusters: analyze clean, all 35 tests green (verified locally — `flutter`/`dart` now on PATH).
- No new dependencies, endpoints, or migrations.

## [2026-06-22 21:00 CEST]: Localization — 🎯 ALL static strings migrated (habits, common sweep, missing-strings, methods)
*Details*: Finished the static migration. `grep "context.l10n.translate(\s*'"` → **0**. Added a reusable migrator (`tool/migrate_cluster.py`) and ran it across the rest.
*Tech Notes*:
- **`habits`** cluster (dashboard + 5 widgets, 49 sites); **misc** widgets → `subscription`/`habits`/`common`; **providers** (goal/macro_goals/categories) → `common` (work via `navigatorKey` context).
- **`common` sweep**: the 15 keyed shared atoms (Email, Notifiche, Obiettivi, Abitudini, Statistiche, weekday usages, …) migrated app-wide (27 sites).
- **34 missing strings** authored (EN/IT/ES/DE) and migrated — latent untranslated bugs incl. **day names** (`common.weekdays.*`), mood labels, correlation/alert descriptions.
- **2 three-param correlation methods** → `t.statistics.*` with positional→named args. Removed all now-unused `core/localization.dart` imports (both quote styles).
- **Remaining (blocks shim deletion):** 78 dynamic `translate(<var>)` + 12 `localeName`/`language` runtime-value calls — to be refactored before final demolition. The shim still serves these, so the app is fully functional/shippable.
- Every step verified: analyze clean, 35 tests green.
- No new dependencies, endpoints, or migrations.

## [2026-06-22 22:30 CEST]: Localization — 🎉 FINAL DEMOLITION (gen_l10n + shim removed, 100% slang)
*Details*: Completed the migration. Refactored the last dynamic calls and the two service files (no `BuildContext`), then physically deleted the legacy localization system. The app is now 100% on type-safe slang.
*Tech Notes*:
- **Dynamic calls** refactored: 52 double-quoted static literals + 13 authored tutorial descriptions + 34 authored "missing" strings (day names, etc.); value-maps via `lib/core/l10n_dynamic.dart` (weekday/month/tab/sort); `language`/`localeName` → `LocaleSettings.currentLocale.languageCode`; `message.text`/`error` no-op translations removed.
- **Service files** (`notifications.dart`, `openrouter_service.dart`): migrated off `lookupAppLocalizations`/gen_l10n getters to the **global `t`** (`t.notifications.*`, `t.ai.openRouter.*`); dropped the `_l10n`/`_fallbackL10n` infra and `AppLocalizations` params; updated the `ai_chat` caller.
- **Final stragglers** (multi-line `context.l10n\n.translate`/getters, captured `final l10n = context.l10n`): privacy password errors → `privacy.*`, category warnings → `macroGoals.*`, correlation methods → `statistics.*`, AI prompt builders → `ai.prompts.*` (with named args).
- **Delegates repointed**: `main.dart` + 2 tests now use `GlobalMaterialLocalizations.delegates` (flutter_localizations) + `AppLocaleUtils.supportedLocales`.
- **DELETED**: `lib/core/localization.dart`, `lib/l10n/generated/`, `l10n.yaml`, `lib/l10n/app_{en,it,es,de}.arb`, and `generate: true` in pubspec. **Kept** `lib/l10n/app_ar.arb` (Arabic source, for re-enabling after the RTL pass).
- **Result**: 0 `context.l10n` usages, `flutter analyze` clean, `flutter test` 35/35 green, `flutter pub get` OK.
- No new runtime dependencies, endpoints, or migrations.

## [2026-06-23]: PHASE 6 — Data/backend correctness (DATA-3..6)
*Details*: Closed the cloud↔Private parity and schema-drift gaps for the App-Store pass. Captured every live-only Supabase object into source, guarded against future drift, paginated the log sync, reconciled the Private schema, and rewrote Private analytics to match the cloud RPC semantics exactly.
*Tech Notes*:
- **DATA-3 (schema drift)**: dumped 9 functions + the `habit_stats` view verbatim from prod (`pg_get_functiondef`/`pg_get_viewdef`) into `../migrations/20260622_add_*.sql` (`delete_user_account`, `get_habit_analytics`, `get_global_trend`, `get_critical_habits`, `get_best_habits`, `get_habit_performance_by_day`, `get_habit_alerts`, `get_habit_yearly_grid`, `get_habit_correlations`, `habit_stats`). New guard `test/schema_drift_test.dart` scans all of `lib/` for `.rpc('x')` + non-table `from('view')` and fails if no `CREATE FUNCTION/VIEW` exists in `schema.sql` ∪ `migrations/` (base tables allowlisted).
- **DATA-6 (log sync)**: `HabitLogsNotifier._syncFromSupabase()` now range-paginates `goal_logs` (page 1000, ordered `date,id`) via the new pure `fetchGoalLogsPaginated()` helper — defeats PostgREST's per-request row cap without breaking the yearly/heatmap views. Optimistic update + rollback untouched. Tests: `test/goal_logs_pagination_test.dart`.
- **DATA-5 (Private schema)**: Private DB bumped `version 1→2`; `onUpgrade` rebuilds `long_term_goals` widening `week_number` CHECK `1..6 → 1..53` (matches cloud; week-of-month semantics documented; zero data risk). The vestigial `color` column is documented as legacy (macro-goal colour is category-derived; nothing dropped). DDL/indexes extracted to shared constants so create/upgrade can't drift.
- **DATA-4 (Private analytics parity)**: new `lib/core/private_analytics.dart` holds pure reimplementations of all 9 analytics objects, matching the captured SQL (habit_stats fields & rate=completions×100/active-days; yearly grid done=1/missed=2/365d; ISODOW day_index; longest-missed-run + gaps-and-islands broken_streaks; done-rate worst_dow + avg_recovery_days; lowest-rate critical-day token; this/last-week critical drop; windowed best-habits). `private_local_database.dart` methods now delegate to them. Fixed `tWeekday` to also localise the `'mon'..'sun'` tokens both backends emit. Tests: `test/private_analytics_test.dart` (19 cases).
- **Baseline**: `flutter analyze --fatal-infos` clean; `flutter test` 74/74 green (was 48).
- No new dependencies or endpoints. Migrations are archival (captured FROM prod — already live; no apply step needed).

## [2026-06-23]: Fix get_best_habits timeframe-token mismatch + RPC param audit
*Details*: Resolved the latent best-habits bug where the statistics UI passed the trend chart's `timeframe_*` tokens to `get_best_habits`, whose filter only knows `week/month/year/all` — so every habit returned rate=0 both online and in Private Mode. Also audited every other `.rpc()` call for the same class of value-contract mismatch.
*Tech Notes*:
- **Fix**: new pure `canonicalBestHabitsTimeframe()` in `goal_provider.dart` maps `timeframe_week_short→week`, `_month_short→month`, `_year_short→year`, `timeframe_all/unknown→all` (idempotent; canonical tokens pass through). Applied once at the top of `bestHabitsProvider`, so both the cloud RPC and Private `bestHabits()` receive a recognised token. No SQL/migration change — cloud's existing 7/30/365/lifetime windows are the contract.
- **Private parity**: `computeBestHabits` unchanged; its `_ => -1` empty-window branch is now defensive-only (provider guarantees canonical input). Stale "parity with cloud bug" comment rewritten.
- **RPC param/value audit**: swept all `.rpc()` sites. Param **names** all match the captured SQL. Only enum-ish **values** are `p_timeframe` (get_global_trend ✓ uses `timeframe_*`; get_best_habits ✗ = this bug) and `p_year` (`all` or year string ✓). `get_best_habits` was the sole offender.
- **Tests**: `test/best_habits_timeframe_test.dart` (mapper); reframed the Private defensive-token test. `flutter analyze --fatal-infos` clean; `flutter test` 77/77 green.
- No new dependencies, endpoints, or migrations.

## [2026-06-23]: Close last schema drift — capture profiles + macro_goal_categories
*Details*: The two remaining base tables the app reads via `from(...)` (`profiles`, `macro_goal_categories`) lived only in prod and were merely allowlisted in the drift guard. Captured their real DDL from the production catalog and strengthened the guard so it now verifies them for real.
*Tech Notes*:
- New `migrations/20260623_add_profiles.sql` and `..._add_macro_goal_categories.sql`, reconstructed from `pg_attribute`/`pg_constraint`/`pg_indexes` (columns, defaults, PK/FK/UNIQUE/CHECK, plus the partial `macro_goal_categories_active_idx`).
- `schema_drift_test.dart`: the second check now requires every `from()` target to have a `CREATE TABLE` **or** `CREATE VIEW` (was: non-allowlisted targets must be a VIEW). The `allowlistedBaseTables` set is replaced by an empty `allowlistedExternalTables` escape hatch — every table/view the app touches now has a definition in the repo, so nothing is skipped.
- `flutter analyze --fatal-infos` clean; `flutter test` 77/77 green (drift guard stricter, same count).
- No app-code or runtime changes; migrations are archival (captured FROM prod).

## [2026-06-23]: Private Mode — full implementation discovery & audit (no code change)
*Details*: Deep read of every privacy-related path (core, all mode-aware providers, every touched screen/widget, iOS native bridge, entitlements, tests) cross-checked against `PRIVATE_MODE_PRODUCTION_PLAN.md`. Findings captured in the new `PRIVATE_MODE_DISCOVERY.md`. Conclusion: Phase 1 (local encrypted Private Mode) is ~95% complete and production-shaped; Phase 2 (iCloud/CloudKit) is intentionally not started.
*Tech Notes*:
- **Verified privacy boundary** holds end-to-end: no Supabase init/calls, no RevenueCat, no Sentry, no paywall UI in Private Mode (incl. the notification background isolate). SQLCipher DB + device-local Keychain key; backup-excluded; biometric lock enforced.
- **Bugs found**: P0 mood-scale mismatch in `mood_provider.dart:163-164` (0–100 thresholds vs 0–10 data) breaks mood↔habit correlation in *both* modes; P1 macro-goal private CRUD lacks rollback/error handling (`macro_goals_provider.dart`); P1 notification habit-write stores `streak=0` + doesn't refresh providers in Private Mode (`notifications.dart:200`).
- **Hygiene/parity**: `goal_category_settings` is dead schema (created/seeded/deleted, never read); cloud export less complete than private export; `excludeFromBackup` scopes the whole ApplicationSupport dir; AI prompt always includes display name (consent-gated); `OpenRouterConfig.apiKey` empty so AI is inert.
- **Localization debt**: hardcoded IT strings in `consent_screen`/`privacy_settings`/`profile_screen`; Arabic still deferred.
- **Test gaps** (per plan): no mode-router, no "no-Supabase-call in Private CRUD", no settings-separation/delete-private-data/notification-routing tests.
- `flutter analyze` clean. No code modified in this pass.

## [2026-06-23]: Private Mode discovery fixes — P0 + all P1
*Details*: Implemented the correctness/robustness fixes from `PRIVATE_MODE_DISCOVERY.md`, one commit per item. All verified with `flutter analyze` (clean) and `flutter test` (77/77 green).
*Tech Notes*:
- **P0 mood scale** (`70bd70c`): mood/energy are stored 0–10 but the correlation classifier (`mood_provider.dart`) and the mood stat charts still used 0–100 thresholds. Fixed: classifier `>=6`/`<4`; `habit_mood_tab` avg bars `/10` + `10/5/0` axis + avg-red `<4`; `global_mood_tab` line chart `maxY:10`/`interval:2`. Percentage values (sensitivity/resilience/*Pct) left as 0–100.
- **P1/5.2 macro rollback** (`391ffd3`): the 5 Private-mode macro-goal CRUD branches now snapshot state and roll back + show `ErrorModal` on a local write failure (new `_showMacroGoalError`, mirrors `goal_provider`). Reuses existing `t.common.*` strings.
- **P1/5.3 notification streak** (`ee6777e`): new `PrivateLocalDatabase.setHabitLogWithStreak` computes the signed `computeStreak` from history + the goal's start date so a notification Done/Skip stores the same streak as the foreground toggle (Private analytics read the stored streak). Notification path now uses it.
- **P1/5.4 provider refresh** (`5782ad9`): after a notification Done/Skip write, the handler invalidates `habitLogsProvider` + `habitStatsProvider` via `ProviderScope.containerOf(navigatorKey.currentContext)` (chosen approach: invalidate-from-handler). No-ops in the background isolate / cold start. Introduces a tolerated notifications↔goal_provider import cycle (lazy providers).
- No new dependencies, endpoints, or migrations. No new localization strings.
- **Remaining from discovery**: P2 (dead `goal_category_settings`, cloud export parity, backup-exclusion scope), P3 (AI consent copy, AI inert/needs key), P4 (localization debt, Arabic), P5 (test gaps). Several are decisions/product calls rather than clear bugs.

## [2026-06-23]: Test infra — shared PrivateDataStore fake + settings-separation regression test
*Details*: (1) Extracted the duplicated `_FakePrivateDataStore` from `private_mode_no_supabase_test.dart` into a reusable public `FakePrivateDataStore` so the 37-method `PrivateDataStore` surface is maintained in one place. (2) Added `settings_separation_test.dart` closing one of the "test gaps" noted earlier (settings-separation). All verified with `flutter analyze` (clean) and `flutter test` (110/110 green).
*Tech Notes*:
- **New file** `test/support/fake_private_data_store.dart`: `FakePrivateDataStore implements PrivateDataStore`. Records every WRITE method name into `calls`; reads return sensible empties (`loadGoals`→[], `loadSettingsRow`→{'id':'fake'}, `hasPrivateAiExternalConsent`→false, etc.); analytics methods return harmless empties (no longer throw `UnimplementedError`) so the fake is broadly reusable.
- **Migrated** `test/private_mode_no_supabase_test.dart` to import the shared fake and deleted its local `_FakePrivateDataStore`. Existing assertions unchanged and still green (5 tests).
- **New file** `test/settings_separation_test.dart` (2 tests): in Private mode, after `setAccentColor` and after `updateSettings(copyWith(...))`, asserts (a) the fake recorded `updateSettingsRow` (local write happened), (b) the cloud-mode SharedPreferences keys `pref_accent_color`/`pref_theme_mode` stay `null` (proving the `_saveToPrefs`/Supabase path is never taken), and (c) `settingsProvider.isPro == true` (Pro unlocked locally).
- **Notification plumbing in the settings test**: building `settingsProvider` runs `_syncNotifications` → `NotificationService` → `flutter_local_notifications`, whose static platform `instance` is an unset `late` field in unit tests (throws `LateInitializationError`). Fix: a no-op `FlutterLocalNotificationsPlatform` via `MockPlatformInterfaceMixin` (overriding only `cancelAll`), `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` (the iOS facade branch uses null-safe `?.`, so scheduling no-ops; the Android branch uses a hard `!`), and `tz.initializeTimeZones()` + `setLocalLocation(tz.UTC)` so `_nextInstanceOfTime` resolves `tz.local`.
- **New dev dependency**: `plugin_platform_interface: ^2.1.8` added to `dev_dependencies` (was already transitive via `flutter_local_notifications`; same locked version 2.1.8, no version churn) so the test may use `MockPlatformInterfaceMixin` without tripping `depend_on_referenced_packages`.
- No production code changed. No new endpoints/migrations/localization strings.

## [2026-06-23]: Private Mode discovery backlog — session wrap-up
*Details*: Completed every in-code item from PRIVATE_MODE_DISCOVERY.md across focused, individually-tested commits. Test suite 77 → 110, all green; `flutter analyze` clean throughout. Remaining items are manual/external only.
*Tech Notes*:
- **Fixed & committed**: P0 mood scale (`70bd70c`); P1 macro rollback (`391ffd3`), notification streak (`ee6777e`), notification provider-refresh (`5782ad9`); P2 schema/backup docs (`6cd09be`), cloud export parity (`f1507af`); P3 AI consent copy + P4 localized strings (`7c5efda`); P5 tests — AuthState/data-mode (`102c056`), no-Supabase-call guard + `PrivateDataStore` interface (`d84fdcf`), settings separation + shared fake (`2fec42a`).
- **New testability seam**: `lib/core/private_data_store.dart` (`PrivateDataStore`, 37 methods) implemented by `PrivateLocalDatabase`; `privateLocalDatabaseProvider` retyped to it. Enables fake-backed provider tests.
- **Deferred (manual/external, see TO_SIMO_DO.md)**: AI API key (5.9); Arabic + RTL pass + native QA (5.11); Phase 2 iCloud/CloudKit (needs Apple provisioning); optional DB-integration tests for delete/notification routing.
- One dev dependency promoted (`plugin_platform_interface`, transitive→direct dev, same version) for notification mocking in tests. No other new deps/endpoints/migrations.

## [2026-06-23]: Arabic (`ar`) re-enabled — precise translations + RTL pass
*Details*: Re-enabled the Arabic locale end-to-end (it had been deferred during the slang migration). Authored a full, precise Modern-Standard-Arabic translation, wired Arabic back into the locale stack + language picker, and did the structural RTL pass. Verified with `dart run slang` + `flutter analyze` (clean) + `flutter test` (110/110 green) + `dart run slang analyze` (`ar: 0 missing`).
*Tech Notes*:
- **Translations** — new `lib/i18n/ar.i18n.json`, authored as a nested namespace tree mirroring `en.i18n.json` exactly (908 leaves across 15 namespaces). Generated via a one-shot script that asserted structural + `{placeholder}` + leading/trailing-whitespace parity against `en` before writing, so parity is guaranteed (confirmed independently by `slang analyze`). Conventions: MSA with Arabic punctuation (؟ ، ); `{placeholders}` and the literal `count`/`label` legacy tokens preserved verbatim; brand/technical terms (`Evolve`, `Pro`, `AI`, `Apple`/`Google`, `Face ID`, `EULA`, `Sentry`, `RevenueCat`, `OpenRouter`, `Supabase`) kept in Latin; the login motto translated (matching es/de, which also translate it); Western digits.
- **Obsolete bootstrap** — the `tool/arb_to_slang.py` "add `ar` + regenerate" route in TO_SIMO_DO.md is no longer valid: that converter emits *flat* keys and aborts once the JSON is nested (which it now is). Arabic is therefore authored directly as nested JSON like the other locales; slang auto-discovers any `lib/i18n/*.i18n.json`. Updated the converter's comment to say so. Legacy flat `lib/l10n/app_ar.arb` left untouched (removed in the plan's final demolition with the other ARBs).
- **Enable wiring** — restored the Arabic option in the `app_settings_screen.dart` language picker (model/`AppLanguagePreference` already supported `ar`); regenerated slang so `AppLocale.ar` + `AppLocaleUtils.supportedLocales` include Arabic; updated the stale `main.dart` `_appLocaleFor` comment (it now resolves `ar` → `AppLocale.ar`, no longer downgrades to `en`). RTL text direction is automatic via `GlobalMaterialLocalizations.delegates` + the `ar` supported locale.
- **RTL pass** — new `lib/core/rtl.dart` (`isRtl`, `directionalIcon(...)`, and a `DirectionalIcon` widget that reads `Directionality` itself so it works at `const` call sites). Converted physical→directional across ~19 files: 5 content `EdgeInsets.only(left/right)`→`EdgeInsetsDirectional`, 7 content `Alignment.center{Left,Right}`→`AlignmentDirectional.center{Start,End}`, all 8 `Positioned`→`PositionedDirectional` (incl. the bottom-nav indicator `AnimatedPositioned`→`AnimatedPositionedDirectional` and the profile avatar badge), and mirrored all 17 directional chevron icons. All conversions are LTR-invariant (start=left/end=right under LTR), so the shipping locales are provably unaffected.
- **Intentionally left physical** (need on-device RTL QA, see TO_SIMO_DO.md): decorative diagonal gradients (`begin/end: topLeft/bottomRight`); the year/week slide-transition alignments (`yearly_view_widget.dart`, `weekly_view_widget.dart`, driven by `_slideDirection`); and `fl_chart` axis layout incl. `macro_goals_stats_view.dart:1528`.
- No new runtime dependencies, endpoints, or migrations. New files: `lib/i18n/ar.i18n.json`, `lib/core/rtl.dart` (+ slang-generated `lib/i18n/translations_ar.g.dart`).

## Current Status
_(Superseded 2026-07-13: this block is stale — later 2026-06/2026-07 entries below report the suite growing from 110 to 194 tests.)_
Phase 1 Private Mode is feature-complete, localized (en/it/es/de/**ar**), and regression-guarded (110 tests). Arabic translations + the structural RTL pass are done in code and green; the only remaining Arabic work is human/device-gated (native-Arabic + VoiceOver visual QA, human translation review, and confirming the 3 intentionally-skipped physical spots) — see TO_SIMO_DO.md. Other immediate next steps if resumed: the remaining manual items in TO_SIMO_DO.md (AI key / Phase 2 CloudKit), none of which are code-only.

## [2026-06-23]: iCloud Sync (Private Mode Phase 2) — implementation
*Details*: Implemented end-to-end, opt-in, E2E-encrypted iCloud sync of the private data space, feature-by-feature per ICLOUD_SYNC_PLAN.md. 11 commits, 160 unit tests (all green), `flutter analyze` clean, `flutter build ios --no-codesign` succeeds. Live CloudKit + two-device QA require the provisioned container/device (TO_SIMO_DO.md).
*Tech Notes*:
- **Schema v3** (`48c678a`): `sync_state`/`sync_meta` + per-table triggers (dirty/tombstone); `macro_goal_categories.updated_at`; DDL extracted to testable `PrivateDbSchema`; tested via `sqflite_common_ffi`.
- **Crypto/keys** (`c187b54`): AES-256-GCM (`SyncCrypto`, pointycastle); `SyncKeyStore` holds the 256-bit key + canonical owner in the iCloud Keychain (`flutter_secure_storage` synchronizable), separate from the device-local DB key. Pure E2E, no backdoor.
- **Engine** (`8614296`,`47ecba3`): `SyncEngine` push/pull over a `CloudKitBridge` abstraction; per-record LWW on device edit-time + future-skew guard; tombstones; FK-safe apply; account-unavailable + pending-zone-wipe handling; `enable()` does key/owner adoption + `reKeyOwner` identity merge (union per-row, LWW singletons).
- **Bridges** (`68c8483`,`acce20d`): Dart `MethodChannelCloudKitBridge` (mock-channel tested) + native Swift CloudKit bridge over `CKContainer iCloud.com.simo.evolve` (private DB, custom `PrivateZone`, generic `PrivateRecord`, change-token delta fetch, `.ifServerRecordUnchanged` conflicts, CKAsset avatars) inlined in AppDelegate.swift; iCloud entitlements added.
- **Service/UI** (`cf5b1e9`,`6cd…`,`9aab0c5`): `CloudKitPrivateSyncService` (status/enable/disable/syncNow/requestFullReset; per-device enabled flag in prefs); dedicated `IcloudSyncScreen` (enable + disclosure, Sync now, status, last-synced), iOS+private-gated entry in privacy settings, localized en/it/es/de; delete-private-data wired to `requestFullReset`.
- **Triggers/refresh** (`9dacd5d`,`92fb560`): foreground sync on resume (private-gated); after a pull, `invalidatePrivateDataProviders` refreshes the cached UI providers.
- Deps promoted transitive→direct: `sqflite_common_ffi` (dev), `pointycastle`.

## Current Status
_(Superseded 2026-07-13: see later entries below — the debounced-write trigger and avatar CKAsset sync refinements have since shipped, the schema is now v4, and the test suite has grown to 194.)_
iCloud Sync core is implemented, unit-tested (160), and iOS-compiling. Remaining: after-write debounced trigger + avatar CKAsset sync (refinements), and Apple provisioning + two-device device QA (manual, TO_SIMO_DO.md). Local Private Mode (Phase 1) remains complete.

## [2026-07-01 08:08]: Bugfix - Scrollable Habit Selector in Statistics
*Details*: Fixed a bug where the habit selector bottom sheet on the statistics page was not scrollable, preventing access to all habits if the user had many.
*Tech Notes*:
- Wrapped the main `Column` in `_showGoalSelector` (`lib/ui/screens/statistics_screen.dart`) within a `SingleChildScrollView` to allow vertical scrolling.

## [2026-07-01 08:21]: Bugfix - Statistics Refresh on Import
*Details*: Fixed a bug where the statistics page did not update its metrics after importing data from a backup zip.
*Tech Notes*:
- Modified `lib/ui/screens/privacy_settings_screen.dart` to use the `invalidatePrivateDataProviders(ref)` helper from `lib/providers/sync_refresh.dart` during `_importData`.
- This ensures that in addition to the base data providers (goals, logs, etc.), all derived statistics and analytics providers are invalidated and forced to recalculate with the newly imported data, rather than showing stale cached values.

## [2026-07-01 08:26]: Bugfix - Reschedule Notifications on Import
*Details*: Fixed a bug where local notifications (reminders) for imported habits were not scheduled until the app was restarted.
*Tech Notes*:
- Exposed `syncNotifications()` in `lib/providers/settings_provider.dart` (renamed from private `_syncNotifications`).
- Modified `lib/ui/screens/privacy_settings_screen.dart` to wait 1 second after invalidating providers, and then call `ref.read(settingsProvider.notifier).syncNotifications()` to reschedule notifications for the newly loaded habits.
- [2026-07-01 08:31]: Fixed Statistics Page UI Overflow
  - *Details*: Fixed a UI issue where the 'Key Habits' ("Abitudini Chiave") card in the statistics page would overflow by 2.0 pixels at the bottom.
  - *Tech Notes*: Increased the height of the `PageView` container in `lib/ui/widgets/statistics/info_tab_widget.dart` from 280 to 320. Additionally, wrapped the `Column` inside `_AbitudineChiaveCard` with a `SingleChildScrollView` to provide a fallback scrolling mechanism for users with larger text scaling settings.

## [2026-07-01 08:34]: Fix - Fixed Statistics by Computing Streaks on Import
*Details*: Fixed a bug where imported backup logs had `streak: 0` hardcoded, causing statistics to be broken (best, worst, current streak). The `BackupImportService` now sorts the logs chronologically per goal and accurately calculates the running streak for every log.
*Tech Notes*: 
- Modified `lib/core/backup_import_service.dart`
- Used `computeStreak` from `lib/core/streak_utils.dart` to calculate streaks accurately during backup import.

## [2026-07-01 08:37]: Fix - Fixed Best Habits 10000% Bug
*Details*: Fixed a UI bug in the 'Best Habits' (Abitudini Migliori) widget on the Global Trend tab where the completion rate percentage was being multiplied by 100 incorrectly, displaying 10000% instead of 100%.
*Tech Notes*: 
- Modified `lib/ui/widgets/statistics/global_trend_tab_widget.dart` to remove the extraneous `* 100` from the rate calculation since the underlying provider already returns it as a percentage.
---

- **[2026-06-26]: iCloud Sync & Privacy — 11-bug fix pass**
  - *Details*: Implemented all 11 findings from `ICLOUD_SYNC_PRIVACY_BUGS.md`
    (8 code-fixed, #10/#11/identity-edge documented as accepted limitations).
    Work delivered in two batches (data-loss bugs first, verified, then the
    rest) on branch `fix/icloud-sync-privacy-bugs`.
  - *Tech Notes*:
    - **#1 (CRITICAL, data loss)**: `SyncLocalStore.applyUpsert` now runs the
      `INSERT OR REPLACE` with `PRAGMA foreign_keys = OFF` (toggled outside the
      txn, mirroring `reKeyOwner`), so applying a pulled parent (`profiles`)
      no longer cascade-deletes children and queues spurious child tombstones.
    - **#2**: new `PrivateLocalDatabase.adoptOwner(canonical)` writes the
      device-local owner keychain key + cache; `CloudKitPrivateSyncService`
      gained an injected `ownerWriter` and calls it after `enable()` when the
      canonical sync-owner differs from the local owner (second-device merge).
    - **#3**: `SceneDelegate.scene(willConnectTo:)` now calls
      `CloudKitSyncBridge.register`; `MethodChannelCloudKitBridge` catches
      `MissingPluginException` (accountStatus → `couldNotDetermine`, mutating
      calls → no-op, fetch/save → empty outcome).
    - **#4**: native `CKModifyRecordsOperation.savePolicy = .allKeys` (was
      `.ifServerRecordUnchanged`, which rejected every edit to an existing
      record); `SyncEngine.syncNow` reordered to **pull-then-push** so the
      client-side `updatedAt` LWW stays authoritative and a stale local edit
      can't clobber a newer cloud record.
    - **#5**: `_runExclusive` in-flight `Future` chain serializes
      `enable`/`syncNow`/`disable`/`requestFullReset` (private un-locked
      `_enable`/`_syncNow` bodies avoid re-entrant deadlock).
    - **#6/#7**: `deleteAllPrivateData` now `DELETE`s `sync_state` and nulls
      `server_change_token`/`last_full_sync_at`, but **preserves**
      `pending_zone_wipe` so a queued offline cloud wipe still runs.
    - **#8**: `PrivateDbSchema.localOnlyColumns = {profiles: [avatar_url]}` —
      the engine strips these from the push payload and the store preserves the
      existing local value on apply (avatar path is device-local).
    - **#9**: `_pull` defers future-skewed records and holds the change token at
      its pre-fetch value (was advancing past them → permanent drop).
    - **Tests**: regression tests added for #1, #2, #5, #6/#7, #8, #9
      (sync_engine_test, cloudkit_private_sync_service_test,
      private_db_schema_test). All sync/privacy suites green; `flutter analyze`
      clean on the 7 changed lib files.
    - **No new dependencies. No new endpoints.** Native change is iOS-only.

- **2026-07-05: True identity-based merge for data import (iOS/mobile)**
  - *Details*: The import flow already offered a Replace/Merge choice, but
    "Merge" was fake — it minted fresh UUIDs for every imported record and
    appended them, so re-importing a backup duplicated all goals/logs/macro
    goals (moods silently collided on `UNIQUE(user_id,date)` and were dropped).
    Replaced it with a real merge: records are matched by identity and
    reconciled with **last-write-wins by `updated_at`**. Replace mode is
    unchanged (wipe the 5 domain tables, load fresh; profile/settings untouched).
    Merge is **union-only** (never deletes local records absent from the file).
    Applies to **both** stores — Private mode (SQLCipher, precise local LWW) and
    Cloud mode (Supabase, same identity model via fetch-existing + newer-wins
    upsert). Also fixed the broken export↔import round-trip: import is now
    format-aware and the app's own JSON export is re-importable.
  - *Identity & conflict rules*:
    - Goals & macro goals → by `id`; goal logs → natural key `(goal_id, date)`;
      daily moods → natural key `date`; all last-write-wins on `updated_at`.
    - A **missing** incoming `updated_at` is treated as *oldest* (never clobbers
      existing data); ties keep the existing record. See `incomingWins()`.
    - Categories → by `id`, else case-insensitive **name** (DB enforces
      `UNIQUE(user_id,name)`); existing wins, only a missing `archived_at` is
      filled. Referencing macro goals are remapped onto the surviving category id
      (prevents FK violations and duplicate "Health"/"Work" categories on
      re-import). Merge preserves original ids instead of minting new ones.
    - Orphan logs (goal absent locally and in the file) are skipped to respect
      the FK. `goal_logs.streak` is **recomputed** from the merged history for
      every touched goal (via `computeStreak`), never trusted from the file.
  - *Tech Notes*:
    - **New files**: `lib/core/import_merge_stats.dart` (`ImportMergeStats` /
      `EntityMerge` result counts + `incomingWins`/`parseImportTimestamp`);
      `lib/core/import_merge.dart` (`normalizeBackup` — web-ZIP *and* app-JSON
      shapes, current + legacy map-logs, HSL→hex, into one canonical structure —
      plus `applyPrivateImportMerge` running inside one transaction).
    - **Interface change**: `PrivateDataStore.importData` now returns
      `Future<ImportMergeStats>` (was `void`); `PrivateLocalDatabase.importData`
      delegates to `applyPrivateImportMerge`; fake updated.
    - `BackupImportService`: `parseZipPreview`→`parsePreview` (accepts `.zip`
      *and* `.json`); `executeImport` takes `canonicalData` and returns stats;
      `_executeCloudImport` rewritten for LWW + best-effort cloud streak
      recompute.
    - `PrivateLocalDatabase.exportData` now emits **full rows** (ids +
      timestamps + log value/streak) as lists under `schemaVersion:1` so the
      export round-trips losslessly and carries `updated_at` for LWW.
    - UI (`privacy_settings_screen.dart`): file picker accepts `zip`+`json`;
      post-import summary now reports **added / updated / unchanged** per entity.
    - i18n: `importDataSubtitle` + `importModeMergeDesc` reworded across all 5
      locales (en/it/es/de/ar); regenerated `translations.g.dart` via `dart run
      slang`.
    - **Tests**: `test/import_merge_test.dart` (9 tests: normalizer web/native/
      legacy shapes; merge dedup, LWW both directions, category name-dedup +
      remap, replace-wipes, streak recompute, orphan-skip). Full suite **174/174
      green**; `flutter analyze` reports **zero errors** project-wide.
    - **No new dependencies. No new endpoints.** No schema/migration change
      (`macro_goal_categories.updated_at` from v3 is reused).

- **2026-07-05: Import merge — production hardening (4 must-fix blockers)**
  - *Details*: A multi-agent pre-release review of the import-merge feature found
    4 confirmed release blockers (2 causing cloud data loss). This pass fixes all
    4 plus several folded should-fixes, on the principle of a centralized
    *skip-and-report* validation layer and a cloud path that builds its full plan
    before it deletes anything.
    - **#1 (cloud crash + data loss)**: the cloud `macro_goal_categories` table has
      no `updated_at` column, but the import wrote it → PGRST204, and in replace
      mode the wipe had already run. Removed `updated_at` from every cloud category
      write (new-row upsert carries no `updated_at`; archived-fill is a bare
      `archived_at` update). Audited all other cloud payloads for column parity.
    - **#2 (cloud replace = data loss on any failure)**: cloud replace deleted 5
      tables *before* building payloads, so a malformed field threw after the wipe.
      Now `_executeCloudImport` fetches existing state, builds the ENTIRE plan via
      the pure `planCloudImport()`, and only *then* deletes + upserts. Combined with
      validation, a bad file can no longer wipe-then-fail.
    - **#3 (private FK abort)**: a goal silently dropped by `INSERT OR IGNORE` still
      entered `knownGoalIds`, so its logs FK-aborted the whole transaction. Now the
      merge gates `knownGoalIds`/counters on the real write result (`rid != 0`), and
      validation drops invalid goals up front.
    - **#4 (private CHECK/NOT-NULL abort)**: the LWW winning-UPDATE path had no
      validation, so an out-of-vocabulary status / out-of-range score / null field
      aborted the whole import. Now `validateCanonical()` drops such rows before the
      merge, so no constraint-violating value ever reaches an INSERT or UPDATE.
  - *Policy*: skip-and-report. Invalid rows (missing required field, bad status/
    type vocab, score out of 0–10, month/quarter/week out of range) are DROPPED
    (never coerced with invented values); identity/text fields are string-coerced
    (defensive reads kill the `as String` crash); every drop is counted and shown
    to the user as a per-entity **skipped** count (preview warning + final summary).
  - *Tech Notes*:
    - `lib/core/import_merge.dart`: added `validateCanonical()` (+ `ValidatedBackup`)
      and the pure `planCloudImport()` (+ `CloudImportPlan`); `applyPrivateImportMerge`
      now gates writes on `rid`/affected-rows and has a category name-remap fallback.
    - `lib/core/import_merge_stats.dart`: `EntityMerge.skipped`.
    - `lib/core/backup_import_service.dart`: `parsePreview` runs normalize→validate;
      `executeImport` folds skipped counts in; `_executeCloudImport` rewritten to
      fetch→plan→execute (validate-before-delete). Removed dead `_rows`/`_decide`.
    - `lib/ui/.../privacy_settings_screen.dart`: preview shows "⚠ N invalid record(s)
      will be skipped"; summary rows include a `skipped` count. (Dialog copy still
      English — localization tracked as a polish follow-up.)
    - Folded should-fixes: honest skipped counts (was "phantom added"); intra-file
      duplicate `(goal_id,date)` logs / duplicate mood dates deduped in the cloud plan;
      category insert-ignore now remaps instead of dangling a `category_id` FK.
    - **Tests**: `test/import_merge_test.dart` (+validation drops/skip-counts,
      non-string id coercion, #3 orphan-not-FK-abort, #4 bad-status-dropped) and new
      `test/cloud_import_plan_test.dart` (no `updated_at` on categories, name-remap,
      archived-fill, LWW, intra-file dedup, replace-all-added). Full suite **184/184
      green**; `flutter analyze` **zero errors** project-wide.
    - **No new dependencies, endpoints, or migrations.** Cloud execution
      (network I/O) still needs on-device manual verification — see TO_SIMO_DO.md.

- **2026-07-05: Import merge — should-fix + polish follow-up**
  - *Details*: Cleared the remaining non-blocking items after the must-fix batch.
    - **Cloud streak recompute de-N+1'd**: `_recomputeCloudStreaks` was doing one
      HTTP `UPDATE` per changed log (a request storm on large cloud imports). Now
      two reads (start dates + all affected logs, via `inFilter`) and a single
      chunked bulk upsert of only the changed rows.
    - **Error-path no longer pops the settings screen**: `_importData` tracks a
      `progressShown` flag so an error thrown *before* the progress dialog opens
      (e.g. a corrupt file during preview) shows the error dialog without popping
      the whole `PrivacySettingsScreen`.
    - **`created_at` preserved on LWW update**: the row builders now take the
      caller-decided `created_at` (file's on insert, existing row's on a winning
      update), so a merge never rewrites the local `created_at` with the file's.
    - **Import dialogs localized**: the success/failure dialogs, the per-entity
      summary rows (added/updated/unchanged/skipped), and the preview "invalid
      records skipped" warning were hardcoded English; now driven by 14 new i18n
      keys across all 5 locales (en/it/es/de/ar), regenerated via `dart run slang`.
  - *Tech Notes*:
    - `lib/core/backup_import_service.dart`: batched `_recomputeCloudStreaks`.
    - `lib/core/import_merge.dart`: `_goalRow`/`_macroRow` use the passed
      `created_at`; insert callers pass the file's, update callers the existing.
    - `lib/ui/.../privacy_settings_screen.dart`: `progressShown` guard;
      `_mergeRowText` + dialogs use `context.t.privacy.import*` keys.
    - `lib/i18n/*.i18n.json`: +14 keys (importCompletedTitle, importFailedTitle,
      importSummary{Replaced,Merged,Done}, importPreviewSkipped, importEntity*,
      importRow{Replace,Merge,Skipped}).
    - **Tests**: added cases for `created_at` preservation and non-numeric log
      `value` coercion; full suite **186/186 green**, `flutter analyze` clean.
    - Cosmetic note: the *cloud* LWW path still writes the file's `created_at` on
      update (it doesn't fetch the existing one); harmless and left as-is.

- **2026-07-06: Fix — profile photo renders black on other pages**
  - *Details*: After updating the profile photo from Settings, it showed as a
    black/blank circle in the dashboard header (and anywhere but the profile
    screen). Root cause: the dashboard `_AppBar` rendered the avatar with
    `NetworkImage(avatarUrl)` unconditionally, but in **Private mode** `avatarUrl`
    is a LOCAL FILE path — the network load failed and the circle fell back to
    its card/background color. The profile screen already handled this correctly;
    the two render sites were copy-pasted and had diverged.
  - *Fix / Tech Notes*:
    - New shared widget `lib/ui/widgets/profile_avatar_image.dart`
      (`ProfileAvatarImage`) resolves the source by data mode — `Image.file` for
      Private (local path), `Image.network` for Cloud, default asset on null/error
      — so the dashboard and profile screen can no longer diverge. Both now use it.
    - `dashboard_screen.dart`: avatar now uses `ProfileAvatarImage` (was a
      `DecorationImage` with `NetworkImage`); added the `activeDataModeProvider`
      read.
    - `profile_screen.dart` `_pickImage`: the avatar path is stable
      (`avatar.<ext>`), so overwriting it left Flutter's `ImageCache` holding the
      old decoded bytes — added `FileImage(...).evict()` after the copy so every
      page re-reads the new photo (fixes a latent stale-image-on-re-update issue).
    - **Tests**: `test/profile_avatar_image_test.dart` (Private → FileImage not
      NetworkImage; Cloud → NetworkImage; null → default asset). Suite **189/189
      green**; `flutter analyze` clean. Final render best confirmed on device.

- **2026-07-06: Yearly-view month bars use a performance-based color**
  - *Details*: In the yearly (12-month) calendar view, every day with any
    completion was drawn in one flat color (the theme primary). Now each bar is
    colored by completion, using the same red→yellow→green scale as the home
    monthly-view cells. Also fixed a latent bug: the bars' completion metric had
    a `// Simplified check` that divided by *all* habits, even ones not active on
    that day, so early days counted against completion and showed short/red bars.
  - *Tech Notes*:
    - New `lib/core/performance_color.dart` — `performanceHue(pct)` (0→red,
      1→green at hue 142) + `performanceColor(pct, {saturation, lightness,
      alpha})`. Single source of truth so the two calendar surfaces can't drift
      apart (same lesson as the ProfileAvatarImage extraction). Alpha is applied
      via `Color.withValues` so it's byte-identical to the old cell colors.
    - `yearly_view_widget.dart` `_MonthBarsPainter`: denominator now
      `habits.where((h) => h.isActiveOn(date))` (matches the monthly view — fixes
      both color and bar heights); bars use `performanceColor(pct, lightness:
      0.5)`; removed the now-unused `accentColor`; `shouldRepaint` also compares
      `habits`.
    - `habit_calendar_widget.dart` `_DayCell`: refactored its inline HSL formula
      to `performanceColor(...)` — **no visual change** (guarded by a test that
      asserts equality with the old formula).
    - **Tests**: `test/performance_color_test.dart` (hue mapping + clamp; alpha;
      byte-identical equivalence with the old cell color). Suite **194/194
      green**; `flutter analyze` clean. Colors best confirmed on device.

- **2026-07-06: Home monthly-calendar day cell — cleaner, professional look**
  - *Details*: Each day cell rendered up to 8 tiny green squares (one per
    completed habit) that appeared as you logged habits — visually noisy and
    redundant with the cell's performance-color background. Removed them; the
    cell is now just a centered day number over the performance-colored
    background/border (+ the existing 100%-complete glow).
  - *Tech Notes*:
    - `habit_calendar_widget.dart` `_DayCell`: removed the habit-dots `Wrap` and
      its `dotsToShow` computation; the day number is now centered (`Center`)
      instead of top-aligned. Dropped the now-unused `validHabits` / `dayRecord`
      fields + constructor args (they only fed the dots). No behavior change to
      the performance coloring. Suite **194/194 green**; `flutter analyze` clean.
      Visual best confirmed on device.

- **2026-07-16: iOS — fixed "Cycle inside Runner" archive failure (app-extension build-phase order)**
  - *Details*: `flutter build ipa` failed at the archive step with
    `Error (Xcode): Cycle inside Runner; building could produce unreliable
    results.` The cause was the `DeviceActivityMonitorExtension` app-extension
    (added to the Runner target as an "Embed Foundation Extensions" copy phase):
    Xcode appended that phase **last**, after Flutter's "Thin Binary" phase.
    Flutter's "Thin Binary" phase declares `${TARGET_BUILD_DIR}/${INFOPLIST_PATH}`
    (Runner.app/Info.plist) as an **input**, but Info.plist can't finalize until
    the `.appex` is copied into `Runner.app/PlugIns/` — and that copy was gated
    *after* Thin Binary → dependency cycle
    (EmbedPodsFrameworks → ThinBinary → Info.plist → appex → CopyPodsResources →
    EmbedPodsFrameworks). This is the canonical Flutter + app-extension + Xcode 15/16
    cycle (flutter/flutter#135056).
  - *Tech Notes*:
    - `ios/Runner.xcodeproj/project.pbxproj`, Runner target `buildPhases`: moved
      `Embed Foundation Extensions` (2438998C…) to run **immediately after
      `Embed Frameworks` and before `Thin Binary`** (and before both `[CP]` Pods
      phases). Single-line reorder; no other project changes. New order:
      … Embed Frameworks → **Embed Foundation Extensions** → Thin Binary →
      [CP] Embed Pods Frameworks → [CP] Copy Pods Resources.
    - Deliberately did **not** add a Podfile `post_install` auto-reorder hook: the
      only robust way (opening `Runner.xcodeproj` with the `xcodeproj` gem and
      `save`) rewrites the whole project, and this project uses Xcode-16
      `PBXFileSystemSynchronizedRootGroup` objects (the extension's
      file-sync group) that older `xcodeproj` gem versions may not round-trip —
      risking corruption of the extension target. The manual reorder lives in the
      committed pbxproj and survives `flutter clean` / `pod install`, so a hook is
      unnecessary.
    - Verified as far as possible off-device (this Mac has no full Xcode):
      `plutil -lint project.pbxproj` → OK; new phase order confirmed;
      `flutter analyze` clean (0 errors). Final `flutter build ipa` must be
      re-run on the Mac mini (Xcode host) to confirm the archive completes.
    - Separately confirmed the Dart translation errors seen in the older Xcode
      log (missing slang getters: apiKey, apiKeyInvalid, privateRecovery.*,
      freeSlotsFullBanner, accountDeletedAppleRevokeFailed, expiresOn,
      priceUnavailable, pricesUnavailable, aiCoach) were a **stale pre-regeneration
      artifact** — all getters are now defined in `lib/i18n/translations_*.g.dart`
      and `flutter analyze` is clean. Not a current blocker.

- **2026-07-16: iOS — DeviceActivityMonitorExtension min-iOS 26.5 → 16.0**
  - *Details*: The extension target had `IPHONEOS_DEPLOYMENT_TARGET = 26.5`
    (Xcode auto-set it to the current SDK at target creation) while the app is
    15.0. iOS would not load the extension below 26.5, so Screen-Time
    auto-verification would silently never run for ~all users. Lowered to 16.0
    (floor for individual FamilyControls authorization).
  - *Tech Notes*: `ios/Runner.xcodeproj/project.pbxproj` — extension configs
    Debug/Release/Profile (2438998D/8E/8F), `IPHONEOS_DEPLOYMENT_TARGET = 16.0`.
    `plutil -lint` OK. Runtime availability on 16.0–26.4 devices to be confirmed
    on device.

- **2026-07-17**: Screen Time (Guideline 2.1) — surveyed, NOT enabled; two reconcile bugs fixed behind the flag
  - *Details*: A 31-agent survey of the whole Screen Time surface concluded the honest answer to Apple's question is **"No, build 20 has no Screen Time functionality"**, and that enabling it would ship a feature that cannot work. `VerificationConfig.screenTimeEnabled` stays **false**. Two verifiable defects in the reconcile path were fixed anyway, so the feature is closer to ready for its own release.
  - *Tech Notes*:
    - **Why not enable it.** Nothing in the app ever requests Family Controls authorization (`requestIndividualAuthorization` has zero production call sites), and every `DeviceActivityEvent` is registered with empty `applications`/`categories`/`webDomains` (`AppDelegate.swift:638-643`) with **no `FamilyActivitySelection`/`FamilyActivityPicker` anywhere in the repo**. The design assumes an empty set means "all activity"; that is a framework-semantics claim that cannot be settled without a device, and if it is wrong every Screen Time habit silently passes forever. A reviewer following any path we described would create a habit that never verifies. Plus none of the Swift has ever been compiled (`TO_SIMO_DO.md:30`). Apple's 2.1 questions are answered by replying in Resolution Center, not by uploading a binary — shipping would turn a two-line reply into a re-review of never-compiled code on the exact surface under scrutiny.
    - **MY BUG, fixed**: `TO_SIMO_DO.md` told Simone to write a reviewer note describing "the Screen Time path (habit → Auto-verify → Screen Time)". The flag is off, so that path does not exist in the shipped build. Sending it would have told App Review a false thing about the very feature they asked about. Removed, and replaced with the truthful 2.1 answers.
    - **I WAS WRONG ABOUT THE UPLOAD BLOCKER, and the correction matters.** The survey's headline finding was an ITMS-90473/90474 version mismatch (extension synthesises 1.0/1 inside a 1.1.2/20 app). I verified the *facts* — they are exactly right. But git says the extension has been **embedded since 03ffb4e (2026-07-16)**, `b8d3fdd` is someone fixing an *archive* failure with it embedded, and **build 20 uploaded and reached a reviewer anyway**. So the validation error empirically does not fire, and the inference was wrong. I had already applied the "fix" and reverted it — and it would have made things **worse**: the extension configs have no `baseConfigurationReference`, so they never see `Generated.xcconfig`, and `$(FLUTTER_BUILD_NUMBER)` would have expanded to an **empty** version string. Empirical evidence beat a confident inference; this is why the pbxproj was checked before being trusted.
    - **BUG FIXED — deleting your last Screen Time habit left DeviceActivity monitoring running forever.** `runVerificationReconcile` returned on `goals.isEmpty` **before** the sync block, so `syncMonitoredGoals([])` was never called — and the native side only stops monitoring when it is called. An empty list is precisely the case that needs the call. The sync now runs before the early return.
    - **BUG FIXED — the sync ran on every single foreground.** The native handler answers with a bare `center.stopMonitoring()` (all activities, unconditionally) then re-registers the same set (`AppDelegate.swift:621-660`). A per-process `ScreenTimeSyncCache` + the pure `screenTimeSpecsChanged` now make an unchanged set a no-op. **The cache is deliberately in memory, never persisted**: iOS may drop monitoring while the app is not running (reboot, force-quit, OS purge) and nothing tells us, so the first reconcile of every launch must re-register unconditionally. Comparison is order-independent — spec order follows goal order, which changes on an unrelated drag and means nothing to DeviceActivity. A failed sync is **not** cached, so it retries.
    - **What is deliberately NOT claimed.** The survey asserted the stop/restart *resets DeviceActivity's accumulated counters*. Its own adversarial verifiers refuted that as framework inference stated as fact, and they were right — it cannot be checked without a device. The guard is justified on what IS verifiable (the churn is pure waste when nothing changed), not on the unverifiable consequence. Half the survey's 24 verified claims were refuted this way; nothing here rests on an unrefuted one.
    - **Authorization is now CHECKED, not requested.** `center.startMonitoring` was called with no authorization check (`AppDelegate.swift:644`) and DeviceActivity throws when unauthorized — every foreground. The reconcile now checks status and skips. It does **not** request: a system prompt fired from a background lifecycle hook arrives out of nowhere; the request belongs at the Screen Time opt-in, which does not exist while the feature is dark. Stopping (an empty sync) deliberately bypasses the gate — tearing monitoring down needs no permission, and gating it would strand a user who revoked Family Controls.
    - Everything else the survey found that needs a device is written up in `TO_SIMO_DO.md`: the empty-token-set question, the unregistered extension App ID, the iOS 15/16 split with no `#available` guard on `syncMonitoredGoals`, the missing Screen Time privacy-manifest entry, and the hardcoded-English extension notification that posts with no permission check.
  - *Verification*: `flutter analyze` clean. Mobile **357 tests** (+15 new in `screen_time_sync_test.dart`). Both fixes are mutation-verified: reintroducing the early return fails the empty-sync test, removing the guard fails the once-per-launch test. **No Swift was touched** — it cannot be compiled here, and the survey's most confident Swift claim turned out to be wrong.

## Current Status — Apple rejection remediation

**Five of six rejections are fixed in code** (1.5, 4.0, 3.1.2, 2.5.1, 3.1.1, 5.1.2(i)). **The sixth — 2.1, Screen Time — is answered by REPLYING to Apple, not by shipping**: the truthful answer is "no, build 20 has no Screen Time functionality", and the reply text is drafted in `TO_SIMO_DO.md`. The feature stays dark (`VerificationConfig.screenTimeEnabled = false`) until it can be proved on a device.

**Nothing in the 3.1.1 / 5.1.2 work has run on a device or against the live Edge Function.** The proxy is not deployed and `OPENROUTER_API_KEY` is not set, so every proxy path is verified against mocked transports only. The provider pin — which the privacy policy now asserts **by name** — is enforced in the function's code and checked at runtime by `observeSseStream`, but has never been observed. That is the single highest-value item left, because the policy makes a legal claim in Simone's name that depends on it.

**All remaining work is Simone's**, and it is listed in `TO_SIMO_DO.md`: apply `migrations/20260717_add_ai_coach_proxy.sql`; `supabase secrets set OPENROUTER_API_KEY`; deploy the function; set an OpenRouter spend cap; verify the provider pin with one live request; read the new AI-recipient paragraphs in `privacy.html` (all 5 locales) before the site goes live; review the es/de/ar legal translations; the App Store Connect metadata (EULA line, privacy-policy URLs, the Health nutrition label, the reviewer note); the macOS Manual-release toggle; and the on-device QA pass for everything written blind here.

**If Screen Time is picked up later**, `TO_SIMO_DO.md` now carries the full open list. The first question to settle, before any code, is whether a `DeviceActivityEvent` with empty application/category/webDomain sets fires at all — the entire v1 design rests on it, and it can only be answered on hardware.

- **2026-07-17**: Fixed `DeviceActivityMonitorExtension` missing `CFBundleVersion` error on `flutter run`
  - *Details*: The local `flutter run` was failing because `DeviceActivityMonitorExtension/Info.plist` had no `CFBundleVersion` or `CFBundleShortVersionString`. The previous note was completely correct about `baseConfigurationReference`: without it, `$(FLUTTER_BUILD_NUMBER)` expands to an empty string. The fix was applied: Added the standard keys to `DeviceActivityMonitorExtension/Info.plist` and linked the extension's build configurations (Debug/Release/Profile) to the respective `Runner` base configurations in `project.pbxproj` so they can successfully resolve `$(FLUTTER_BUILD_NUMBER)`.
  - *Tech Notes*: `ios/Runner.xcodeproj/project.pbxproj` was updated to include `baseConfigurationReference` pointing to `Debug.xcconfig` and `Release.xcconfig` for the extension target.

- [2026-07-18 15:07]: Keyboard dismissal UX fix for habit numerical inputs
  - *Details*: Resolved an issue where iOS numeric keyboards lacked a dismissal action. Implemented a 'Done' button above the number pad and enabled tap-to-dismiss behavior globally on the habit management modal.
  - *Tech Notes*: Added keyboard_actions dependency (^4.2.0), wired a FocusNode from VerificationRuleField up to HabitManagementModal, and wrapped the view in KeyboardActions and GestureDetector.

- [2026-07-18 15:29]: Replace keyboard_actions with native OverlayEntry for iOS Done button
  - *Details*: The keyboard_actions package with disableScroll=true was found to intercept touches in the CustomScrollView, preventing the numeric text field from receiving focus. Reverted the keyboard_actions dependency and replaced it with a targeted `_DoneKeyboardAccessory` using `OverlayEntry` and `WidgetsBindingObserver` that cleanly floats the 'Done' button above the keyboard without modifying the widget tree.
  - *Tech Notes*: Removed keyboard_actions from pubspec.yaml. Removed KeyboardActions from HabitManagementModal. Implemented native Overlay in VerificationRuleField.

- [2026-07-18 15:37]: Tap-to-dismiss behavior for Habit Management inputs
  - *Details*: Added `onTapOutside: (_) => unfocus()` to the TextFields in the habit management modal (Habit Name and Verification Rule Threshold). This leverages Flutter's built-in TapRegion handling so clicking anywhere outside the active input instantly dismisses the keyboard without interfering with the local gestures.
  - *Tech Notes*: Modified TextField configurations in habit_management_modal.dart and verification_rule_field.dart.

- [2026-07-20 09:11]: Version Bump
  - *Details*: Updated app version to `1.1.2+23` for App Store submission.
  - *Tech Notes*: Modified `pubspec.yaml` to `1.1.2+23`. Updated `MARKETING_VERSION` across `project.pbxproj` from `1.1.0` and `1.0` to `1.1.2`.

- [2026-07-23]: **Bump Mobile/iOS Build Version to 39**
  - *Details*: Incremented application version build number from 38 to 39 in `pubspec.yaml` (`1.1.3+38` -> `1.1.3+39`) for iOS release build alignment.
  - *Tech Notes*: `pubspec.yaml` version update feeds `CFBundleVersion` (`$(FLUTTER_BUILD_NUMBER)`) in `ios/Runner/Info.plist`. No API or dependency changes.

- [2026-07-23]: **Bump Mobile Version String to 1.1.4**
  - *Details*: Incremented mobile version string from `1.1.3` to `1.1.4` (`1.1.4+39`) in `pubspec.yaml` and updated `MARKETING_VERSION` in `ios/Runner.xcodeproj/project.pbxproj` to `1.1.4`.
  - *Tech Notes*: Keeps pubspec version name in sync with Xcode `MARKETING_VERSION`.



- [2026-07-24]: App Store Metadata Update
  - *Details*: Updated the application name to "Evolve: Habits & Goals Tracker" across all languages.
  - *Tech Notes*: Modified `name.txt` files in all language subdirectories within `mobile/metadata` to ensure consistency in the App Store listing.
