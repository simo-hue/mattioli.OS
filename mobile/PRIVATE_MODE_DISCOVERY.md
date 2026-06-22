# Private Mode — Implementation Discovery & Audit

Created: 2026-06-23
Scope: Flutter mobile app (`mobile/`)
Method: Full static read of every privacy-related path — core, providers, all touched screens/widgets, iOS native bridge, entitlements, tests — cross-checked against `PRIVATE_MODE_PRODUCTION_PLAN.md`. `flutter analyze` run (clean).

> This is a **discovery document only**. No code was changed. It records what exists, what is missing, and what is broken, so the fix/implementation phase can start from a precise map.

---

## 1. Executive Summary

**The goal** — let the user use *every* feature with data stored privately and encrypted on-device, with optional iCloud sync later — is **largely achieved for Phase 1 (local-only)**. The architecture is clean, consistent, and the analytics parity layer is genuinely well-engineered and unit-tested.

| Area | Status |
| --- | --- |
| **Phase 1 — Local encrypted Private Mode** | ✅ **~95% complete, production-shaped** |
| **Phase 2 — iCloud / CloudKit sync** | ⛔ **Not started (intentionally)** — no-op service, no entitlements |
| `flutter analyze` | ✅ Clean — "No issues found" |
| Privacy boundary (no Supabase / Sentry / RevenueCat leaks in Private Mode) | ✅ Verified across all providers & screens |

**Verdict:** Phase 1 is close to shippable. What remains is (a) a short list of real-but-mostly-minor bugs, (b) one cross-mode correctness bug (mood scale), (c) localization debt, (d) automated-test gaps the plan itself calls out, and (e) the entirety of Phase 2 (deferred by design).

---

## 2. Architecture (as built)

The data-mode boundary from the plan is implemented as designed.

- **`AppDataMode { supabase, private }`** + **`activeDataModeProvider`** — `lib/core/data_mode.dart`. Persisted in `SharedPreferences` under `active_data_mode`. Read synchronously at cold start in `main.dart` *before* any network init.
- **Storage stack:** `sqflite_sqlcipher` (encrypted SQLite) — **not** Drift as the plan recommended, but a valid equivalent. Plus `flutter_secure_storage`, `path_provider`, `uuid`.
- **`PrivateLocalDatabase`** (`lib/core/private_local_database.dart`, 993 lines) — singleton; owns schema, CRUD, export, delete, and the analytics parity engine.
- **`PrivateSyncService`** (`lib/core/private_sync_service.dart`) — abstract interface + `NoOpPrivateSyncService` (Phase 2 placeholder).
- **Repository boundary:** the plan's named repository classes were **not** created as separate classes. Instead, **each existing provider is mode-aware** and routes to either Supabase or `PrivateLocalDatabase`. Functionally equivalent and lower-churn; the named repositories are effectively folded into the providers.

---

## 3. Phase 1 status — section by section (vs the plan)

| # | Plan section | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Dependency & storage foundation | ✅ | `private_local_database.dart`: 48-byte random key in Keychain, owner UUID bootstrap, backup exclusion, schema v2 + migration |
| 2 | Local schema (7 tables) | ✅ | All tables present with CHECK/UNIQUE/indexes mirroring cloud; `ai_insights` correctly excluded |
| 3 | Data mode & router | ✅ | `main.dart` router redirect; `canAccessApp = isLoggedIn \|\| isPrivateMode` (`auth_provider.dart:53`); saved mode wins at launch |
| 4 | Provider & repository refactor | ✅ | All providers mode-aware (goals, logs, macro goals, categories, moods, profile, settings, stats, tutorial) |
| 5 | Settings separation | ✅ | Private settings in local `profiles` row; `isPro` forced true; cloud uses SharedPreferences+Supabase |
| 6 | Profile & avatar | ✅ | Local avatar file under `private_profile/`; deleted on data deletion (`_deletePrivateProfileFiles`) |
| 7 | Subscription & Pro gates | ✅ | `isPro=true` suppresses all `ProFeaturesModal` triggers; entry points/Pro badge hidden via `!isPrivateMode`; `subscriptionService.init` only in Supabase mode |
| 8 | Sentry & privacy boundary | ✅ | `AppLogger.externalReportingDisabled`; cold-start skip; late-init on leaving Private Mode w/ consent; Sentry nav observer excluded in Private Mode |
| 9 | AI external-send consent | ✅ (see §5.8) | `_ensurePrivateAiConsent()` gate before any OpenRouter send; stored in local DB |
| 10 | Local statistics / RPC equivalents | ✅ | 11 compute functions in `private_analytics.dart`, all unit-tested in `private_analytics_test.dart` |
| 11 | Notifications & background actions | ✅ (see §5.3) | `_writeHabitLogFromNotification` routes to local DB; background isolate skips Supabase init in Private Mode |
| 12 | Export, reset, delete | ✅ (see §5.6) | Mode-scoped export; `deleteAllPrivateData`; exiting Private Mode is non-destructive |
| 13 | UI integration | ✅ (see §5.10) | "Continue privately" button; profile mode-switch ("Use private mode" / "Go to Login"); iCloud hidden |
| 14 | Schema documentation update | ✅ | `mobile_schema.sql` present; `schema_drift_test.dart` guards cloud RPC/table drift |
| 15 | Phase 1 verification | ⚠️ Partial | `flutter analyze` clean; unit tests exist; **no router/no-Supabase-call/settings-separation/delete tests; manual smoke test not evidenced** |

