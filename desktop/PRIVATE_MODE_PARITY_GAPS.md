# Private Mode — Desktop ⇄ iOS Parity Gap Audit

Created: 2026-07-04
Scope: **Private Mode only** (the local, encrypted, account-less data mode + its iCloud sync). Other features are intentionally out of scope for this pass.
Method: full static read of every privacy-related path in **`desktop/lib`** (Flutter macOS/Windows/Linux client) cross-referenced against the **`mobile/lib`** (Flutter iOS/Android client) implementation and its design docs (`mobile/PRIVATE_MODE_PRODUCTION_PLAN.md`, `mobile/PRIVATE_MODE_DISCOVERY.md`, `mobile/ICLOUD_SYNC_PLAN.md`).

> **This is a discovery/gap document only.** No code was changed. It is the input for the next (implementation) iteration. Every claim cites `file:line`. The goal is 100% of the mobile Private-Mode feature set on desktop.

---

## 0. How to read this document

- **PART A** — Phase 1 (local encrypted Private Mode) gaps, by capability area. This is where most work is.
- **PART B** — Confirmed desktop bugs in the *existing* Private-Mode code (fix these regardless of new features).
- **PART C** — Phase 2 (iCloud/CloudKit sync). 100% absent on desktop; needs a product/architecture decision because CloudKit is Apple-only.
- **PART D** — Recommended implementation order.
- **PART E** — Open questions / product decisions needed before coding.
- **Appendix** — file-by-file mobile→desktop mapping.

Priority legend:

| Tag | Meaning |
| --- | --- |
| **P0** | Breaks the core Private-Mode promise, or causes data loss / silent no-ops. |
| **P1** | A whole feature is missing or non-functional in Private Mode; user-visible. |
| **P2** | Asymmetry, partial parity, or hygiene issue. |
| **P3** | Polish, localization, or deferred (Phase 2). |

Type legend: **[MISSING]** feature absent · **[BUG]** present but incorrect · **[PARTIAL]** present but incomplete · **[DECISION]** needs a product call.

---

## 1. Executive summary

The desktop app has a **real but shallow** Phase-1 Private Mode: the data-mode boundary, encrypted SQLite, the repository proxy, category CRUD, the Sentry boundary, the "Continue privately" button, and the settings mode-switch all exist and largely mirror mobile. But it is **missing the entire local analytics engine, the AI-consent privacy gate, correct Pro-unlock behavior, profile bootstrap, localization, and all of Phase 2 (iCloud sync)** — and it ships several concrete data-integrity bugs in the code that *is* there.

### Parity scorecard

| # | Capability | Mobile (iOS) | Desktop | Status |
| --- | --- | --- | --- | --- |
| 1 | Data-mode boundary & persisted mode | ✅ `data_mode.dart` | ✅ `desktop_data_mode.dart` | **Parity** |
| 2 | Cold-start ordering (skip Supabase/Sentry) | ✅ `main.dart` | ✅ `main.dart` | **Parity** |
| 3 | Router gate (`isPrivate \|\| isLoggedIn`) | ✅ | ✅ `evolve_desktop_app.dart:50` | **Parity** |
| 4 | Encrypted local DB (SQLCipher) | ✅ 1364-line store | ⚠️ thin, buggy | **P0/P1** |
| 5 | Owner UUID + **profile row bootstrap** | ✅ `_ensureProfile` | ❌ no profile row inserted | **P0 [BUG]** |
| 6 | Schema migrations | ✅ v3 + upgrades | ❌ v1, no migration path | **P2** |
| 7 | Habit / log / macro-goal / mood CRUD (local) | ✅ | ✅ `private_dashboard_repository.dart` | **Parity** (mostly) |
| 8 | Category CRUD (local) | ✅ | ✅ `goal_categories_controller.dart` | **Parity** |
| 9 | **Local analytics / statistics engine** | ✅ `private_analytics.dart` (12+ fns) | ❌ **none** — stats use Supabase RPC | **P0 [MISSING]** |
| 10 | Macro-goal stats (local) | ✅ `macroGoalsStats` | ❌ RPC-only | **P1 [MISSING]** |
| 11 | Private profile & avatar | ✅ file-managed, wiped on delete | ⚠️ writes 0 rows; avatar leaks | **P1 [BUG]** |
| 12 | **Pro unlock in Private Mode** (`isPro=true`) | ✅ forced true | ❌ **forced false** → features locked | **P1 [BUG]** |
| 13 | Subscription/RevenueCat suppression | ✅ | ✅ (section hidden, RC skipped) | **Parity** |
| 14 | Sentry / external-reporting boundary | ✅ 3 gate points | ✅ `AppLogger`+`main.dart`+`data_mode` | **Parity** |
| 15 | **AI external-send consent gate** | ✅ `_ensurePrivateAiConsent` | ❌ **none** — shares habits by default | **P0 [MISSING]** |
| 16 | Notifications: actionable Done/Skip → local DB | ✅ bg isolate, streak-aware | ❌ no notification actions at all | **P2 [MISSING]** |
| 17 | Export (active mode only) | ✅ full private export | ⚠️ partial, mislabeled | **P2 [PARTIAL]** |
| 18 | Import (zip backup) | ✅ | ❌ owner-id mismatch + bad column | **P0 [BUG]** |
| 19 | Delete private data | ✅ rows+files, re-seeds profile | ⚠️ leaves avatar dir | **P1 [BUG]** |
| 20 | "Continue privately" + mode switch UI | ✅ | ✅ `auth_page.dart`, `settings_page.dart` | **Parity** (hardcoded copy) |
| 21 | Localization (en/it/es/de/ar) | ✅ slang, all strings | ❌ **no l10n**; hardcoded Italian | **P2 [MISSING]** |
| 22 | **Phase 2 — iCloud/CloudKit sync** | ✅ complete, E2E encrypted | ❌ **100% absent** | **P3 [MISSING+DECISION]** |

