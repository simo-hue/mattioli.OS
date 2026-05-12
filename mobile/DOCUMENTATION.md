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
  - Improved axis labels with better padding and font weights.
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
- **UI**: Replaced `showTimePicker` with `showCupertinoModalPopup` and `CupertinoDatePicker` in `habit_management_modal.dart`.
- **Format**: Forced 24h format in the Cupertino picker.