---

## 4. Phase 2 (iCloud sync) — not started (as expected)

Confirmed absent, consistent with "Phase 2 starts only after Phase 1 is stable":

- `PrivateSyncService` is a **no-op** (`NoOpPrivateSyncService` always returns `localOnly()`).
- `ios/Runner/Runner.entitlements` contains **only** Apple Sign-In — **no** `com.apple.developer.icloud-*`, **no** `keychain-access-groups`.
- No Swift CloudKit bridge, no sync metadata columns, no client-side payload encryption, no iCloud settings UI.
- iCloud controls are correctly **hidden** everywhere (nothing to hide yet).

Everything Phase 2 needs (sections 1–6 of the plan) is greenfield.

---

## 5. Findings — bugs, gaps & risks (prioritized)

### P0 — Correctness (affects "every feature works")

**5.1 — Mood scale mismatch breaks mood↔habit correlation (cross-mode)**
`lib/providers/mood_provider.dart:163-164` classifies days with `moodScore >= 60` (high) and `moodScore < 40` (low), i.e. a **0–100** scale. But mood is a **0–10** value: the check-in UI shows `${value.round()}/10` (`daily_check_in_modal.dart:227`) and the private DB enforces `CHECK (mood_score >= 0 AND mood_score <= 10)`. Result: `>= 60` is never true and `< 40` is always true → **every day is counted as "low mood"**, so `moodCorrelationProvider` (sensitivity/resilience, high/low completion %) is wrong.
- Not Private-Mode-specific (the provider is mode-agnostic), but it directly undercuts the "all features work in Private Mode" goal.
- Fix: scale thresholds to 0–10 (e.g. `>= 6` / `< 4`) — verify against the web app's intended semantics first.

### P1 — Private-mode robustness

**5.2 — Macro-goal private CRUD has no error handling / optimistic rollback**
In `lib/providers/macro_goals_provider.dart`, the Private-Mode branches (`addGoal` ~159, `updateStatus` ~210, `updateTitle` ~245, `updateCategory` ~283, `deleteGoal` ~316) do `await db.<op>(); return;` with **no try/catch**. Compare with `goal_provider.dart`, whose private paths snapshot state and roll back + show an `ErrorModal` on failure. A local write failure here throws unhandled and leaves optimistic UI state diverged from disk. Add the same rollback+error pattern.

**5.3 — Notification-driven habit log stores `streak = 0` in Private Mode**
`notifications.dart:200` calls `setHabitLog(... )` without a streak, defaulting to `0`. The foreground path (`goal_provider.cycleStatus`) computes the real streak via `computeStreak`. Since the private analytics read the stored `streak` (`_loadLogEntries`), a habit completed from a notification will have a wrong/zero streak until it's re-edited in the foreground. Recompute the streak in the notification write path (or recompute streaks lazily in the analytics layer).