**Bottom line:** to reach "100% of iOS Private-Mode features," desktop needs (a) a local analytics engine, (b) the AI consent gate, (c) correct Pro-unlock, (d) the DB/profile/import/delete bug fixes, (e) localization, and (f) a Phase-2 sync strategy (which requires a decision because CloudKit can't run on Windows/Linux).

---

## 2. Architecture: how each app implements Private Mode

Both apps use Riverpod + `sqflite_sqlcipher` and the same `AppDataMode { supabase, private }` idea. The **routing shapes differ**, which matters for where new code goes:

- **Mobile** folds Private Mode into **each existing provider**: every provider does `ref.watch(activeDataModeProvider)` and, if `private`, talks to a single `PrivateDataStore` (`mobile/lib/core/private_data_store.dart`) implemented by `PrivateLocalDatabase` (`mobile/lib/core/private_local_database.dart`, 1364 lines). The store owns CRUD **and** the analytics engine. A regression test (`mobile/test/private_mode_no_supabase_test.dart`) proves no Supabase call escapes the private branch.
- **Desktop** uses a **repository proxy**: `dashboardRepositoryProvider` (`desktop/lib/features/dashboard/data/dashboard_repository.dart:56`) watches `activeDesktopDataModeProvider` and returns either the cloud repo or `PrivateDashboardRepository` (`desktop/lib/features/dashboard/data/private_dashboard_repository.dart`). Categories/profile use their own mode-aware controllers. But **statistics were never routed through this proxy** — they call Supabase RPCs directly (see A2), which is the single biggest structural gap.

**Recommendation for the implementer:** desktop does *not* need to copy mobile's `PrivateDataStore` interface wholesale, but it **does** need a local analytics surface equivalent to `mobile/lib/core/private_analytics.dart`, wired into the statistics providers the same way the repository proxy is wired into the dashboard. Porting `private_analytics.dart` (pure Dart, no Flutter deps) almost verbatim is the lowest-risk path and preserves cross-client numeric parity.

---

# PART A — Phase 1 (local encrypted Private Mode) gaps

## A1 — Local encrypted database & schema  ·  P0/P1

**Mobile:** `mobile/lib/core/private_local_database.dart` + `mobile/lib/core/private_db_schema.dart`. Schema **v3** with real migrations (`onUpgrade`: v2 widens a CHECK constraint, v3 adds `macro_goal_categories.updated_at` + sync objects). 48-byte key in device-local Keychain (`first_unlock_this_device`, never synced). Idempotent `_ensureProfile` seeds the owner `profiles` row (with `is_pro:1`) and a `goal_category_settings` row. Backup exclusion applied to the Application Support dir.

**Desktop:** `desktop/lib/core/desktop_private_db.dart`. Schema **v1**, `_onUpgrade` is an empty stub (`desktop_private_db.dart:253-258`). 32-char key in `FlutterSecureStorage` (`desktop_private_db.dart:92-100`). Owner UUID in secure storage (`desktop_private_db.dart:43-51`).

Gaps / defects:

1. **P0 [BUG] — No `profiles` owner-row bootstrap.** `_onCreate` creates the `profiles` table but **never inserts the owner row**, and nothing else does (`grep insert('profiles'` across `desktop/lib` = 0 hits). Consequences:
   - `PrivateProfileNotifier.updateProfile` / `updateAvatar` (`desktop/lib/features/auth/application/desktop_profile_controller.dart:84`, `:112`) run `UPDATE profiles ... WHERE id = ownerId` against **zero rows** — profile name / DOB / avatar silently never persist to the DB.
   - FK columns (`goals.user_id REFERENCES profiles(id)`, etc.) point at a non-existent parent. It currently "works" only because sqflite leaves `PRAGMA foreign_keys` **off** by default. Mobile explicitly turns FKs **on** (`onConfigure: PRAGMA foreign_keys = ON`) — desktop does not (`desktop_private_db.dart:83-89`), so referential integrity is unenforced.
   - **Fix:** add an idempotent `_ensureProfile(db, ownerId)` (mirror `mobile` `private_local_database.dart:151-173`) called on open, inserting the owner row with the same defaults **including `is_pro`/`sentry_consent`/preference columns** (see A4). Enable `PRAGMA foreign_keys = ON` in `onConfigure`.

2. **P1 [BUG] — Owner-id inconsistency between read and import paths.** The read/CRUD paths use the Keychain UUID `ownerId` (`private_dashboard_repository.dart:31`, `goal_categories_controller.dart:173`), but `DesktopPrivateDb.importData` hardcodes `final owner = 'local_user'` (`desktop_private_db.dart:269`) and stamps every imported row with `user_id='local_user'`. Imported data is therefore written under a different owner than the app queries → **imported private data is invisible**. **Fix:** `importData` must accept/read the real `ownerId`.

3. **P0 [BUG] — `goal_logs` has no `value` column but import inserts one.** `importData` inserts `'value': l['value']` (`desktop_private_db.dart:328`) and `DesktopBackupImportService._processData` emits `value` (`desktop/lib/core/desktop_backup_import_service.dart:245`), but the `goal_logs` DDL has no `value` column (`desktop_private_db.dart:153-165`). SQLite throws `table goal_logs has no column named value` → **private import fails outright.** (Mobile's `goal_logs` *does* define `value REAL`.) **Fix:** either add `value REAL` to the desktop DDL (recommended for parity) or drop `value` from the import maps.

4. **P2 — Schema column drift vs mobile.** Desktop `profiles` lacks the preference columns mobile stores there (`theme_mode`, `accent_color`, `language`, `pref_*`, `notif_*`, `is_pro`, `biometric_lock`, `private_ai_external_consent`, …; see mobile `private_db_schema.dart:134-170`). Desktop instead scatters these across `SharedPreferences` (see A4). Decide whether desktop stores private settings in the `profiles` row (mobile parity, needed for future sync) or keeps them in prefs — and align the schema accordingly.

5. **P2 — No migration framework.** With `_currentVersion = 1` and an empty `_onUpgrade`, any future schema change to shipped private DBs will have no upgrade path. Establish the versioned-migration pattern now (mirror mobile `private_db_schema.dart:42-95`).

---

## A2 — Local analytics / statistics engine  ·  P0  ·  [MISSING]

**This is the single largest gap.** In Private Mode the statistics screens are effectively empty.

**Mobile:** `mobile/lib/core/private_analytics.dart` (492 lines) provides pure-Dart reimplementations of every cloud RPC/view, and the providers dispatch to them in private mode (`mobile/lib/providers/goal_provider.dart:627-878`, `mobile/lib/providers/macro_goals_stats_provider.dart:17`). Functions and their returned shapes:

| Function | Replaces cloud | Returned shape (must match for parity) |
| --- | --- | --- |
| `computeHabitStatsRow` | view `habit_stats` | `{goal_id,user_id,title,current_streak,best_streak,worst_streak(abs),total_completions,missed_days,total_active_days,rate}` |
| `computeYearlyGrid` | `get_habit_yearly_grid` | `List<int>` len 365, oldest→newest, done=1/missed=2/else 0 |
| `computePerformanceByDay` | `get_habit_performance_by_day` | `[{day_index(ISODOW 1..7),done_count,total_count}]` |
| `computeHabitAlerts` | `get_habit_alerts` | `{worst_negative_days,worst_negative_start,broken_streaks[top5]}` |
| `computeAnalyticsRow` | `get_habit_analytics` | `{goal_id,worst_dow,avg_recovery_days}` |
| `computeGlobalCriticalDay` | `get_global_critical_day` | token `'mon'..'sun'` (tie→alpha), `'N/A'` if empty |
| `computeCriticalHabits` | `get_critical_habits` | `[{goal_id,drop,neg_streak}]` (7d vs prior-7d) |
| `computeBestHabits` | `get_best_habits` | top-5 `[{goal_id,rate,streak}]` (week/month/year/all) |
| `computeGlobalTrend` | `get_global_trend` | `[{point_index,date,rate}]` (daily/monthly/bucketed by timeframe) |
| `macroGoalsStats(year)` *(inline in DB class)* | `get_macro_goals_stats` | large map: `total_goals,completed_goals,success_rate,best_*,category_*,type_distribution,seasonality,monthly_*,quarterly_activity,…` |
| `habitCorrelations` / `allHabitCorrelations` *(inline)* | `get_habit_correlations` / `_all_` | correlation rows |

**Desktop:** all statistics come from Supabase RPCs in `desktop/lib/features/statistics/data/statistics_rpc_providers.dart`. `_RpcContext.read` returns `null` when there is no Supabase client/user (`statistics_rpc_providers.dart:146-153`) — which is exactly the Private-Mode state — so **every RPC provider returns empty/`{}`/`[]`**. `desktop/lib/features/statistics/presentation/statistics_page.dart` consumes them with `.value ?? fallback`:
- A few have snapshot-derived fallbacks (`globalCriticalDayRpcProvider ... ?? _criticalDay(snapshot)` at `statistics_page.dart:212`).
- But **yearly grid** (`:541`), **performance-by-day** (`:563`), **habit alerts** (`:619`), **correlations** (`:797`), **best/critical habits**, and **global trend** fall back to empty → the advanced analytics tabs are blank in Private Mode.
- Macro-goal stats: `desktop/lib/features/goals/presentation/goals_stats_view.dart:78` uses `macroGoalsStatsRpcProvider` only → **empty in Private Mode.**

**What to implement:**
1. Port `mobile/lib/core/private_analytics.dart` to `desktop/lib/features/statistics/data/private_analytics.dart` (pure Dart; adapt only the row/model types to the desktop `DashboardSnapshot`/domain models). Preserve every numeric semantic exactly (ISODOW indexing, `worst_streak` as absolute value, yearly grid ordering & done=1/missed=2, critical-day alphabetical tie-break, best-habits top-5, timeframe bucketing).
2. Port the macro-goal stats + correlations (inline in mobile `private_local_database.dart:896-1294`).
3. Make each desktop stats provider mode-aware: `if (ref.watch(activeDesktopDataModeProvider).isPrivate) return <local compute over the private DB>; else <existing RPC>`. Reuse the `PrivateDashboardRepository` reads (or add analytics reads to `DesktopPrivateDb`) to source the rows.
4. **Watch the two timeframe vocabularies** (mobile note): the UI emits `timeframe_*_short`/`timeframe_all`; `computeBestHabits` expects `week|month|year|all` while `computeGlobalTrend` expects the `timeframe_*` tokens. Route each correctly (mobile canonicalizes via `canonicalBestHabitsTimeframe`).

---

## A3 — Private profile & avatar  ·  P1  ·  [BUG]/[PARTIAL]

**Mobile:** avatar copied to `ApplicationSupport/private_profile/avatar<ext>` and path saved to `profiles.avatar_url`; name/DOB saved to the `profiles` row; `_deletePrivateProfileFiles` deletes the avatar file **and** the `private_profile` dir on wipe (`mobile/lib/core/private_local_database.dart:730-751`, called from `deleteAllPrivateData`).

**Desktop:**
1. **P1 [BUG] — profile writes hit 0 rows** (root cause = A1.1 no profile bootstrap). `PrivateProfileNotifier` reads/writes the `profiles` row (`desktop_profile_controller.dart:38-125`) but the row doesn't exist. In-memory state updates so the UI *looks* right until restart, then the value is gone.
2. **P1 [BUG] — private profile name is fragmented into `SharedPreferences`.** `dashboard_page.dart:56` gates the first-run name prompt on `prefs.getString('private_profile_name')` and `dashboard_page.dart:1037` writes the name there — a *separate* store from `privateProfileProvider`/the DB. So there are two disconnected "private name" sources. **Fix:** unify on the DB `profiles.full_name` (after A1.1), or explicitly pick one store and make both call sites use it.
3. **P1 [BUG] — avatar file leaks on delete.** `_pickAvatar` copies the image to `ApplicationSupport/private_profile/avatar.<ext>` (`settings_page.dart:627-634`), but `_deletePrivateData` → `DesktopPrivateDb.deleteAll()` only deletes the DB file + owner id (`desktop_private_db.dart:61-72`); it never removes the `private_profile` dir. **Fix:** delete the `private_profile` directory in `deleteAll()` (mirror mobile `_deletePrivateProfileFiles`).
4. **P2 — avatar not restored on restart.** Because the path lives only in the (empty) DB row and `_profileImage` is in-memory, the private avatar won't reload after relaunch. Fixed as a side effect of A1.1 + A3.2.

---

## A4 — Settings separation & Pro unlock  ·  P1  ·  [BUG]

**Mobile:** in Private Mode `isPro` is **forced `true`** everywhere so all features unlock (seed, loads, every mutation; `mobile/lib/providers/settings_provider.dart`), and `updateSettingsRow` unconditionally re-forces `is_pro:1, sentry_consent:0`. Crucially, **Pro badges/paywalls are hidden by `!isPrivateMode`, not by `!isPro`** — copying only the `isPro` value is not enough. Private settings persist in the `profiles` row.

**Desktop:**
1. **P1 [BUG] — `isPro` is forced `false` in Private Mode** — the opposite of mobile. `settings_page.dart:174`: `isPro: isPrivateMode ? false : ref.watch(...).isPro`. Effect: Pro-gated UI stays **locked** in Private Mode. Concrete example: the extended accent palette labeled *"Palette estesa riservata a Evolve Pro"* (`settings_page.dart:289`). This contradicts the locked decision *"unlock all features without subscription gates"* (`mobile/PRIVATE_MODE_PRODUCTION_PLAN.md:41`). **Fix:** treat Private Mode as entitled — force `isPro=true` (or bypass the gate entirely) in private mode, and audit every Pro gate to hide on `isPrivateMode` (mobile pattern), not merely on `isPro`.
2. **P2 — private settings live in `SharedPreferences`, not the encrypted DB.** Desktop persists theme/accent/calendar/language/24h/haptics/notification flags via `_setBool`/`_setString`/`_syncProfile` into prefs and (in cloud mode) Supabase `profiles`. There is **no `profiles`-row settings write in Private Mode**, so private settings aren't in the encrypted store and won't be covered by any future sync. Decide whether to store private settings in the DB `profiles` row (mobile parity — recommended if Phase 2 is on the roadmap) and implement the private branch in the settings save paths.
3. **P2 — settings-separation guarantee unverified.** Mobile proves changing private settings doesn't touch Supabase settings and vice-versa (dedicated tests). Desktop's `_syncProfile` is used in both modes; confirm it no-ops against Supabase in Private Mode.

---

## A5 — AI external-send consent gate  ·  P0  ·  [MISSING]

**Mobile:** before any OpenRouter request in Private Mode, `_ensurePrivateAiConsent()` (`mobile/lib/ui/screens/ai_chat_screen.dart:313-352`) checks `store.hasPrivateAiExternalConsent()`; if false it shows an opt-in dialog and only proceeds/persists consent on accept (stored in `profiles.private_ai_external_consent`). The one-time gate is the single deliberate external egress in Private Mode.

**Desktop:** **no consent gate at all.** `desktop/lib/features/ai_coach/presentation/ai_coach_page.dart` builds a context prompt from the user's habits/goals and streams it to OpenRouter with **`_shareHabits = true` by default** (`ai_coach_page.dart:26-27`, `:65-97`). In Private Mode this sends personal habit data to an external LLM **with no opt-in** — a privacy-boundary violation of the plan (`mobile/PRIVATE_MODE_PRODUCTION_PLAN.md:302-317`). (It is only *nominally* inert today because the OpenRouter API key may be empty, but the architecture is missing.)

**What to implement:**
1. Add a `private_ai_external_consent` column to desktop `profiles` (A1) + read/write helpers.
2. Add a `_ensurePrivateAiConsent()` gate before the first external send in Private Mode (mirror mobile), with localized copy that states the display name is always included when context is shared.
3. Default `_shareHabits`/`_shareGoals` to a safe posture and never send private context without consent.

---

## A6 — Subscription / Pro-gate suppression  ·  Parity (with A4 caveat)

**Desktop is correct here:** RevenueCat is only reachable with a Supabase user (`desktop/lib/features/settings/application/desktop_subscription_controller.dart:170-188` `_canUseRevenueCat`), so no RC init/calls happen in Private Mode; and the Subscription settings section is hidden in Private Mode (`settings_page.dart:107-112`). The only issue is the inverted `isPro` (A4.1). No new work beyond A4.

---

## A7 — Sentry / external-reporting boundary  ·  Parity

**Desktop matches mobile's intent.** `AppLogger.setExternalReportingDisabled` is set from the saved mode at cold start (`desktop/lib/main.dart:35-41`) and inside the mode notifier (`desktop/lib/core/desktop_data_mode.dart:33`, `:42`); Supabase init is skipped in Private Mode (`main.dart:23-30`); Sentry is disabled entering Private Mode and re-enabled (with consent) on leaving (`desktop_data_mode.dart:46-54`); events are sanitized (`desktop/lib/core/desktop_sentry_service.dart:51-55`). 

Minor follow-ups (P2/P3): desktop's `AppLogger` sanitization surface is smaller than mobile's `PrivacyUtils` (email/JWT/secret redaction, `mobile/lib/core/privacy_utils.dart`); consider porting `PrivacyUtils` for equivalent breadcrumb hygiene. Desktop has no navigator-observer Sentry exclusion because it uses `MaterialApp.home` routing rather than a router with observers — nothing to do unless routing changes.

---

## A8 — Notifications mode-awareness  ·  P2  ·  [MISSING]

**Mobile:** notifications carry Done/Skip/Snooze actions; the background isolate reads `active_data_mode`, skips Supabase in Private Mode, and writes the habit log to the local DB with a correctly computed streak (`mobile/lib/core/notifications.dart:210-257`, `:514-554`), then invalidates providers.

**Desktop:** `desktop/lib/features/settings/data/desktop_notification_service.dart` schedules habit reminders (`payload: 'habit|<id>|<title>'`, `:109`) but defines **no action buttons and no action handler** — tapping just opens the app. So there is currently *no* notification write-path in either mode. This is a smaller gap (desktop lacks actionable notifications entirely) but to reach parity: add Done/Skip actions and route them mode-aware to `PrivateDashboardRepository.setHabitStatus` (with streak) in Private Mode, matching mobile. Note macOS/Windows/Linux differ in notification-action support — treat as platform-gated.

---

## A9 — Export / reset / delete  ·  P1/P2

**Mobile:** `PrivateLocalDatabase.exportData()` returns a full private snapshot (profile, settings, habits, habitLogs, macroGoals, macroGoalCategories incl. archived, dailyMoods) tagged `mode:'private'`, shared as `evolve_private_export.json` (`mobile/lib/core/private_local_database.dart:535-567`; UI `mobile/lib/ui/screens/privacy_settings_screen.dart:790-805`). `deleteAllPrivateData` wipes all tables + avatar files, then **re-seeds an empty profile** so the app stays usable (`private_local_database.dart:569-584`); DB key/owner are intentionally kept.

**Desktop:**
1. **P2 [PARTIAL] — private export is incomplete and mislabeled.** `_exportData` (`settings_page.dart:548-613`) reads the in-memory `dashboardControllerProvider` snapshot and emits settings + habits + goals + habitLogs + moods, but **omits `macro_goal_categories` and profile/DOB**, exports only `weekly_progress` (not full frequency/start/end), and hardcodes `'source':'evolve-desktop-supabase-cache'` even in Private Mode (`settings_page.dart:552`). Bring it to parity with mobile's private export (source-tag by mode, include categories + profile).
2. **P1 [BUG] — delete leaves the avatar dir** (see A3.3).
3. **P2 — delete does not re-seed an empty profile.** After `deleteAll()` the profile row is gone (and never existed — A1.1); ensure the post-delete state re-seeds a fresh owner profile (mobile parity) so the app remains usable without a restart. (Desktop currently calls `goToLogin()` after delete, side-stepping this, but that also *exits* Private Mode, which mobile does **not** do — mobile stays in Private Mode with a clean profile. Decide the intended UX.)

---

## A10 — Import  ·  P0  ·  [BUG]

Covered by A1.2 (owner-id `'local_user'` mismatch → imported rows invisible) and A1.3 (`value` column → insert throws). Additionally: desktop gates import to **Private Mode only** (`settings_page.dart:853-857`) whereas mobile supports both; and `DesktopBackupImportService` is otherwise a solid port (HSL→hex, streak recompute, id remap). Fix A1.2/A1.3 and the importer becomes functional.

---

## A11 — UI integration & mode switching  ·  Parity (copy hardcoded)

Present and working on desktop:
- **"Continue privately"** button on the auth screen (`desktop/lib/features/auth/presentation/auth_page.dart:159-177` → `enterPrivateMode()`).
- **Router gate** allows the app when `isPrivateMode || isLoggedIn` (`evolve_desktop_app.dart:50`).
- **Mode switch in settings**: "Vai al Login" (non-destructive exit → `goToLogin()`, `settings_page.dart:237-244`) and account/data rows swap by mode; subscription section hidden; delete row is mode-specific (`settings_page.dart:526-541`).
- **Biometric gate** works in both modes (`desktop/lib/features/settings/application/desktop_biometric_controller.dart`).

Gaps: all copy is **hardcoded Italian** (see A12). Also confirm there is no persistent "private status" indicator (plan forbids it) — desktop shows mode only inside settings, which is fine.

---

## A12 — Localization  ·  P2  ·  [MISSING]

**Mobile** routes every Private-Mode string through slang `context.t.*` in en/it/es/de/ar (`t.auth.continuePrivately`, `t.profile.usePrivateModeOnDevice`, `t.privacy.*`, `t.ai.privateConsent*`, `t.icloudSync.*`, …).

**Desktop has no app-string localization at all** — `grep` for `context.t` / slang / `.arb` / `AppLocalizations` across `desktop/lib` returns **nothing**; `MaterialApp` wires only `GlobalMaterialLocalizations.delegates` (`evolve_desktop_app.dart:45`) and a `supportedLocales` list, while every feature string is a hardcoded Italian literal (e.g. `auth_page.dart:167` "Continua in modalità privata su questo Mac", the whole settings page, AI coach, dialogs). There is a `desktop_locale_controller` but it only sets `MaterialApp.locale` for Material widgets.

**What to implement:** stand up a localization framework for desktop (slang to match mobile, or Flutter ARB), and externalize at minimum all Private-Mode strings into en/it/es/de/ar. This is a broader effort than Private Mode alone; scope the first pass to the Private-Mode surfaces listed here.

---

# PART B — Confirmed desktop bugs (fix regardless of new features)

These exist in the *current* desktop Private-Mode code and are individually verifiable:

| # | Bug | Location | Effect | Fix |
| --- | --- | --- | --- | --- |
| B1 | No `profiles` owner-row bootstrap; FKs left OFF | `desktop_private_db.dart:112-251` (`_onCreate`), `:83-89` (`_open`) | Private profile/avatar writes update 0 rows; unenforced FKs | Add idempotent `_ensureProfile`; `PRAGMA foreign_keys=ON` in `onConfigure` |
| B2 | Import owner-id `'local_user'` ≠ read owner UUID | `desktop_private_db.dart:269` | Imported private data invisible | Use real `ownerId` in `importData` |
| B3 | `goal_logs` insert of non-existent `value` column | `desktop_private_db.dart:328`, `desktop_backup_import_service.dart:245` | Private import throws | Add `value REAL` to DDL (parity) or drop `value` from import |
| B4 | `isPro` forced `false` in Private Mode | `settings_page.dart:174` | Pro features locked in Private Mode | Force `isPro=true` / bypass gates in private mode |
| B5 | No AI external-send consent | `ai_coach_page.dart:26-97` | Habits sent to OpenRouter with no opt-in | Add private AI consent gate |
| B6 | Avatar dir not deleted on wipe | `desktop_private_db.dart:61-72` | `private_profile/` avatar persists after "delete private data" | Delete `private_profile` dir in `deleteAll()` |
| B7 | Private name split between prefs and DB | `dashboard_page.dart:56`,`:1037` vs `desktop_profile_controller.dart` | Two disconnected name sources | Unify on DB `profiles.full_name` |
| B8 | Private statistics blank | `statistics_rpc_providers.dart:146-153`, `statistics_page.dart`, `goals_stats_view.dart:78` | Advanced analytics empty in Private Mode | Local analytics engine (A2) |
| B9 | Private export omits categories/profile; mislabeled source | `settings_page.dart:548-592` | Incomplete/mis-tagged export | Parity with mobile private export |

---

# PART C — Phase 2: iCloud / CloudKit sync  ·  P3  ·  [MISSING + DECISION]

**Status: 100% absent on desktop.** `grep -i "cloudkit\|icloud\|sync_engine\|tombstone\|PrivateSyncService\|dirty"` across `desktop/lib` returns nothing. Mobile has a **complete, unit-tested, E2E-encrypted** implementation (`mobile/ICLOUD_SYNC_PLAN.md`; container `iCloud.com.simo.evolve`, zone `PrivateZone`, record type `PrivateRecord`).

### C.1 What mobile has (for reference)

- **Portable Dart engine** (backend-agnostic): `SyncEngine` (LWW on `updated_at`, FK-ordered pull, tombstones, ±5-min clock-skew guard, device re-key on enable), `SyncLocalStore` (`sync_state`/`sync_meta` + dirty/tombstone SQL triggers), `SyncCrypto` (AES-256-GCM via pointycastle), `SyncKeyStore`, `RowCodec`, and an abstract `CloudKitBridge` (`mobile/lib/core/*`). All unit-testable via a fake bridge.
- **Apple-only transport & secrets:** the Swift `CloudKitSyncBridge` (`mobile/ios/Runner/AppDelegate.swift:67-321`) using `CKContainer.privateCloudDatabase` + change-token delta fetch + `.ifServerRecordUnchanged` conflict; the E2E key shared across devices via **iCloud Keychain** (`synchronizable:true` / `kSecAttrSynchronizable`, `mobile/lib/core/secure_storage_utils.dart:36-42`); the entitlements (`mobile/ios/Runner/Runner.entitlements`); and `excludeFromBackup`.
- **Triggers:** foreground-on-resume + manual "Sync now" only (no push/periodic). Settings UI `mobile/lib/ui/screens/icloud_sync_screen.dart` (507 lines).

### C.2 The decision desktop must make

CloudKit is **Apple-only**. The desktop client targets **macOS, Windows, and Linux** (`desktop/README.md`, platform dirs `macos/`, `windows/`, `linux/`). So:

- **macOS** *could* reuse CloudKit (same CloudKit APIs + a macOS Swift/FFI bridge + the same container), giving true cross-device sync with iOS. But that leaves Windows/Linux with no sync.
- **Windows/Linux** need a **different backend** entirely (options: Supabase Storage/Postgres for the private space, a custom sync server, WebDAV/S3, or Apple's CloudKit Web Services HTTP API with server-to-server auth).

The good news (mobile's architecture win): **the entire Dart sync engine is portable**. A desktop port can keep `SyncEngine`/`SyncLocalStore`/`SyncCrypto`/`SyncKeyStore` semantics unchanged and only supply (a) a new `CloudKitBridge` implementation for the chosen backend, and (b) a new key-distribution mechanism to replace iCloud Keychain (manual key export/import, QR pairing, passphrase-derived key via KDF, or backend-mediated escrow), plus a backend-specific account-status model.

### C.3 Desktop-specific replacements required (whatever backend is chosen)

1. **Transport bridge** — reimplement the `CloudKitBridge` contract (`accountStatus/ensureZone/saveRecords/fetchChanges(token)/deleteRecords/deleteZone`) against the chosen backend, preserving the "change token + delta fetch + optimistic-concurrency conflict" contract.
2. **Key distribution** — no iCloud Keychain off Apple platforms. Replace `synchronizable:true` with a deliberate cross-device key mechanism; re-author the key-loss/recovery UX.
3. **Account/availability model** — map the backend's auth/quota/network state onto the 5-state `CloudAccountStatus` (or replace it) and the settings copy.
4. **`excludeFromBackup`** — desktop equivalent for "keep the local DB out of any OS/cloud backup," or an explicit decision to skip.
5. **Sync triggers** — mobile relies on `AppLifecycleState.resumed`; desktop apps live/idle differently, so likely add an explicit periodic/idle trigger (none exists in mobile today).
6. **Local schema** — port the `sync_state`/`sync_meta` tables + per-table dirty/tombstone triggers (mobile `private_db_schema.dart:271-338`), and add `macro_goal_categories.updated_at` (this piggybacks on the A1 migration work).
7. **Settings UI** — a desktop `iCloud/Sync` settings section (enable toggle, "Sync now", last-synced/status, unavailable messaging), platform-gated (only where a backend is available), with clear "does not use Supabase for the private space" copy.

**Recommendation:** treat Phase 2 as a **separate milestone after Phase 1 parity is solid**, and get the C.2 backend decision from the product owner *before* writing any sync code (see PART E). If macOS-only CloudKit is acceptable for v1, the Swift bridge can be reused with minimal change; otherwise plan a cross-platform backend.

---

# PART D — Recommended implementation order

Phase 1 first (gets desktop to true local-Private-Mode parity); Phase 2 is a gated follow-up.

1. **DB foundation & bug fixes (P0)** — B1 (profile bootstrap + FK on), B2 (owner-id), B3 (`value` column), B6 (avatar wipe). Small, high-impact, unblock everything else. (A1)
2. **Pro unlock (P1)** — B4 + audit all Pro gates to key on `isPrivateMode` not `isPro`. (A4.1)
3. **AI consent gate (P0 privacy)** — B5 + consent column + localized copy. (A5)
4. **Local analytics engine (P0 feature)** — port `private_analytics.dart` + macro stats + correlations; make stats providers mode-aware. Largest single task. (A2, B8)
5. **Profile/name unification & avatar restore (P1)** — B7 + reload avatar from DB. (A3)
6. **Export/delete parity (P2)** — B9 + decide post-delete UX (stay in Private Mode + re-seed profile vs current goToLogin). (A9)
7. **Private settings in DB (P2)** — move private settings into the `profiles` row if Phase 2 is on the roadmap. (A4.2)
8. **Notification actions (P2)** — Done/Skip → local DB, mode-aware. (A8)
9. **Localization (P2)** — stand up l10n; externalize Private-Mode strings (en/it/es/de/ar). (A12)
10. **Schema migration framework (P2)** — versioned migrations before more schema churn. (A1.5)
11. **Phase 2 sync (P3)** — only after the C.2 decision. (PART C)

Verification to add alongside (mirror mobile's guards): a "no Supabase call in Private CRUD/stats" test, a settings-separation test, a delete-private-data test.

---

# PART E — Open questions / product decisions needed

1. **Phase 2 backend for non-Apple desktop (blocking Phase 2).** macOS-CloudKit-only for v1, or a cross-platform backend for Windows/Linux (Supabase private space? custom server? CloudKit Web Services)? This determines the whole sync design.
2. **Cross-device key distribution off iCloud Keychain.** Manual export/import, QR pairing, passphrase-derived (KDF), or backend escrow? Affects security posture + UX.
3. **Post-"delete private data" UX.** Mobile stays in Private Mode with a fresh empty profile; desktop currently exits to Login. Which is intended?
4. **Where private settings live.** Encrypted DB `profiles` row (mobile parity, sync-ready) vs `SharedPreferences` (current desktop). Needed before Phase 2.
5. **Private-mode import scope.** Keep desktop's "Private Mode only" import gate, or match mobile (both modes)?
6. **Localization framework choice for desktop.** Slang (match mobile, share message keys) vs Flutter ARB.
7. **AI in Private Mode.** OpenRouter key is empty today; confirm AI is meant to function in Private Mode (then the consent gate becomes load-bearing) and supply the key via `--dart-define`, not committed.

---

## Appendix — file map (mobile → desktop)

| Concern | Mobile file | Desktop equivalent | State |
| --- | --- | --- | --- |
| Data-mode enum/provider | `core/data_mode.dart` | `core/desktop_data_mode.dart` | ✅ present |
| Local DB (schema+CRUD+analytics) | `core/private_local_database.dart` (1364) | `core/desktop_private_db.dart` (376) + `features/dashboard/data/private_dashboard_repository.dart` | ⚠️ thin; no analytics; bugs |
| DB schema/migrations | `core/private_db_schema.dart` (v3) | inline in `desktop_private_db.dart` (v1) | ⚠️ no migrations |
| Store interface | `core/private_data_store.dart` | *(none)* | ➖ optional |
| **Analytics engine** | `core/private_analytics.dart` (492) | *(none)* | ❌ **missing** |
| Stats providers (mode-aware) | `providers/goal_provider.dart`, `providers/macro_goals_stats_provider.dart` | `features/statistics/data/statistics_rpc_providers.dart` (RPC-only) | ❌ not mode-aware |
| Settings separation / isPro | `providers/settings_provider.dart` | `features/settings/presentation/settings_page.dart` (+ prefs) | ⚠️ isPro inverted; prefs not DB |
| Private profile/avatar | `providers/user_provider.dart` + DB | `features/auth/application/desktop_profile_controller.dart` | ⚠️ 0-row writes; avatar leak |
| Subscription suppression | `core/subscription_service.dart` | `features/settings/application/desktop_subscription_controller.dart` | ✅ present |
| Sentry boundary | `core/app_logger.dart`, `core/sentry_service.dart`, `core/privacy_utils.dart` | `core/app_logger.dart`, `core/desktop_sentry_service.dart` | ✅ present (thinner sanitizer) |
| **AI consent gate** | `ui/screens/ai_chat_screen.dart:313-352` | `features/ai_coach/presentation/ai_coach_page.dart` | ❌ **missing** |
| Notifications mode-aware | `core/notifications.dart` | `features/settings/data/desktop_notification_service.dart` | ❌ no actions |
| Export/import/delete | `core/private_local_database.dart`, `core/backup_import_service.dart` | `core/desktop_backup_import_service.dart`, `settings_page.dart` | ⚠️ bugs (B2/B3), partial export |
| "Continue privately" + switch | `ui/screens/auth_screen.dart`, `profile_screen.dart` | `features/auth/presentation/auth_page.dart`, `settings_page.dart` | ✅ present (hardcoded copy) |
| Privacy settings screen | `ui/screens/privacy_settings_screen.dart` (1614) | `settings_page.dart` `_privacy()` (~90 lines) | ⚠️ much thinner |
| **Phase 2 sync (all)** | `core/private_sync_service.dart`, `sync_engine.dart`, `sync_local_store.dart`, `sync_crypto.dart`, `sync_key_store.dart`, `cloudkit_bridge*.dart`, `ui/screens/icloud_sync_screen.dart`, `ios/Runner/AppDelegate.swift`, `Runner.entitlements` | *(none)* | ❌ **100% missing** |

---

STATUS: COMPLETED
NEXT ACTION: Have the product owner resolve PART E (esp. E1 Phase-2 backend), then implement PART D in order — start with the P0 DB bug fixes (B1–B3, B6), the Pro-unlock fix (B4), the AI consent gate (B5), and the local analytics engine (A2), which together restore the core Private-Mode promise on desktop.
