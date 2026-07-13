# Project Documentation

## Recent Changes

- [2026-07-13]: **Active vs All Habits Filter**
  - *Details*: Added a persistent, local-only filter to the global statistics "Abitudini" tab, allowing users to switch between viewing only active habits or all habits (including removed/past ones).
  - *Tech Notes*:
    - Added `statsHabitFilter` to `AppSettings` in `settings_provider.dart`, saving to SharedPreferences but excluded from Supabase sync to avoid DB migration.
    - Updated `GlobalHabitsTabWidget` with a new `_buildFilterDropdown` UI element using `showEvolveSheet` next to the sorting dropdown.
    - Filter logic checks `goal.isActiveOn(DateTime.now())`.
    - Added `filterActive` and `filterAll` translation keys across all languages and generated `.g.dart` files using slang.

- [2026-07-11]: **Apple-Style UI — Phase 2: kit expansion + app-wide migration (mobile, in progress)**
  - *Details*: Audited the whole mobile app (4 parallel read-only agents) → ~40 un-Apple surfaces that collapse into ~6 missing primitives. Built the primitive layer and migrated ~50 surfaces across 7 categories, primitive-first for full cross-platform coherence. Every batch verified: `flutter analyze` stays at 16 pre-existing issues (down from baseline 18; zero new), `flutter test` = 144 green. Visual QA is owner's. Full roadmap + resume state at `mobile/docs/apple-style-phase2-plan.md`.
  - *Tech Notes*:
    - New primitives in `lib/ui/kit/`: `evolve_dialog.dart` (`showEvolveConfirm`/`showEvolveAlert` over `CupertinoAlertDialog`, app-brightness-aware, rich `content:` slot), `evolve_button.dart` (`EvolveButton` — filled/tinted/secondary/destructive/plain, luminance-contrast text, `haptic` param), `evolve_switch.dart` (`EvolveSwitch`/`EvolveSwitchRow` — CupertinoSwitch + gated haptic), `evolve_segmented_control.dart` (`EvolveSegmentedControl<T>`, equal-width), `evolve_section_header.dart` (13px muted, no forced uppercase), `evolve_toast.dart` (`showEvolveToast` — root-overlay fading banner). Barrel `evolve_kit.dart`.
    - Migrations: ~13 confirm/alert dialogs → showEvolveConfirm/Alert; 5 segmented pills → EvolveSegmentedControl; ~8 CTAs → EvolveButton; 4 settings switches → EvolveSwitch; section headers → EvolveSectionHeader (settings ×4 + the phase-1-deferred habit-modal field labels); 20 SnackBars → showEvolveToast; 5 selection sheets → showEvolveSheet (Pro-lock preserved).
    - Correctness fixes en route: ~10 ungated `HapticFeedback.*` → gated `ref.haptic*`; dead `dart:ui`/`services` imports removed; hardcoded English `'Close'` localized.
    - Deliberately preserved bespoke/brand: subscription success + `subscription_alert_modal` (hero/gradient), habit-modal gold Pro-upgrade CTA, dashboard onboarding CTAs, one-time tutorial coach-marks, consent legal-terms checkbox, `bottom_nav_bar`/chart CustomPaint.
    - Post-QA continuation (owner confirmed primitives clean): goal_item editor + ai-settings dialog → form sheets; accent-picker + 5 modal sheet chromes → EvolveGrabber; privacy delete/reset → showEvolveSheet; EvolveSpinner (paywall); `GoogleFonts.outfit`→inter; default-view trailing `.toUpperCase()` removed; 16/18 ungated haptics gated; day_details 22 static `AppColors`→`context.appColors` + `Icons.close`→Lucide. Final: `flutter analyze` = 16 (all pre-existing), `flutter test` = 144 green.
    - Test fix: `test/icloud_sync_screen_test.dart` `find.byType(Switch)`→`find.byType(CupertinoSwitch)` (matches the intentional T11 Material→Cupertino toggle migration). It went unnoticed because earlier gates piped `flutter test | tail` (masking the runner's exit code) — corrected to read the runner's own verdict.
    - Deferred as optional polish (owner happy with current UI): T15 settings-card grouped-inset restructure; privacy change-password editor; Cupertino time/date/detail pickers' nav-header chrome; 2 non-Consumer ungated haptics (protocollo tile, category editor) needing a widget-class refactor.

- [2026-07-11]: **Apple-Style UI Kit — implemented (mobile)**
  - *Details*: Built the shared `lib/ui/kit/` and migrated the three named surfaces to it so they read as native iOS: the "Select Habit" sheet (statistics), the "Choose category" sheet + its editor + delete confirm (goals), and every colour picker (habit, category, accent). Cross-platform (no `Platform.isIOS` gating), built on the existing `context.appColors`. Verified: `flutter analyze` clean (no new issues) and full suite green (144 tests). Visual QA is owner's.
  - *Tech Notes*:
    - New `lib/ui/kit/evolve_sheet.dart`: `showEvolveSheet` (draggable selection sheet, grabber + 17pt centred title + detents 0.6→0.92), `showEvolveFormSheet` (keyboard-aware editor with Cancel/title/Done nav header), `EvolveListSection` (grouped-inset rounded card + hairline separators), `EvolveListRow` (ConsumerWidget → gated `hapticSelection`; accent `CupertinoIcons.check_mark` / chevron), `EvolveIconTile`, `EvolveColorDotTile`, `EvolveTextAction`.
    - New `lib/ui/kit/evolve_color_picker.dart`: `kEvolveDefaultPalette` (desktop's 6 colours), `EvolveColorSwatchGrid` (swatch circles + luminance-aware contrast + "Custom" cell; hooks `isLocked`/`onLockedTap`/`onCustomTap`/`customLocked` for the accent Pro-gate), `showEvolveColorPicker(context, initial)→Future<Color?>` (restyled `flutter_colorpicker` in a form sheet).
    - `statistics_screen.dart`: `_showGoalSelector` → `showEvolveSheet` (All-habits row + Pro-lock flow + selected highlight preserved).
    - `category_picker_sheet.dart`: rewritten — sheet → kit; editor `Dialog` → `showEvolveFormSheet`; delete `AlertDialog` → `CupertinoAlertDialog` (destructive). Post-dispose-safe notifier capture preserved.
    - `habit_management_modal.dart`: colour `Wrap` + Cupertino popup → `EvolveColorSwatchGrid`; removed local `_presetColors`/`_showColorPicker` + `flutter_colorpicker` import.
    - `app_settings_screen.dart`: accent presets → `EvolveColorSwatchGrid` with `premiumAccentColors` + `customLocked: !isPro` + `onCustomTap`; the `_showValidationDialog`/too-dark `SlidePicker` flow and light-mode white→dark remap kept intact.
    - Palette unification side effect: habit/category colours now default to the shared 6; any previously-saved off-palette colour still displays (rendered in the "Custom" cell), no data loss.
    - Deliberately out of scope (surgical): the habit modal's own `COLOR`/`REMINDER` micro-labels and the accent sheet's title/handle chrome were left as-is — only the colour control inside them was migrated.

- [2026-07-11]: **Apple-Style UI Kit — design spec finalized (mobile)**
  - *Details*: Agreed (via grill-me session) the full design/scope for making three mobile surfaces feel authentically Apple — "Select Habit" (statistics), the "Choose category" selector (goals), and every color picker — through one shared reusable kit. No code yet; this logs the finalized architectural decision. Full spec at `mobile/docs/apple-style-kit-spec.md`.
  - *Tech Notes*:
    - New `lib/ui/kit/` (Cupertino-look on Material scaffolding, cross-platform, NOT `Platform.isIOS`-gated). `Evolve`-prefixed API mirroring desktop: `showEvolveSheet` / `showEvolveEditorSheet`, `EvolveListSection`, `EvolveListRow`, `EvolveColorSwatchGrid`, `showEvolveColorPicker`.
    - Sheet anatomy: grabber, bold 17pt centered title (kills the 10px uppercase label), solid `appColors.card`, `DraggableScrollableSheet` detents 0.6→0.92, grouped-inset rounded rows.
    - Color control: swatch-grid + "Custom" hatch; unified 6-color palette mirroring desktop (`kEvolveDefaultPalette`); accent site keeps premium Pro-gated palette via a per-cell locking hook; `flutter_colorpicker` retained but restyled.
    - Type/interaction: keep Inter (iOS scale), surgical `CupertinoIcons` checkmark+chevron, gated `Haptics.selectionClick`/`mediumImpact`, accent-tinted selection.
    - Blast radius: `statistics_screen.dart`, `macro_goals/category_picker_sheet.dart` (incl. editor→sheet, delete→`CupertinoAlertDialog`), `habit_management_modal.dart`, `app_settings_screen.dart`. Non-goals: no theme rename, no migration of the other ~12 sheets, no new deps.

- [2026-07-04 14:45]: **Desktop Goals Interactive Tutorial Porting**
  - *Details*: Ported the interactive interactive tutorial for the Macro Goals page (`GoalsPage`) from the Mobile implementation to the Desktop application, ensuring 100% coherence between platforms.
  - *Tech Notes*:
    - Implemented `tutorial_provider.dart` to manage state based on desktop context.
    - Updated `_GoalsPageState` with GlobalKeys for target UI elements (`_planSelectorKey`, `_performanceToggleKey`, `_addGoalKey`, etc.).
    - Ported `_GoalsTutorialScrimPainter` and `_GoalsTutorialStep` for the visual overlay and cutout.
    - Added a "fake tutorial goal" in case the user has no active goals, so the action buttons can be highlighted properly during the tutorial.


- [2026-06-30 22:21]: **App Version Increment**
  - *Details*: Incremented the app version from `1.0.5+9` to `1.0.6+10` in `pubspec.yaml` in preparation for the App Store release.
  - *Tech Notes*: Only `pubspec.yaml` was modified as iOS picks up the `FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER` automatically.

- [2026-06-30 20:13]: **Mattioli.OS Web Backup Import Feature**
  - *Details*: Implemented a feature allowing users to import their web backup ZIP files directly into the iOS mobile app. The data accurately maps web formats (goals, long term goals, categories, and moods) into the mobile SQLite or Supabase database and handles edge cases like color transformations.
  - *Tech Notes*:
    - Added `BackupImportService` in `lib/core/backup_import_service.dart` to parse ZIP contents using the `archive` package and apply HSL to Hex color conversion.
    - Updated `PrivateLocalDatabase` and `PrivateDataStore` to implement `importData` method with `db.transaction`.
    - Added a comprehensive preview dialog in `PrivacySettingsScreen` providing the user with Replace or Merge conflict options.
    - Added `file_picker` to enable native iOS file selection.
    - Updated UI Strings across 5 languages inside `lib/i18n/*.i18n.json` using `slang`.

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

- [2026-05-18 22:35]: **RevenueCat Configuration Completions (FASE 3)**
  - *Details*: Fully completed and verified FASE 3 of the resubmission plan. The user successfully uploaded the StoreKit 2 API Key (.p8 file), Key ID, Issuer ID, and the App-Specific Shared Secret to the RevenueCat iOS App dashboard. Checked off all FASE 3 items in `RESUBMISSION_PLAN.md`.
  - *Tech Notes*:
    - Confirmed that Evolve's App Store entitlements (`Evolve Pro`) map 100% correctly with the Flutter code's dynamic entitlement checks.
    - Verified all configurations are live and active.

- [2026-05-18 22:40]: **Removed CONVENIENTE Badge & Fixed Plan Text Truncation**
  - *Details*: Completely removed the 'CONVENIENTE' badge from both the active and fallback yearly subscription cards. This ensures that the full name of the subscription plan ("Evolve Pro Annuale") is fully displayed on all devices without any truncation or ellipsis, resulting in a cleaner and more professional UI.
  - *Tech Notes*:
    - Removed the conditional `isBestValue` Container check in [subscription_screen.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/ui/screens/subscription_screen.dart) at line 581 and line 1142.
    - Verified compilation with `flutter analyze` returning 0 errors/warnings.

- [2026-05-18 22:50]: **Obfuscated Production Release Build Compiled (FASE 4)**
  - *Details*: The production IPA release build was successfully generated in Flutter. The command cleaned the workspace, loaded all required packages, archived the iOS runner project with automatic developer signing (team key `8528AN28A3`), and built the final obfuscated `.ipa` binary for App Store Connect distribution, located at `build/ios/ipa/Runner.ipa`.
  - *Tech Notes*:
    - Build details: Version `1.0.0`, Build `1`, Deployment target `13.0`.
    - Obfuscation applied: `--obfuscate --split-debug-info=build/app/outputs/symbols` to protect against reverse engineering.

- [2026-05-18 22:55]: **App Privacy Configuration Completed (FASE 5)**
  - *Details*: Configured and published all App Privacy settings on App Store Connect. Standardized declarations to indicate that the application collects Contact Info (Name, Email) and Diagnostics/Other Data for functional app purposes only, with zero third-party tracking.
  - *Tech Notes*:
    - Fully resolved the App Tracking Transparency (ATT) rejection. Since the app performs zero tracking, the ATT popups are completely omitted.
    - Marked FASE 4 and FASE 5 as fully completed in `RESUBMISSION_PLAN.md`.

- [2026-05-20 13:30]: **Web Companion Rebranding Reversion to Mattioli.OS**
  - *Details*: Reverted companion web application's visual branding from "Evolve" / "EVOLVE" back to "Mattioli.OS" per request, restoring all SEO metadata, footer widgets, page references, and support emails to the original brand name.
  - *Tech Notes*:
    - Updated `index.html` titles, SEO metadata tags, and canonical links.
    - Updated `PublicHeader.tsx` and `Auth.tsx` to display "Mattioli.OS" in standard mixed-casing (removed `uppercase` Tailwind styles for brand consistency).
    - Updated `PublicFooter.tsx` and all page components (`LandingPage.tsx`, `PhilosophyPage.tsx`, `TechPage.tsx`, `FAQ.tsx`, `CreatorPage.tsx`, `GetStartedPage.tsx`, `Index.tsx`) to reference "Mattioli.OS" and support URLs.
    - Updated legal policies (`PrivacyPolicy.tsx` and `TermsOfService.tsx`) to restore the original brand name and support email (`support@mattioli.os`).
    - Verified compilation and layout safety using typescript typecheck `npx tsc --noEmit` with 0 compile errors.

- [2026-05-20 13:35]: **Landing Page Navigation Update**
  - *Details*: Removed the external App Store link "Download Mattioli.OS for iOS" on the hero section of the landing page and replaced it with a dynamic, internal link to the Philosophy page to keep visitors engaged with the core concept of the platform.
  - *Tech Notes*:
    - Replaced `<a>` element containing the App Store reference in `LandingPage.tsx` with a `<Link>` component pointing to `/philosophy`.
    - Added an elegant inline `ArrowRight` icon styled with the theme's signature purple glow.
    - Verified compilation and layout safety using typescript typecheck `npx tsc --noEmit` with 0 compile errors.

- [2026-05-20 13:38]: **Primary Landing Page CTA Update**
  - *Details*: Replaced the "Access Web Companion" primary CTA button with a highly-engaging "Get Started Now" button linking to the step-by-step self-hosting installation guide, optimizing the landing page funnel for open-source self-mastery adopters.
  - *Tech Notes*:
    - Updated the `<Link>` path from `/auth` to `/get-started` in `LandingPage.tsx`.
    - Renamed CTA button text to "Get Started Now".
    - Verified compilation and layout safety using typescript typecheck `npx tsc --noEmit` with 0 compile errors.

- [2026-05-20 13:40]: **Removed Footer App Store Promotion Card**
  - *Details*: Deleted the iOS App Store Promotion Card from the public footer (`PublicFooter.tsx`) to streamline the layout and focus exclusively on the core open-source web companion platform.
  - *Tech Notes*:
    - Removed the promotion card container and its dynamic animation effects from `PublicFooter.tsx`.
    - Removed the unused `Download` icon import from `lucide-react` in `PublicFooter.tsx`.
    - Verified compilation and layout safety using typescript typecheck `npx tsc --noEmit` with 0 compile errors.

- [2026-06-03 17:53 CEST]: **Desktop Supabase Config Hardening**
  - *Details*: Removed the checked-in desktop Supabase URL and publishable key from `desktop_supabase_config.dart`. The desktop app now reads Supabase values only from Flutter `--dart-define` inputs.
  - *Tech Notes*:
    - Updated `DesktopSupabaseConfig` so `EVOLVE_SUPABASE_URL` and `EVOLVE_SUPABASE_PUBLISHABLE_KEY` have no committed default values and are trimmed before use.
    - Added `desktop_supabase_config_security_test.dart` to prevent checked-in Supabase URLs/JWT keys from reappearing in the desktop config.
    - Updated `desktop/README.md` with the required `--dart-define` workflow for local and release desktop builds.

- [2026-06-03 17:53 CEST]: **Mandatory Desktop Supabase Build Defines**
  - *Details*: Enforced production-ready desktop startup by making Supabase credentials mandatory at build time. The desktop target now fails compilation when `EVOLVE_SUPABASE_URL` or `EVOLVE_SUPABASE_PUBLISHABLE_KEY` are missing, preventing accidental unsigned/unconfigured desktop builds.
  - *Tech Notes*:
    - Added a build guard for required Supabase build defines. The initial Dart const assertion was later moved to the macOS build phase so static analysis remains usable.
    - Restored unconditional Supabase validation and initialization in `main.dart`.
    - Added `desktop/.gitignore` rules for local `.env` files used by `--dart-define-from-file`.
    - Added a safe `desktop/.env.example` template with no production values.
    - Removed the concrete Supabase project ref from `desktop/FEATURE_PARITY.md` so desktop documentation no longer exposes the production backend identifier.
    - Removed the concrete Supabase project ref from the desktop security regression test; it now checks only generic Supabase URL/JWT patterns.
    - Updated the desktop security test to require build-time Supabase defines during verified test runs.

- [2026-06-03 18:15 CEST]: **Repository Supabase Identifier Scrub**
  - *Details*: Completed a repository-level follow-up audit after desktop `.env` setup. The desktop configuration has a single source of truth via Flutter build defines, and the remaining concrete Supabase project identifier in the root Supabase CLI config was replaced with a neutral local project id.
  - *Tech Notes*:
    - Verified `desktop/.env` is ignored while `desktop/.env.example` remains trackable.
    - Verified desktop imports do not depend on mobile config files or duplicated local Dart config.
    - Updated `supabase/config.toml` from a concrete remote project ref to `mattioli-os-local`; remote Supabase deploy/link commands must provide the real project ref via local CLI state or CI secrets.

- [2026-06-03 18:20 CEST]: **Desktop Build Guard Refinement**
  - *Details*: Replaced the Dart const build guard with native desktop build guards so `flutter analyze` remains usable while macOS, Linux, and Windows desktop builds still fail automatically when required Supabase dart defines are missing.
  - *Tech Notes*:
    - Removed the const assertion guard from `DesktopSupabaseConfig`; runtime validation still protects app startup.
    - Added `desktop/scripts/check_required_dart_defines.sh`, which validates `DART_DEFINES` without printing secret values.
    - Added the script to the macOS Runner build phases before Flutter app embedding.
    - Added `desktop/cmake/check_required_dart_defines.cmake` and wired it into Linux and Windows CMake configuration.
    - Updated `desktop/README.md` to document the desktop build guard behavior and the required `.env` verify/run commands.

- [2026-06-03 18:25 CEST]: **Desktop macOS Dependency Lock Alignment**
  - *Details*: Normalized macOS dependency metadata after verified desktop builds. The committed CocoaPods lockfile now reflects the plugin dependencies actually used by the desktop app, while stale SwiftPM package resolution files generated by an older dependency path were removed.
  - *Tech Notes*:
    - Updated `desktop/macos/Podfile.lock` through the verified macOS Flutter build.
    - Removed stale `Package.resolved` files under the macOS Xcode workspaces; current macOS plugin dependencies are resolved through CocoaPods for this target.

## Build note (desktop Supabase)

- Desktop builds/runs still require `EVOLVE_SUPABASE_URL` and `EVOLVE_SUPABASE_PUBLISHABLE_KEY`, supplied via local environment variables, CI secrets, or Flutter `--dart-define`/`--dart-define-from-file` flags before compiling desktop. For Supabase CLI deploys, keep the real project ref in local/CI secret configuration rather than committed files. (This is a standing build requirement, not the project's current status — see the latest `*Current Status*` at the end of this file.)

- [2026-06-17]: Android Folder Regeneration and Publishing Prep
  - *Details*: Regenerated the Android folder, configured release signing, and modified MainActivity for local_auth.
  - *Tech Notes*: Keystore generated in android/app/upload-keystore.jks. Passwords stored in key.properties. Both ignored in .gitignore. Successfully built the release appbundle.

- [2026-06-19 14:34]: **Version Increment for Publication**
  - *Details*: Incremented the version numbers across the project's components in preparation for an update publication.
  - *Tech Notes*:
    - Mobile app (`mobile/pubspec.yaml`): Incremented version from `1.0.3+7` to `1.0.4+8`.
    - Desktop app (`desktop/pubspec.yaml`): Incremented version from `1.0.0+1` to `1.0.1+2`.
    - Web app (`package.json`): Incremented version from `0.0.0` to `0.0.1`.

- [2026-06-19 22:20]: **App Store Connect Localization Automation**
  - *Details*: Configured Fastlane to automatically populate missing App Store Connect fields (What's New in This Version) for all supported languages.
  - *Tech Notes*:
    - Created localized folders under `mobile/ios/fastlane/metadata/` for 16 target languages (fr-FR, ko, es-MX, etc.).
    - Executed `fastlane deliver` with `--app_version "1.0.4"` and `--force` to propagate default release notes ("UI improvements") bypassing interactive blocks and version ambiguity.
    - Updated `mobile/ios/fastlane/Fastfile` with custom ruby scripts as fallbacks for Spaceship API usage.

- [2026-06-20 14:17]: **Automated Global Metadata Translation**
  - *Details*: Fully automated the translation of the app's metadata (Name, Subtitle, Promotional Text, Description, Keywords) into 16+ languages required by App Store Connect to resolve missing localization errors. Explicitly set "release_notes.txt" to "UI improvements" across all languages as requested.
  - *Tech Notes*:
    - Created and executed a Python script (`translate_all.py`) utilizing `deep-translator` via Google Translate API to dynamically generate localized text files for each language directory in `fastlane/metadata/`.
    - Handled URL configurations globally, ensuring correct `support_url.txt`, `marketing_url.txt`, and `privacy_url.txt` properties without breaking format schemas.
    - Handled an edge case for Hebrew translation code (`iw` instead of `he`).

- [2026-06-20 14:34]: **App Store Connect Metadata Translation & Upload**
  - *Details*: Successfully downloaded current App Store Connect metadata to resolve name uniqueness conflicts, translated the release notes ("UI improvements") to 38 localized languages using Google Translate, and successfully uploaded the localized release notes to App Store Connect via Fastlane.
  - *Tech Notes*: Downloaded true metadata using `fastlane deliver download_metadata`. Translated `release_notes.txt` iteratively with `deep_translator` for all locales in `fastlane/metadata`. Uploaded securely without duplicate name conflicts via `fastlane deliver --force`.

- [2026-06-20 14:39]: **App Store Connect Metadata Critical Fixes (404 URLs)**
  - *Details*: Fixed broken Support and Marketing URLs across all 38 localized languages before App Review submission. The old URLs pointed to \`wealth-compass\` which returned HTTP 404s, guaranteeing a rejection.
  - *Tech Notes*: Updated \`support_url.txt\` to \`https://simo-hue.github.io/evolve/#faq\` and \`marketing_url.txt\` to \`https://simo-hue.github.io/evolve/\`. Uploaded via \`fastlane deliver\`.

- [2026-06-20 15:10]: App Store Connect Metadata Push
  - *Details*: Uploaded release notes ("UI improvements") across 38 localized languages for Evolve. Cleaned up the local Fastlane setup.
  - *Tech Notes*: Removed corrupted metadata folder pointing to dummy app. Generated and executed temporary Deliverfile to selectively push release notes via Fastlane without overriding App Info fields. Cleaned up all temporary python scripts and Fastlane artifacts.

- [2026-06-30]: **Mattioli.OS Web Backup Import**
  - *Details*: Implemented a feature in the iOS app to import ZIP backups exported from the Mattioli.OS web platform.
  - *Tech Notes*: Added  and  dependencies. Created  to parse the web JSON structure and remap colors (HSL to hex). Executed data migration locally using SQLCipher transactions, and patched Supabase schema mismatches (e.g., removing  from ). Handled custom UI styling and  warnings in .

- [2026-06-30]: **Mattioli.OS Web Backup Import**
  - *Details*: Implemented a feature in the iOS app to import ZIP backups exported from the Mattioli.OS web platform.
  - *Tech Notes*: Added `archive` and `file_picker` dependencies. Created `BackupImportService` to parse the web JSON structure and remap colors (HSL to hex). Executed data migration locally using SQLCipher transactions, and patched Supabase schema mismatches (e.g., removing `updated_at` from `macro_goal_categories`). Handled custom UI styling and `ListTile` warnings in `profile_screen.dart`.

---
STATUS: COMPLETED
NEXT ACTION: Ensure device is running the latest built version of the codebase.

- [2026-06-30 21:08:00]: Fixed Private Mode Import Crash
  - *Details*: Resolved `Supabase.instance` initialization assertion error when importing data while offline.
  - *Tech Notes*: `BackupImportService` now accepts a nullable `SupabaseClient?`. In `privacy_settings_screen.dart`, we explicitly pass `null` instead of calling `Supabase.instance.client` when `activeDataModeProvider` is in `AppDataMode.private`.

- [2026-06-30 23:25]: App Store Connect Metadata Translation Update
  - *Details*: Added translated 'What's new' text ('Funzionalità di Import per utenti di Mattioli.OS') for App Store Connect metadata.
  - *Tech Notes*: Updated Fastfile to explicitly set FASTLANE_ITC_TEAM_ID, map correct locales (fr-FR, de-DE), and automatically upload translations directly to App Store Connect via Spaceship::ConnectAPI.

- [2026-07-01]: App Version Increment
  - *Details*: Incremented the version in pubspec.yaml for the upcoming mobile app App Store release.
  - *Tech Notes*: Updated mobile/pubspec.yaml version from 1.0.6+10 to 1.0.7+11.

- [2026-07-01]: Settings Page Version Text Update
  - *Details*: Updated the app version text shown in the Settings page to automatically pull the actual native version from the build configuration, rather than using a hardcoded translation string.
  - *Tech Notes*: Modified `appVersion` string in all 5 localized `i18n.json` files to accept a `{version}` parameter. Updated `_ProfileScreenState` in `profile_screen.dart` to fetch `PackageInfo.fromPlatform()` on `initState` and pass it to the Slang translation method.
- [2026-07-01]: Fixed Import Dialog UI and Translations
  - *Details*: Fixed the yellow underline styling issue in the import loading dialog and added translations for the "This might take a few seconds..." text.
  - *Tech Notes*: Wrapped the `showDialog` container in `privacy_settings_screen.dart` with a `Material(type: MaterialType.transparency)` widget to remove the yellow double-underline default text style fallback. Added the `importWaitMessage` key to all `i18n.json` files and ran `dart run slang` to generate localized strings.

- [2026-07-01]: App Store Connect Metadata Translation Update (Miglioramento Grafico)
  - *Details*: Added translated 'Miglioramento Grafico' text for App Store Connect metadata 'What's new' field.
  - *Tech Notes*: Updated `ios/fastlane/Fastfile` to include 'Miglioramento Grafico' mapped to its correct localized translations.

- [2026-07-02]: App Version Increment
  - *Details*: Incremented the version in pubspec.yaml for the upcoming mobile app App Store release.
  - *Tech Notes*: Updated `mobile/pubspec.yaml` version from 1.0.7+11 to 1.0.8+12.

- [2026-07-02]: App Store Connect 'What's New' Update
  - *Details*: Updated 'What's new in this version' to "Logs nelle impostazioni" across all supported App Store languages using Fastlane.
  - *Tech Notes*: Edited the translations dictionary in `ios/fastlane/Fastfile` and executed `fastlane update_notes`.

- [2026-07-03 22:36]: **App Store Connect Metadata Translation & Upload**
  - *Details*: Successfully downloaded current App Store Connect metadata to resolve name uniqueness conflicts, translated the release notes ("UI improvements") to 38 localized languages using Google Translate, and successfully uploaded the localized release notes to App Store Connect via Fastlane.
  - *Tech Notes*: Downloaded true metadata using `fastlane deliver download_metadata`. Translated `release_notes.txt` iteratively with `deep_translator` for all locales in `fastlane/metadata`. Uploaded securely without duplicate name conflicts via `fastlane deliver --force`.

- [2026-07-03 22:48]: **App Store Connect Metadata Translation & Upload**
  - *Details*: Successfully downloaded current App Store Connect metadata to resolve name uniqueness conflicts, translated the release notes ("UI improvements") to 38 localized languages using Google Translate, and successfully uploaded the localized release notes to App Store Connect via Fastlane.
  - *Tech Notes*: Downloaded true metadata using `fastlane deliver download_metadata`. Translated `release_notes.txt` iteratively with `deep_translator` for all locales in `fastlane/metadata`. Uploaded securely without duplicate name conflicts via `fastlane deliver --force`.

- [2026-07-03 22:58]: **App Store Connect Metadata Translation & Upload**
  - *Details*: Successfully downloaded current App Store Connect metadata to resolve name uniqueness conflicts, translated the release notes ("UI improvements") to 38 localized languages using Google Translate, and successfully uploaded the localized release notes to App Store Connect via Fastlane.
  - *Tech Notes*: Downloaded true metadata using `fastlane deliver download_metadata`. Translated `release_notes.txt` iteratively with `deep_translator` for all locales in `fastlane/metadata`. Uploaded securely without duplicate name conflicts via `fastlane deliver --force`.

- [2026-07-03]: Dashboard Porting (Privacy Mode Onboarding & Pro Limits)
  - *Details*: Aligned the Desktop `DashboardPage` with the Mobile `HomeScreen` by porting the startup onboarding flow and `_NamePromptDialog` for Privacy Mode users. Added `100 goals` pro limits check and rich empty states.
  - *Tech Notes*: Migrated `DashboardPage` to `ConsumerStatefulWidget`. Integrated `sharedPreferencesProvider`. Fixed widget signatures. No new dependencies.

- [2026-07-03]: Data Import Feature (Privacy Mode)
  - *Details*: Ported the Backup Import Service from mobile to Desktop, enabling Privacy Mode users to restore their local data via `.zip` files. Added the "Importa dati" UI flow to `settings_page.dart`.
  - *Tech Notes*: Created `desktop_backup_import_service.dart`, integrated `file_picker` and `archive` in `pubspec.yaml`, injected `importData()` into `DesktopPrivateDb`, and copied `streak_utils.dart` to calculate streaks locally.

- [2026-07-03]: AI Coach Feature Porting (Desktop)
  - *Details*: Fully ported the AI Coach screen and logic from mobile into `desktop/lib/features/ai_coach`. The desktop app now features a live Markdown-powered chat capable of injecting the user's local dashboard state (Habits & Goals) directly into the system prompt.
  - *Tech Notes*: Added `flutter_markdown` and `http` to pubspec. Created `ChatMessage` domain model. Ported `OpenRouterConfig` and `OpenRouterService`, adapting the streaming logic to the desktop environment. Rewrote `AiCoachPage` replacing the stub with a complete interactive chat UI holding local state.

- [2026-07-06 23:30]: **Cross-platform iCloud Sync (desktop macOS + shared engine extraction)**
    - *Details*: Implemented end-to-end-encrypted iCloud (CloudKit) sync on the macOS desktop app, wire-compatible with the existing iOS implementation — same container (`iCloud.com.simo.evolve`), zone (`PrivateZone`), record type (`PrivateRecord`), AES-256-GCM payload format and LWW/tombstone semantics — so all of a user's Apple devices converge on one private dataset. The entire sync core was extracted from `mobile/` into a new shared package **`packages/evolve_sync`** (engine, crypto, local store, bridge contract + MethodChannel impl, private-DB schema, sync service, key store, write debouncer, fakes + 73 tests) consumed by BOTH apps, making schema/wire-format drift between platforms impossible. Design record: `desktop/ICLOUD_SYNC_PLAN.md` (grill-me interview, 9 locked decisions).
    - *Tech Notes*:
      - **Key transport**: sync key + canonical owner moved to the shared keychain access group `$(AppIdentifierPrefix)com.simo.evolve.sync` (iCloud Keychain syncs across devices; only a shared access group crosses APPS). Mobile 1.0.10 migrates transparently via `MigratingSyncSecretStore` (read-heal, dual-write for ≤1.0.9 devices, delete-both); desktop reads the group directly (fss 10 `MacOsOptions`). Entitlements updated on both targets.
      - **New features on both platforms**: avatar sync as an encrypted `CKAsset` (`avatar:<owner>`, `SyncAvatarStore` seam, no-re-dirty re-localization via `SyncLocalStore.setLocalOnlyColumn`) and the after-write debounced trigger (`SyncWriteDebouncer`, ~3 s, hooked at the private write methods).
      - **Desktop wiring**: `DesktopSyncLifecycle` (launch + window-refocus + after-write + 15-min periodic triggers), `desktopPrivateSyncServiceProvider` (macOS-gated), `DesktopPrivateDb` gains syncStore/adoptOwner/avatar helpers + sync-aware `deleteAllPrivateData` (clears `sync_state`, preserves `pending_zone_wipe` — mobile #6/#7 parity). Native Swift `CloudKitSyncBridge` ported line-for-line into `desktop/macos/Runner/AppDelegate.swift`, registered in `MainFlutterWindow`; deployment target raised to macOS 12.3; `swiftc`-typechecked (no Xcode on this machine — compile + device QA delegated via TO_SIMO_DO.md).
      - **Desktop UI**: iCloud Sync card in Settings → Privacy (toggle + E2E disclosure, status incl. new `hasKey`-driven "waiting for iCloud Keychain" hint, Sync Now + last-synced); delete-private-data now performs the full sync reset (requestFullReset before local wipe) with the "run on each device" caveat. Strings in en/it/es/de/ar.
      - **Latent desktop bugs fixed en route**: private profile controller read/wrote non-existent `avatar_path` column (broke private profile load + avatar save); category archive didn't bump `updated_at` (LWW un-archive risk).
      - **Versions**: mobile bumped to 1.0.10+14 (Mac App Store release is gated on it being live). Suites: package 73/73, mobile 144/144, desktop 94/94; `flutter analyze` at baseline on all three.

- [2026-07-07 01:10]: **Desktop completion pass — settings parity, import/export overhaul, Apple-style UI kit**
    - *Details*: Three sub-agent-implemented, individually-reviewed-and-committed work items bringing the macOS desktop app to feature and polish parity: (S1) mobile settings ported (new "AI & System" and "Insights & reports" groups, Pro gating, Focus Mode now genuinely suppresses notification scheduling incl. the dashboard reschedule path, calendar-view persistence bug fixed, haptics hidden on macOS); (S2) import/export made fully working (identity-based last-write-wins merge replacing the silently-lossy ConflictAlgorithm.ignore + per-merge UUID minting, in-transaction streak recomputation, invalid-row validation with skipped counts surfaced in the UI, per-entity import summary, native macOS Save dialog, canonical camelCase export shape so desktop backups finally round-trip to the iPhone app); (S3) a shared Apple-style control kit (EvolveSwitch/Select/Menu/TimePicker/DateField/RadioRow/ProBadge) replacing every Material form control app-wide, RTL-safe with hover states.
    - *Tech Notes*: Entitlements user-selected read-only → read-write (Save dialog); file_picker ^11 + share_plus ^12 (mobile's pair — pod reinstall needed on the Xcode machine); new files desktop/lib/core/{calendar_view_preference,import_merge,import_merge_stats}.dart and desktop/lib/shared/widgets/evolve_controls.dart; i18n additions ×5 locales, slang regenerated. Desktop suite grew 94 → 140 tests (analyze clean); mobile 144 and evolve_sync 73 untouched. Visual QA checklist + device verifications tracked in desktop/TO_SIMO_DO.md; commits a553fe5, d4cdce7, cd0ce3f.



- [2026-07-07]: macOS Universal Purchase & Fastlane Setup
  - *Details*: Configured the macOS desktop app to use Universal Purchase by matching the bundle ID (com.simo.evolve) with the iOS app. Added Fastlane for macOS (Appfile, Fastfile) to automate App Store Connect uploads.
  - *Tech Notes*: Modified AppInfo.xcconfig, Release.entitlements, DebugProfile.entitlements, and project.pbxproj to use com.simo.evolve.
- [2026-07-07]: Fix Desktop Private Mode Parity Gaps (B1, B3, B4)
  - *Details*: Fixed critical parity gaps and bugs in the Desktop Private Mode to ensure stability and feature consistency with mobile.
  - *Tech Notes*:
    - Replaced hardcoded `isPro: false` with `desktopIsProProvider` in `_ProfileCard` (`settings_page.dart`) to unlock pro features in Private Mode.
    - Disabled the import of the `value` field from `goal_logs` in `desktop_backup_import_service.dart` and `desktop_private_db.dart` to fix the SQL schema error on importing mobile backups.
    - Added `db.execute('PRAGMA foreign_keys = ON;');` in `PrivateDbSchema.onConfigure` (inside `desktop_private_db.dart`) to ensure referential integrity, matching mobile behavior and preventing silent database failures when profile rows are missing.
    - Verified all fixes with `flutter analyze` which completed with zero issues.

- [2026-07-07 10:19:00]: Unified Desktop Onboarding Tutorial
  - *Details*: Refactored the desktop onboarding tutorial to be a contiguous, atomic flow across multiple tabs (Overview -> Goals -> Insights), matching the iOS behavior. The tutorial no longer gets fragmented or left pending on other pages.
  - *Tech Notes*: 
    - `dashboard_page.dart`: Updated `_finishDashboardTour` to optionally advance to the Goals tab.
    - `goals_page.dart`: Adjusted tutorial trigger to require `tutorialProvider` (Dashboard tutorial) to be complete. Updated `_finishGoalsTutorial` to advance to the Insights tab.
    - `statistics_page.dart`: Adjusted tutorial trigger to require `goalsTutorialProvider` to be complete. Updated `_finishStatsTour` to reset navigation back to Overview.
    - Updated `nextButtonLabel` and `finishLabel` to correctly indicate progression ("Next" vs "Finish") during the flow.
- [2026-07-07 10:47:00]: macOS-Style Color Picker Popover
  - *Details*: Redesigned the color picker in the Desktop app to feature a clean, native-feeling macOS popover with segmented tabs for Presets and Custom color selections, dropping the old full-screen/modal dialog.
  - *Tech Notes*:
    - Created `popover.dart` containing `showPopover` and `PopupRoute` logic to anchor floating panels to a caller's `RenderBox`.
    - Created `EvolveColorPickerContent` (`evolve_color_picker.dart`) providing segmented controls (Presets, Custom), custom color wheel via `flutter_colorpicker`, and a HEX text input.
    - Created `ColorPickerButton` (`color_picker_button.dart`) to unify the color swatch interaction.
    - Cleaned up inline preset circles in `create_habit_dialog.dart`, `create_goal_dialog.dart`, and `goals_page.dart`.
    - Updated `settings_page.dart` (Accent Color Selector) to use `showPopover`.
    - Removed legacy `color_picker_dialog.dart`.
- [2026-07-07 10:50:00]: Popover Inline Presets Tweak
  - *Details*: Modified `ColorPickerButton` to display the presets inline as a row of circles ending with a custom `+` gradient swatch, rather than just a single color circle.
  - *Tech Notes*:
    - The custom `+` swatch explicitly triggers the new popover containing the spectrum and Hex input. This retains the quick-select functionality of presets while elevating the advanced color picking experience to the new popover.
    - Verified functionality with `flutter analyze`, yielding no errors.
- [2026-07-07 10:59:00]: Popover Color Picker Rendering Fixes
  - *Details*: Fixed a severe rendering issue where `flutter_colorpicker` was attempting to render its inner components as a landscape `Row` (overflowing by 342 pixels) which further triggered layout collapses and "No Material widget found" errors.
  - *Tech Notes*:
    - Set `portraitOnly: true` on the `ColorPicker` in `evolve_color_picker.dart` to strictly enforce a vertical `Column` layout, bypassing the library's wide aspect-ratio assumptions on desktop platforms.
- [2026-07-07 11:02:00]: Popover "Pick" Button
  - *Details*: Added a fully translated "Pick" confirmation button to the bottom of the custom color popover.
  - *Tech Notes*:
    - Injected `t.common.actions.pick` into all 5 language `.i18n.json` files and ran `dart run slang` to regenerate `translations.g.dart`.
    - Added a `FilledButton` at the bottom of the `EvolveColorPickerContent` `Column` to manually close the popover upon selection.

- [2026-07-11]: **Cross-platform "swipe back" navigation (iOS edge-swipe + macOS two-finger trackpad)**
    - *Details*: Made "swipe to go back" work from every back-navigable page, aligning the gesture across platforms. On mobile, the 7 settings/detail sub-pages (Personal Info, Subscription, App Settings, Notifications, Privacy, App Logs, iCloud Sync) could not be swiped back because each pushed itself with a custom `PageRouteBuilder` (a hand-rolled 400 ms slide), which does not wire up Flutter's iOS edge-swipe-back gesture — only the Profile ("settings") screen and AI Chat worked, since they use `MaterialPageRoute`. All 7 now use `MaterialPageRoute`, so iOS gets the native Cupertino slide + edge-swipe-back for free (RTL-aware) and Android keeps its native Material transition; every call site (`XxxScreen.route()`) is unchanged. On macOS the app has no page stack (a sidebar shell of 6 peer sections; settings is a single page), so "back" was given a concrete meaning: `NavigationController` now keeps a visited-section history plus a `back()`/`canGoBack`/`lastDirection` API; a two-finger trackpad swipe-right and ⌘[ both return to the previously visited section, and the shell's existing section `AnimatedSwitcher` became a directional slide+fade driven by the navigation direction.
    - *Tech Notes*:
      - **Mobile**: 7 files under `mobile/lib/ui/screens/*` had their `static Route route()` body changed from `PageRouteBuilder` → `MaterialPageRoute` (`icloud_sync` keeps `<void>`); no import or behaviour changes, custom leading chevrons retained.
      - **Desktop `navigation_controller.dart`**: added `enum NavDirection { forward, back }`, a capped (50) `_history` stack; `select()` now records the prior section (dedup consecutive) and sets the direction; new `back()` / `canGoBack` / `lastDirection`. State type stays `DesktopSection`, so existing `ref.watch` call sites are untouched.
      - **Desktop `desktop_shell.dart`**: added `import 'package:flutter/gestures.dart'`; ⌘[ (`bracketLeft`, meta) → `back`; wrapped the content area (sidebar excluded) in a `Listener` using `onPointerPanZoom*` (macOS trackpad pans arrive as pointer pan-zoom events) that pops history on a horizontal-dominant swipe past a 48 px threshold, once per gesture, RTL-aware; the section `AnimatedSwitcher` gained a directional slide (±0.06) + fade `transitionBuilder` (220 ms, easeOutCubic) keyed off `lastDirection`.
      - **No new dependencies** (all Flutter built-ins). `flutter analyze` clean on both apps. Runtime swipe QA on iOS/macOS delegated via `TO_SIMO_DO.md` (no Xcode on this machine); the macOS trackpad pan-sign assumption is called out there for on-device confirmation.

- [2026-07-11]: **macOS forward navigation (two-finger swipe-left + ⌘])**
    - *Details*: Completed the macOS back/forward pair. The two-finger trackpad swipe-back added earlier now has its complement: a swipe in the opposite direction (left) — and ⌘] — re-enters the section you just backed out of, browser/Finder-style. Forward is a no-op until you've gone back, and any fresh navigation (sidebar click, ⌘1-5/⌘,, command palette) clears the forward history, matching standard browser semantics. Desktop-only: mobile's back-swipe pops and destroys the page, so there is nothing to go forward to.
    - *Tech Notes*:
      - **`navigation_controller.dart`**: added a `_forward` stack + `canGoForward`; `back()` now pushes the current section onto `_forward` before popping `_history`; new `forward()` pops `_forward`, pushes current back onto `_history`, sets `NavDirection.forward`; `select()` clears `_forward`.
      - **`desktop_shell.dart`**: the trackpad handler (`_backSwipe*` → `_navSwipe*`) now resolves both directions — swipe-right past the 48 px threshold → `back()`, swipe-left → `forward()` — RTL-aware, one-shot per gesture, horizontal-dominance guarded; added ⌘] (`bracketRight`, meta) → `forward`. No transition changes: `forward()` reuses the existing `NavDirection.forward` slide, so it animates in from the trailing edge automatically. No visible button.
      - **No new dependencies.** `flutter analyze` clean. Runtime forward-swipe QA delegated via `TO_SIMO_DO.md`.

- [2026-07-11]: **Fix two iOS runtime crashes: AI Coach open + Settings→back-to-login (mobile)**
    - *Details*: Two on-device QA crashes fixed in the mobile app.
      **AI Coach crashes on open**: `AIChatScreen.initState()` seeded the greeting via `_addInitialMessages()`, which reads `context.t` — the slang translations `InheritedWidget`. Inherited-widget lookups are illegal during `initState`, so opening the AI Coach threw `dependOnInheritedWidgetOfExactType<InheritedLocaleData<AppLocale, Translations>>() … was called before _AIChatScreenState.initState() completed`. The seeding now runs from `didChangeDependencies()`, guarded with `if (_messages.isEmpty)` so it runs exactly once and never re-seeds on later theme/locale changes. Greeting text and message model unchanged; the delete-chat re-seed path is untouched.
      **Settings→back-to-login crash (toast overlay leak)**: `showEvolveToast`'s `_EvolveToast` drove its ~2s dwell with a non-cancellable `await Future<void>.delayed(duration)` and only removed its `OverlayEntry` via `onDismissed`. A toast still on-screen when the route tree was torn down on logout (`context.go('/login')`) left the pending delay alive and its inherited dependents (Theme/MediaQuery) dangling, tripping `InheritedElement.debugDeactivated: assert(_dependents.isEmpty)` (framework.dart:6268 → the reported `_dependents.isEmpty is not true`). Ported the sibling desktop kit's hardening: the dwell now runs on a `Timer` stored in state and `cancel()`ed in `dispose()`, and `showEvolveToast` guards `entry.remove()` behind a `bool removed` flag so it is never called twice / on an already-removed entry. Visual behaviour (fade+slide in, ~2s, fade out) is identical.
    - *Tech Notes*:
      - **`mobile/lib/ui/screens/ai_chat_screen.dart`**: removed the `initState` seeding; added `didChangeDependencies()` with `if (_messages.isEmpty) _addInitialMessages();`. No other `context.` inherited lookups occur in `initState`.
      - **`mobile/lib/ui/kit/evolve_toast.dart`**: `+import 'dart:async';`; `_run()` (Future.delayed) → `_show()`/`_dismiss()` on a `Timer? _dismissTimer` cancelled in `dispose()`; `showEvolveToast` wraps `onDismissed` in a one-shot `removed` guard.
      - **No new dependencies; no API/behaviour changes.** Verified against the exact repros with two new widget tests: `mobile/test/ai_chat_screen_test.dart` (pumps `AIChatScreen` in Private mode, asserts it builds + seeds the greeting — reproduced the `InheritedLocaleData` throw pre-fix) and `mobile/test/evolve_toast_teardown_test.dart` (shows a toast then tears the tree down mid-dwell, asserting no pending timer / exception — reproduced "A Timer is still pending even after the widget tree was disposed" pre-fix; a second case asserts normal self-dismiss).
      - `flutter analyze`: **16 issues** (all pre-existing infos; 0 errors/warnings — baseline unchanged). `flutter test`: **All tests passed!** at **147** (was 144; +3 new). On-device re-verification of the two repro flows delegated via `TO_SIMO_DO.md` (no Xcode on this machine).

- [2026-07-11]: iOS Version Bump & Metadata
  - *Details*: Bumped the iOS app version to 1.1.0 in `mobile/pubspec.yaml` and updated the fastlane translations in `mobile/ios/fastlane/Fastfile` to include "New UI" as requested.
  - *Tech Notes*: Ran `fastlane update_notes` to sync the updated metadata to App Store Connect, but it failed with "Nessuna versione in stato editabile trovata!". The new version 1.1.0 must be created manually on App Store Connect first before the metadata can be updated.


- [2026-07-12]: **Merge origin/main into local main**
  - *Details*: Resolved merge conflicts between local macOS feature additions and remote Apple-Style UI Phase 2 refactorings.
  - *Tech Notes*: Unified `ColorPickerButton` with `EvolveFieldLabel` in `create_habit_dialog.dart`. Reintegrated custom streak color logic into remote's `_DayHabitRow` in `habits_page.dart`. Reconciled macOS entitlements for both iCloud syncing and network server access. Regenerated translations via `slang`.

- [2026-07-13 11:34]: Weekly View Redesign (Variants A & B)
  - *Details*: Replaced the previous capsule-based weekly view with two modern chart alternatives using `fl_chart`. Variant A (`weekly-view/radar-chart`) uses a Radar chart to show the shape of the week's completion. Variant B (`weekly-view/stacked-bars`) uses a stacked bar chart showing individual habit completion per day. Both share the same navigation, summary row, privacy mode handling, and tap-to-show day details interaction. Both are implemented on separate git branches for testing.
  - *Tech Notes*: Uses `fl_chart` v0.69.0. Implemented on `weekly_view_widget.dart` on two different branches.

- [2026-07-13 15:55]: **Auto-Verified Habits — design decisions + verification core (`packages/evolve_verification`)**
  - *Details*: Started a new feature — habits whose daily `done`/`missed` is set **automatically** from Apple data instead of manual check-in: e.g. "≥10k steps" (HealthKit) or "≤2h screen time" (Screen Time). Verification is inherently **iOS-only** (no public HealthKit or Screen Time API exists on macOS); macOS + web display synced verdicts read-only. This entry lands the first, fully device-free-testable slice: the pure-Dart reconcile/verdict core. Native bridges, the schema migration, the DeviceActivity extension, UI and notifications are later slices (see *Current Status*).
  - *Design decisions* (grill session, all ratified):
    - **D1** v1 ships both HealthKit + Screen Time; iOS verifies, macOS/web display only.
    - **D2** Screen Time = *total* device usage, binary threshold (empty `DeviceActivityEvent`; over⇒missed, interval-end-clean⇒done). Raw minutes are never readable by our code.
    - **D3** Lazy-on-foreground reconciliation is authoritative; background is best-effort notification latency only; all writes idempotent + recomputable.
    - **D4** Split representation: verdicts land in `goal_logs` as ordinary `done`/`missed` (zero streak/RPC/sync churn); the rule = nullable columns on `goals`; a local-only unsynced table holds the reconcile queue + provenance + couldn't-verify.
    - **D5** Nine curated templates (steps, exercise min, active energy, stand hours, distance, mindful min, sleep hours, workout, total screen time); defer per-app screen time + compound rules.
    - **D6** Local-current-day boundaries; honor `frequency_days`; 7-day bounded backfill (HealthKit re-queries, Screen Time import-only); couldn't-verify auto-settles + stops nagging after ~2 days.
    - **D7** Two Dart bridges (`HealthKitBridge` query-based, `ScreenTimeBridge` event-based) + pure-Dart `VerificationService`, in a new `packages/evolve_verification`; native impls in `mobile/`; Monitor extension only (no Report extension).
    - **D8** Full schema parity (Supabase + `evolve_sync` v3→v4 + both Goal models + web type + read-only badge); reuse `goal_logs.value` for the HealthKit measured number (null for Screen Time); dedicated mobile-only local bookkeeping store; device-local screen-time verdicts documented.
    - **D9** Just-in-time per-type auth; verifiable goals degrade to manual habits; manual entries win + freeze the day; revocation detected directly (Screen Time) / via couldn't-verify streak (HealthKit); soft Watch-data warnings.
    - **D10** Forward-only rule edits (no rule-versioning); late verdicts → bounded streak-tail recompute; verification toggles per goal; deletes deregister monitors; 20-activity cap surfaced.
    - **D11** Accountability-forward notifications: Screen-Time threshold-cross (real-time, from the extension) + couldn't-verify nudge ON; HealthKit celebration + failure summary opt-in.
    - **D12** Front-load the 2× family-controls entitlement requests; ship dark behind a feature flag; HealthKit may enable before Screen Time; raw data never leaves the device.
  - *Tech Notes*:
    - **New package `packages/evolve_verification`** (pure Dart, `flutter`-dep for `@immutable` only; no platform channels — native bridges live in `mobile/`). Mirrors `evolve_sync`'s split: contract + logic + fakes here, so it is fully unit-testable without a device. Barrel `evolve_verification.dart`; test doubles exported separately from `testing.dart`.
    - **Models**: `VerificationProvider`/`VerificationComparator`/`VerificationAggregation`/`VerificationUnit` (stable `wireName`s persisted to `goals`); `VerificationTemplate` + `VerificationCatalog` (the 9 v1 templates, each pinning provider/comparator/unit/aggregation/native identifier + threshold bounds); `VerificationRule` with `toColumns()`/`fromColumns()` (all-null ⇒ manual habit; partial ⇒ null, never a half-active rule); `DayVerdict`/`VerificationOutcome` (pending/pass/fail/couldNotVerify).
    - **Bridges**: `HealthKitBridge` (`dailyQuantity`→`double?`, null = no-data/ambiguous → never a false miss; `hasRecentData` Watch probe) and `ScreenTimeBridge` (`syncMonitoredGoals`, `drainSignals`, `ScreenTimeGoalSpec`/`ScreenTimeSignal`, `ScreenTimeMonitorLimitException`). In-memory fakes for both.
    - **`VerificationService`**: static pure decision tables `evaluateHealthDay` / `evaluateScreenTimeDay`, and `reconcile()` → a declarative `ReconcilePlan` (`LogWrite`s + `CouldNotVerifyEntry`s) the caller applies. Honors scheduled-days, 7-day backfill, forward-only `effectiveFrom`, manual-freeze, idempotency, and drains Screen Time signals once per pass.
    - **Adversarial review** (one agent) caught and we fixed three real `reconcile()` defects, each now regression-tested: (1) couldn't-verify was re-emitted for days already terminally logged (ephemeral Screen Time signals) → guard on existing terminal outcome; (2) `Duration(days:1)` date arithmetic drifted off local midnight across DST, breaking midnight-keyed lookups → switched to calendar-safe `DateTime(y,m,d±n)`; (3) a logged Screen Time `missed` could be flipped back to `done` by a late duplicate `stayedUnder` → over-limit is now permanent (HealthKit fail→pass on late data still allowed).
    - **Verification**: `flutter analyze` clean; `flutter test` **37/37 pass**. No new app dependencies; nothing wired into `mobile/`/`desktop/` yet (package is standalone).
  - *Current Status*: Slice 1 (verification core) **complete + verified**. **Immediate next step**: Slice 2 — additive schema migration for the rule columns on `goals` (`evolve_sync` v3→v4 with `onUpgrade` + `schema_drift`/`private_db_schema` tests, plus the Supabase migration and web `Goal` type), and the mobile-only local `verification_state` table. Then: native Swift bridges (typecheck-only here) + the `DeviceActivityMonitor` extension, `mobile/` wiring (Goal model + provider + reconcile-on-foreground), the creation/badge UI, notifications, and the feature flag. Manual (Xcode/Apple) actions logged in `TO_SIMO_DO.md`.

- [2026-07-13 17:20]: **Auto-Verified Habits — Slice 2: schema & coherence for the rule columns**
  - *Details*: Landed the `goals.verify_*` verification-rule columns across every backend and client so a rule persists and syncs without being wiped, per decision D8. No behavioural change yet (no verified goals can be created until the UI slice); this is the additive data-model foundation. The measured HealthKit number will reuse the pre-existing `goal_logs.value` column (no migration).
  - *Tech Notes*:
    - **`evolve_sync` schema v3→v4** (`packages/evolve_sync/lib/src/private_db_schema.dart`): added five nullable columns to the `goals` DDL (`verify_provider`, `verify_metric`, `verify_comparator`, `verify_threshold REAL`, `verify_unit`) + an idempotent `_upgradeToV4` (`ALTER TABLE goals ADD COLUMN …`). Left **unconstrained** (no CHECK) so a future provider/metric from a newer client round-trips instead of being rejected. The columns flow through iCloud sync automatically — the sync engine serializes whole rows (`readRow` is `SELECT *`) and `applyUpsert` re-inserts the map; per-record try/catch in the apply loop means a mixed-version device just logs+retries a not-yet-appliable row rather than corrupting data. Both apps ship `evolve_sync` together, so the mixed-version window is bounded. New tests: fresh-schema column presence + a v3→v4 migration test (columns added, existing rows preserved, rule writes/reads back). `flutter test` **75/75**.
    - **Supabase / web**: added the same columns to `schema.sql` `public.goals` + a new `migrations/20260713_add_goal_verification_columns.sql` (`ADD COLUMN IF NOT EXISTS`, numeric threshold, column comments, no RLS change). Web `src/types/goals.ts` `Goal` gained the optional `verify_*` fields + `VerificationProvider`/`VerificationComparator` unions (additive-optional; can't break the TS build). **Manual step (logged in TO_SIMO_DO):** apply the migration to the live Supabase project.
    - **Goal models & every read/write path** (both apps depend on the new `evolve_verification` package): mobile `Goal` and desktop `DashboardHabit` gained a `VerificationRule? verificationRule` field (via `VerificationRule.fromColumns`/`toColumns`), threaded through `copyWith`, JSON, and the DB row-mappers. Critical wipe-guard: mobile `upsertGoal` and the sync `applyUpsert` use `ConflictAlgorithm.replace`, so the private row-mappers (`_goalToRow`, desktop `createHabit`/`updateHabit`) now **always** write the columns (null when manual) — an omitted column on REPLACE would NULL a synced rule. The **Supabase-facing** serializers (`Goal.toJson`, `DashboardHabit.toRemoteJson`) include `verify_*` **only when a rule is present**, so manual-habit cloud writes don't depend on the Supabase migration having been applied yet. Reads (`_goalFromRow`, `_habitFromRow`, `fromRemoteJson`) parse the columns back.
    - *Deferred within this feature* (no data at risk — no verified goals exist until the UI slice): backup export/import round-trip of `verify_*` (mobile `import_merge`/`backup_import_service` + desktop `_goalRow`) lands with the creation UI.
  - *Verification*: `flutter analyze` — mobile **0 errors/warnings** (17 pre-existing infos; regenerated stale `translations.g.dart` via `dart run slang`), desktop **0 errors** (1 pre-existing `main.dart` warning). Tests: `evolve_verification` 37/37, `evolve_sync` 75/75, **mobile 147/147**, desktop 143 pass / **2 pre-existing failures** (`import_merge_lww` `goal_logs.value` round-trip + an `icloud_sync_card` widget test) — **confirmed pre-existing** by running them in an isolated worktree at HEAD (they fail identically without any Slice 2 change). No new dependencies beyond the `evolve_verification` path package wired into both apps.
  - *Current Status*: Slice 2 **complete + verified** (no regressions; 2 unrelated pre-existing desktop failures flagged separately). **Immediate next step**: Slice 3 — the mobile-only local `verification_state` bookkeeping store + the `VerificationService` wiring into a mobile provider (reconcile-on-foreground → apply `ReconcilePlan` to `goal_logs` with streak-tail recompute), all still testable here; then the native Swift bridges (`HealthKitBridge`/`ScreenTimeBridge` MethodChannel impls, Swift typecheck-only on this machine) + the `DeviceActivityMonitor` extension, behind the feature flag.

- [2026-07-13 18:30]: **Auto-Verified Habits — Slice 3: reconcile orchestration + local bookkeeping store**
  - *Details*: Built the device-free-testable orchestration brain that turns the pure reconcile engine into applied writes, plus the mobile-local bookkeeping store and the feature flag. No app wiring yet (that rides with the native bridges in Slice 4, when it can actually run on device) — everything here is verified with fakes + an in-memory database.
  - *Tech Notes*:
    - **`evolve_verification` package additions** (pure Dart): `VerificationStateStore` (interface — manual-freeze + couldn't-verify bookkeeping only; auto verdicts already live in `goal_logs`), `VerificationLogWriter` (interface — persists a verdict to the streak-bearing log and owns the streak-tail recompute, D10), and `VerificationController` + `ReconcileReport`. The controller assembles the `existing` state `reconcile()` needs by merging the app's logged outcomes with store-reported manual freezes over the backfill window, runs the engine, then applies the plan: `writeVerdict` + `resolveCouldNotVerify` for each write, `recordCouldNotVerify` for each couldn't-verify day, and returns counts + the in-nag-window nudges for the notification layer. Fakes for the store + log-writer added to `testing.dart`. **7 controller tests** (merge, D9 freeze, idempotency, couldn't-verify record→resolve across passes, nudge window, screen-time flow-through).
    - **Mobile**: `SqfliteVerificationStateStore` implements the interface over a `verification_state(goal_id, date, kind∈{manual,could_not_verify}, recorded_at)` table — **unsynced and data-mode-independent** (D8), typed against `DatabaseExecutor` so it runs on `sqflite_sqlcipher` in the app and `sqflite_common_ffi` in tests (and inside transactions). **10 ffi tests.** `verification_config.dart` adds the compile-time feature flags (`enabled`/`healthKitEnabled`/`screenTimeEnabled`, all **false** — ships dark per D12, HealthKit gateable before Screen Time).
    - **Adversarial review** (one agent) of the two logic files found **no correctness defects**; it flagged one latent fragility in the controller's key-merge (harmless today, but would bite if `reconcile` ever read `loggedOutcome` for manual days) — pre-emptively hardened by normalizing logged keys to local-midnight before the merge, so it's provably correct regardless of future changes.
  - *Verification*: `flutter analyze` clean (package + the new mobile files). Tests: `evolve_verification` **44/44** (37 + 7), **mobile 157/157** (147 + 10). No existing mobile code modified — Slice 3 is purely additive. Native bridges and provider/foreground wiring remain Slice 4.
  - *Current Status*: Slice 3 **complete + verified**. **Immediate next step**: Slice 4 (native + app wiring) — the Swift `HealthKitBridge`/`ScreenTimeBridge` MethodChannel implementations + the `DeviceActivityMonitor` app-extension (Swift typecheck-only on this machine; Xcode target/App Group/entitlement are the `TO_SIMO_DO` manual actions), a `VerificationLogWriter` adapter over the app's habit-log store (with streak-tail recompute), the Riverpod provider + reconcile-on-foreground lifecycle hook, and marking provenance=manual from the `cycleStatus` check-in path — all gated by `VerificationConfig`.

---

- **2026-07-13**: Fix — Biometric (Face ID / Touch ID) app lock never engaged
  - *Details*: A deep multi-agent audit found the lock was dead by construction. In `dashboard_screen.dart` the gate flag `_isBiometricAuthenticated` was initialised `true` and never set `false` anywhere, so the lock branch (`isLocked && !_isBiometricAuthenticated`) and the dashboard `_authenticate()` prompt were unreachable — enabling the toggle changed nothing at runtime (the user's report: "behaviour doesn't change when it's on or off"). There was also no lifecycle re-lock, no root-level gate, a private-mode first-frame race (biometricLock defaulted false while the SQLite settings row loaded async), and a Supabase pull that let a stale/other-device `biometric_lock=false` clobber a locally-enabled lock.
  - *Fix*: Introduced an app-wide `BiometricLockGate` (`mobile/lib/ui/widgets/biometric_lock_gate.dart`) mounted in `MaterialApp.router`'s `builder`, so it wraps every route and keeps the app mounted beneath an opaque overlay (navigation state survives lock/unlock). It owns the session auth via `biometricUnlockedProvider` (Notifier<bool>) + derived `biometricLockEnabledForUserProvider` / `biometricLockActiveProvider`; is a `WidgetsBindingObserver` that re-arms on `paused` and prompts on `resumed`; covers content while not-`resumed` (app-switcher privacy); and fails **closed** on auth error/cancel but **open** only when no biometrics are enrolled (avoids permanent lockout). Removed the dead lock code from `dashboard_screen.dart` and deferred its onboarding/tutorial until the lock clears. Privacy settings marks the session unlocked when enabling (it already did Face ID) to avoid an immediate re-prompt. `settings_provider.dart`: seed `biometricLock` synchronously from SharedPreferences on the private-mode first frame (+ mirror on save/load), and keep the local value authoritative on Supabase pull.
  - *Tech Notes*: No new dependencies (`local_auth: ^3.0.1` already present; API `authenticate(localizedReason, biometricOnly, persistAcrossBackgrounding)` confirmed valid). New providers: `biometricUnlockedProvider`, `biometricLockEnabledForUserProvider`, `biometricLockActiveProvider`. Files: +`ui/widgets/biometric_lock_gate.dart`, +`test/biometric_lock_gate_test.dart` (3 tests), edited `main.dart`, `providers/settings_provider.dart`, `ui/screens/dashboard_screen.dart`, `ui/screens/privacy_settings_screen.dart`. `flutter analyze` clean (no new issues); `flutter test` **160/160 pass**. Manual device verification + iOS SPM plugin-wiring check logged in `TO_SIMO_DO.md`.

- [2026-07-13 19:40]: **Auto-Verified Habits — Slice 4a: native bridge layer (Dart contract verified + Swift scaffold)**
  - *Details*: Built both sides of the two native bridges. The **Dart** MethodChannel implementations are fully verified here (they pin the exact native contract); the **Swift** implementations are a careful scaffold that could NOT be compiled/typechecked on this machine — hard constraint below.
  - *Tech Notes*:
    - **Constraint:** this dev machine has **no iOS SDK** (Command Line Tools only, no full Xcode), so `xcrun --sdk iphoneos` fails and iOS Swift importing HealthKit/FamilyControls/DeviceActivity **cannot be compiled or even typechecked here** (unlike the macOS desktop Swift, which has the macOS SDK). SourceKit reports only the expected environmental errors. So the Swift is a scaffold, **compiled/verified in Xcode by Simone** (TO_SIMO_DO updated with exact file/target/compile steps).
    - **Dart bridges** (`mobile/lib/core/`): `MethodChannelHealthKitBridge` (`evolve/healthkit`) + `MethodChannelScreenTimeBridge` (`evolve/screentime`), implementing the package interfaces, mirroring `MethodChannelCloudKitBridge` — typed marshaling + **graceful `MissingPluginException` degradation** (reads→null/false, mutations no-op) so a build without the native plugin (feature dark / entitlement pending) can't crash or fabricate a verdict. HealthKit passes an explicit local `[startMs,endMs)` day window; Screen Time maps a native `monitor_limit` error → `ScreenTimeMonitorLimitException` and decodes drained signals (skipping malformed). **13 mock-channel tests** cover the contract + degradation.
    - **Swift scaffold** (`mobile/ios/`): `Runner/VerificationAppGroup.swift` (shared App Group constant — must be a member of both targets), `Runner/HealthKitBridge.swift` (`HKStatisticsQuery` for quantity types in the template unit; `HKSampleQuery` sum/count for sleep/mindful/stand/workout; read-only; nil when absent), `Runner/ScreenTimeBridge.swift` (FamilyControls `.individual` auth; DeviceActivity monitoring via an **empty event = all activity** + per-day threshold on a 00:00–23:59 repeating schedule, DeviceActivityName = goalId; drains from the App Group), `DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` (extension: `eventDidReachThreshold`→reachedThreshold, `intervalDidEnd`→stayedUnder; tiny for the ~6 MB cap). `AppDelegate.swift` registers both channels (harmless while the flag is off).
  - *Verification*: `flutter analyze` clean; **mobile 173/173** (+13 bridge tests). Swift unverified-here by necessity (no iOS SDK) — compile is a documented `TO_SIMO_DO` step.
  - *Current Status*: Slice 4a **complete** (Dart verified; Swift scaffolded, compile-pending). **Next**: Slice 4b (app wiring, all testable here) — a `VerificationLogWriter` adapter over the habit-log write path (pass/fail→done/missed, carry `value`, streak-tail recompute), the Riverpod provider assembling `VerificationController` with the real bridges + `SqfliteVerificationStateStore`, the reconcile-on-foreground lifecycle hook, and `cycleStatus`→`markManual` — all gated by `VerificationConfig` (dark). Then UI (creation/badge), notifications, backup round-trip.

- [2026-07-13 21:00]: **Auto-Verified Habits — Slice 4b: app wiring (reconcile runs end-to-end, behind the flag)**
  - *Details*: Wired the reconcile engine into the live app so that — once `VerificationConfig.enabled` flips and the Swift compiles — a foreground resume auto-verifies habits and writes verdicts to `goal_logs`. All Dart, all analyzable here; the pure input builders are unit-tested. The whole path is inert while the flag is off.
  - *Tech Notes*:
    - **`goal_logs.value` plumbing**: `PrivateDataStore.setHabitLog` (+ `PrivateLocalDatabase` impl) gained an optional `double? value` written into `goal_logs.value`; new `HabitLogsNotifier.applyAutoVerdict(goalId, dateKey, status, value)` sets a verdict directly (not cycling), recomputes the streak from full history, and persists to the active backend (private `setHabitLog` / Supabase `upsert`), with optimistic-state rollback on failure.
    - **`verification_providers.dart`** (import-cycle-free): `healthKitBridgeProvider` / `screenTimeBridgeProvider` (the real MethodChannel bridges), `verificationServiceProvider`, and `verificationStateStoreProvider` (`FutureProvider` opening a dedicated unsynced `verification_state.db`, mode-independent per D8).
    - **`verification_wiring.dart`**: pure builders `verifiableGoalsFrom` (honors per-provider flags, maps rule/effectiveFrom=startDate/frequency→weekdays), `loggedOutcomesFrom` (done→pass, missed→fail), `screenTimeSpecsFrom`; the `GoalLogVerificationWriter` adapter (→ `applyAutoVerdict`); and `runVerificationReconcile(WidgetRef)` (assembles the controller with real bridges + store + adapter, syncs DeviceActivity monitors, runs the pass).
    - **Hooks (gated + inert)**: `main.dart` `didChangeAppLifecycleState` runs the reconcile on `resumed` when `VerificationConfig.enabled`; `cycleStatus` fire-and-forget `markManual`/`clearManual` on a verified goal so a manual check-in freezes the day (D9).
    - **Known follow-ups (flagged, not blocking a dark build)**: (1) `runVerificationReconcile` calls `syncMonitoredGoals` on every foreground; the native side stop-all+restarts, which may reset DeviceActivity threshold accumulation mid-interval — should be diffed / moved to goal-CRUD before enabling Screen Time. (2) `applyAutoVerdict` is verified by inspection (mirrors the well-tested `cycleStatus`) — add a provider-level integration test when the feature activates. (3) streak-tail recompute across reconcile passes is single-day like manual edits (batch writes apply ascending, so within-pass streaks are correct).
  - *Verification*: `flutter analyze` clean (0 errors/warnings); **mobile 179/179** (+6 wiring-builder tests). No behavioural change (flag off).
  - *Current Status*: Slice 4b **complete + verified**. The verification feature is now wired end-to-end behind `VerificationConfig` (dark). **Remaining before launch**: compile the Swift + create the Xcode target/App Group/entitlement (TO_SIMO_DO); then UI (verified-goal creation flow + auto/`?` badges), the notification layer (Screen-Time threshold-cross + couldn't-verify nudge, D11), and backup export/import round-trip of `verify_*`. Flip `VerificationConfig.enabled` once the native layer compiles and the entitlement is approved.

- [2026-07-13 22:15]: **Auto-Verified Habits — UI slice: verified-goal creation control + badge**
  - *Details*: The creation-side UI so a user can turn a habit into an auto-verified one (pick a template + threshold) and see which habits are auto-verified. Rendered only when `VerificationConfig.enabled`, so it's dark until the native layer ships.
  - *Tech Notes*:
    - **`mobile/lib/ui/widgets/verification_rule_field.dart`**: `VerificationRuleField` — a `CupertinoSwitch` to enable auto-verify, a `ChoiceChip` row over the 9 `VerificationCatalog` templates, and a clamped +/- threshold stepper; emits a `VerificationRule?` via `onChanged` (off ⇒ null ⇒ manual habit). Shows the "Needs an Apple Watch" soft-warning for Watch-gated templates (D5/D9). Plus display helpers (`verificationRuleSummary` → "≥ 10,000 Steps" / "≤ 120 min Screen time", label/unit/comparator formatting) and a small `VerificationBadge` (Material `Icons.verified`).
    - **`habit_management_modal.dart`**: new `_verificationRule` state threaded through create (`Goal(... verificationRule:)`), edit (`copyWith(verificationRule:, clearVerificationRule:)`), `_onEdit` load, and all resets; the field renders after the reminder row **gated by `VerificationConfig.enabled`**. The habit list rows show the `VerificationBadge` when `habit.isVerified`.
    - **Follow-ups (TO_SIMO_DO)**: i18n of the template labels/summary (currently English fallbacks), the design-kit restyle of the field to match the app's sheet/Cupertino idiom, and on-device visual QA — all deferred because the UI is dark until the flag flips.
  - *Verification*: `flutter analyze` clean; **mobile 188/188** (+8 field/badge tests). No behavioural change (flag off).
  - *Current Status*: Creation UI **complete + verified** (dark). **Remaining before launch**: the couldn't-verify `?` day indicator + "grant Health access" fix-it affordance (display polish), the notification layer (D11), backup round-trip of `verify_*`, and the native Xcode compile/entitlement — then flip `VerificationConfig.enabled`.

- [2026-07-13 23:00]: **Auto-Verified Habits — notification layer (D11)**
  - *Details*: The two accountability-forward, on-by-default notifications: the real-time Screen-Time limit alert (native) and the couldn't-verify nudge (Dart). Opt-in celebration/failure summaries are a deferred follow-up. Inert while the flag is off.
  - *Tech Notes*:
    - **Screen-Time threshold-cross (native, real-time)**: `DeviceActivityMonitorExtension.eventDidReachThreshold` now posts a `UNUserNotificationCenter` local notification ("Screen time limit reached") the instant usage crosses the limit — the flagship notification, independent of the flaky interval-end callback. (Swift; compile-pending like the rest of the extension.)
    - **Couldn't-verify nudge (Dart)**: `NotificationService.showVerificationNudge(goalId, title)` shows an immediate `flutter_local_notifications` banner ("Couldn't verify '…' — did you keep it?") with a **stable per-goal id** (re-firing replaces, never stacks). `runVerificationReconcile` fires it via the pure `couldNotVerifyNudges(report, titlesById)` mapper — collapsed to **one banner per goal (latest day)**, dropping untitled goals.
    - **Follow-ups (flagged)**: i18n of the notification copy + channel name; a dedicated notification-settings toggle (currently always-on when the feature is on); cross-session de-dup so a nudge doesn't re-alert on every foreground within its nag window (the stable id prevents stacking but not re-alerting); the opt-in HealthKit celebration + end-of-day failure summary (OFF by default per D11).
  - *Verification*: `flutter analyze` clean; **mobile 189/189** (+2 nudge-mapper tests). No behavioural change (flag off).
  - *Current Status*: Notification layer **complete + verified** (dark). **Remaining before launch**: the couldn't-verify `?` day indicator + "grant Health access" fix-it affordance (display polish), backup export/import round-trip of `verify_*`, the native Xcode compile/entitlement — then flip `VerificationConfig.enabled`.

- [2026-07-13 23:40]: **Auto-Verified Habits — display polish (fix-it + couldn't-verify indicator)**
  - *Details*: The proactive "Grant Health access" affordance and the reusable "?" couldn't-verify indicator. The deep calendar-cell wiring of the "?" is deferred (needs surgery in the calendar/day-details widgets and is inert while the feature is dark).
  - *Tech Notes*:
    - **Grant Health access (D9)**: `habit_management_modal` shows a "Grant Health access" secondary button below the rule field when the current rule is HealthKit (gated by `VerificationConfig.enabled`); `_grantHealthAccess` calls `healthKitBridgeProvider.requestAuthorization({typeId})` — a *proactive* permission request at creation, rather than waiting to infer denial from a run of couldn't-verify days.
    - **`CouldNotVerifyChip`** (in `verification_rule_field.dart`): a tappable "?" circle with a "Couldn't verify — tap to resolve" tooltip, ready to drop into the habit calendar's day cells.
    - **Deferred (flagged)**: wiring `CouldNotVerifyChip` into the calendar day cells / day-details modal (keyed off `SqfliteVerificationStateStore.couldNotVerifyDays`) so unresolved days actually render the "?" and open the manual-resolve path; and the *inferred* fix-it prompt (surface "grant access" automatically after N consecutive couldn't-verify HealthKit days, D9). Both need real verified data (flag on) to be meaningful.
  - *Verification*: `flutter analyze` clean; **mobile 190/190** (+1 chip test). No behavioural change (flag off).
  - *Current Status*: Display polish **partially complete** (fix-it affordance + reusable chip done; calendar `?` wiring deferred). **Remaining before launch**: backup export/import round-trip of `verify_*`, the calendar `?` wiring, and the native Xcode compile/entitlement — then flip `VerificationConfig.enabled`.

- [2026-07-14 00:15]: **Auto-Verified Habits — backup round-trip of `verify_*`**
  - *Details*: Closed the deferred Slice-2 coherence hole: a backup export/restore now preserves a habit's verification rule instead of silently turning it manual. Covers both apps and every stage of their import pipelines.
  - *Tech Notes*:
    - **Mobile**: `PrivateLocalDatabase.exportData` now emits the five `verify_*` fields in the `habits` array; `import_merge.dart` carries them through all three stages — both `normalizeBackup` shapes (cloud `raw['goals']` + native `raw['habits']`), the canonical validator (with `_str`/num sanitization), and `_goalRow` (the DB write).
    - **Desktop**: `DesktopPrivateDb.exportData` emits `verify_*`; the import pipeline carries them through `DesktopBackupImportService.buildCanonicalModel` (normalize), `import_merge.dart`'s validator + insert path, and `DesktopPrivateDb._goalRow`.
    - `goal_logs.value` was already exported/imported on both sides (from Slice 2), so the HealthKit measured number round-trips too.
  - *Verification*: `flutter analyze` clean on both apps. **Mobile 191/191** (+1 import round-trip test asserting the rule survives export→normalize→validate→write→`VerificationRule.fromColumns`). Desktop **143 pass / 2 pre-existing failures** (unchanged — `goal_logs.value` lossless-import + icloud-sync-card, both confirmed pre-existing and unrelated).
  - *Current Status*: Backup round-trip **complete + verified**. The auto-verified-habits feature is now **functionally complete in Dart** and dark behind `VerificationConfig`. **The only remaining work is yours in Xcode** (compile the Swift + create the extension target / App Group / Family Controls entitlement, per TO_SIMO_DO) plus the deferred calendar `?` wiring; then flip `VerificationConfig.enabled` (HealthKit can go before Screen Time). Follow-ups (non-blocking): i18n of UI/notification copy, a notification-settings toggle, cross-session nudge de-dup, opt-in celebration/failure notifications, `syncMonitoredGoals` diffing, an `applyAutoVerdict` provider-level integration test.

- [2026-07-13]: Remove dead `biometricLockProvider`
  - *Details*: Deleted the unused `biometricLockProvider` (`FutureProvider<bool>` reading secure-storage key `pref_biometric_lock` with KeyStore-corruption recovery) from `mobile/lib/providers/shared_prefs_provider.dart`. A repo-wide grep confirmed zero `ref.watch`/`ref.read` consumers — biometric lock is fully served by `settingsProvider.biometricLock` and the gate providers in `mobile/lib/ui/widgets/biometric_lock_gate.dart` (`biometricUnlockedProvider` / `biometricLockEnabledForUserProvider` / `biometricLockActiveProvider`), introduced by the earlier "Biometric Face ID app lock" fix. Also dropped the now-orphaned `import '../core/app_logger.dart';` (only used inside the removed provider). `secureStorageProvider` and its imports are untouched.
  - *Tech Notes*: No new dependencies, no API changes. Verified against current `main`: `flutter analyze` clean (0 errors/warnings; 20 pre-existing info-level lints), `flutter test` **191/191 pass**. The secure-storage key `pref_biometric_lock` is no longer read anywhere.

- [2026-07-14 09:00]: **Auto-Verified Habits — closing the deferred Dart follow-ups (package layer)**
  - *Details*: Start of the punch-list that finishes the feature in Dart before on-device HealthKit testing. This first slice is the pure `evolve_verification` core: it exposes the verdicts a reconcile pass wrote (so the notification layer can fire celebration/failure alerts) and adds a persisted "already nudged" concept to the store contract (so the couldn't-verify nudge stops re-alerting on every foreground).
  - *Tech Notes*:
    - `ReconcileReport.written` (int) → replaced by `ReconcileReport.writes` (`List<LogWrite>`), with `written` kept as a derived getter and `changedAnything` re-expressed over it. The list is naturally de-duplicated across foregrounds because `VerificationService` only emits a write when the verdict actually changed — so D11 celebration/failure notifications need no bookkeeping of their own.
    - `VerificationStateStore` contract gained `nudgedDays(goalId)` + `markNudged(goalId, day)`. `markNudged` is a no-op unless the day is currently couldn't-verify, and the mark is dropped whenever the day resolves (`resolveCouldNotVerify`), is frozen manual (`markManual`), or the goal is deleted — so a day that lapses back into couldn't-verify can nudge afresh. Implemented in `FakeVerificationStateStore`; the on-device sqflite implementation + migration land in the next mobile slice.
  - *Verification*: `cd packages/evolve_verification && flutter test` → **49 pass** (44 baseline + 4 fake-store nudged tests + 1 controller `report.writes` test). Mobile compiles against the change (no `report.written` readers in the app; `verification_wiring`/`verification_providers` analyze clean).
  - *Current Status*: Package slice **complete + verified**. **Next**: mobile sqflite store — add the `nudged_at` column + a v1→v2 migration on `verification_state.db` and implement `nudgedDays`/`markNudged`.

- [2026-07-14 09:20]: **Auto-Verified Habits — mobile store: `nudged_at` column + v1→v2 migration**
  - *Details*: The on-device implementation of the new nudge-dedup store methods. Because the `verification_state.db` is a dedicated, versioned database (and all verification commits post-date the 1.1.1 release, so no shipped build has this table), the column is added via a clean schema-version migration rather than a hot patch.
  - *Tech Notes*:
    - `SqfliteVerificationStateStore.createTable` now includes a nullable `nudged_at TEXT` column; `migrateToV2(db)` runs `ALTER TABLE … ADD COLUMN nudged_at TEXT`, guarded by a `PRAGMA table_info` probe so it is idempotent and safe on a table that already has the column.
    - `verificationStateStoreProvider` bumped `version: 1 → 2` with an `onUpgrade` that calls `migrateToV2` for `oldVersion < 2`. The post-open idempotent `createTable` call is retained.
    - `nudgedDays(goalId)` selects couldn't-verify rows with `nudged_at IS NOT NULL`; `markNudged(goalId, day)` UPDATEs the live couldn't-verify row's `nudged_at`, so it no-ops once the day resolves/freezes (the row is gone) — matching the fake's semantics.
  - *Verification*: `flutter test test/verification_state_store_test.dart` → **15 pass** (10 baseline + 4 nudged-marker tests + 1 v1→v2 migration test proving the ALTER is idempotent and the column works). `flutter analyze` clean on the touched files.
  - *Current Status*: Mobile store slice **complete + verified**. **Next**: i18n foundation for the verification UI + notification copy, then the settings toggles and the wiring behaviour that consumes `nudgedDays`/`markNudged`.

- [2026-07-14 10:00]: **Auto-Verified Habits — i18n of the verification UI + notification copy**
  - *Details*: Closed the "English-only fallbacks" follow-up. Every user-facing verification string is now a slang key across all five locales (en/it/es/de/ar), plus the seven notification-settings labels the next slice will render. (Arabic verification copy is machine-authored MSA and flagged in `TO_SIMO_DO` for a native review pass.)
  - *Tech Notes*:
    - New top-level `verification` i18n section (16 keys incl. nested `templates` [9 metric labels] + `units` [4]) and 7 `notifications.verification*` keys, injected append-only into all five `*.i18n.json` and regenerated with `dart run slang`.
    - `verification_rule_field.dart`: the pure helpers `verificationTemplateLabel` / `verificationUnitSuffix` / `verificationRuleSummary` now take a `Translations` argument (keeps them testable via `AppLocale.en.buildSync()` and usable off-widget); the widgets read `context.t.verification.*`. Summary assembly reworked so the unit joins with a space only when present — output is byte-identical to before for en (`≥ 10,000 Steps`, `≤ 120 min Screen time`).
    - `notifications.showVerificationNudge` now pulls its title/body/channel name+description from `t.verification.*` (global `t`, isolate-safe); extracted a shared `_verificationDetails` getter the celebration/failure notifications will reuse.
    - `habit_management_modal.dart`: the "Grant Health access" button label is localized.
    - Widget tests that render the now-localized widgets are wrapped in `TranslationProvider` (required for `context.t`).
  - *Verification*: `flutter analyze` clean on the touched files; `flutter test test/verification_rule_field_test.dart` → **9 pass** (helper tests pass an explicit `Translations`; widget tests render en). Generated `translations*.g.dart` remain gitignored (regenerated on checkout).
  - *Current Status*: i18n slice **complete + verified**. **Next**: the three notification-settings toggles (nudges on by default; celebration + failure-summary opt-in) wired to new `notif_*` prefs.

- [2026-07-14 10:30]: **Auto-Verified Habits — notification-settings toggles + prefs**
  - *Details*: Adds user control over the auto-verification notifications: a "Couldn't-verify nudges" toggle (on by default) plus opt-in "Goal celebrations" and "Missed-habit alerts" (off by default). This slice lands the settings surface + persistence; the reconcile wiring consumes the prefs in the next slice.
  - *Tech Notes*:
    - `AppSettings` gains `verificationNudges` (default true), `verificationCelebrations` (false), `verificationFailureSummary` (false) — threaded through the constructor, `copyWith`, `_defaultSettings`, `_loadFromPrefs`, and `_settingsFromPrivateRow`.
    - **Storage = device-local SharedPreferences** (`notif_verification_nudges` / `_celebrations` / `_failure_summary`), mirrored in both `_saveToPrefs` and `_saveToPrivate`. This deliberately follows the `biometricLock` precedent (see the line ~516 comment) to avoid a private-DB **and** a Supabase `profiles` schema migration; the prefs are not synced (auto-verification is iOS-device-specific anyway), so the Supabase push/pull are untouched and a stale server value can't flip them.
    - `notification_settings_screen.dart`: a new "HABIT VERIFICATION" section (three `_buildSwitchRow`s, icons `badgeCheck`/`partyPopper`/`triangleAlert`) rendered only `if (VerificationConfig.enabled)`. Each toggle requests notification permission when enabled, mirroring the existing rows.
  - *Verification*: `flutter analyze` clean on both files; `flutter test test/settings_separation_test.dart` → **2 pass** (private-mode settings still never touch the cloud). Copy is localized (previous slice).
  - *Current Status*: Settings slice **complete + verified**. **Next**: the reconcile wiring — consume `verificationNudges` to gate + de-dup the nudge (via the store's nudged marker), and fire opt-in celebration/failure notifications off `report.writes`.

- [2026-07-14 11:00]: **Auto-Verified Habits — reconcile wiring: nudge de-dup consumption + opt-in celebration/failure (D11)**
  - *Details*: Wires the notification prefs + the persisted nudged marker into `runVerificationReconcile`, closing both the cross-session nudge de-dup follow-up and the opt-in celebration/failure-summary follow-up.
  - *Tech Notes*:
    - **Nudge de-dup**: nudges now gated by `settings.verificationNudges` and filtered through the pure `unnudgedNudges(candidates, alreadyNudged)` against `store.nudgedDays(goalId)`; each fired nudge calls `store.markNudged` so it won't re-alert on the next foreground within the nag window. A later couldn't-verify day for the same goal still nudges (the marker is per goal-day and drops when a day resolves).
    - **Celebration (opt-in)**: gated by `settings.verificationCelebrations`; the pure `celebrationNotices(writes, titles, todayKey)` selects `pass` writes dated *today* with a known title (backfilled past passes are intentionally silent). Driven by `report.writes`, which `VerificationService` only emits on a *changed* verdict, so each goal celebrates at most once — no separate bookkeeping.
    - **Failure summary (opt-in)**: gated by `settings.verificationFailureSummary`; one banner covering the fresh `missed` writes this pass (uses `failureSummaryBodyOne` when a single habit, `…Many` with a count otherwise). Also write-driven → fires once per newly-missed day.
    - `NotificationService` gained `showVerificationCelebration` (id keyed to goal+day) and `showVerificationFailureSummary`, both reusing the shared `_verificationDetails` channel. `runVerificationReconcile` captures a single `now` and passes it to both `reconcile` and the today-key check to avoid a midnight-boundary mismatch. New import: `settings_provider` (no cycle).
  - *Verification*: `flutter analyze` clean; `flutter test test/verification_wiring_test.dart` → **13 pass** (+3 `unnudgedNudges`, +2 `celebrationNotices`). The orchestration itself stays pure-helper-tested (it needs a `WidgetRef`); the `applyAutoVerdict` provider-level test is the next slice.
  - *Current Status*: Wiring behaviour **complete + verified**. Notifications now: nudge (on, de-duped) + celebration/failure (opt-in), all gated. **Next**: wire the couldn't-verify "?" into the calendar + day-details, then the `applyAutoVerdict` integration test.

- [2026-07-14 11:40]: **Auto-Verified Habits — couldn't-verify "?" wired into the calendar + day-details**
  - *Details*: Closes the last deferred UI hole (D6): unresolved auto-verifications now actually render a "?" in the habit calendar and open the manual-resolve path. This was previously inert (the `CouldNotVerifyChip` existed but nothing fed it data).
  - *Tech Notes*:
    - New `couldNotVerifyDaysProvider` (`FutureProvider<Map<String, Set<DateTime>>>` in `verification_wiring.dart`): reads `SqfliteVerificationStateStore.couldNotVerifyDays` for the currently-verified goals (via `verifiableGoalsFrom`). Reactive to goal changes; returns empty when the feature is off / no verified goals / the store can't open (wrapped in try-catch → degrades to "no ?", keeping widget tests that transitively mount the calendar safe). `runVerificationReconcile` invalidates it after any pass that `changedAnything`.
    - **Day-details modal** (`day_details_modal.dart`): watches the provider; `GoalLogCard` gained a `couldNotVerify` flag (true only when `status == null` **and** the day is in the goal's couldn't-verify set) that renders a primary-tinted "?" glyph + a localized "tap to resolve" hint in place of the pending circle. The card's existing tap → guarded `cycleStatus` is the resolve path (marks the day manual, which clears the couldn't-verify marker); the "?" clears instantly because the display gates on `status == null`.
    - **Calendar** (`habit_calendar_widget.dart`): `_DayCell` gained a `couldNotVerify` flag driving a small corner "?" badge (hidden in privacy mode); the per-day value is the aggregate "any active verified habit this day is unresolved". Tapping the cell opens the day-details modal as before.
    - Riverpod note: used `AsyncValue.asData?.value` (this pinned version lacks `valueOrNull`).
  - *Verification*: `flutter analyze` clean on all three files; new `goal_log_card_verification_test.dart` → **3 pass** (renders "?" + hint when couldNotVerify; hidden otherwise; tap fires the resolve callback). Full mobile suite re-run in the final slice.
  - *Current Status*: Calendar "?" wiring **complete + verified**. **Next**: the `applyAutoVerdict` provider-level integration test, then the full-suite + docs sweep.

- [2026-07-14 12:00]: **Auto-Verified Habits — `applyAutoVerdict` provider-level integration test**
  - *Details*: Replaces the "verified by inspection" note with a real test of the write path the reconcile drives (`GoalLogVerificationWriter` → `HabitLogsNotifier.applyAutoVerdict`).
  - *Tech Notes*: `test/apply_auto_verdict_test.dart` stands up `habitLogsProvider` in Private mode over the shared `FakePrivateDataStore` (same `ProviderContainer` pattern as `private_mode_no_supabase_test`), never initialising Supabase. A `_RecordingStore` subclass captures `setHabitLog` args; a `_ThrowingStore` forces the failure branch. Three cases: (1) a `done` verdict persists `status='done'` + the measured `value` + a positive streak and updates the in-memory logs; (2) a `missed` verdict persists correctly; (3) a persistence failure rolls back the optimistic in-memory update (the expected `[HabitLogs] applyAutoVerdict error` log confirms the rollback path ran).
  - *Verification*: `flutter analyze` clean; `flutter test test/apply_auto_verdict_test.dart` → **3 pass**.
  - *Current Status*: `applyAutoVerdict` test slice **complete + verified**. All targeted deferred Dart follow-ups are now closed; final full-suite sweep + docs/memory/TO_SIMO_DO next.

- [2026-07-14 12:40]: **Auto-Verified Habits — adversarial-review fixes (6 confirmed findings)**
  - *Details*: Ran a 5-dimension adversarial review (correctness / SQLite migration / Riverpod / i18n / settings) over the whole deferred-items diff, each finding independently verified before counting. Fixed all 6 confirmed findings.
  - *Tech Notes*:
    - **Failure-summary count (medium)**: `runVerificationReconcile` counted fail *writes*, so one habit missing several backfilled days read as "N habits". Now counts **distinct goals** (`.map(goalId).toSet()`).
    - **"?" resolve dead-end (medium ×2)**: `couldNotVerifyDaysProvider` returned every unresolved marker unbounded, so the calendar/day-details showed a "tap to resolve" "?" on days older than the check-in window (where the tap only toasts). The provider now **bounds its result to the resolvable window (today + yesterday)** — every rendered "?" is actionable.
    - **migrateToV2 crash on a missing table (medium)**: `PRAGMA table_info` returns 0 rows for an absent table, so the guard passed and `ALTER TABLE` threw "no such table" inside `onUpgrade`, failing `openDatabase` and breaking the whole subsystem for that population. Added an `if (columns.isEmpty) return;` early-out (the post-open `createTable` builds it with `nudged_at`).
    - **Stale "?" after manual un-resolve (medium)**: the keep-alive provider wasn't invalidated when a manual resolve cleared the store marker. The day-details resolve tap now `ref.invalidate(couldNotVerifyDaysProvider)` for verified habits.
    - **failureSummaryBodyOne copy (low)**: dropped the hard-coded "today" (the miss is a finalized *past* day) across all 5 locales + `dart run slang`.
    - **Marker accumulation (bundled with the "?" finding)**: added `VerificationStateStore.pruneCouldNotVerifyBefore(goalId, day)` (contract + fake + sqflite); `VerificationController.reconcile` prunes markers older than the backfill window so the bookkeeping table can't grow without bound.
  - *Verification*: `evolve_verification` **51 pass** (+2: fake prune + controller prune-on-reconcile); mobile targeted store/wiring/apply/card tests **green** (+2: sqflite prune + migrateToV2-missing-table); `flutter analyze` clean. Full mobile + desktop sweep re-run below.
  - *Current Status*: Review fixes **complete + verified**. Remaining: final full-suite counts + memory update.