**5.4 — In-memory providers not refreshed after a notification write (Private Mode)**
After `_writeHabitLogFromNotification`, `habitLogsProvider` / `habitStatsProvider` aren't invalidated, so the dashboard can show stale state until a manual rebuild. In cloud mode the next foreground sync masks this; Private Mode has no sync trigger. Consider invalidating the relevant providers on resume in Private Mode.

### P2 — Schema / parity / hygiene

**5.5 — `goal_category_settings` is dead schema (both modes)**
The table is created, seeded with `{}`, and deleted on wipe (`private_local_database.dart:281-289, 335, 685`) but is **never read or written** by any provider in either mode (no `categorySettings` provider exists). It's vestigial. Either wire the feature or drop the table from the mirror to avoid confusion.

**5.6 — Cloud export is less complete than the private export**
`privacy_settings_screen.dart:_exportData` (cloud branch, ~772-803) exports only settings + habits + macroGoals; the **private** export (`PrivateLocalDatabase.exportData`) also includes logs, moods, categories, profile/DOB. The plan permits "extend cloud export only if needed," so this is acceptable but is a real asymmetry worth a decision.

**5.7 — Backup exclusion is applied to the whole Application Support directory**
`private_local_database.dart:117-120` passes `file.parent` (the entire `ApplicationSupport` dir) to the native `excludeFromBackup`, not just the DB file + its `-wal`/`-shm` sidecars. Correct for the DB, but it also excludes any unrelated app-support files from backup. Consider scoping to a dedicated subdirectory for the private DB.

### P3 — Privacy nuance & AI

**5.8 — AI system prompt always includes the user's first name**
`ai_chat_screen.dart:374-376` always writes `userName` into the context block, even when both "share habits"/"share goals" switches are off. It is gated behind the one-time `_ensurePrivateAiConsent` dialog, so it's not a silent leak — but the consent copy (`t.ai.privateConsentBody`) should explicitly state the display name is always sent.

**5.9 — AI is currently inert**
`OpenRouterConfig.apiKey = ''` → every AI call short-circuits to "API key missing." So "AI works in Private Mode" is only nominally true today. Not a Private-Mode bug, but note it: the consent path can't be exercised end-to-end until a key is provided (and the key should be supplied via a secure/`--dart-define` mechanism, not committed).

### P4 — Localization (plan §13 wants all new UI localized in en/it/ar/es/de)

**5.10 — Hardcoded strings remain**
- `consent_screen.dart`: `'Ricevi promemoria…'` (254), `'Abilita'` (278), `'Continua'` (336).
- `privacy_settings_screen.dart:205`: biometric reason `'Autenticati per abilitare la protezione dell'app'`.
- `profile_screen.dart`: section headers `'AIUTO'` (479) and `'SISTEMA'` (516).

**5.11 — Arabic deferred**
`AppLanguagePreference` lists `ar`, but `_appLocaleFor`/comments defer the RTL pass, so Arabic falls back to English. Plan §13 lists Arabic as required for release.

### P5 — Test coverage gaps (called out by the plan's own test plan)

Present: `private_analytics_test`, `schema_drift_test`, `tutorial_provider_test`, `user_profile_test`, `best_habits_timeframe_test`, `streak_utils_test`, `goal_logs_pagination_test`, etc.
Missing (plan "Automated Test Plan"): **mode-router redirect**, **"no Supabase call in Private CRUD"**, **settings separation**, **delete-private-data**, **notification action routing**, **repository/mode selection**.

---

## 6. Privacy boundary verification (the core promise)

| Boundary | Result | Notes |
| --- | --- | --- |
| No `Supabase.initialize` at cold start in Private Mode | ✅ | `main.dart:46` |
| No Supabase data calls from Private CRUD | ✅ | Every provider returns from the `private` branch before any `.from()`/`.rpc()` |
| Background isolate (notifications) skips Supabase in Private Mode | ✅ | `notifications.dart:509-529` |
| No RevenueCat init in Private Mode | ✅ | `subscriptionService.init` only in Supabase auth branch |
| No paywall / Pro UI in Private Mode | ✅ | `isPro=true` suppresses triggers; entry points hidden via `!isPrivateMode` |
| No Sentry submission in Private Mode | ✅ | `externalReportingDisabled` + cold-start skip + nav-observer excluded |
| AI external send requires explicit consent | ✅ | `_ensurePrivateAiConsent` (see 5.8 caveat) |
| Local DB encrypted at rest | ✅ | SQLCipher + 48-byte key in `first_unlock_this_device` Keychain (device-local, not iCloud-synced) |
| DB excluded from backup while sync off | ✅ | Native `excludeFromBackup` (see 5.7 scope caveat) |
| Delete private data removes rows + avatar + files | ✅ | `deleteAllPrivateData` + `_deletePrivateProfileFiles` |
| Exiting Private Mode is non-destructive | ✅ | `returnToLoginFromPrivateMode` only switches mode |
| Biometric app-lock enforced (both modes) | ✅ | `dashboard_screen.dart:752-926` |

