# Private Mode — Desktop Implementation Plan

Created: 2026-07-04
Scope: Bring the **desktop** Flutter client (`evolve_desktop`, macOS/Windows/Linux) to **100% Private-Mode parity** with the mobile client (`mattioli_os`, iOS/Android). Executes the gaps in [`PRIVATE_MODE_PARITY_GAPS.md`](PRIVATE_MODE_PARITY_GAPS.md).
Relationship: this is the **production plan** (the "how/when"); the gap audit is the "what/why". Mirrors mobile's `mobile/PRIVATE_MODE_PRODUCTION_PLAN.md`.

**Guiding principle (decided with the product owner):** *mirror mobile unless there is a hard platform reason not to.* The mobile client is the source of truth for schema, analytics semantics, and behavior.

> The desktop Private Mode shipped 2026-07-03 was a **mock/first pass with no real users** — we are building it properly for the first time, so we are free to restructure the private-data layer (clean baseline, no back-compat burden).

---

## 0. Locked decisions (from the design interview)

| # | Decision | Resolution |
| --- | --- | --- |
| 1 | Sequencing | **Phase 1** (local parity) first & shippable; lay **Phase-2-ready foundations** (settings in DB, `sync_state`/`sync_meta` + triggers, `pointycastle`, migration framework, abstract transport + No-Op). |
| 2 | Schema | Adopt mobile's `private_db_schema.dart` as the **single source of truth** — identical tables/columns/constraints/indexes. |
| 3 | Baseline | **Clean-recreate** (fresh DB file `evolve_private_v2.db`); versioned-migration framework still installed for future changes. |
| 4 | Alignment depth | Mirror mobile's **data+compute layer** (schema + analytics + a fuller store); keep desktop's presentation/repository layer; wire private branches via thin adapters. **Cloud path untouched.** |
| 5 | Localization | Adopt **slang**; **full desktop coverage** in en/it/es/de/ar (reuse mobile's translations), incl. an **Arabic RTL pass**. |
| 6 | AI | Build the private AI-consent gate + `private_ai_external_consent` column now; key via `--dart-define`; ship **inert** until a key is supplied. |
| 7 | Notifications | Actionable **Done/Skip/Snooze on macOS** (mode-aware writes to local DB); Windows/Linux keep tap-to-open (deferred). |
| 8 | Testing | Full mobile-aligned guard suite: `sqflite_common_ffi` + `mocktail`; analytics parity, no-Supabase-call guard, settings-separation, delete-private-data, DB bootstrap/migration tests. |
| 9 | Sync direction | **Apple-only sync**: macOS reuses mobile's CloudKit stack on the **same `iCloud.com.simo.evolve` container** (iOS↔macOS converge). **Windows/Linux local-only forever** (No-Op, sync UI hidden). |

**Auto-resolved by the guiding principle:**
- Import stays available in **both** modes (remove desktop's private-only gate).
- Delete private data keeps the DB key/owner, re-seeds an empty profile, and **stays in Private Mode** (does *not* exit to Login).
- Export = a full, mode-tagged private snapshot (incl. categories + profile).
- Backup exclusion: macOS excludes the DB from Time Machine (`NSURLIsExcludedFromBackupKey`); Windows/Linux have no standard API (DB is SQLCipher-encrypted regardless).

---

## 1. Scope

**In scope (Phase 1 + foundations):** everything in Workstreams WS1–WS9 below.

**Deferred (Phase 2, separate milestone):** the actual CloudKit sync *transport* + iCloud settings UI on macOS. Only the **backend-agnostic foundations** are built now.

**Permanently out of scope:** Windows/Linux cross-device sync (local-only forever); rewriting desktop's cloud/presentation architecture; localizing behavior differences unrelated to parity.

---

## 2. Target architecture

```
Presentation (desktop-native, UNCHANGED shape) ───────────────────────────
  DashboardController · statistics_page · goals_stats_view · settings_page
        │  (private branches only, wired via thin adapters)
Data + compute (MIRRORS MOBILE, ported) ──────────────────────────────────
  DesktopPrivateDb  ─ owns: aligned schema, CRUD, export/import/delete,
                       _ensureProfile, analytics READS
  private_db_schema.dart (ported)  ─ portable DDL + migrations + sync objects
  private_analytics.dart (ported)  ─ pure RPC/view reimplementations
        │
Foundations for Phase 2 (laid now, No-Op transport) ──────────────────────
  sync_state / sync_meta + triggers · SyncCrypto (AES-GCM) · abstract
  PrivateSyncTransport (CloudKit on macOS later; NoOp on Win/Linux forever)
```

- **Mode routing** (already correct): `activeDesktopDataModeProvider` (`desktop_data_mode.dart`); repo proxy `dashboardRepositoryProvider` (`dashboard_repository.dart:56`); router gate `evolve_desktop_app.dart:50`; cold-start gating `main.dart`.
- **Analytics source data:** analytics read **directly from the private DB** (like mobile's store methods), *not* from the in-memory `DashboardSnapshot` (which is lossy). Expose via mode-aware stats providers.

---

## 3. Pubspec additions (align versions with `mobile/pubspec.yaml`)

- `pointycastle: ^4.0.0` (Phase-2 crypto foundation)
- `slang: ^4.0.0`, `slang_flutter: ^4.0.0` (localization)
- dev: `slang_build_runner: ^4.0.0`, `sqflite_common_ffi` (DB tests off-device), `mocktail` (fakes)
- Already present & shared: `flutter_riverpod ^3.3.1`, `sqflite_sqlcipher ^3.4.0`, `uuid`, `path`, `path_provider`, `flutter_secure_storage`, `shared_preferences`, `flutter_local_notifications`.

---

## 4. Aligned private schema (WS1 reference)

Port `mobile/lib/core/private_db_schema.dart` → `desktop/lib/core/private_db_schema.dart` as a **standalone module** (so DDL runs on in-memory `sqflite_common_ffi` in tests). Tables (identical to mobile): `profiles`, `goals`, `goal_logs` (incl. `value REAL`, `streak`, `UNIQUE(goal_id,date)`), `long_term_goals`, `daily_moods` (0–10 CHECK, `UNIQUE(user_id,date)`), `goal_category_settings`, `macro_goal_categories` (incl. `updated_at`, `archived_at`, `UNIQUE(user_id,name)`). Plus indexes.

- `profiles` carries the **settings columns** mobile stores there: `theme_mode`, `accent_color`, `language`, `pref_*`, `notif_*`, `is_pro` (DEFAULT 1), `biometric_lock`, `morning_brief_time`, `evening_review_time`, `date_of_birth`, `terms_accepted_at`, `sentry_consent`, `private_ai_external_consent`.
- **Sync objects (Phase-2 foundation, created now):** `sync_state`, `sync_meta`, and the per-table dirty/tombstone triggers (mobile `private_db_schema.dart:271-338`). Inert until Phase 2.
- **`_ensureProfile`**: idempotent owner-row seed (`is_pro:1`, `sentry_consent:0`, defaults) — mobile `private_local_database.dart:151-173`.
- **Baseline:** open `evolve_private_v2.db`; `version` starts at the mobile-aligned number; `PRAGMA foreign_keys = ON` in `onConfigure`.

---

## 5. Workstreams

Each workstream lists tasks, key files, acceptance criteria, and its verification gate. Order reflects dependencies (§6).

### WS1 — DB foundation & P0 bug fixes  *(unblocks everything)*
**Tasks**
- Add pubspec deps (§3). Port `private_db_schema.dart` (§4). Rewrite `desktop_private_db.dart` to: open `evolve_private_v2.db`, `PRAGMA foreign_keys=ON`, run the ported schema, call `_ensureProfile`, expose the versioned-migration `onUpgrade`.
- Give `DesktopPrivateDb` the **full CRUD + helper surface** mobile's store has (goals/logs/macro/categories/moods/profile/settings + `exportData`/`importData`/`deleteAllPrivateData` + `setPrivateAiExternalConsent`). Have `PrivateDashboardRepository` + controllers call these.
- Fix **B1** (profile bootstrap + FK on), **B2** (import owner-id → real `ownerId`), **B3** (`value` column now exists in DDL), **B6** (`deleteAll` also removes the `private_profile` avatar dir).
- Delete-private-data → re-seed empty profile + **stay in Private Mode** (drop the `goToLogin()` call in `settings_page.dart:1006`).

**Acceptance:** DB opens with FKs on; owner `profiles` row exists after first open; profile/avatar writes affect 1 row; import round-trips under the real owner and is visible in the dashboard; deleting private data wipes rows+avatar files and re-seeds a usable empty profile without leaving Private Mode.
**Gate:** `dart format`, `flutter analyze`, new DB bootstrap/migration + import tests green.

### WS2 — Pro unlock  *(B4)*
**Tasks:** force `isPro=true` in Private Mode (via the DB `profiles.is_pro` = 1 and settings mapping); audit every Pro gate to hide on `isPrivateMode`, not `!isPro` (fix `settings_page.dart:174`; the accent-palette gate `:289`; any other `isPro` UI).
**Acceptance:** in Private Mode all Pro-gated features are usable and no paywall/upgrade/Pro-badge UI appears. Cloud mode Pro behavior unchanged.
**Gate:** analyze + a settings/Pro test.

### WS3 — AI external-send consent gate  *(B5)*
**Tasks:** add `private_ai_external_consent` read/write to the store (done in WS1 schema); add `_ensurePrivateAiConsent()` before the first external send in `ai_coach_page.dart` (mirror mobile `ai_chat_screen.dart:313-352`); default share-toggles to a safe posture; move `openrouter_config.dart` key to `String.fromEnvironment` (`--dart-define`), default empty; localized consent copy stating the display name is included when context is shared.
**Acceptance:** in Private Mode, no external send happens until consent is granted (persisted in the DB); once granted, sends proceed; cloud mode unchanged; empty key ⇒ inert with the "key missing" message.
**Gate:** analyze + a consent-gate unit test (fake store).

### WS4 — Local analytics engine  *(the big one; A2/B8)*
**Tasks**
- Port `mobile/lib/core/private_analytics.dart` → `desktop/lib/features/statistics/data/private_analytics.dart` **verbatim in semantics** (ISODOW indices, `worst_streak` as abs, yearly grid oldest→newest done=1/missed=2, critical-day alpha tie-break, best-habits top-5, timeframe bucketing). Reconcile input types to desktop models via small adapters.
- Port the **macro-goal stats** + **habit correlations** (inline in mobile `private_local_database.dart:896-1294`).
- Verify/align `desktop/lib/core/streak_utils.dart` with mobile's `streak_utils.dart` (analytics read the **stored** signed streak).
- Add analytics **read methods** to `DesktopPrivateDb`, then make each stats provider mode-aware: `if (isPrivate) return <local compute> else <existing RPC>` — `statistics_rpc_providers.dart` (all families), `goals_stats_view.dart:78` (macro stats). Handle the **two timeframe vocabularies** (`week|month|year|all` for best-habits vs `timeframe_*` for global-trend).
**Acceptance:** every statistics tab (yearly grid, performance-by-day, alerts, correlations, best/critical habits, global trend, macro stats) renders real data in Private Mode with **no network**; numbers match mobile for identical inputs.
**Gate:** `private_analytics_test` (parity vectors ported from mobile) green; no-Supabase-call guard covers the private stats path.

### WS5 — Profile / name / avatar + export/delete parity  *(A3/A9/B7/B9)*
**Tasks:** unify the private name on the DB `profiles.full_name` (remove the `SharedPreferences 'private_profile_name'` fork in `dashboard_page.dart:56,1037`); reload avatar from the DB path on launch; bring `_exportData` to full private-export parity (include `macro_goal_categories` + profile, mode-tag the source); confirm delete removes avatar files (WS1) and re-seeds.
**Acceptance:** name/DOB/avatar persist across restart from the DB; a single name source; private export contains all private entities and is tagged `mode:'private'`.
**Gate:** analyze + delete-private-data test + export-shape test.

### WS6 — Private settings in the DB `profiles` row  *(A4.2)*
**Tasks:** in Private Mode, route settings reads/writes through the DB `profiles` row (theme/accent/calendar/language/24h/haptics/notif flags/times/biometric), mirroring mobile's `_loadPrivateSettings`/`_saveToPrivate`; ensure `updateSettingsRow` re-forces `is_pro:1, sentry_consent:0`; keep cloud settings on their current prefs+Supabase path.
**Acceptance:** changing settings in Private Mode persists to the encrypted DB (survives restart) and never touches Supabase; cloud settings unaffected.
**Gate:** settings-separation test (private↔cloud isolation).

### WS7 — Localization (full desktop coverage)  *(A12; own track, parallelizable)*
**Tasks:** stand up **slang** (`slang.yaml`, `lib/i18n/`, build_runner); localize all **new/modified Private-Mode strings** inline as WS1–WS6/WS8 are written (reuse mobile's `auth`/`privacy`/`ai`/`settings` keys); then a **full-app extraction sweep** of the remaining hardcoded Italian across `settings_page`, `statistics_page`, `auth_page`, `ai_coach_page`, dialogs, etc., in **en/it/es/de/ar**; port `mobile/lib/core/rtl.dart` and do the **Arabic RTL pass** (directional paddings/alignments/icons).
**Acceptance:** no hardcoded user-facing strings remain; all 5 locales resolve; Arabic renders RTL correctly.
**Gate:** analyze; a locale-completeness check (every key present in all 5 locales); manual RTL smoke on one screen per view.

### WS8 — macOS actionable notifications  *(A8)*
**Tasks:** add Done/Skip/Snooze notification actions on macOS via `flutter_local_notifications`; handle the action callback mode-aware → in Private Mode write the habit log to `DesktopPrivateDb` with a computed streak (mirror mobile `notifications.dart`), then invalidate the dashboard/stats providers; Snooze reschedules only. Windows/Linux keep tap-to-open (documented deferral).
**Acceptance:** on macOS, Done/Skip from a notification persists the log (with correct streak) in Private Mode and refreshes the UI; no Supabase call in Private Mode; cloud mode writes to Supabase.
**Gate:** analyze + a notification-action routing unit test (fake store); manual macOS smoke.

### WS9 — Test suite & guards  *(A/§8; alongside all streams)*
**Tasks:** add `sqflite_common_ffi`+`mocktail`; write: **analytics parity** (WS4), **no-Supabase-call-in-Private** guard (CRUD + stats + notifications), **settings-separation** (WS6), **delete-private-data** (WS1/WS5), **DB bootstrap/migration** (WS1). Wire ffi DB init in a shared test harness.
**Acceptance:** all above green; CI-equivalent local run clean.
**Gate:** `flutter test` all green.

---

## 6. Sequencing & dependencies

```
WS1 (DB foundation) ──► WS2 (Pro) ──► WS3 (AI consent)
      │                       └──► WS6 (settings in DB)
      └──► WS4 (analytics) ──► WS5 (profile/export/delete)
      └──► WS8 (macOS notifications)
WS7 (localization) runs in parallel; strings for WS1–WS8 localized inline.
WS9 (tests) runs alongside; each WS lands with its tests.
```

**Critical path:** WS1 → WS4 (analytics is the largest and depends on the aligned DB). WS7 is parallel; WS8 is independent after WS1.

---

## 7. Phase 2 (deferred) — what's laid now vs later

**Laid now (WS1):** `sync_state`/`sync_meta` + triggers, `pointycastle`, the abstract `PrivateSyncTransport` interface + a `NoOpSyncTransport`, the device-local owner UUID (unchanged), settings/profile already in the DB (WS6/WS5) so they're sync-ready.

**Later (Phase 2 milestone, macOS only):** port mobile's `sync_engine`/`sync_local_store`/`sync_crypto`/`sync_key_store`/`cloudkit_bridge*`/`private_sync_service`/`icloud_sync_screen`; add the Swift CloudKit bridge to the **macOS Runner** (reuse `AppDelegate.swift` `CloudKitSyncBridge`, same container/zone/record type); gate `privateSyncServiceProvider` on `Platform.isMacOS` (else No-Op). Windows/Linux stay No-Op forever; the sync UI is hidden off macOS.

**Manual/external for Phase 2 (→ `TO_SIMO_DO.md` when we get there):** add **macOS** to the `iCloud.com.simo.evolve` CloudKit container in the Apple Developer portal; add iCloud/CloudKit entitlements to the macOS target; two-device (iPhone↔Mac) QA.

---

## 8. Verification (definition of done — Phase 1)

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze` (clean)
- `flutter test` (all green, incl. the new guard tests)
- `flutter build macos --debug` + manual smoke: enter Private Mode → create habit/log/macro-goal/category/mood → edit profile+avatar → change settings → **all statistics tabs show data** → export → restart (mode + data persist) → macOS notification Done writes a log → AI consent gate blocks until accepted → delete private data (stays in Private Mode, empty profile) → switch to Login (data preserved) → back to Private (data intact).
- Privacy smoke: no Supabase/RevenueCat/Sentry activity in Private Mode; AI needs consent.
- Cloud-mode regression: login, data loads, CRUD syncs, subscription unchanged.

---

## 9. Manual / external items (not blocking Phase 1)

- Supply the **OpenRouter key via `--dart-define`** whenever AI should go live (WS3). Never commit it.
- Phase 2 Apple provisioning (see §7).

---

## 10. Immediate next step

Begin **WS1 — DB foundation & P0 bug fixes**: add pubspec deps, port `private_db_schema.dart`, rewrite `desktop_private_db.dart` to the aligned schema with `_ensureProfile` + FKs on + the migration framework + sync objects, and land B1/B2/B3/B6 with their tests.
