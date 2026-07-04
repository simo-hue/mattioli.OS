# Evolve Desktop - Documentation

## [2026-07-03]: Privacy Mode Implementation
*Details*: Implemented a "Privacy Mode" for the macOS desktop application to allow users to use the app entirely offline and anonymously, mirroring the iOS mobile app's privacy features. This mode stores all user data locally without syncing to Supabase.
*Tech Notes*:
- **Local Database**: Integrated `sqflite_sqlcipher` for encrypted local SQLite storage.
- **Repository Abstraction**: Created `PrivateDashboardRepository` and a proxy repository to dynamically switch between Supabase and local storage based on the active mode (`activeDesktopDataModeProvider`).
- **Data Identification**: Used `uuid` v4 for generating IDs locally in Private Mode, mimicking Supabase's UUIDs.
- **Sentry Integration**: Added a privacy boundary that forcibly disables Sentry crash reporting when Private Mode is active.
- **Authentication**: Added a "Continua in modalità privata" button to the authentication screen that bypasses Supabase login.
- **Settings**: Adapted the settings page to hide cloud-only features (e.g., password change, subscription) when in Private Mode, replacing them with local data deletion options.

## [2026-07-04]: Private Mode ⇄ iOS Parity Gap Audit
*Details*: Produced `desktop/PRIVATE_MODE_PARITY_GAPS.md` — a discovery/gap document comparing the desktop Private-Mode implementation against the mobile (iOS) app to drive a follow-up implementation pass toward 100% feature parity. No code was changed.
*Tech Notes*:
- Cross-referenced every privacy path in `desktop/lib` against `mobile/lib` (Phase 1 local encrypted mode + Phase 2 iCloud/CloudKit sync).
- Key gaps found: local analytics/statistics engine entirely missing on desktop (stats use Supabase RPC → empty in Private Mode); no AI external-send consent gate; `isPro` forced *false* in Private Mode (locks Pro features — inverse of mobile); missing `profiles` owner-row bootstrap (profile/avatar writes hit 0 rows); import owner-id mismatch (`'local_user'` vs UUID) + non-existent `goal_logs.value` column; avatar dir not deleted on wipe; no localization (hardcoded Italian); Phase 2 iCloud sync 100% absent (requires a backend decision since CloudKit is Apple-only).
- The document contains a parity scorecard, per-area gap analysis with `file:line` refs, a confirmed-bugs table, a Phase-2 architecture decision section, a prioritized implementation order, and open product questions.

## [2026-07-04]: Private Mode parity — implementation (Phase 1)
Executing `PRIVATE_MODE_IMPLEMENTATION_PLAN.md` (decided via a design interview: mirror mobile; macOS↔iOS CloudKit sync in Phase 2; Windows/Linux local-only forever; full slang localization incl. Arabic RTL; macOS actionable notifications).

### Current Status
- **WS1 — DB foundation: DONE.** Ported mobile's `private_db_schema.dart` verbatim (single source of truth, v3, sync_state/sync_meta + dirty/tombstone triggers). Rewrote `desktop_private_db.dart` onto it: `PRAGMA foreign_keys = ON`, `seedProfile` owner bootstrap, `deleteAllPrivateData` (wipe+avatar+reseed, keep key/owner, **stays in Private mode**), fresh `evolve_private_v2.db` baseline, static testable helpers (`seedProfile`/`wipeUserData`/`applyImport`). Fixed **B1** (profile bootstrap + FKs), **B2** (import under real owner UUID, not `local_user`), **B3** (`goal_logs.value` column), **B6** (avatar dir deleted on wipe). Updated callers (`private_dashboard_repository`, `goal_categories_controller`, `settings_page`) for the aligned schema (NOT-NULL timestamps, no `is_active`). Added `sqflite_common_ffi`. Tests: `test/private_db_schema_test.dart` (10) green.
- **WS2 — Pro unlock: DONE.** Added `desktopIsProProvider` (true in Private mode, else RevenueCat) in `desktop_subscription_controller.dart`; rerouted the real feature gates (macro-stats year selection ×2 in `goals_stats_view.dart`, >100-goals cap in `dashboard_page.dart`). Pro badge/paywall stay hidden via `!isPrivateMode`. Test: `test/private_entitlement_test.dart` green.
- Verification: `flutter analyze` clean on all touched files (remaining warnings are pre-existing debt in `goals_stats_view.dart`). 5 pre-existing widget/config test failures are environmental (need `--dart-define` Supabase config) and predate this work.

- **WS3 — AI external-send consent: DONE.** `openrouter_config.dart` key now via `--dart-define=OPENROUTER_API_KEY` (empty→inert). `DesktopPrivateDb.hasPrivateAiExternalConsent`/`setPrivateAiExternalConsent` added. `ai_coach_page.dart` now gates every external send behind `_ensurePrivateAiConsent()` in Private mode (blocks until accepted; consent persisted in the profiles row).
- **WS4a — Local analytics engine: DONE.** Ported `mobile/lib/core/private_analytics.dart` **verbatim** → `lib/features/statistics/data/private_analytics.dart` (+ `canonicalBestHabitsTimeframe`). Added `private_analytics_source.dart` (`privateAnalyticsDataProvider` loads goals/logs from the encrypted DB into the engine's input structures, refreshes on dashboard changes). Rerouted the consumed stat providers in `statistics_rpc_providers.dart` to compute locally in Private mode (global critical day, global trend, yearly grid, performance-by-day, alerts, + best/critical habits) — private branch returns before any Supabase read. Parity test `test/private_analytics_test.dart` (19 vectors ported verbatim from mobile) green. **Statistics now render in Private mode** (was the single biggest gap).

### Test status
`flutter test` → **+59 -5**. The 30 new Private-Mode tests all pass (`private_db_schema_test` 10, `private_entitlement_test` 1, `private_analytics_test` 19). The 5 failures are PRE-EXISTING and environmental (need `--dart-define` Supabase config) — confirmed via `git stash` that they fail identically on the original code.

### Remaining workstreams (not yet started)
- **WS4b** — port the inline **habit correlations** + **macro-goal stats** from mobile `private_local_database.dart:896-1294`; wire `habitCorrelationsRpcProvider`, `allHabitCorrelationsRpcProvider`, `macroGoalsStatsRpcProvider` to compute locally (still RPC-only → blank in Private mode).
- **WS5** — unify private profile name onto DB `profiles.full_name` (drop the `SharedPreferences 'private_profile_name'` fork in `dashboard_page.dart:56,1037`); reload avatar from DB on launch; bring `settings_page._exportData` to full-private-export parity (use `DesktopPrivateDb.exportData`, include categories + profile).
- **WS6** — route private settings through the DB `profiles` row (theme/accent/calendar/language/24h/haptics/notif flags/times/biometric).
- **WS7** — stand up **slang**; full desktop localization (en/it/es/de/ar) incl. the new Private-Mode strings (AI consent dialog copy in `ai_coach_page.dart`, delete/entitlement snackbars) + Arabic **RTL pass** (port mobile `lib/core/rtl.dart`).
- **WS8** — macOS actionable notifications (Done/Skip/Snooze → local DB, mode-aware).
- **WS9** — guard tests: no-Supabase-call-in-Private (CRUD + stats), settings-separation, notification-action routing.
