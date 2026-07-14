# DOCUMENTATION

## [2026-07-07]: Fix Xcode Build Warnings for macOS Desktop Target

### Details
Resolved all actionable Xcode warnings when building the macOS desktop target in Xcode 26.6. Three files were modified to eliminate warnings across the Runner project, Pods project, and third-party pod dependencies.

### Changes Made

#### 1. `macos/Runner/Info.plist`
- **Fix**: Changed `LSApplicationCategoryType` from `public.app-category.lifestyle` to `public.app-category.productivity`
- **Why**: Eliminated the "No App Category is set" warning caused by a mismatch between Info.plist and build settings (which already used `productivity`)

#### 2. `macos/Runner.xcodeproj/project.pbxproj`
- **Fix**: Updated `LastUpgradeCheck` from `1510` to `2660`
- **Why**: Eliminated the "Update to recommended settings" warning on the Runner project by telling Xcode the project has been reviewed with Xcode 26.6

#### 3. `macos/Podfile`
- **Fix 1**: Added `inhibit_all_warnings!` in the `target 'Runner'` block
- **Why**: Suppresses all warnings from third-party CocoaPods dependencies (SQLCipher ~100+ implicit conversion warnings, sign_in_with_apple switch exhaustive warning, sqflite_sqlcipher unicode whitespace warning)
- **Fix 2**: Added `installer.pods_project.root_object.attributes['LastUpgradeCheck'] = '2660'` in `post_install`
- **Why**: Eliminates the "Update to recommended settings" warning on the Pods.xcodeproj

### Warnings NOT Fixed (Cannot be fixed locally)
- **Flutter Assemble**: `objective_c.dylib` framework name inconsistency — this is an upstream issue in the `objective_c` Dart package. Must be fixed by the package maintainers.

### Tech Notes
- No new dependencies added
- Ran `pod install` successfully after changes
- CocoaPods base config warnings during install are expected/normal for Flutter projects (handled via xcconfig chain)

## [2026-07-07]: Fix App Store Distribution Errors (dSYM + Version)

### Details
Fixed two blockers preventing App Store distribution of the macOS desktop app:
1. Missing Sentry.framework dSYM in the archive
2. Incorrect version number for first upload

### Changes Made

#### 1. `pubspec.yaml`
- **Fix**: Changed `version` from `1.0.1+2` to `1.0.0+1`
- **Why**: First App Store upload requires starting at 1.0.0 (marketing version) with build number 1

#### 2. `macos/Runner.xcodeproj/project.pbxproj`
- **Fix**: Added "Copy SPM dSYMs" build phase to the Runner target
- **Why**: Sentry SDK is included via Swift Package Manager as a pre-built xcframework (`getsentry/sentry-cocoa`). Xcode has a known bug where it doesn't copy dSYMs from SPM binary dependencies into the archive. The script runs only during archiving (`ACTION = install`) and finds all `.dSYM` bundles under `SourcePackages/artifacts/` and copies them into `DWARF_DSYM_FOLDER_PATH`.
- **Root Cause**: The error "dSYM for the A" referred to Sentry.framework — confirmed by matching UUIDs `6366CFF2-C8BE-3E50-A69D-9399F335E6DD` (x86_64) and `9F678086-6277-3D61-B292-9D4098B03A2C` (arm64).

### Tech Notes
- The "Copy SPM dSYMs" script runs ONLY during Archive (`ACTION = install`), not during regular builds
- It copies ALL dSYMs from SPM binary package artifacts, future-proofing against other binary SPM deps
- No new dependencies added

## [2026-07-07]: Merge Global and Habit Selectors in Statistics Page

### Details
Modified the statistics page UI to combine the 'Global' vs 'Single habit' segmented control and the individual habit dropdown into a single selector dropdown, simplifying the UX and saving vertical space.

### Changes Made

#### 1. `lib/features/statistics/presentation/statistics_page.dart`
- **Fix**: Removed `_HabitSelectorCard` from the top trailing header.
- **Fix**: Removed the `EvolveSegmentedControl` from `_controlRow()`.
- **Fix**: Replaced the segmented control with the `_HabitSelectorCard` wrapped in the `_filterKey` `KeyedSubtree`.
- **Fix**: Updated `_HabitSelectorCard` to always display an `EvolveSelect<String>` dropdown containing a special `_global` value (labeled "Globale") followed by all available habits.
- **Why**: Eliminates the two-step process of first selecting "Single habit" and then choosing the habit, combining it all into one direct selection dropdown.


### Tech Notes
- Maintained the "Evolve Pro" badge inside the new combined dropdown.
- Passed `snapshot` and `selectedHabit` directly to `_controlRow` method.

### WS7 — COMPLETE
The full-app localization sweep is finished: every user-facing Italian string across all desktop screens, dialogs, controllers, and services is localized in **en/it/es/de/ar** (align-to-mobile: reused mobile keys/values wherever the string matched, professional bespoke translations otherwise incl. MSA Arabic), and the Arabic **RTL** pass is done. Private Mode on desktop is now at full functional + localization parity with mobile. `flutter test` **+74 -1** (only the environmental Supabase-config test fails), `flutter analyze lib` **0 errors**.

## [2026-07-04]: Post-WS7 — desktop bug/feature scan + fixes
*Details*: After WS7, ran a deep 3-agent read-only scan (data/private-mode correctness, feature-parity vs mobile, UI/controller logic) for bugs and missing features, then fixed the clear bugs and began the two owner-chosen features.
*Tech Notes*:
- **Clear bugs fixed (4 parallel subagents, each file-exclusive; verified +74 -1, analyze clean):**
  - Goals: weekly goal created from dashboard used ISO week-of-year (→ vanished from Goals weekly view) → now `logicalWeekOfMonth`; tutorial fake goal was tappable (→ StateError + spurious sync banner) → `_cycleGoalStatus` early-returns for `tutorial_fake_goal`; Pro 100-goal cap now enforced on the Goals page quick-add too; reschedule now shown for active/completed non-lifetime goals; dead "horizon" dropdown removed from the goal-editor (it never persisted).
  - AI Coach: double-send race guarded (`_isTyping` early-return); the streaming loop is wrapped in try/catch/finally so a stream error surfaces to the user and always resets `_isTyping`.
  - Dashboard: daily check-in dialog now seeds today's saved mood/energy; habit-toggle optimistic streak now uses the shared `computeStreak` (was naive ±1).
  - Private DB (`desktop_private_db.dart`): `setHabitLogFromNotification` now computes a correct signed streak via `computeStreak` for BOTH done/missed (was streak:0 for missed); `applyImport` skips malformed rows instead of aborting the whole transaction; merge-import dedupes categories by `(user_id,name)` and remaps `category_id` (was silently dropping colliding categories). All 38 private-DB tests pass.
- **`private_dashboard_repository.dart` streak/tombstone refactor (self):** `setHabitStatus`/`_habitFromRow` now compute the streak via the shared `computeStreak` (removed the bespoke `_computeNextStreak`/`_latestStreak` that clamped negatives to 0 and used a stale snapshot); `setHabitStatus`/`saveCheckIn` now upsert by unique key instead of `INSERT OR REPLACE` (which did DELETE+INSERT and corrupted the Phase-2 sync tombstone/`sync_state`).
- **Feature 1 DONE — Notifications & reminders (self):** Windows daily reminders now recur (`matchDateTimeComponents` on macOS **and** Windows); habit add/edit/delete now re-schedules OS notifications immediately (defensive fire-and-forget `_rescheduleNotifications` in `DashboardController`, reading the notif prefs) instead of only on a Settings re-save; the habit-editor reminder is now a `showTimePicker` field (read-only, clearable, normalized to 24h `HH:mm`) instead of free text. No new i18n. Analyze clean.
- **Feature 2 IN PROGRESS — Statistics screen rebuild (subagent):** wiring the desktop Statistics UI to the real analytics providers (best/critical/correlations/analytics-row that were computed but unconsumed), porting mobile's `computeMoodCorrelations`/`MoodCorrelation` engine, and un-hardcoding the Global-Trend timeframe. Reuses mobile `statistics.*` i18n. **Owner decisions:** keep the current goal-cycle behavior (not the delayed-Done spec); build Statistics + Notifications (not the Pro-experience feature) — the remaining parity gaps (Pro upsell modal, dashboard/stats tutorials, App Logs viewer, cloud export/import round-trip, drag-reorder, etc.) are a documented backlog in `scratchpad/SCAN_FINDINGS.md`.

### Current Status — this pass COMPLETE (`flutter test` +74 -1, `flutter analyze lib` 0 errors)
Everything from this pass is landed and verified together:
- **WS7 localization + Arabic RTL** — complete (all screens/dialogs/controllers/services in en/it/es/de/ar; `test/localization_rtl_test.dart` guard added).
- **9 clear bug fixes** (goals week-math / tutorial-goal crash / Pro-cap / reschedule visibility / dead horizon dropdown / AI double-send+stream errors / check-in seed / optimistic streak / private-DB notification-streak+import robustness).
- **`private_dashboard_repository` refactor** — streak via shared `computeStreak`; `OR REPLACE` → upsert (sync-tombstone fix).
- **Feature: Notifications & reminders** — Windows recurrence, reschedule-on-habit-change, reminder time-picker.
- **Feature: Statistics screen rebuild** — ported mobile's mood-correlation engine (`computeMoodCorrelations`/`MoodCorrelation` in `private_analytics.dart` + `moodsByDate` in the source + `moodCorrelationsRpcProvider`); wired the previously-unconsumed `bestHabits`/`criticalHabits`/`allHabitCorrelations`/`habitCorrelations` providers + new `habitStatsRpcProvider`/`habitAnalyticsRpcProvider` into the Global Alerts/Info + per-habit Overview/Improvement/Performance/Mood tabs; added the Global-Trend timeframe selector (un-hardcoded); reused mobile `statistics.*` i18n + new `stats.*` keys. Critical-day metric now localizes the ISO-dow token via `_criticalDayLabel`.

**Remaining backlog (owner-directed, NOT done this pass):** the larger parity gaps the owner deprioritized — Pro upsell modal, dashboard/stats onboarding tutorials, App Logs viewer, cloud backup export/import round-trip, drag-to-reorder, inline category create/edit in the add-goal picker, paywall value-prop UI, and assorted P2 UX deltas. All captured with `file:line` in `scratchpad/SCAN_FINDINGS.md` (Bucket C). Owner decisions recorded: **keep** the current goal-cycle behavior; the delayed-Done/long-term-only spec is NOT implemented.