---

## 7. Recommended next steps (suggested order)

1. **Fix P0 mood scale** (5.1) — quick, high user-visible impact; verify intended 0–10 semantics vs web.
2. **Harden macro-goal private CRUD** (5.2) — add rollback + `ErrorModal`, matching `goal_provider`.
3. **Fix notification streak + provider refresh in Private Mode** (5.3, 5.4).
4. **Decide on `goal_category_settings`** (5.5) and **cloud export parity** (5.6).
5. **Tighten backup-exclusion scope** (5.7) and **AI consent copy** (5.8).
6. **Localization sweep** (5.10, 5.11) for all new Private-Mode UI.
7. **Add the missing automated tests** (§5 P5) — especially the "no Supabase call in Private CRUD" guard, since it protects the core promise.
8. **Plan Phase 2 (iCloud)** only after the above — it's fully greenfield (entitlements → Swift CloudKit bridge → client-side encryption → sync metadata/LWW → settings UI).

---

## 8. Manual / external prerequisites surfaced (not blocking Phase 1)

- **AI:** supply `OpenRouterConfig.apiKey` securely (e.g. `--dart-define`) if AI is to function (5.9).
- **Phase 2:** Apple Developer CloudKit container + iCloud/Keychain-sharing entitlements must be provisioned before any sync code can run.

---

## 9. Resolution status — updated 2026-06-23

All in-code findings have been fixed, tested (`flutter analyze` clean; `flutter test` 110/110 green), and committed. Test suite grew 77 → 110.

| Item | Status | Commit |
| --- | --- | --- |
| P0 5.1 — mood scale 0–100 → 0–10 (classifier + both charts) | ✅ Fixed | `70bd70c` |
| P1 5.2 — macro-goal private CRUD rollback/error handling | ✅ Fixed | `391ffd3` |
| P1 5.3 — notification habit-write computes streak | ✅ Fixed | `ee6777e` |
| P1 5.4 — refresh providers after notification Done/Skip | ✅ Fixed (invalidate-from-handler) | `5782ad9` |
| P2 5.5 — `goal_category_settings` vestigial | ✅ Documented (kept for parity) | `6cd09be` |
| P2 5.6 — cloud export parity (logs/moods/categories/profile) | ✅ Fixed | `f1507af` |
| P2 5.7 — backup-exclusion scope | ✅ Documented (intentional; path kept stable) | `6cd09be` |
| P3 5.8 — AI consent copy (display name always sent) | ✅ Fixed | `7c5efda` |
| P3 5.9 — AI inert (empty API key) | ⛔ Manual — see TO_SIMO_DO.md | — |
| P4 5.10 — hardcoded strings localized (en/it/es/de) | ✅ Fixed | `7c5efda` |
| P4 5.11 — Arabic + RTL | ⛔ Deferred by design (RTL pass + native QA) — TO_SIMO_DO.md | — |
| P5 — mode-router / AuthState gating tests | ✅ Added | `102c056` |
| P5 — no-Supabase-call in Private CRUD (+ PrivateDataStore interface) | ✅ Added | `d84fdcf` |
| P5 — settings separation (+ shared test fake) | ✅ Added | `2fec42a` |
| P5 — delete-private-data / notification-routing tests | ⛔ Deferred (needs DB-integration infra) — TO_SIMO_DO.md | — |
| Phase 2 — iCloud/CloudKit sync | ⛔ Not started (needs Apple provisioning) — TO_SIMO_DO.md | — |

**Net:** Phase 1 Private Mode is feature-complete and regression-guarded. Remaining items are manual/external (AI key, Arabic RTL + QA, CloudKit provisioning) or optional future test infrastructure.