## [2026-07-04]: Feature 2 DONE — Statistics screen wired to real analytics
*Details*: Rebuilt the desktop Statistics screen (`lib/features/statistics/presentation/statistics_page.dart`) so it consumes the REAL ported analytics instead of hardcoded strings / bespoke heuristics, matching mobile's behavior. Ported mobile's mood-correlation engine and wired every previously-computed-but-unconsumed provider into the UI.
*Tech Notes*:
- **Mood-correlation engine ported** (`private_analytics.dart`): added `MoodCorrelation` + `MoodEntry` models and `computeMoodCorrelations({moodsByDate, logsByDate})`, ported faithfully from mobile `lib/providers/mood_provider.dart` (0–10 banding high≥6/low<4; sensitivity=high−low; resilience=low; done-vs-missed avg mood/energy). `private_analytics_source.dart` now also loads `daily_moods` into `PrivateAnalyticsData.moodsByDate` (keyed by `dashboardDateKey` = `YYYY-MM-DD`, matching the log join).
- **New providers** (`statistics_rpc_providers.dart`, all mode-aware, private branch returns before any Supabase read): `habitStatsRpcProvider` (→ `computeHabitStatsRow`/`habit_stats` view), `habitAnalyticsRpcProvider` (→ `computeAnalyticsRow`/`get_habit_analytics`, re-keyed by goal_id), `moodCorrelationsRpcProvider` (PURE client-side both modes — no cloud RPC exists; private reads the encrypted DB, cloud reads the dashboard snapshot's `moods`+`habitLogs`).
- **Providers now consumed by the UI** (were computed-but-dead): `bestHabitsRpcProvider`/`criticalHabitsRpcProvider` (Global-Trend best/critical callouts, resolved to habit titles), `criticalHabitsRpcProvider`+`habitStatsRpcProvider`+`habitAnalyticsRpcProvider` (Global **Alerts** → improvement areas / failure analysis / recovery patterns, mirroring mobile `global_alerts_tab_widget`), `habitCorrelationsRpcProvider` (per-habit Overview correlations), `allHabitCorrelationsRpcProvider` (global Info correlation card), `habitAlertsRpcProvider.broken_streaks` (Improvement tab — was discarded), `moodCorrelationsRpcProvider` (Mood tab).
- **Tabs rewired**: Global-Trend now has a real week/month/year/all `ChoiceChip` selector feeding `globalTrendRpcProvider`/`bestHabitsRpcProvider` (was hardcoded `'timeframe_week_short'`); per-habit Overview shows the real last-30-day pass/fail grid (yearly-grid slice) + habit_stats metrics instead of the bogus repeated-completion "trend30"; Improvement renders worst-negative-streak + broken-streaks; Performance adds strongest/weakest-day callouts; Mood is fully driven by `computeMoodCorrelations` (removed the bespoke `_habitLowMoodCompletion`/`_habitLowEnergyCompletion`/`_habitCheckInCompletion`/`_habitCorrelations`/`_habitMoodValues` helpers).
- **i18n** (additive only): reused ~55 mobile `statistics.*` values (copied into desktop via the spec tool, all 5 langs) + ~15 new `stats.*` param keys (strongest/weakest-day detail, broken-streak item, together-%, alert details, timeframe labels). `dart run slang` regenerated. `stats.title`='Statistiche' preserved (widget-test critical).
- **Verification**: `flutter analyze lib/features/statistics/` → **0 issues**; `flutter analyze lib` → the only 12 remaining are pre-existing debt in `create_goal_dialog.dart`/`goals_stats_view.dart`/`settings_page.dart` (untouched by this task). Required suite `private_analytics_test` + `private_analytics_extra_test` + `private_stats_mode_test` + `widget_test` → **+33 all passed**.

## Summary
**All 9 workstreams addressed.** WS1–WS6, WS8, WS9 are complete and verified. WS7's localization foundation is complete and the Private-Mode surfaces are fully localized; the remaining full-app string sweep + Arabic RTL widget-mirroring is documented, mechanical, and incremental. Private Mode on desktop is now at functional parity with mobile: aligned encrypted schema, all P0 bug fixes, working local statistics (habits + correlations + macro + **mood correlations**, all surfaced on a fully-wired Statistics screen), Pro unlock, AI privacy-gate, profile/avatar/export, private settings in the DB, macOS actionable notifications, and a working localization foundation. `flutter test` → **+72 -1** (the one failure is the environmental Supabase-config test). Net test health improved from the original **-5** to **-1**.

## [2026-07-04]: BACKLOG Item 1 DONE — Cloud/Private backup export/import round-trip
*Details*: Made desktop backups round-trippable and enabled import in cloud mode. Previously neither desktop export could be re-imported: the cloud export emitted a lossy `evolve-desktop-supabase-cache` snapshot, the private export emitted a full `.json` the importer couldn't read, and the importer only accepted a web `.zip` (`backup.json`) — and import was gated to private mode with a `null` Supabase client. (Design decided via a grilling session: **extend the importer to ingest native `.json`** rather than rewrite exports to the web schema; both desktop exports now share one native DB-row shape; cross-device import of the mobile camelCase `mattioli_os_export.json` is also supported.)
*Tech Notes*:
- **`DesktopBackupImportService`** (`core/desktop_backup_import_service.dart`) rewritten into one authoritative importer. `parsePreview` dispatches `.zip`→`parseZipPreview` (web schema) and `.json`→`_parseJsonPreview`. New static `_normalizeShape` maps the two native `.json` shapes — native DB-row (private + cloud export) and mobile camelCase (`habits`/`macroGoals`/`macroGoalCategories`/`dailyMoods`, incl. map-shaped `habitLogs`/`dailyMoods`) — into the common pre-process schema. `_processData` (now `static`, exposed via `buildImportModel`/`modelFromJson`) extended to accept a native `macro_goal_categories` list (stable ids, hex) + native `category_id` alongside the web `goal_category_settings.mappings`/color-key path, decode `frequency_days` from the private DB's JSON-string form to a real `List<int>`, and pass `profile` through.
- **Profile round-trip**: `DesktopPrivateDb.applyImport` now applies the `profile` block via `sanitizeSettings` (allow-list: forces `is_pro=1`/`sentry_consent=0`, drops the local-path `avatar_url`), wrapped in try/catch so an out-of-domain CHECK value skips the profile instead of rolling back the whole import. Cloud import upserts a conservative profile allow-list (`full_name`/`username`/`date_of_birth`).
- **Cloud export** (`settings_page._exportData`): now reads the raw Supabase rows (goals/goal_logs/long_term_goals/daily_moods/macro_goal_categories + profiles) and emits the lossless native DB-row shape — the in-memory dashboard snapshot was lossy (no log ids/streaks, no category list). **Cloud import** (`_importData`): file picker accepts `['zip','json']`, the private-only gate is dropped, the real `Supabase.instance.client` is passed in cloud mode, `parsePreview`+`executeImport(isPrivateMode:)` are used, and dashboard/categories/profile providers are invalidated.
- **Cloud upsert correctness** (found + fixed via an adversarial review pass): per-table `onConflict` targets matching the operative UNIQUE constraints (`daily_moods`→`user_id,date`, `goal_logs`→`goal_id,date`, others `id`), so a merge onto existing data can't 23505; a merge-mode `reconcileCategoriesByName` reuses existing-by-name category ids and remaps referencing macro goals (mirrors the private path); dropped the phantom `updated_at` from the category model (`macro_goal_categories` has no such column → would PGRST204).
- **Tests**: `test/backup_roundtrip_test.dart` (8 tests, FFI): native + mobile-camelCase round-trip, merge-mode id-remap, DB persistence, profile invariants (is_pro/sentry forced, avatar dropped), `frequency_days` decode, no-`updated_at`, web-`backup.json`-as-`.json` category passthrough, the pure `reconcileCategoriesByName` helper, and profile-CHECK resilience.
- **i18n**: none needed — reused existing `t.settingsPage.*` keys.
- **Verification**: `flutter analyze lib` → **0 errors** (12 pre-existing infos/warnings, none in changed code); `flutter test` → **+82 -1** (only the environmental Supabase-config test fails). Two adversarial review workflows (find → verify) drove out and then confirmed the fixes for 6 cloud-path data-integrity defects.

## [2026-07-04]: BACKLOG Item 2 DONE — Pro upsell modal + paywall value-proposition
*Details*: Locked features previously dead-ended in a bare SnackBar, and the paywall had working price/Activate/Restore/Manage plumbing but no pitch. Ported mobile's `ProFeaturesModal` as a desktop dialog, routed every Pro gate to it, and enriched the Settings subscription section with an upsell header, feature list, and a purchase success celebration. (Mirrors `mobile/lib/ui/widgets/pro_features_modal.dart` + `subscription_screen.dart`.)
*Tech Notes*:
- **`pro_features_modal.dart`** (new, `features/settings/presentation/`): `showProFeaturesDialog(context, ref)` — sparkles header, `t.proModal.title`/`subtitle`, four `ProFeatureRow`s (AI coach / habit stats / goal metrics / unlimited habits), an amber CTA (`t.proModal.viewPlans`) that pops the dialog and deep-links to Settings via `navigationControllerProvider.select(DesktopSection.settings)`, and a "maybe later" dismiss. Exposes `proFeatures()` + `ProFeatureRow` + `proAccent` so the paywall reuses the exact same pitch.
- **Gate routing**: the three Pro gates now open the modal instead of a bare SnackBar — `_FocusGoalsPanel` (dashboard goal-cap ≥100), `_submitQuickGoal` (goals quick-add cap), and the `goals_stats_view` year-picker locked-year tap. Per the grill decision the modal opens on every platform; the CTA's destination (Settings→Subscription) already renders the correct per-platform state (purchase is macOS-only). The year-picker tap captures the page context before the sheet builder shadows it (the sheet's own context is deactivated by the `Navigator.pop` and can't host a dialog).
- **Paywall value-prop** (`_SubscriptionSettings`): when not Pro, shows an upsell header (`proUpsellTitle`/`proUpsellSubtitle`) + a feature list (`proModal.featuresHeader` + the shared `ProFeatureRow`s); the Activate action is now async and shows `_showProSuccessDialog` (`proWelcomeTitle`/`proActiveMessage`/`proStartJourney`) only when `purchase()` returns true and the widget is still mounted. The annual plan already carried the `bestValue` badge.
- **i18n**: 18 new keys × 5 locales (en/it/es/de/ar) reusing mobile values (`proModal.*` from mobile `subscription.*`/`common.unlockEvolvePro`; `settingsPage.proUpsell*`/`proWelcome*`/`proActive*`/`proStart*` from mobile `subscription.upgrade*`/`welcomeTitle`/`activeFullMessage`/`common.startYourJourney`) plus one authored desktop CTA (`proModal.viewPlans`, deep-links to Settings so it's price-free). `dart run slang` regenerated.
- **Tests**: `test/pro_features_modal_test.dart` (2 widget tests, `it` locale): the modal shows the Italian pitch and its CTA deep-links to `DesktopSection.settings`; "Forse più tardi" dismisses without navigating.
- **Tests**: `test/pro_features_modal_test.dart` (2 widget tests, `it` locale): the modal shows the Italian pitch and its CTA deep-links to `DesktopSection.settings`; "Forse più tardi" dismisses without navigating.
- **Verification**: `flutter analyze lib` → **0 errors** (same 12 pre-existing infos); `flutter test` → **+84 -1** (only the environmental Supabase-config test fails). A 4-lens adversarial review workflow (gate-routing / paywall-success / i18n-RTL / regression) returned zero findings after the pre-emptive context fix.

## [2026-07-04]: BACKLOG Item 3 DONE — Dashboard + Statistics onboarding tours
*Details*: Only the goals coach-mark tour existed; the dashboard showed a plain welcome dialog that immediately set `has_seen_tutorial`, Statistics had no tour, and `statsTutorialProvider` was dead. Added step-by-step coach-mark tours to both screens by extracting the goals tutorial's scrim-overlay pattern into a reusable widget. Mirrors mobile's dashboard tour (`dashboard_screen.dart`) and stats tour (`statistics_screen.dart`, which already used this same overlay pattern the desktop goals tutorial was ported from).
*Tech Notes*:
- **`shared/widgets/coach_tutorial.dart`** (new): `CoachStep` (optional `targetKey` + title/description) and `CoachTutorialOverlay` (StatefulWidget) — a reusable dimming scrim + spotlight cut-out (`_CoachScrimPainter`, `Path.combine` difference) + step card with Back/Next/Finish. It owns an internal overlay `GlobalKey`, computes each step's target `Rect` via `targetKey.currentContext.findRenderObject().localToGlobal(ancestor: overlay)`, and reschedules a guarded post-frame `setState` when the rect isn't laid out yet (survives late layout / window resize). The host owns `steps`/`index`/`onIndexChanged`/`onFinish` and passes the localized button labels; the overlay must be the last child of a `Stack` over the page so target keys resolve in the same coordinate space. Extracted from — and behaviourally identical to — the goals tutorial (`goals_page.dart`), which is left untouched.
- **Dashboard tour** (`dashboard_page.dart`): the welcome dialog's "Start" button no longer calls `setTutorialSeen(true)`; it pops and sets `_showTour=true`. `build()` now returns `Stack[page, if(_showTour && !_didFinishTour) CoachTutorialOverlay(...)]`; the `_CheckInPanel`/`_HabitPanel`/`_FocusGoalsPanel` panels are wrapped in `KeyedSubtree` anchor keys. Three steps (daily check-in → habits → focus goals) reuse mobile copy; `_finishDashboardTour()` clears the flags and calls `tutorialProvider.setTutorialSeen(true)`.
- **Stats tour** (`statistics_page.dart`): added `initState` post-frame that starts the tour when `!ref.read(statsTutorialProvider)` — **wiring the previously-dead `statsTutorialProvider`**. Anchors the `_AnalyticsToolbar` (filter) and the `_TabSelector` (sections; the same `_tabsKey` is used on both mutually-exclusive global/habit branches, so only one is in the tree per frame). Two steps mirror mobile exactly (filter-by-habit, statistics-sections); `_finishStatsTour()` persists `statsTutorialProvider`.
- **Reset**: the Settings "reset tutorial" hook (`_resetTutorials`) already reset all three flags (dashboard/goals/stats), so first-run re-arms all three tours — no change needed.
- **i18n**: 13 `tutorial.*` keys × 5 locales, reused 1:1 from mobile's `tutorial.*` (back/next/finish + the six step titles/descriptions). `dart run slang` regenerated.
- **Overlay hardening** (from the review): the geometry-refresh loop is now **bounded** (`_maxRefreshAttempts`, falls back to a target-less full-scrim step) so a never-laid-out target can't pin a CPU with a per-frame `setState`; and each step **`Scrollable.ensureVisible`s** its target so an off-screen anchor (e.g. Focus Goals below the fold on a narrow single-column layout) is scrolled into view instead of drawing a full opaque scrim with no cut-out.
- **Tests**: `test/coach_tutorial_test.dart` (`it` locale) drives the overlay through both steps (asserts `Avanti` → `Fine` and that Finish fires `onFinish`) and proves an unresolvable/orphan target settles (no infinite refresh) while still showing the card.
- **Verification**: `flutter analyze lib` → **0 errors** (same 12 pre-existing infos); `flutter test` → **+86 -1** (only the environmental Supabase-config test fails). A 3-lens adversarial review workflow (tour-lifecycle / geometry-RTL / regression) returned only 2 LOW findings, both hardened above (neither was reachable via the two shipped host pages).

## [2026-07-04]: BACKLOG Item 4 DONE — App Logs viewer
*Details*: The desktop `AppLogger` existed but only had `error()` (debugPrint + Sentry) with no retention and no viewer. Gave it an in-memory ring buffer + levels and built an in-app diagnostic log viewer opened from Settings, mirroring mobile's `app_logs_screen.dart` (filter / search / detail / copy / share / clear).
*Tech Notes*:
- **`core/app_logger.dart`**: added `AppLogLevel` + `LogEntry` (level/message/error/stackTrace/extras + `levelLabel`/`formattedTimestamp`), a 500-entry in-memory ring buffer (`_logs`), a newest-first `logs` getter, `errorCount`/`warningCount`/`infoCount`, `addListener`/`removeListener`/`clearLogs`, and `warning()`/`info()`. `error()` keeps its exact existing signature (`String, Object, [StackTrace?, Map?]`) so every caller still compiles, and now also buffers. `_notifyListeners` iterates a copy so a listener toggling its subscription mid-notify can't throw. The buffer is process-local (no disk persistence — a deliberate scope choice; the viewer shows the current session, and a foreign log file would raise a private-mode question). External (Sentry) reporting stays gated by the private-mode boundary.
- **`features/settings/presentation/app_logs_dialog.dart`** (new): `showAppLogsDialog(context)` — an `EvolveDialog` (760×580) viewer with header actions (search toggle / copy-all / share / clear), filter chips (All/Errors/Warnings/Info + live counts), a search field (`AnimatedCrossFade`), and a `ListView` of monospace cards that **expand inline** (message/error/extras/stack via `SelectableText` + per-entry copy). It subscribes to `AppLogger` in `initState` and unsubscribes in `dispose`. Card expansion is keyed by **`LogEntry` identity** (a `Set<LogEntry>`), not list index, so a newest-first insert or a filter change can't move the expanded card onto a different entry. Share writes a temp `.txt` and uses `SharePlus` on macOS/Windows, clipboard on Linux (mirrors the settings export). Clear is confirmed via `EvolveAlertDialog`.
- **Settings row**: an `_ActionRow` (`Icons.terminal_rounded`, `t.settingsPage.appLogsTitle`/`appLogsDetail`) opens the viewer.
- **i18n**: `appLogs.*` reused 1:1 from mobile (5 locales) + authored `settingsPage.appLogsTitle`/`appLogsDetail`/`systemSection` and `appLogs.shareLogs`/`exportDone`. `dart run slang` regenerated.
- **Tests**: `test/app_logs_test.dart` — a unit test (buffer levels, newest-first order, counts, clear) and a widget test (viewer shows entries; the Errors filter hides the info entry).
- **Verification**: `flutter analyze lib` → **0 errors** (same 12 pre-existing infos); `flutter test` → **+88 -1** (only the environmental Supabase-config test fails). Fixed one self-caught bug pre-review (index- vs identity-keyed expansion); a 3-lens adversarial review workflow (logger / viewer / regression) then returned **zero findings**.

## [2026-07-04]: BACKLOG Item 5 DONE — AI Coach context + suggested prompts
*Details*: The desktop AI Coach sent only the user's turns (`_messages.where((m) => m.isUser)`), so the model lost context on follow-ups, and its context prompt omitted the user's name / goal counts / today's completion; it also had no suggestion chips. Both are fixed to mirror mobile (`ai_chat_screen.dart`).
*Tech Notes*:
- **Multi-turn memory** (`ai_coach_page._sendMessage`): now sends the **full conversation** — `List<ChatMessage>.from(_messages)` — so both user and assistant turns reach `OpenRouterService.generateStreamResponse` (which already maps `isUser ? 'user' : 'assistant'`). The eager `List.from` snapshot is taken *before* the empty placeholder assistant bubble is appended, so the placeholder is never sent.
- **Enriched context prompt**: adds a name line (`t.aiCoach.userNameLine`) always; a today-completion line (`t.aiCoach.todayCompletion`, done/total over habits active today) in the habits block; and active + completed goal counts (`t.aiCoach.activeGoalsCount`/`completedGoalsCount`) in the goals block. `_userName()` reads the private profile (private mode) or the cloud user metadata, first token, with a localized fallback. The private-mode AI-consent gate (`_ensurePrivateAiConsent`) is unchanged and still runs before any context is built or sent.
- **Suggested prompts**: a horizontal chip row above the input, shown only when not streaming. `_dynamicSuggestions()` reads live state and delegates to a **pure, top-level `buildAiSuggestions(...)`** (time-of-day + which context switches are on → up to four unique, deterministic by message count) — extracted so it's unit-testable. Tapping a chip fills the input and sends via `_sendMessage` (so it still honors the typing guard + consent gate).
- **i18n**: `ai.suggestions.*` (19 keys) reused 1:1 from mobile; `aiCoach.userNameLine`/`activeGoalsCount`/`completedGoalsCount`/`todayCompletion`/`defaultUserName` reused from mobile `ai.prompts.*`. `dart run slang` regenerated.
- **Tests**: `test/ai_suggestions_test.dart` (5) covers `buildAiSuggestions` — up-to-four unique, morning/evening + goals/habits branches, deterministic rotation by message count, and the no-switches fallback.
- **Verification**: `flutter analyze lib` → **0 errors** (same 12 pre-existing infos); `flutter test` → **+93 -1** (only the environmental Supabase-config test fails). A 3-lens adversarial review workflow (history-context / suggestions-ui / regression) returned **zero findings**.

## [2026-07-05]: BACKLOG Item 6A DONE — Drag-to-reorder habits
*Details*: The habit model carried `displayOrder` and both repos ordered by it, but there was no reorder UI or controller method. Added inline drag-to-reorder on the Habits protocol list, persisting the new order to whichever repository is active (mirrors mobile's `habit_management_modal` reorder).
*Tech Notes*:
- **`DashboardController.reorderHabits(oldIndex, newIndex)`**: moves the habit, reassigns every habit's `displayOrder` to its new list position, then `state = …` + `_saveLocal()` + `_syncRemote(() => _repository.reorderHabits(reordered))` — the same optimistic/local-first pattern as every other mutation (a remote failure keeps the local order and flags the sync warning; no hard rollback, by design). Uses the `ReorderableListView.onReorderItem` contract (newIndex is already adjusted for the removed item, so no `-1`).
- **Repository**: `DashboardRepository.reorderHabits` (base no-op); `PrivateDashboardRepository` = an atomic sqflite **batch** that updates only `{display_order, updated_at}` per id (never the whole row, so a reorder can't reset `start_date`/`frequency`); `SupabaseDashboardRepository` = **one atomic batch `upsert([{id, display_order}], onConflict: 'id')`** (existing rows → UPDATE path; mirrors mobile against the same backend). The single request is deliberate — a review flagged that N separate updates could half-apply on a mid-loop failure and corrupt the order. `_PrivateRepositoryProxy` delegates; `UnavailableDashboardRepository` throws `_requireSession`.
- **UI** (`habits_page._ProtocolPanel`): the habit `for`-loop became a `ReorderableListView.builder(shrinkWrap, NeverScrollableScrollPhysics, buildDefaultDragHandles: false, onReorderItem: …)`; each `_HabitRow` gets `key: ValueKey(habit.id)` + a 24px leading drag-handle column (`ReorderableDragStartListener` + `Icons.drag_indicator`, grab cursor), with a matching leading spacer added to `_HabitHeader` so the columns stay aligned. Tap targets (toggle/edit/delete) are unaffected.
- **i18n**: none (no new user-facing strings).
- **Tests**: `test/dashboard_controller_test.dart` — a new test asserts `reorderHabits(0, 2)` on `[a,b,c]` → `[b,c,a]` with `displayOrder [0,1,2]` and persists that order to the repository.
- **Verification**: `flutter analyze lib` → **0 errors** (same 12 pre-existing infos); `flutter test` → **+94 -1** (only the environmental Supabase-config test fails). A 2-lens adversarial review (index/persistence, UI/regression) found one MEDIUM (the N-update partial-write), fixed above; math/contract/clamp confirmed correct.

## [2026-07-05]: BACKLOG Item 6B DONE — Inline category management in the add-goal picker
*Details*: The add-goal bar's category picker was a bare popup (default + existing only) and archiving a category happened instantly with no confirmation or linked-goal warning. Extended the existing components (rather than porting a parallel sheet) to add inline create + auto-select and a linked-count archive confirmation, mirroring mobile's `category_picker_sheet`.
*Tech Notes*:
- **Inline create + auto-select** (`_createCategoryInline`): the `_QuickCategoryButton` popup gained a divider + a "＋ New category" item that opens `_CategoryEditorDialog`, creates via `desktopGoalCategoriesControllerProvider.addCategory` (catch + snackbar on failure), then adds it to `_categories` and sets `_quickGoalCategory` to it (auto-select). The item has no `value` (implicit null) + an `onTap` — Flutter routes a null menu result to `onCanceled`, not `onSelected`, so create fires without spuriously selecting Default (same mechanism as the existing null-valued "Default" item). Threaded as `onCreateCategory` through `_GoalBoard` → `_QuickGoalBar` → `_QuickCategoryButton`.
- **Archive confirmation** (`_archiveCategory`): now counts the goals still referencing the category (`goals.where((g) => g.categoryId == category.id)`), shows an `EvolveAlertDialog` (`macroGoals.archiveCategory2` title; `categoryUnavailableLinked`/`categoryUnavailableArchived` body filled via `replaceFirst('label'|'count')`, matching mobile's token style; Cancel / `macroGoals.archive`), and only archives on confirm. Archive stays **soft**: linked goals keep their `category_id` and remain in history — the category is only hidden from the picker for new goals. The category-manager dialog's archive button now `await`s the confirm before refreshing.
- **i18n**: `macroGoals.archiveCategory2`/`archive`/`createNewCategory` reused from mobile; the two archive-warning strings use **slang `{label}`/`{count}` params** (`categoryUnavailableLinked`/`categoryUnavailableArchived`) rather than mobile's `replaceFirst` token style — the review found the token approach silently no-ops in es/de (their translations spell the tokens differently and omit the count) and can corrupt a label containing the substring "count"; the param getters interpolate correctly in all 5 locales. `dart run slang` regenerated.
- **Tests**: none added (deep provider-coupled dialog UI with no cleanly-extractable pure logic); verified via `flutter analyze` + the full-suite regression + adversarial review. Default categories remain non-archivable (the manager only exposes archive for non-default).
- **Verification**: `flutter analyze lib` → **0 errors** (same 12 pre-existing infos); `flutter test` → **+94 -1** (only the environmental Supabase-config test fails). A 2-lens adversarial review workflow (create/select semantics, archive/regression) found the i18n token bug (HIGH: es/de no-op + MEDIUM: "count"-in-label corruption), fixed above by switching to slang params; the popup null→onCanceled create semantics were confirmed correct.

## [2026-07-05]: BACKLOG Item 7 DONE — Statistics & data polish (4 sub-items)
*Details*: Four parity/correctness gaps across the statistics + data surfaces, mirroring mobile.
*Tech Notes*:
- **Life-view DOB in private mode** (`habits_page._LifeCalendar`): read the date of birth from `privateProfileProvider.value?.dateOfBirth` (the encrypted profile) in private mode instead of only the Supabase `userMetadata` — which is null in private mode, so everyone defaulted to 2003. Cloud mode still reads `userMetadata`.
- **Dashboard habit-row 3-state** (`dashboard_page._HabitRow`, grilled decision): the row now takes today's log status (`snapshot.habitStatusFor(id, now)`) and renders **done** (filled color + check) / **missed** (rose border + close) / **untracked** (empty), instead of a binary checkbox; tapping still cycles via `toggleHabit` (the controller already cycles null→done→missed→null).
- **Sortable Global Habits** (`statistics_page._GlobalHabits`): was a read-only list off `weeklyProgress` (done/7). Now a `ConsumerStatefulWidget` backed by **`habitStatsRpcProvider`** (real per-habit `rate`/`best_streak`/`worst_streak`), with a `ChoiceChip` **sort** (rate / best-streak / name) and a `_HabitStatsRow` (color dot, title, rate bar + %, best/worst badges). The obsolete `_HabitPerformanceRow` was removed.
- **Yearly heatmap missed-vs-untracked** (`statistics_page._HabitCalendar`): the grid collapsed missed into untracked (`status==1?1.0:0.0`) through the single-color `_HeatmapPanel`. Now a 3-state `_YearlyHabitHeatmap` reads the yearly-grid int statuses (1=done / 2=missed / 0=untracked; matches `computeYearlyGrid`, with a snapshot-derived fallback), colors cells habit-color / rose / faint, and adds a **completed / missed / rate** summary. The now-unused `_habitActivityValues` was removed.
- **i18n**: added `stats.sortRate`/`sortStreak`/`sortName`/`worstStreakLabel` (5 locales); reused `stats.successRate` (param), `statistics.completed2`/`notCompleted`, `stats.bestStreakLabel`. `dart run slang` regenerated.
- **Tests**: none added (statistics UI reading existing, already-tested providers); verified via `flutter analyze` + full-suite regression + adversarial review.
- **Verification**: `flutter analyze lib` → **0 errors** (same 12 pre-existing infos); `flutter test` → **+94 -1** (only the environmental Supabase-config test fails). A 2-lens adversarial review workflow (statistics correctness, regression) returned **zero findings**.

## [2026-07-05]: BACKLOG Item 8 — Cleanup batch (part 1: mechanical fixes)
*Details*: The first batch of the Item-8 cleanup grab-bag — small, independent correctness/consistency fixes.
*Tech Notes*:
- **Reset-to-defaults** (`settings_page._resetSettingsToDefaults`): AI-insights + weekly-reports now reset to **true**, matching the initial-state defaults (they were incorrectly reset to false).
- **HSL/color import parser** (`desktop_backup_import_service._hslToHex`): a valid `#hex` is preserved, a known **named color token** (red/blue/… palette) maps to hex, an `hsl(...)` string converts, and an unrecognized value is now **returned unchanged instead of silently blue-washed** (both the regex-fail and the catch fell back to `#3B82F6`). Downgraded the failure log from `error` to `warning`.
- **FK-pragma** (`private_db_schema.onConfigure`): documented that `PRAGMA foreign_keys = ON` is set in `onConfigure` so FKs are enforced for the whole connection (migrations + imports), matching mobile's per-connection intent (the canonical sqflite hook).
- **`_GoalItem` ValueKey** (`goals_page`): each `_GoalItem` now has `key: ValueKey(goal.id)` (+ `super.key` on the ctor) so its 2-second pending-state timer follows identity across re-sorts instead of flipping the wrong goal.
- **`DropdownButtonFormField` deprecation** (`create_goal_dialog`): `value:` → `initialValue:` (the other two dropdowns already used `initialValue`); this clears one of the pre-existing analyzer infos (now 11).
- **Tests**: `test/backup_roundtrip_test.dart` gained a color-normalization test (hex preserved, named token mapped, hsl converted, unknown not blue-washed).
- **Verification**: `flutter analyze lib` → **0 errors** (11 pre-existing infos now, down from 12); `flutter test` → green except the environmental Supabase-config test.

## [2026-07-05]: BACKLOG Item 8 — Cleanup batch (part 2: notification cloud write + consent screen)
*Details*: Two grilled sub-items — implement notification actions in cloud mode, and add the missing consent-screen surfaces.
*Tech Notes*:
- **Notification actions in cloud mode** (`desktop_notification_service._handleHabitAction`, grill decision = implement): the Done/Skip actions were a silent no-op in cloud mode (only private mode wrote). Now cloud mode writes via a new `_writeCloudHabitLog` — the cloud counterpart of `DesktopPrivateDb.setHabitLogFromNotification`: it loads the habit's `goal_logs` (newest-first so the recent days are within PostgREST's row cap), builds the `{dayKey:{goalId:status}}` map, applies today's status, resolves `start_date`, computes the signed streak via the shared `computeStreak`, and upserts `goal_logs` (`onConflict: goal_id,date`). It runs in the foreground `onDidReceiveNotificationResponse` (main isolate; the app is running, so `Supabase.instance.client` is available — guarded by try/catch + a `currentUser` null check). A review noted (accepted trade-offs): the fetch is unpaginated like the rest of the app (mitigated by the DESC order); and unlike the in-app toggle it isn't offline-queued (a failed offline action is re-done in-app).
- **Consent screen** (`consent_page.dart`, grill decision = add both): added a **notification-permission card** (`Enable` → `DesktopNotificationService.requestPermissions()`, shows a granted state) and a **Terms-of-Service link** alongside the existing privacy link (both open the app's single legal page via `url_launcher`, mirroring mobile's combined "terms & privacy" resource). Password min stays **8** (grilled — intentional divergence, no change).
- **i18n**: `consentPage.openTerms`/`notificationsTitle`/`notificationsSubtitle`/`enableNotifications`/`notificationsEnabled` (5 locales). `dart run slang` regenerated.
- **Verification**: `flutter analyze lib` → **0 errors** (11 pre-existing infos); `flutter test` → green except the environmental Supabase-config test. A 1-lens review of the cloud write returned 2 LOW findings (unpaginated fetch — pre-existing app-wide, mitigated by DESC order; no offline queue — accepted).

## [2026-07-05]: BACKLOG Item 8 — Cleanup batch (part 3: color picker + check-in emoji + day-details) — **Item 8 & backlog COMPLETE**
*Details*: The final three UI-polish sub-items, completing Item 8 and the whole feature-parity backlog.
*Tech Notes*:
- **Full color picker** (`shared/widgets/color_picker_dialog.dart`, new): `showEvolveColorPicker(context, initial)` (reuses the `flutter_colorpicker` `ColorPicker` in an `EvolveAlertDialog` — the dep was already present) + `CustomColorSwatch` (rainbow tile, `size` param, highlighted when the current selection isn't a preset). Added the custom swatch to the preset grids in **create-habit**, **create-goal** (32px), and **`_CategoryEditorDialog`** (24px); picking sets the dialog's selected color, which flows through the existing create/update paths.
- **Check-in emoji feedback** (`dashboard_page._CheckInSlider`): each mood/energy slider now shows a face emoji for its 0–10 value via the pure `_checkInEmoji` (no i18n — emoji are locale-independent).
- **Day-details dialog** (`habits_page._DayDetailsDialog`): each habit row gained a **🔥 streak badge** (`secondary`), and an **"editable only today/yesterday" hint** (`habitsPage.editableHint`) shows when the day isn't editable (the edit-gating via `_canEditDate` already existed).
- **i18n**: `habitsPage.editableHint` (5 locales). `dart run slang` regenerated.
- **Verification**: `flutter analyze lib` → **0 errors** (11 pre-existing infos); `flutter test` → green except the environmental Supabase-config test. A 1-lens adversarial review returned **zero findings**.

### BACKLOG COMPLETE
All 8 desktop feature-parity backlog items are implemented, localized (en/it/es/de/ar), analyzed (0 errors), tested, adversarially reviewed, and committed. `flutter analyze lib` → **0 errors** (11 pre-existing infos, down from 12); `flutter test` → all green except the one environmental `desktop_supabase_config_security_test` (needs a `--dart-define` Supabase config; fails identically on unmodified code).

## [2026-07-06]: Fix — macOS Keychain -34018 (private DB blocked) + ListTile-in-panel ink assertion
*Details*: Running the Debug macOS build, `flutter_secure_storage` failed with `PlatformException(..., -34018, "A required entitlement isn't present.")` on every private-DB open, cascading into "Failed to load private profile / Unable to load private analytics data / Unable to load local macro goal categories". Root cause: the sandboxed app's **DebugProfile.entitlements** had no `keychain-access-groups` key (Release.entitlements already had it), so the Keychain was inaccessible under the app sandbox. Also fixed the debug-only "ListTile background color or ink splashes may be invisible" assertion that fired at first-run.
*Tech Notes*:
- **Keychain entitlement** (`macos/Runner/DebugProfile.entitlements`): added `<key>keychain-access-groups</key><array/>` so Debug matches `Release.entitlements`. The empty array (rather than a team-prefixed `$(AppIdentifierPrefix)…` group) is deliberate: signing is ad-hoc (`CODE_SIGN_IDENTITY = "-"`, no `DEVELOPMENT_TEAM`), so the app relies on its own implicit access group; a team-prefixed shared group would not resolve. Entitlements are embedded at code-sign time → a full rebuild/re-sign is required (hot reload/restart will not pick it up). Failure chain was `DesktopPrivateDb._encryptionKey` → `FlutterSecureStorage.write` (`desktop_private_db.dart:533`).
- **EvolvePanel Material** (`shared/widgets/evolve_panel.dart`): wrapped the panel child in `Material(type: MaterialType.transparency, borderRadius: 16, clipBehavior: Clip.antiAlias)` inside the existing `DecoratedBox`. ListTile-family widgets paint ink/selected backgrounds on the nearest `Material`; the panel's colored `DecoratedBox` sat between the tile and that Material and hid them (assertion fired on `consent_page`'s Checkbox/SwitchListTile at first-run). One fix covers all 34 `EvolvePanel` usages.
- **Verification**: `flutter analyze lib/shared/widgets/evolve_panel.dart` → **No issues found**; `plutil -lint DebugProfile.entitlements` → OK; both Debug and Release entitlements now carry `keychain-access-groups`. Full macOS build/run was **not** verified in this environment — this machine has only the Command Line Tools (no `Xcode.app`), so `xcodebuild` is unavailable; it must be rebuilt on the Mac that has Xcode.

## [2026-07-06]: Follow-up 2 — override inherited ad-hoc CODE_SIGN_IDENTITY on Runner app target
*Details*: `DEVELOPMENT_TEAM` + `CODE_SIGN_STYLE = Automatic` alone did NOT fix the "entitlements require signing with a development certificate" error, because the Runner **app** target inherits `CODE_SIGN_IDENTITY = "-"` (ad-hoc / "Sign to Run Locally") from the three **project-level** XCBuildConfiguration blocks (pbxproj lines 577/654/710). An explicit `"-"` forces ad-hoc signing regardless of the team, and ad-hoc can't sign the `keychain-access-groups` entitlement.
*Tech Notes*:
- **`macos/Runner.xcodeproj/project.pbxproj`**: added `CODE_SIGN_IDENTITY = "Apple Development";` to the Runner app target's three configs (Debug/Release/Profile), overriding the inherited project-level `"-"`. Left the project-level `"-"` untouched so RunnerTests (manual style, no team, no entitlement) keeps signing ad-hoc. For App Store archiving later, automatic signing re-signs with the distribution cert at export time, so "Apple Development" as the build-time identity is fine.
- **Verification**: `plutil -lint project.pbxproj` → OK; 3 `CODE_SIGN_IDENTITY = "Apple Development"` entries, each alongside `DEVELOPMENT_TEAM = 8528AN28A3` in a Runner app config. Build/run still not runnable here (no Xcode on this machine).

## [2026-07-06]: Desktop UI restyle — full visual parity with the iOS app
*Details*: The desktop app worked but looked visually different from iOS (system font vs Inter, Material icons vs lucide, opaque flat panels vs translucent glowing cards, tab bars vs white-pill segmented controls). Restyled every desktop surface to the mobile design language using `MOBILE_SCREEN/*.PNG` and `mobile/lib` as the source of truth. Presentation-only: no provider/callback/navigation/logic changes, no new user-facing strings beyond 4 added translation keys, and no feature changes.
*Tech Notes*:
- **Typography**: Inter 400/500/600/700/800 bundled at `desktop/assets/fonts/` (Inter v4.1 static TTFs, declared in `pubspec.yaml`) and set as the global `fontFamily` — offline-safe alternative to mobile's runtime `google_fonts`. Text theme now mirrors mobile (page titles 32/w900/ls-1.2, card headings 22/w800, uppercase 10px micro-labels ls1.2+).
- **Theme** (`app/theme/evolve_theme.dart`): added `EvolveColors.success (0xFF26C252) / successBright (0xFF22C55E) / destructive (0xFFEF4444)`; inputs (radius 12, translucent fill), buttons (radius 12, w700), dialogs (radius 20, 0.5-alpha border), green success switches — all matching `mobile/lib/core/theme.dart`.
- **New shared components** (`shared/widgets/evolve_panel.dart`): `EvolveSegmentedControl<T>` (the mobile white-pill selector — now used for every tab/period/view/mode switch on all pages), `EvolveIconChip` (tinted + outlined variants), `EvolveSectionLabel` (uppercase micro-label with fading hairline, "PROTOCOLLO" style), `EvolveSquareIconButton` (36px bordered square); `EvolvePanel` gained `radius`/`glowColor` and the translucent card recipe (panel .4 alpha fill, .5-alpha border, soft shadow). `DesktopPage.title/subtitle` now optional.
- **Shell**: top bar replaced by the mobile greeting header (time-of-day greeting + green status dot + date, ⌘K search, sync, avatar with gold Pro ring → opens Settings); sidebar active item = white pill with black-on-white label; lucide icons throughout (`navigation_controller.dart`).
- **Dashboard**: mobile PROTOCOLLO strip (Daily Check-in tile with pulse-glow/check badge, AI Chat → Coach, Manager → Habits), metric cards with icon chips + corner glows, white 3px dot-less trend line, flame streak badges; create-habit/goal dialogs use mobile's 7 preset colors with glowing swatches and uppercase field labels.
- **Per-page restyles** (5 parallel subagent passes, all analyzer-clean): statistics (All Habits selector card, segmented tabs, Performance Evolution card with big % + green trend pill, fl_chart white line, mobile Alert cards), habits (card-per-row manager with grip/glow-dot/pencil/trash, calendar with `performanceColor` red→green day cells), goals (segmented horizons, tinted goal cards, restyled stats charts; also removed the undeclared `intl` dependency usage and pre-existing dead code — analyzer now 0 issues repo-wide, down from 11), settings (mobile profile-row recipe, uppercase section labels, destructive red buttons, Radio→RadioGroup migration), auth/consent/AI coach (mobile hero auth layout, white/black chat bubbles, suggestion pills, glowing CTAs).
- **i18n**: added `dashboard.goodAfternoon/goodEvening/manager/aiChat` in all 5 locales (greeting words copied from the mobile app); `dart run slang` regenerated.
- **Support**: copied `mobile/lib/core/performance_color.dart` → `desktop/lib/core/` (shared red→green HSL completion scale).
- **Verification**: `dart format --set-exit-if-changed lib test` clean; `flutter analyze` → **No issues found** (0, was 11); `flutter test` with dummy Supabase defines → **96/96 pass**, tests unchanged (the PROTOCOLLO tile subtitles use `t.ai.macroGoals`/`t.ai.dailyHabits` instead of `t.nav.*` so the sidebar nav labels stay unique on screen, which the shell widget test asserts). `flutter build macos` could **not** run here (no Xcode — Command Line Tools only); visual pass deferred to TO_SIMO_DO.md.

## [2026-07-06]: Goals page desktop-first recomposition (Round 2 — layout only)
*Details*: The Goals page was a mobile-shaped vertical stack (horizon toolbar → period bar panel → quick-add bar → one long list with completed/failed dividers) that wasted horizontal space. Recomposed it the same desktop-first way as the Overview/dashboard, without touching the Round-1 visual skin, providers, callbacks, GlobalKeys, debounce, pro-gating or dialog flows. Only 2 files changed: `lib/features/goals/presentation/goals_page.dart` and `goals_stats_view.dart` (page-private helpers only; shared widgets/theme/i18n untouched).
*Tech Notes*:
- **Consolidated command bar** (`_GoalCommandBar` replaces `_GoalPeriodBar` + the board-embedded `_QuickGoalBar` slot): one `EvolvePanel` holding period dropdowns + prev/next + Categorie button (left) and the quick-add composer expanding (right) on a single row when the inner width ≥ 1000px; below that (e.g. the 960px minimum window) it stacks on two lines, with the selectors in a `Wrap` so it can never overflow. Quick-add cluster hidden in Stats mode (as before). `_planSelectorKey` now targets the period cluster; `_addGoalKey`/`_tutorialCategoryKey`/`_performanceToggleKey` wiring unchanged.
- **Board two-column layout** (dashboard pattern, `LayoutBuilder` ≥ 1120): `Row[Expanded(flex:7) active-goals EvolvePanel (period title 22/w800 + muted subtitle + active `_GoalItem`s), 18px gap, 350px right rail]`. Right rail: period summary card (progress ring copied from the dashboard `_ProgressRing`/`_RingPainter` as `_PeriodProgressRing`/`_PeriodRingPainter`, % = completed/total of the visible period, plus COMPLETATI/FALLITI/ATTIVI counts reusing existing strings) → Completed panel → Failed panel (SectionHeading with the existing divider strings + compact `_GoalItem`s). Narrow (<1120) keeps the original single-column flow with `_StatusDivider`s.
- **`_GoalItem` desktop hover affordance**: row wrapped in `MouseRegion`; the calendarClock/pencil/trash2 actions sit at 0.35 opacity and fade to 1 on hover (`AnimatedOpacity` 120ms) — always tappable, tooltips/behavior unchanged.
- **Goals stats view**: header + year selector on one `SectionHeading` row; KPI + highlight cards merged into a dashboard-style `Wrap` grid (4 cols ≥ 1080, else 2, spacing 14; KPIs first so grid rows stay homogeneous); chart cards paired two-up when ≥ 1120 (`_chartPair`: cumulative+monthly, radar+pie for single year; year-progression+monthly-history, radar+seasonality for all-years; type-distribution/interest-evolution/quarterly full-width), stacked as before when narrow; chart heights normalized to 240–260.
- **Verification**: `dart format` on both files clean; `dart analyze lib` → **No issues found** (whole lib). Widget-test constraints preserved by construction: 'Lifetime/Annuale/Trimestrale/Mensile/Settimanale'/'Stats' each rendered once (segmented control only), single 'Categorie' tooltip, and the 960×640 command bar wraps instead of overflowing.

## [2026-07-06]: Habits + Statistics desktop-first recomposition (Round 2 — layout only)
*Details*: Same desktop-first pass as the Goals entry above, applied to the two remaining mobile-shaped pages. The Overview/dashboard composition (metric Wrap grid, `LayoutBuilder` split at 1120px, flex-7 primary column + right rail, controls in `SectionHeading(trailing:)`) is now the template for every main section. Visual skin, providers, callbacks, GlobalKeys, dialogs and all `t.` keys untouched; page-private helpers only.
*Tech Notes*:
- **Habits** (`habits_page.dart`): summary cards → dashboard-style metric grid (4/2 cols, icon chips, 27/w800 values, corner glows). At ≥1120px the Protocol/Calendar segmented control disappears and both panels render **side by side** (`Row[Expanded(flex:6) protocol, 18, Expanded(flex:5) calendar]`): protocol keeps grip/tri-state/7-day squares/reminder/pencil-trash with a new dense metrics mode when the column is <700px; the calendar panel hosts the Month/Week/Year/Life white-pill switcher + Oggi/prev/next in its header, month grid capped at 540px so day cells stay 44–72px. Narrow windows keep the original tab behavior (`_surface` state now used only there). Habit rows gained a hover treatment (fill/border alpha shift, 140ms) and day cells a pointer cursor.
- **Statistics** (`statistics_page.dart`): toolbar consolidated to 2 rows (selector card flexible + scope control 300px on one line ≥980px; tabs below). Info: metric tiles in a `_MetricGrid` Wrap + heatmap/correlations in a 7-flex/350 split. Trend: hero card (timeframe control in the heading, chart 280px) with the two insights as icon-chip cards in a 350px right rail at ≥1120px (inline row kept for narrow). Alert: the three sections are single panels with in-card micro-headers, laid 3-up ≥1120px / 2-up ≥760px; item cards moved to the raised inner-card recipe. Habits tab: sort control in the panel header, hover highlight on rows. Mood + all single-habit scope tabs (Overview/Performance/Improvement/Mood) got matching grid/rail/pair treatments; the yearly-heatmap Calendar tab intentionally stays full-width.
- **Widget tests** (`test/widget_test.dart`): the habits test no longer taps a 'Calendario' tab (at 1440×900 both panels are visible; it now asserts the two panel headings + the four view labels directly) and a new narrow-window test (960×640) verifies the tab fallback still works with no overflow.
- **Verification**: `dart format --set-exit-if-changed lib test` clean; `flutter analyze` → No issues found; `flutter test` → **97/97 pass**. macOS build/visual pass still deferred to the Xcode machine (see TO_SIMO_DO.md).

## [2026-07-06]: Round 3 — Fully fluid, viewport-pinned, production-polish pass (user-interviewed spec)
*Details*: Grill session with Simone locked the final desktop design: no page max-width anywhere (true fluid, MacBook Pro 14" → external monitors), workspace surfaces pinned to the viewport, Habits back to a full-width Protocol/Calendar switch (the round-2 side-by-side split was rejected as cramped), and a production polish bar (hover/focus/cursors, unified 200ms motion, designed empty states, themed scrollbars, light-theme audit, keyboard shortcuts proven by tests).
*Tech Notes*:
- **Foundation** (`desktop_page.dart`, `evolve_theme.dart`, `dashboard_page.dart`): the 1540px `ConstrainedBox` cap is gone — fluid inside 28px gutters; `DesktopPage(pinned: true)` mode fills the viewport with no page scroll (child gets remaining height); global `ScrollbarTheme` (6→8px hover, rounded, border-colored). Overview guardrails: PROTOCOLLO tile strip capped at 1284px, metric cards capped ~470px, right rail proportional `(w*0.26).clamp(350,440)` — charts absorb width, tap targets don't. Spec captured in the session LAYOUT_SPEC (breakpoints 1120/1440/1760, rail formula, empty-state recipe, motion 200ms easeOutCubic).
- **Habits** (`habits_page.dart`): `pinned: true`; fixed chrome = compact 73px metric row (3 cards, capped 470) + full-width Protocollo/Calendario `EvolveSegmentedControl` (the user-requested switch; `_surface` restored); views cross-fade in an expand-fit `AnimatedSwitcher`. Protocol = full-width desktop table in one panel: fixed heading/column labels, `ReorderableListView` scrolling internally behind a themed `Scrollbar`, comfortable single column preset (dense fork deleted), LAYOUT_SPEC empty state with New-habit CTA. Calendar = true full-screen calendar: header (period title + view pill 380 + Oggi/chevrons), month grid fills the height by construction (flexed week rows; % caption ≥72px cells, compact <64px, dot clipping), week = 7 full-height columns with weekday labels, year = 4x3/3x4 flexing tiles, life scrolls internally. Fits 960×640 by arithmetic (301px view area → 26–32px day cells).
- **Statistics** (`statistics_page.dart`): habit selector card (360px, `_filterKey`) moved into the page-header trailing slot beside the last-30-days pill; one control row (tabs Expanded + scope 300; stacks <980) — chrome 3 rows → 1.5; tab/scope switches animate. Trend hero chart height `(w*0.22).clamp(280,380)` with insight cards in a row below (proportional rail at ≥1760); Info metric grid capped 470 + heatmap/correlations 7-flex/rail split; Alert 3-up ≥1120; Habits desktop-table mode ≥1440 (roomier columns, fluid progress bars); single-habit rails proportional; unified `_EmptyState` recipe across 5 empty spots.
- **Goals** (`goals_page.dart`, `goals_stats_view.dart`): 920px toolbar cap removed (6-segment control spans content). Active goals = adaptive card grid (rows <1400, 2-up ≥1400, 3-up ≥1760; `IntrinsicHeight` row-chunking, 14px gaps) via `_GoalItem(asCard:)` — same widget for rail/narrow rows; category `StatusPill`-style chip + due label on cards; rail proportional. Fixed a latent duplicate-GlobalKey crash (tutorial keys now only on the first active item). Stats view: KPI tiles capped 470, chart heights `(w*0.18).clamp(240,320)`, `_chartTriple` 3-up at ≥1760 (single-year).
- **Settings** (`settings_page.dart`, `app_logs_dialog.dart`): groups became titled cards (`EvolvePanel` radius 20 with the `EvolveSectionLabel` inside; rows as flat ListTiles with 68px-indented hairline dividers — `_RowCard` deleted); `_GroupGrid` tiles cards 2-up at ≥1280 content (greedy row-count balancing, cards never split; lone-group sections span full width); profile card + destructive zone + pro band full-width; section switches cross-fade. Light-theme bug fixed in the logs dialog (INFO severity used the dark-muted const; now palette-driven).
- **AI Coach** (`ai_coach_page.dart`): `pinned: true`; the `MediaQuery.height - 230` hack is gone; panel fills the viewport, messages scroll internally (controller + themed scrollbar), thread/suggestions/input all centered in a shared 900px column; send button gained cursor+hover lift.
- **Keyboard shortcuts proven by test**: new widget test drives ⌘1–⌘5, ⌘, and ⌘K with real key events (asserting each section renders and the palette opens/navigates, including after a dialog round-trip — fixed-frame pumps because the check-in pulse animation never "settles"). Habits tests rewritten for the switch contract + new 960×640 minimum-window guards for Habits and Statistics.
- **Verification**: `dart format --set-exit-if-changed lib test` clean; `flutter analyze` → No issues found; `flutter test` → **99/99 pass**. macOS build/visual pass deferred to the Xcode machine (no Xcode here) — see TO_SIMO_DO.md.

## [2026-07-06]: Fix — pages vertically centered when shorter than the viewport
*Details*: Simone's screenshots showed the Goals page content floating mid-screen on every tab except Stats. Root cause (proven with an offset-probe widget test): the shell's `AnimatedSwitcher` uses Flutter's default layout builder, which stacks pages with `Alignment.center` under loose constraints — any page whose scroll content is SHORTER than the viewport (e.g. an empty goals board on a wide window) got vertically centered; tall pages (the Stats charts) masked the bug by filling the viewport. Present since round 1, only visible after round 3's fluid layouts made short pages genuinely short.
*Tech Notes*: `desktop_shell.dart` — the section `AnimatedSwitcher` now supplies a `layoutBuilder` with `Stack(fit: StackFit.expand)`, so every page fills the content area and starts at the top; cross-fade behavior unchanged. New regression test "pages start at the top even when content is short" measures the Goals title offset at 2000×1050 across board/Stats tabs (must be identical and < 120px). `flutter analyze` clean; **100/100 tests pass**.

## [2026-07-07]: Settings parity with iPhone (toggles, calendar-view fix, Focus Mode)
*Details*: Brought the desktop Settings page to parity with the mobile client's settings model. Fixed the default-calendar-view persistence bug (SharedPreferences stored the display LABEL 'Mese'/'Settimana'… while the profiles row stored the CODE 'mese'/'settimana'…): both now store the canonical code, with backward compatibility for previously-stored labels. Added the missing toggles — AI Suggestions (Pro-gated like mobile's `toggleAi`), Focus Mode, Milestones, Deep Work Insights in a new "AI & System" group (Application section), and AI Insights + Weekly Reports in a new "Insights & reports" group (Notifications section). Hid the haptic-feedback row (macOS generates no haptics; the synced column is untouched). Focus Mode now actually suppresses local notifications, mirroring mobile.
*Tech Notes*:
- New `lib/core/calendar_view_preference.dart`: pure `normalizeCalendarViewCode()` / `calendarViewLabel()` helpers shared by `settings_page.dart` and `habits_page.dart` (which previously had no 'mese' arm, so a Month default wrongly opened the week view). Unit-tested in `test/calendar_view_preference_test.dart`.
- `settings_page.dart`: new state fields with mobile-matching defaults (`pref_ai_suggestions`/`pref_focus_mode`/`pref_deep_work_insights` OFF, `pref_milestones` ON, `notif_ai_insights`/`notif_weekly_reports` OFF — the last two previously defaulted ON on desktop and reset inconsistently). Experience toggles dual-write prefs always and the encrypted profiles row in Private mode only (mobile keeps them out of the Supabase profiles upsert; `DesktopPrivateDb._settingsColumns` already whitelists all keys, so they iCloud-sync). Notification toggles go through `_setNotificationBool` (profiles-row sync in both modes + schedule re-sync, no permission prompt — mobile parity).
- AI Suggestions gate uses `desktopIsProProvider` (Private mode always entitled, matching mobile's forced `is_pro=1`); non-Pro taps open `showProFeaturesDialog`.
- `desktop_notification_service.dart`: `sync(...)` gained `focusMode` (default false) — after `cancelAll()` it returns without scheduling when ON, mirroring mobile `AppSettingsNotifier.syncNotifications`.
- i18n: 14 new `settingsPage.*` keys in all 5 locales (en/it/es/de/ar); labels reuse the mobile translations verbatim (`suggerimentiAi`, `modalitaFocus`, `insightAi`, `resocontiSettimanali`, `aiSistema`, …); details are new translations. Regenerated with `dart run slang` from the desktop root.
- Tests: `test/settings_parity_test.dart` (4 widget tests: rows present, haptics hidden, focus-mode pref dual-write, Pro gate) + 8 unit tests for the calendar mapping; `widget_test.dart` updated to the new surface contract. `flutter analyze` → No issues found; `flutter test` → 106/106 green (was 94).
- Audit note: mobile currently has NO visible UI for these six settings (only the provider/model, legacy i18n strings and the export payload reference them) — placement and gating were derived from the mobile provider semantics and legacy i18n naming.

## [2026-07-07]: Data import/export made fully working and professional (LWW merge, stats, native Save dialog, cross-client export parity)
*Details*: Reworked the desktop backup pipeline to the mobile client's semantics (mobile/lib/core/import_merge.dart is the gold standard). The critical fix: merge-mode imports previously used `ConflictAlgorithm.ignore` everywhere, silently dropping any imported row whose id already existed — even when NEWER — and the model builder minted fresh ids per merge, duplicating everything on re-import. Merge is now a true identity-based last-write-wins reconciliation (goals/macros by id, logs by (goal_id,date), moods by (user_id,date), categories by id-then-case-insensitive-name with category_id remap), with per-entity added/updated/unchanged/skipped stats surfaced in the UI, streaks recomputed from the MERGED history, invalid rows dropped-and-counted upfront, a native macOS Save dialog for export, and the export payload aligned with mobile's canonical shape (schemaVersion + settings + camelCase containers) so backups round-trip desktop ⇄ mobile.
*Tech Notes*:
- **New `lib/core/import_merge_stats.dart`**: verbatim port of mobile's EntityMerge/ImportMergeStats + `incomingWins` strictly-newer LWW comparator (missing/unparseable incoming timestamp never wins; ties keep existing).
- **New `lib/core/import_merge.dart`**: `validateCanonical` (drop + count invalid rows per entity; desktop extra: the `profile` block passes through), `reconcileCategoriesByName` (the ONE category-identity brain — id match, else case-insensitive trimmed name, archived_at fill, intra-file name dedup — shared by the private merge and the cloud plan; replaces the service's old name-only helper), `recomputeStreaksForGoals` (rebuild signed streaks from merged history, write only changed rows to minimize sync churn), and `planCloudImport` (pure fetch-first cloud plan mirroring mobile — validate-before-delete, id-reuse on updates, intra-file dup dropping).
- **`lib/core/desktop_private_db.dart`**: `applyImport` rewritten to the LWW merge (returns `ImportMergeStats`; replace mode keeps wipe-then-insert; created_at preserved on LWW updates; macro category_id nulled when it would dangle; merge-mode logs may attach to PRE-EXISTING habits, not just file habits; row-level resilience guards kept). `importData` returns the stats and still fires `notifyWrite()` after the txn (sync_state is never touched by import code — the triggers do the bookkeeping; replace-mode deletions intentionally tombstone so deletes propagate). `exportData` now emits the mobile-parity shape via new static `exportSnapshot`: `schemaVersion: 1`, `settings` (the profiles row, like mobile's `loadSettingsRow`), camelCase containers (`habits`/`habitLogs`/`macroGoals`/`macroGoalCategories`/`dailyMoods`), `frequency_days` decoded to a real list (`decodeFrequencyDays`). Rationale: mobile's import normalization reads ONLY camelCase containers for `mode: 'private'` files, so the old snake_case desktop export normalized to empty lists on mobile.
- **`lib/core/desktop_backup_import_service.dart`**: pipeline is now normalize → process (colors/web-category synthesis/frequency decode; ids KEPT, no per-merge remap, no streak precompute) → `validateCanonical` → preview (`BackupImportPreview` carries validated `canonicalData` + `skipped`) → `executeImport(canonicalData:, replaceExisting:, isPrivateMode:, skipped:)` returning `ImportMergeStats`. Cloud import is plan-based (`planCloudImport` + chunked `onConflict: 'id'` upserts + archived_at fills + best-effort cloud streak recompute), replacing the old `ignoreDuplicates` upserts that could never update. `BackupImportResult` and `modelFromJson`/`buildImportModel` removed in favor of `buildCanonicalModel` (static, test-visible).
- **`settings_page.dart`**: export uses `FilePicker.saveFile` on macOS (native Save dialog, suggested names `evolve_private_export.json` / `mattioli_os_export.json`, cancel = silent no-op; Linux keeps clipboard, others keep share_plus); cloud export switched to the same canonical camelCase shape (+ `schemaVersion`, `settings`, frequency decode); whole export wrapped in try/catch. Import preview shows "⚠ N invalid record(s) will be skipped" when validation dropped rows; the bare success snackbar is replaced by a per-entity summary dialog (added/updated/unchanged/skipped per row — replace mode shows totals), mirroring mobile's import-completed dialog.
- **Entitlements**: `com.apple.security.files.user-selected.read-only` → `read-write` in BOTH `macos/Runner/DebugProfile.entitlements` and `Release.entitlements` (required by the Save dialog; iCloud/keychain keys untouched).
- **Dependencies**: `file_picker` ^3.0.4 → ^11.0.2 (static `FilePicker.pickFiles`/`saveFile` API; the old `FilePicker.platform.*` calls were migrated). `share_plus` ^13.1.0 → ^12.0.2 to resolve the win32 constraint conflict — this is exactly the mobile client's pair (file_picker ≤11 needs win32 ^5, share_plus 13 needs win32 ^6; the `ShareParams`/`fileNameOverrides` API is identical in 12).
- **i18n**: 14 new `settingsPage.*` keys in all 5 locales (importPreviewSkipped, importCompletedTitle, importSummaryReplaced/Merged/Done, importEntityHabits/Logs/MacroGoals/Categories/Moods, importRowReplace/Merge/Skipped, exportDoneSaved) — translations reused verbatim from mobile's `privacy.*` where they exist; regenerated with `dart run slang`.
- **Tests**: `test/backup_roundtrip_test.dart` migrated to the new API (merge mode now asserts ids are PRESERVED; the reconcile suite covers id-match/case-insensitive-name/archive-fill/intra-file dedup; new cloud-plan test asserts category rows omit `updated_at` for Supabase). New `test/import_merge_lww_test.dart` (12 tests): merge LWW win/lose with exact stats, re-import idempotency, logs merging onto pre-existing habits, orphan-log resilience, gap-filling streak recompute over merged history (a log NOT in the file gets its streak corrected), replace-mode signed-streak recompute, per-entity skipped counting, desktop→desktop full JSON round-trip (schemaVersion/settings/frequency_days), mobile-1.0.10 exportData-shaped import, and sync bookkeeping: merge dirties exactly the written rows (LWW losers stay clean), a no-op re-import leaves sync_state untouched, replace tombstones removed rows while re-imported ids come back alive+dirty.
- **Verification**: `flutter analyze` → No issues found; `flutter test` (with the dummy Supabase dart-defines) → **121/121 pass** (was 106).

---

- [2026-07-07] Apple-like control kit (desktop-wide de-Materialization of form controls)
*Details*: The desktop app's form controls were stock Material (Switch, DropdownButton, showTimePicker, RadioListTile, bare AlertDialogs), reading non-native on macOS. Added a shared control kit next to the existing Evolve widgets and converted every surface to it — pure presentation, no business-logic changes, no new dependencies.
*Tech Notes*:
- **New `lib/shared/widgets/evolve_controls.dart`** (the kit; themes only via EvolvePalette/accent, Lucide icons, RTL-safe, hover + pointer cursors everywhere):
  - `EvolveSwitch` — macOS-style 40×24 toggle (success-green ON like the old switchTheme, white thumb, AlignmentDirectional so it mirrors under RTL, null onChanged = faded disabled state).
  - `EvolveMenu` / `EvolveMenuItem` / `EvolveMenuDivider` — the popup primitive (MenuAnchor under the hood, Evolve panel surface, hover rows, checkmark on selected, onTap fires after close like PopupMenuItem).
  - `EvolveSelect<T>` + `EvolveSelectOption<T>` — macOS pop-up-button select (chevrons-up-down trigger; variants: filled/naked, expand-to-width with menu min-width matching the trigger, optional leading widgets e.g. color dots, optional uppercase micro-label via the new shared `EvolveFieldLabel`).
  - `EvolveTimePicker` + `showEvolveTimePicker` — clock-chip trigger + Evolve dialog with hour/minute stepper columns (chevrons + direct typing, digits clamped), AM/PM segmented toggle in 12h mode (labels from MaterialLocalizations), HH:MM cluster pinned LTR under RTL.
  - `EvolveDateField` + `showEvolveDatePicker` — field-look trigger (InputDecorator so it matches TextFields, clearable) + compact calendar popover dialog (month grid, single/double chevron month/year nav with directional icons, accent-pill selection, today ring, firstDate/lastDate clamping, weekday/month names from MaterialLocalizations — zero new i18n keys).
  - `EvolveRadioRow<T>` — bordered radio option card (accent ring + dot when selected) replacing RadioListTile groups.
  - `EvolveProBadge` — the mobile amber PRO chip.
- **Converted surfaces**: settings_page (all _SwitchRow/_SelectRow/_TimeRow rows incl. iCloud sync card; import preview dialog → EvolveAlertDialog with icon count rows, destructive-tinted skipped-warning chip and EvolveRadioRows; import progress dialog → EvolveDialog; Personal info date-of-birth free-text field → EvolveDateField, still persisting the ISO `yyyy-MM-dd` string, empty when cleared; PRO badge on the Pro-gated AI Suggestions row), statistics_page (habit scope DropdownButton → naked expanded EvolveSelect with habit color dots), goals_page (_PeriodDropdown → EvolveSelect; _QuickCategoryButton PopupMenuButton → EvolveMenu with the same custom dot trigger; goal editor category DropdownButtonFormField → EvolveSelect with dots), habits_page (category DropdownButtonFormField → EvolveSelect; reminder showTimePicker → showEvolveTimePicker), create_goal_dialog (GoalType DropdownButtonFormField → EvolveSelect), ai_coach_page (context dialog + private-AI consent dialog → Evolve dialogs; SwitchListTiles → kit switches via _ContextSwitchRow), consent_page (crash-diagnostics SwitchListTile → ListTile + EvolveSwitch, row-tap toggle preserved).
- **Theme**: evolve_theme gains a `checkboxTheme` (rounded-6 accent checkbox) so the two remaining CheckboxListTiles (consent terms, habits weekday picker) match the kit. Grep confirms zero Material Switch/Dropdown/showTimePicker/showDatePicker/RadioListTile/PopupMenuButton usages remain in lib/.
- **i18n**: single copy fix — `settingsPage.importDataDetail` said "(.zip format)" but the importer accepts JSON or ZIP; now "JSON or ZIP" in en/it/es/de/ar + `dart run slang` regenerate. No keys added/removed.
- **Tests**: settings_parity_test + icloud_sync_card_test finders updated `find.byType(Switch)` → `find.byType(EvolveSwitch)` (same semantics). New `test/evolve_controls_test.dart` (19 tests): switch tap/disabled/RTL, select open-pick/no-refire/disabled/RTL, time picker trigger format, stepper+OK, cancel, RTL LTR-cluster ordering, 12h AM→PM conversion, date field pick/month-nav/clear/range-clamp/RTL, radio row, PRO badge.
- **Verification**: `flutter analyze` → No issues found; `flutter test` (dummy Supabase dart-defines) → **140/140 pass** (was 121).

### Current Status
Apple-like control kit COMPLETE (analyze clean, 140/140 tests green, tree left uncommitted for review). Immediate next step: Simone's visual QA pass on the Xcode machine — checklist appended to TO_SIMO_DO.md ("Apple-like control kit — visual QA (2026-07-07)"), covering dark + light themes and Arabic RTL.

- [2026-07-07]: Automatic Refresh after Import
  - *Details*: Fixed a bug where the dashboard and other pages didn't visually refresh after a data import unless a manual refresh was triggered. The UI loading dialog is now blocked until the data refresh finishes entirely.
  - *Tech Notes*: Replaced `ref.invalidate(...)` calls in `_importData` with explicitly awaited `ref.read(...).refresh()` and `.future` reads so that Riverpod pulls the newly imported data from the local store immediately, ensuring seamless view updates.

- [2026-07-07]: Loading Dialogs for Deletion Actions
  - *Details*: Added a loading spinner dialog and a dedicated result popup to all data deletion operations in settings (Reset Data, Delete Account, Delete Private Data) so that the app gives immediate visual feedback instead of appearing frozen or simply showing a brief snackbar.
  - *Tech Notes*: Replaced `_showGate` snackbars with a `_showResultDialog` (using `EvolveAlertDialog`) for deletion methods. Extracted the import loading dialog into a reusable `_showLoadingDialog` helper in `_SettingsPageState` and applied it across all heavy asynchronous deletion/reset methods.

---

- [2026-07-11]: Apple-style coherence pass — toast + spinner primitives, field-label dedup, desktop year-picker
  - *Details*: Second coherence round mirroring the mobile app's Phase 2 intent but with DESKTOP conventions (theme via `context.evolveColors`/`evolveAccent`, Lucide icons, Inter, hover/pointer polish, and deliberately NO haptics). Pure presentation — no business-logic or data changes, no new dependencies, no i18n keys. Label CASING left untouched (the UPPERCASE de-cap remains a separate pending decision).
  - *Tech Notes*:
    - **New `lib/shared/widgets/evolve_spinner.dart`** — `EvolveSpinner({color, radius = 12})` wrapping `CupertinoActivityIndicator` (macOS-native indeterminate spinner). Replaced 10 `CircularProgressIndicator` sites across statistics_page, settings_page (×3), goals_stats_view, auth_page, consent_page, desktop_shell, create_habit_dialog, create_goal_dialog — preserving explicit `color` (on-primary button spinners) and mapping each old `SizedBox.square(dimension: N)` to `radius: N/2`. Determinate `LinearProgressIndicator` bars left as-is.
    - **New `lib/shared/widgets/evolve_toast.dart`** — `showEvolveToast(context, {message, icon, kind, duration})` + `enum EvolveToastKind { neutral, success, error }`. Self-dismissing root-overlay banner (fade+slide via AnimationController), bottom-center, `panelRaised` fill + `border` + soft shadow; success→`EvolveColors.success`+`circleCheck`, error→`EvolveColors.destructive`+`circleAlert`, neutral→foreground/no icon. The visible-duration timer is a **cancellable `Timer` cancelled in `dispose()`** (not `Future.delayed`) so tearing the tree down mid-toast never leaves a pending timer. Replaced 9 Material `ScaffoldMessenger…showSnackBar` calls with it: settings_page (import error → `error`; `_showGate` → neutral), app_logs_dialog (`_toast`), goals_page (4× category create/archive/edit failures → `error`), auth_page (`_showMessage`), ai_coach_page (stream error → `error`) — mounted guards preserved.
    - **Field-label dedup** — deleted the four local `_FieldLabel` widgets (auth_page, habits_page, create_habit_dialog, create_goal_dialog; each byte-identical to the shared recipe) and pointed all call sites at the existing `EvolveFieldLabel` from evolve_controls.dart. Casing unchanged (still `.toUpperCase()` inside `EvolveFieldLabel`).
    - **goals_stats_view year-picker** — converted the mobile-idiom `showModalBottomSheet` (hand-rolled 40×4 grabber) to a desktop `showEvolveDialog`/`EvolveDialog` with an `EvolveDialogHeader` and a scrollable list of new private `_YearOption` rows (hover highlight, leading icon, trailing check when selected / lock when Pro-gated). Exact behaviour preserved: "All years" + per-year selection, and non-Pro years still pop the dialog, reset to `all`, and open the Pro-features dialog via the pre-captured page context. Removed all 3 `HapticFeedback` calls (the only haptics left in the desktop lib) and the now-unused `flutter/services.dart` import.
    - **desktop_biometric_controller** — `Icons.lock_outline_rounded`→`LucideIcons.lock`, `Icons.fingerprint_rounded`→`LucideIcons.fingerprint` (added the Lucide import; these were the file's only Material icons).
    - **Tests**: new `test/evolve_spinner_test.dart` (renders a `CupertinoActivityIndicator`, forwards color/radius) and `test/evolve_toast_test.dart` (overlay banner carries the message, error kind shows `circleAlert`, auto-dismisses). Fixing the toast timer leak also un-broke `widget_test.dart`'s "tutorial reset" test, which exercises a converted toast path.
    - **Verification**: `flutter analyze` → **No issues found!**; `flutter test` (dummy Supabase dart-defines) → **144 pass / 1 fail**, the single failure being the pre-existing `icloud_sync_card_test.dart` "delete private data…" (+5 vs the 139 baseline, 0 new failures); `dart format lib test` clean.

    - **Label de-cap (owner-approved follow-up — supersedes the "pending decision" note above)**: removed the forced `.toUpperCase()` from `EvolveSectionLabel` + `EvolveFieldLabel` (now 13px / w500 / ls -0.1 sentence-case, matching iOS `EvolveSectionHeader`) and from the Statistics + Goals-stats stat-card micro-labels and the goals `_StatusCountRow` "active" (which was inconsistently uppercased vs its failed/completed siblings). Kept UPPERCASE by explicit literal: the dashboard **'PROTOCOLLO'** strip (branded — matches the iOS header; `dashboard_page.dart` now passes the literal so it survives the de-cap and `widget_test.dart`'s `find.text('PROTOCOLLO')` stays green); the Auth **'OR'** divider left uppercase (a divider, not a section label). Re-verified: analyze clean, `dart format` clean, **144 pass / 1 pre-existing fail**.

- [2026-07-12]: Deep coherence polish — full macOS↔iOS parity audit + residual-drift fixes
  - *Details*: Owner asked to bring the macOS app to the SAME Apple-style as the finished iOS app for maximum coherence. A 6-cluster read-only audit (settings / goals / habits / statistics / dashboard+ai_coach / auth+shell) confirmed the desktop was already ~95% kit-conformant after the prior passes — no raw SnackBars / Switch / Dropdown / Radio / pickers / bottom-sheets, all dialogs already `EvolveAlertDialog`, Lucide-only, Inter theme-level, buttons themed. This round fixes the residual drift the audit surfaced. Pure presentation — no new deps, no business-logic changes.
  - *Tech Notes*:
    - **statistics_page** — the 7 hand-rolled `Color(0xFF10B981)` emerald "positive/completed" greens (30-day grid done-cell + legend, positive-correlation heading + value, high-mood & mood bars + legend dot) → `EvolveColors.success`, matching their already-tokenized rose/amber siblings. The same hex used as an accent PRESET / category-palette / swatch data elsewhere was left untouched.
    - **habits_page** — the day-detail dialog's last raw Material control, a `CheckboxListTile`, → new private `_DayHabitRow` mirroring `_HabitRow`'s completion square (22×22, r7, fills `habit.color` + `LucideIcons.check` ink `0xFF092113` when done; `GestureDetector`+`MouseRegion` kit idiom; dimmed 0.5 when the date isn't editable) plus title / status caption / flame+streak badge. Toggle wiring (`toggleHabitForDay`, `_canEditDate`) preserved verbatim.
    - **dashboard_page** — `_ActionTile`'s hand-rolled tinted icon container → `EvolveIconChip(icon, color)` (the same file's `_MetricCard` already used it; visually 1:1).
    - **goals_stats_view** — `_buildYearSelector` trigger reconciled to the `EvolveSelect` closed-trigger recipe (height 38→34, radius 14→12, `chevronDown`→`chevronsUpDown` 13px, muted calendar, ls -0.1) so it matches every other pop-up; the Pro-gated year dialog behind it is unchanged. 2× `Colors.grey` category-color fallback → `EvolveColors.subtle`.
    - **goals_page** — the tutorial sample goal's `Colors.blueAccent` → `EvolveColors.cyan` (token, same blue).
    - **app_logs_dialog** — ad-hoc severity `Container` pill → shared `StatusPill(label, color)`; the "ADDITIONAL CONTEXT" caps micro-label → `EvolveFieldLabel` + the `appLogs.detailExtras` i18n string de-capped to sentence case in en/it/de/es (ar is caseless) and `dart run slang` regen. Added the `evolve_controls` import.
    - **desktop_biometric_controller** — error text `Colors.redAccent` → `EvolveColors.destructive` (added the `evolve_theme` import).
    - **Deliberately preserved (confirmed convention/brand, NOT drift)**: the `0xFF092113` check-on-habit-color ink (used identically by `_HabitRow`), the accent-picker preset palette + curated chart/category viz palettes (no exact tokens), the `PROTOCOLLO` / `OR` / `DESKTOP` brand tags, the consent legal `CheckboxListTile` (iOS left it too), the Pro-features gold tiles, and the monospace log-content font.
    - **create_goal_dialog category** (owner chose "dropdown + New"): the free-text field is now an `EvolveSelect` of the saved categories (`desktopGoalCategoriesControllerProvider`, non-archived, color-dot leading) plus a "New category" row that reveals an inline autofocus text field — matching the goal editor while preserving free-entry. Empty-categories accounts still get the plain text field. `addGoal(category: String)` unchanged (passes the selected label or typed name); reuses the existing `goalsPage.newCategory` key (no i18n/regen).
    - **Verification**: `flutter analyze` → 1 issue, the pre-existing `main.dart:20 setMockInitialValues` (0 new); `flutter test` (dummy Supabase dart-defines) → **144 pass / 1 pre-existing fail** (`icloud_sync_card_test`); `dart run slang` regen clean.

- [2026-07-14]: Fix — private DB "file is not a database" (error 26) crash-loop on macOS
  - *Details*: `flutter run -d macos` crashed on boot with SQLCipher error 26
    (`open_failed evolve_private_v2.db`), thrown up through
    `CloudKitPrivateSyncService._syncNow → DesktopPrivateDb.syncStore → _open`.
    Root cause: `DesktopPrivateDb._encryptionKey()` unconditionally minted **and
    persisted** a fresh SQLCipher key whenever the Keychain read returned
    null/short. On a dev Mac a Keychain read-miss (re-sign / access-group change
    between builds is the usual trigger) therefore generated a new key, overwrote
    the stored one, and tried to open the pre-existing encrypted file with it →
    header won't decrypt → error 26 → unhandled exception every launch. Desktop
    had diverged from mobile, whose `PrivateLocalDatabase._databasePassword`
    already fails closed for exactly this reason.
  - *Tech Notes*:
    - `desktop_private_db.dart` `_open()` now computes `dbFileExists =
      await File(dbPath).exists()` and passes it to `_encryptionKey`.
    - `_encryptionKey({required bool dbFileExists})` now **fails closed**: if the
      key is absent (read null/<32 chars) **and** a DB file already exists, it
      throws `StateError` instead of minting a new key — so a transient Keychain
      miss can no longer orphan the encrypted data, and a later launch that can
      read the key still recovers. Only a true first run (no db file) generates a
      key. Mirrors mobile verbatim in intent.
    - Does NOT auto-recover an already-orphaned file: the manual one-time reset
      (delete `evolve_private_v2.db*`) is logged in TO_SIMO_DO.md.
    - Remaining desktop↔mobile coherence gaps (flagged, NOT yet done): desktop
      uses raw `FlutterSecureStorage()` — no `first_unlock_this_device`
      accessibility pin and no duplicate-item (`-25299`) write recovery, both of
      which mobile's `SecureStorageUtils` has. Pinning accessibility would reduce
      read-miss frequency; the guard above prevents the catastrophic outcome
      regardless.
    - *Verification*: `flutter analyze lib/core/desktop_private_db.dart` clean;
      DB/sync tests green except one **pre-existing** unrelated fail
      (`import_merge_lww_test` "mobile 1.0.10 export → desktop import", confirmed
      red without this change via `git stash`).

- [2026-07-14]: Full desktop↔mobile parity port for Private-mode secret storage
  - *Details*: Owner-approved follow-up to the error-26 fix. Closed the remaining
    coherence gaps between desktop's private-DB secret handling and mobile's
    hardened `SecureStorageUtils` / `PrivateLocalDatabase`. The private-mode
    secrets (SQLCipher key + owner UUID) were the ONLY desktop keychain consumers
    still on bare `FlutterSecureStorage()` — no accessibility pin, no duplicate
    recovery, and the DB was not backup-excluded (mobile excludes it). No new
    deps; one native macOS channel added (mirrors the existing iOS one).
  - *Tech Notes*:
    - `secure_storage_utils.dart` — added a **device-local tier**
      (`_deviceLocalStorage`, `readDeviceLocal`/`writeDeviceLocal`/
      `deleteDeviceLocal`) pinned to `MacOsOptions(accessibility:
      first_unlock_this_device)` — on-this-Mac-only, never iCloud-synced,
      matching mobile's `_deviceLocalStorage`. `writeDeviceLocal` has -25299
      duplicate-item recovery scoped to the single key and **never** falls back
      to `deleteAll()` (that keychain holds the SQLCipher key; wiping it = perma
      data loss — mirrors mobile's SEC-6 note). Existing default-option items
      stay readable (accessibility isn't part of the read query; synchronizable
      stays false).
    - `desktop_private_db.dart` — routed all three private-secret touchpoints
      (`_encryptionKey`, `ownerId`, `adoptOwner`) through the device-local tier
      and dropped the bare `const FlutterSecureStorage()` (+ its import). Combined
      with the 07-14 fail-closed guard, the private key now has the same lifecycle
      protections as mobile.
    - **Backup exclusion** (new): `_open()` now calls `_excludeFromBackup(dir)`,
      which flags the whole private Application Support directory (DB +
      `-wal`/`-shm` sidecars + `private_profile` avatars) as
      `isExcludedFromBackup` via a new native `evolve/private_storage`
      MethodChannel, and drops a `.private_mode_local_only` marker file.
      Best-effort (failures logged via `AppLogger.warning`, non-fatal). Native
      half added as `PrivateStorageBridge` in `macos/Runner/AppDelegate.swift`
      (a line-for-line port of the iOS handler) and registered in
      `MainFlutterWindow.swift` next to `CloudKitSyncBridge`. Kept in the existing
      Runner-target file so it builds without editing the Xcode project.
    - *Verification*: `flutter analyze lib` → 0 new issues (only the pre-existing
      `main.dart:20 setMockInitialValues` warning); Swift `swiftc -typecheck` of
      both Runner sources → clean; `flutter test` (dummy dart-defines) → **189
      pass / 2 pre-existing fails** (`icloud_sync_card_test`, `import_merge_lww`
      — both confirmed red without these changes via `git stash`). The native
      backup-exclusion behavior itself needs an on-device check on the Xcode
      machine (logged in TO_SIMO_DO.md) — it can't run in this headless env.

- [2026-07-14]: Mobile↔desktop parity AUDIT + Tranche 1 (data-integrity core)
  - *Details*: Owner wants desktop to "act, behave and reason the same way" as
    the finished mobile iOS app. Ran a 44-agent parity audit (13 subsystems,
    per-finding adversarial verification) → 28 confirmed high/medium + 4 low
    divergences, all app-level and portable (none macOS-capability-limited).
    Full report saved to `desktop/PARITY_AUDIT.md`. Agreed fix order:
    1) data-integrity, 2) notifications+biometric, 3) privacy+affordances,
    4) monetization/Pro-gates LAST. This entry covers Tranche 1.
  - *Tech Notes (Tranche 1 — 9 fixes, all faithful ports of mobile logic)*:
    - **#1 goal_logs.value drop** (data loss): added `'value': l['value']` to the
      import parse (`desktop_backup_import_service.dart` `_processData`), the
      private-merge INSERT + LWW UPDATE, and the `exportSnapshot` habitLogs
      projection (`desktop_private_db.dart`). Fixes the failing round-trip test.
    - **#4 orphaned-owner self-heal**: ported `_reconcileOrphanedOwner` (called
      from `_open` after seed) + an in-memory owner-id cache (`_cachedOwnerId`)
      so an adopted owner sticks even if the Keychain write fails.
    - **#26 seedProfile language**: seed `language:'system'` (+ the other prefs
      mobile seeds) so a fresh/synced profile row is byte-identical and the
      schema DEFAULT `'it'` can't propagate via LWW.
    - **#3 deleteAll footgun**: `SecureStorageUtils` refactored to a shared
      `writeScoped` (scoped -25299 recovery, NEVER `deleteAll`); removed the
      `clearAllOnDuplicateFailure`/`deleteAll` paths + the session-persist call's
      use of it (`secure_local_storage.dart`). A session-key write can no longer
      wipe the co-located Private-Mode SQLCipher key.
    - **#16 synced-secret self-heal**: `DesktopSyncSecretStore.write` now
      delegates to `writeScoped` so a -25299 on the collision-prone shared-group
      store self-heals instead of aborting sync.
    - **#10 mode recovery**: added `DesktopPrivateDb.databaseFileExists()` +
      `main.dart` restore of `active_data_mode=private` when the pref is null but
      the DB file exists.
    - **#11 refresh-after-pull**: new `refreshPrivateAfterPull(container)` helper
      (dashboard+analytics+profile+categories), wired into the sync-lifecycle
      `_sync` and the notification `onLocalWrite` so auto-pulls surface
      cross-device profile/category edits (was dashboard+analytics only).
    - **#13 ensureReady on enter-private**: `DesktopAuthController.enterPrivateMode`
      now opens the DB inside try/catch and only flips the mode on success (else
      stays in Supabase mode + `t.authCtrl.operationFailed`), so a failed open
      can't strand the app in Private mode.
    - **#14 notif cleanup on delete**: `_deletePrivateData` now calls
      `_syncNotifications()` after the wipe so orphaned per-habit reminders are
      cancelled.
    - *Verification*: my 10 changed files are `flutter analyze`-clean (0 errors).
      Ran the pure-logic test files (widget tests are blocked — see below):
      **22 test files pass**, incl. the previously-RED
      `import_merge_lww` "mobile 1.0.10 export → desktop import ... losslessly"
      (now green, +12). No genuine failures introduced.
  - *⚠️ BLOCKER (concurrent work, NOT this change)*: the in-flight **AI-coach**
    feature currently leaves the app NON-COMPILING, so `flutter run -d macos` and
    all widget tests fail regardless of these fixes. Two independent breakages,
    both in files this change never touched: (a) `lib/features/ai_coach/**` has 5
    compile errors (missing i18n keys `coachSettings.cloudKeyMissing`, undefined
    `CloudCoachBackend`, `modelNotFound`/`baseUrlFocus`/`onCommitSystemPrompt`
    param mismatches); (b) `lib/core/tutorial_provider.dart` was modified to
    remove/rename `tutorialProvider`, but `settings_page.dart:1016` and
    `dashboard_page.dart:105` still reference it. Must be resolved (by whoever
    owns the AI-coach branch) before on-device verification of ANY desktop work.

- [2026-07-14]: Parity Tranches 2–4 (notifications+biometric / privacy / monetization)
  - *Details*: Continued the mobile→desktop parity port. The concurrent AI-coach
    compile breakage (ai_coach errors + `tutorialProvider` refactor) was resolved
    by that session mid-way, so the full suite + widget tests run again.
  - *Tech Notes*:
    - **Tranche 2 — notifications + biometric (7)**: #7 per-goal reminders now
      schedule independently of the 'Habit Reminders' toggle (only the Morning
      Brief is gated); #21 Snooze reschedules +10 min (id+1000) instead of no-op;
      #22 `_canSchedule` 64-pending cap guard (fail-open); #23 `requestPermissions`
      on any scheduling path (covers the habit editor); #15 biometric unlock fails
      OPEN when no biometrics are enrolled (no macOS lockout); #8 gate is now
      stateful (`AppLifecycleListener`) and re-arms (`rearm()`) on
      inactive/hidden/paused; #30 auto-prompts on cold start + resume + async-arm.
    - **Tranche 3 — privacy + affordances**: #2 ported `PrivacyUtils` and scrub
      message+extras in `AppLogger.info/warning` before Sentry (error() left raw,
      mobile parity); #31 placeholder DSN now treated as UNCONFIGURED + default
      `tracesSampleRate` 1.0→0.2; #27 avatar `FileImage.evict()` after in-place
      overwrite. #25 (verified-habit badge) DEFERRED — substantial UI needing
      visual QA.
    - **Tranche 4 — monetization/Pro-gates (6)**: #5 free-tier 5-habit cap
      (`addHabit` returns bool; both callers show `showProFeaturesDialog`); #6
      per-habit statistics gated (scope switch → paywall for non-Pro); #17 generic
      "any active entitlement → Pro" fallback; #18 isPro seeded from cached
      `pref_is_pro` at build (offline cold-start); #19 purchase/restore sync+
      invalidate+refetch retry + already-purchased auto-restore; #20
      `addCustomerInfoUpdateListener` keeps isPro live. #29 (accent-color gate)
      NOT done — needs an owner policy decision.
    - *Verification*: `flutter analyze lib` → 0 errors (only the pre-existing
      `main.dart:21 setMockInitialValues` warning); `flutter test` → **214 pass /
      1 pre-existing fail** (`icloud_sync_card_test`, a `pumpAndSettle` timeout
      confirmed RED without any of these changes). The 07-14 `import_merge_lww`
      round-trip that was RED is now GREEN. New files: `privacy_utils.dart`,
      `private_data_refresh.dart`.
  - *Owner decisions still needed (not code)*: #12 should a MERGE-import be
    allowed to overwrite the active profile/theme/language (desktop does, mobile
    doesn't)?; #29 Pro-gate the custom accent color like mobile, or leave it free
    on desktop?; #9 is a MOBILE-side fix (its cloud-import drops verify_* rules);
    #28 D8 verified-habit manual-override is a documented shared-design limit.

- [2026-07-14]: Owner-approved finishers — #12, #29, #25
  - **#12 import profile gate** (owner: match mobile): the profile/settings block
    is now applied ONLY on a REPLACE import, both private
    (`desktop_private_db.dart` applyImport, gated on `replaceExisting`) and cloud
    (`desktop_backup_import_service.dart`). A MERGE import no longer overwrites
    the active user's theme/language/name. Added 2 tests (merge preserves / replace
    restores) — green.
  - **#29 accent Pro-gate** (owner: Pro-gate it): `_ColorRow` gained
    `customLocked`/`onCustomLocked`; the custom '+' swatch now shows a lock and
    opens the paywall for non-Pro (Private mode always Pro). Presets stay free.
  - **#25 verified badge** (owner: do it now): new shared `VerifiedHabitBadge`
    (shield-check + reused `t.settingsPage.verified`, no slang regen to avoid the
    concurrent i18n churn); rendered next to the habit title in both the dashboard
    and habits `_HabitRow` when `habit.verificationRule != null`. Still wants a
    visual pass on device (badge copy/placement).

### Current Status
**Full mobile↔desktop under-the-hood parity port COMPLETE** — all 4 tranches +
the three owner-approved finishers (#12/#29/#25). Of the 32 audited divergences,
the only two NOT changed are #9 (a MOBILE-side fix; desktop already correct) and
#28 (a documented shared-design limitation, no code). Code-verified: `analyze
lib` → 0 errors (1 pre-existing warning); `flutter test` → **216 pass / 1
pre-existing fail** (`icloud_sync_card_test`, confirmed RED without any of these
changes). Tree uncommitted for review — NOTE it also contains the concurrent
AI-coach feature + i18n regen, so commit the parity files separately. Only
remaining: on-device QA on the Xcode machine (TO_SIMO_DO.md) — visual pass on the
verified badge + smoke test of notifications / biometric re-lock / Pro gates,
plus the earlier DB-reset / backup-exclusion checks.

- [2026-07-14]: HOTFIX — reverted the device-local `first_unlock_this_device` pin (it was a lockout regression)
  - *Symptom*: on-device import of a real iOS backup threw `Bad state: Private
    database key unavailable while the database file exists; refusing to
    regenerate it` (the fail-closed guard firing).
  - *Root cause*: the earlier secret-storage parity port pinned
    `SecureStorageUtils._deviceLocalStorage` to `first_unlock_this_device`. On
    macOS the `flutter_secure_storage_darwin` `baseQuery` (used by BOTH read and
    write) puts `kSecAttrAccessible` INTO the lookup query, so an item WRITTEN
    with the old default accessibility is NOT matched when READ with a different
    one → `read` returns null → the guard concludes the key is gone. Desktop's
    private-mode secrets were all written with default options, so the pin made
    the existing key (and owner id) unreadable. This would have locked out EVERY
    existing desktop private-mode user on the update, not just import.
  - *Fix*: `_deviceLocalStorage` reverted to default options (`FlutterSecureStorage()`)
    — identical to how desktop always wrote these secrets, so existing keys read
    again. Default options already keep the key device-local (`whenUnlocked`,
    non-synchronizable ⇒ never iCloud-synced) and the DB file is separately
    backup-excluded, so the pin bought ~nothing. The important fixes from that
    port (fail-closed guard, scoped `-25299` recovery, no `deleteAll`, backup
    exclusion) are UNAFFECTED. Corrected the class doc claims in
    `secure_storage_utils.dart` + `desktop_private_db.dart`. Verified: analyze
    clean; DB/sync tests 28 pass. NOTE: mobile keeps its pin (it shipped pinned
    from day one — no legacy items to migrate); desktop can't retroactively
    change already-written keys.


- [2026-07-14 13:10]: AI Coach — full-width composer on wide desktop windows
  - *Details*: On large screens the AI Coach input bar felt fixed-width and the
    prompt suggestion chips were clipped by a hard right-edge "wall". Both were
    caused by the bottom dock (suggestion strip + input bar) being wrapped in a
    `Center` + `ConstrainedBox(maxWidth: 900)` — the same cap used for the
    message thread. Removed that cap from the dock only so the composer and the
    horizontal suggestion `ListView` now span the full panel width (minus the
    existing 20px side padding) and grow with the window.
  - *Tech Notes*: `lib/features/ai_coach/presentation/ai_coach_page.dart`. The
    message thread `ListView` keeps its centered `maxWidth: 900` for reading
    width (bubbles are still individually capped at 640). No new deps, no API
    changes, layout-only. Verified: `flutter analyze` clean; `ai_suggestions`
    tests 5 pass.


- [2026-07-14 14:40]: Statistics — major Insights enrichment (parity fills + new metrics + surprise stats)
  - *Details*: The desktop Insights screen felt sparse next to mobile. Enriched
    all five global tabs plus the per-habit Overview WITHOUT adding tabs.
    **Info**: bold hero (Momentum/Form ring + lifetime tiles — consistency %,
    total done, perfect days, days tracked), all-time best-streak + Top
    Performer + Critical Day tiles, a Keystone-habit insight card, and the old
    90-day heatmap upgraded to a 365-day GitHub-style contribution grid.
    **Trend**: Best/Critical habits are now ranked lists (were single cards),
    plus rolling 7/30-day rate with trend arrows, this-week-vs-average,
    weekly-rhythm radar, weekday-vs-weekend, and monthly seasonality bars.
    **Alerts**: Performance Comparison (best-vs-worst streak gap), Bounce-back
    rate (recovery after a miss), and Danger Zone (weekday streaks break most).
    **Habits**: current-streak column added to the table; consistency
    (regularity) ranking; streak medals + Never-Missed badges; completion-rate
    distribution histogram; per-category breakdown (auto-hides with <2
    categories); and an N×N habit synergy matrix. **Mood**: the mobile-parity
    fills — mood/energy line chart, Mood-Sensitive list, Resilient Habits list,
    and per-habit low/high-mood correlation analysis. **Per-habit Overview**:
    added the Record (best-streak) tile (was 3 tiles, now 4).
  - *Tech Notes*: New pure engine `lib/features/statistics/data/analytics_extra.dart`
    (computeLifetimeSummary, computeKeystoneHabit, computeBounceBackRate,
    computeWeekdayWeekendSplit, computeGlobalWeekdayPerformance,
    computeSeasonality, computeConsistencyScores, computeDangerZone,
    computeMomentumScore, isGoalActiveOn) — deliberately kept OUT of the
    byte-for-byte mobile mirror `private_analytics.dart`. New widgets live in
    `statistics_extras.dart` (`part of statistics_page.dart`, reusing its
    private primitives). In `statistics_rpc_providers.dart` a mode-aware
    `unifiedAnalyticsDataProvider` (Private → encrypted DB; Cloud →
    `buildAnalyticsDataFromSnapshot` over the dashboard snapshot, which already
    holds the full `goal_logs` history) routes every new stat through the same
    pure functions — NO new Supabase RPCs / SQL / migrations. Momentum =
    `0.5·rate7 + 0.3·streakHealth + 0.2·trend`. 82 new `stats.*` i18n keys added
    to all five locales (en/it authored; de/es/ar best-effort) + `dart run
    slang`. Momentum ring uses `CircularProgressIndicator`; radar uses fl_chart
    1.2.0 `RadarChart`; other charts are Flutter primitives. New test
    `test/analytics_extra_test.dart` (21 cases). Verified: `flutter analyze`
    clean; full suite 268 pass / 1 pre-existing env failure
    (`icloud_sync_card_test` Postgrest network). On-device QA pending — no Xcode
    on this Mac.
  - *Post-review*: A 12-agent adversarial review (4 dimensions × per-finding
    verification) confirmed 4 issues; 3 fixed, 1 documented. **Fixed**: (1)
    `computeDangerZone` now scans through `skipped` between a `done` and a
    `missed` (was undercounting breaks, inconsistent with `computeBounceBackRate`);
    (2) cloud Momentum sourced its current-streak from the session-cached
    `habit_stats` view while rate7 was live — now the reactive dashboard snapshot
    drives the current streak in both modes (best-streak still from `habit_stats`),
    restoring Private/Cloud parity; (3) `buildAnalyticsDataFromSnapshot` now skips
    empty `dateKey -> {}` maps the optimistic snapshot can retain, which had
    inflated activeDays / skewed keystone. **Documented (not fixed)**: the
    local-midnight `difference().inDays` day-count can be off by one across a
    spring-forward DST span — kept to match the mobile-mirrored
    `computeHabitStatsRow` so the Consistency % stays consistent with per-habit
    rates (in-code comment added).


- [2026-07-14 15:20]: Statistics — per-habit (Pro) tabs enriched
  - *Details*: The per-habit scope's 5 tabs were sparse (Calendar was a single
    heatmap). Kept the 5-tab structure and enriched each for the wide desktop
    canvas. **Overview** is now a hero: a per-habit **Momentum ring** + an
    8-tile grid (Completion, Current streak, Record, Missed, Total done,
    Bounce-back, Consistency, Days-tracked) + a "vs your other habits"
    percentile pill, keeping the 30-day grid + correlations. **Calendar** adds
    gap analysis (avg / longest / days-since-last-done), monthly **seasonality**
    bars and **this-month-vs-last**, beside the yearly heatmap. **Performance**
    adds **weekday/weekend** split and **rolling 7/30-day** rates with trend
    arrows. **Improvement** adds Bounce-back / Consistency / At-risk / Danger-day
    tiles + a **streak-history** bar strip + a **schedule-adherence** panel.
    **Mood** adds a **next-day mood-impact** panel (mood/energy the day after a
    done vs a miss).
  - *Tech Notes*: 5 new pure functions in `analytics_extra.dart`
    (computeGapStats, computeAdherence, computeStreakHistory,
    computeNextDayMoodImpact, computeHabitMilestones) + their classes; one family
    provider `habitAnalyticsBundleProvider(habitId)` computes the whole per-habit
    bundle in a single pass from `unifiedAnalyticsDataProvider` +
    `habitStatsRpcProvider`, so it's Private/Cloud-aware with no backend changes
    (global bounce-back/consistency/danger-zone/seasonality/weekday-weekend reused
    by scoping to `{habitId: logs}`; percentile derived from the habit_stats
    rows). New per-habit widgets in `statistics_extras.dart` wired into the
    `_Habit*` tab widgets. 28 new `stats.*` keys × 5 locales + `dart run slang`.
    10 new unit tests (30 total in the file). Verified: `flutter analyze` clean;
    suite 276 pass / 1 pre-existing env failure. Per-habit scope stays
    Pro-gated; on-device QA pending — no Xcode on this Mac.
  - *Post-review*: A 10-agent adversarial review confirmed 5 issues, all fixed.
    (1) **[high→fixed]** `computeStreakHistory` grouped `done` logs by status
    only, merging runs across unlogged-day gaps and inflating "longest streak";
    now calendar-contiguous, matching `computeStreak` (streak_utils.dart) — added
    a regression test. (2) **[medium→fixed]** per-habit Momentum sourced the
    current streak from the session-cached `habit_stats` view while rate7 was
    live (Cloud-stale, non-parity); now reads the reactive dashboard-snapshot
    streak in both modes (also for the Overview current-streak tile).
    (3) **[low→fixed]** percentile counted the habit against itself (`<=`); now
    excludes self, strict `<`, divided by (n−1). (4,5) **[low→fixed]**
    `computeGapStats` and `computeHabitMilestones` used local `difference().inDays`
    (DST off-by-one); switched to a DST-safe UTC-midnight day helper, consistent
    with `computeAdherence`/`computeNextDayMoodImpact`. Re-verified: analyze
    clean; suite 277 pass / 1 pre-existing env failure.

## [2026-07-14]: Goals board — linear single-column layout with top ring header

### Details
Reworked the Goals page board so completed/failed goals no longer move into a
right-hand rail. The board is now a single linear column at every window width:
a header band pins the completion ring, the period heading, and the per-status
counts to the top of the box; active goals flow beneath as single-line rows; and
completed then failed goals settle at the bottom under their existing labeled
`COMPLETED` (green) / `FAILED` (red) status dividers, so each row's inline
check/X status mark reads on its own line. This effectively promotes the former
narrow-width single-column flow to all widths and deletes the wide-only card
grid + right rail.

### Changes Made
#### 1. `lib/features/goals/presentation/goals_page.dart`
- `_GoalBoard.build` replaced the `LayoutBuilder` wide/narrow fork with one
  `EvolvePanel` "main box": `_boardHeader` → hairline → active rows → COMPLETED
  divider + rows → FAILED divider + rows (sections still render only when
  non-empty; empty-state unchanged).
- Added `_boardHeader(context)`: ring (`_PeriodProgressRing`, completion =
  completed ÷ total) on the leading edge, `_periodHeading` in an `Expanded`
  middle, and a fixed 160px column of the three `_StatusCountRow`s
  (Completed/Failed/Active) on the trailing edge.
- Removed now-dead code: `_activeGrid`, `_PeriodSummaryPanel` (its ring + counts
  are reused inline by the header), `_GoalItem.asCard` + `_cardLayout`, and
  `_GoalCategoryChip`. `_activeItem` lost its `asCard` param; `_GoalItem.build`
  always uses `_rowLayout` with a constant 12px vertical padding.

### Tech Notes
- No controller/logic changes: complete/fail still cycles via the existing
  2-second debounce in `_GoalItemState`, after which the goal drops into its
  bottom section. Tour target keys (first-active-item checkbox spotlight) intact.
- No new i18n strings — dividers and counts reuse `t.macroGoals.completed` /
  `t.macroGoals.failed` / `t.goalsStats.active`. No locale files touched.
- Full-bleed by design (chosen over a capped column) to stay aligned with the
  command bar and the fluid `DesktopPage` (no max-width cap) sibling pages.
- Verified: `flutter analyze` clean (only the unrelated pre-existing
  `main.dart` secure-storage warning); suite 276 pass / 1 pre-existing env
  failure (`icloud_sync_card_test`, Postgrest network — unrelated to goals); the
  goals-rendering `tour_flow_test` passes. On-device visual QA pending (no Xcode
  on this Mac).

### Follow-up: counts as a single inline strip
Per feedback, the three header counts no longer stack vertically. `_boardHeader`
now renders them on one line, right-aligned on the heading row: `COMPLETED n |
FAILED n | ACTIVE n`, each label in its status color (green / red / accent) with
a hairline pipe (`_countDivider`) between the `_countItem` units. Removed the
now-unused `_StatusCountRow`. Verified the strip fits every locale (longest is
German `FEHLGESCHLAGEN`, ~345px total) down to the 960px minimum window with the
heading ellipsizing. `flutter analyze` clean; `tour_flow_test` still passes.


- [2026-07-14 16:10]: Statistics — mathematical audit (3-way: cloud SQL vs mobile vs desktop) + desktop fixes
  - *Details*: Ran a 38-agent audit deriving the exact formula for 54 habit
    statistics across all three implementations (cloud SQL migrations/*.sql,
    mobile Dart, desktop Dart) with per-finding adversarial verification. Result:
    21 exact 3-way matches, 15 divergences, 18 desktop-only; 19 confirmed issues.
    Full reference in docs/HABIT_STATS_AUDIT.md. Fixed the four clearly-desktop
    bugs: (a) [high] the cloud get_best_habits caller passed the raw UI timeframe
    token to a SQL RPC that filters on week|month|year|all -> all-zero Best-Habits
    rates in cloud mode; now canonicalised. (b) [low] computeKeystoneHabit had no
    positivity gate and could surface an anti-keystone; added lift>0. (c) [medium]
    _performanceComparisonCards sorted by best_streak but showed the gap (could be
    negative); now ranks by the clamped gap (mobile parity). (d) [low] three
    desktop window-rate helpers used today.subtract(Duration(days:n)) (DST-unsafe);
    switched to calendar-day stepping.
  - *Tech Notes*: statistics_rpc_providers.dart, analytics_extra.dart (+keystone
    test), statistics_extras.dart. Verified: analyze clean; suite 278 pass / 1
    pre-existing env fail; 32 analytics unit tests. STILL OPEN (cross-codebase,
    tracked in docs/HABIT_STATS_AUDIT.md + TO_SIMO_DO.md): (A) shared Dart
    DST/timezone edge in the byte-identical private_analytics.dart mirror
    (total_active_days/rate/avg_recovery_days/yearly-grid/critical-habits
    under-count 1 day across spring-forward; mobile+desktop equal, private mode);
    (B) two cloud-SQL get_global_trend bugs (YEAR & ALL drop empty days/months,
    Dart correct) need a migration; (C) the WEB client never persists
    goal_logs.streak, so cloud habit_stats reports 0/stale streaks for web-toggled
    habits; (D) a mobile _recoveryPatterns string-sort bug (desktop correct).


- [2026-07-14 16:40]: Statistics audit — cross-codebase fixes applied (A, B, D)
  - *Details*: Applied the audit's approved cross-cutting fixes. (A) DST-safe date
    math in the byte-identical private_analytics.dart mirror on BOTH mobile +
    desktop: added _daysBetween (UTC-midnight calendar-day count) + _shiftDays
    helpers and replaced the .difference().inDays / .add(Duration(days:)) sites in
    total_active_days (->rate), avg_recovery_days, computeYearlyGrid walk,
    computeCriticalHabits age/neg-streak, and computeBestHabits window — so these
    match the cloud SQL calendar arithmetic across a DST boundary (previously
    under-counted a day, and rate could exceed 100%). (D) Mobile
    _calculateRecuperoData now sorts recovery times numerically (was string-
    sorting "10"<"2", mislabelling the slowest habit fastest). (B) Wrote
    migrations/20260714_fix_get_global_trend_year_all.sql fixing the YEAR & ALL
    timeframes to LEFT JOIN the full day range (empty day = 100%) so the cloud
    trend series matches the correct Dart series.
  - *Tech Notes*: desktop private_analytics.dart, mobile private_analytics.dart
    (identical semantic change), mobile global_alerts_tab_widget.dart, new SQL
    migration. Verified: desktop analyze clean + full suite 278 pass / 1
    pre-existing env fail (private_analytics_test 24 pass); mobile analyze clean +
    private_analytics_test 19 pass. The SQL migration needs review + deploy to
    Supabase (can't run Postgres here). NOT done (web app, out of scope): the web
    client doesn't persist goal_logs.streak -> cloud habit_stats streaks wrong for
    web-toggled habits. Full audit + fix status in ../docs/HABIT_STATS_AUDIT.md.
