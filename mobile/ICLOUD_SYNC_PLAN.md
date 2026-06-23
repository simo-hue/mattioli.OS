# iCloud Sync — Implementation Plan (Private Mode, Phase 2)

Created: 2026-06-23
Status: Approved design, pre-implementation
Scope: Flutter mobile app (`mobile/`), iOS only. Supersedes the high-level "Phase 2" section of `PRIVATE_MODE_PRODUCTION_PLAN.md` with an implementation-resolution design agreed via a design interview.

> Phase 1 (local encrypted Private Mode) is complete and regression-guarded (110 tests). This plan adds optional, opt-in iCloud sync of the private data space. It does **not** touch the Supabase/account data space.

---

## 1. Goal & non-goals

**Goal:** Let a Private-Mode user opt in to syncing *all* their private data across their own Apple devices via their personal iCloud, end-to-end encrypted, with correct multi-device merge and no silent data loss.

**Non-goals (out of scope / future):**
- Android sync — permanently local-only/no-op.
- Sharing data between the Private and Supabase spaces — never.
- CloudKit push / background refresh — **fast-follow** after v1 (engine is identical; push only triggers it).
- A user-facing recovery key — **future** (v1 is pure E2E).
- Syncing `ai_insights` — excluded (not stored locally).

---

## 2. Locked decisions (design interview)

| # | Decision | Rationale |
| --- | --- | --- |
| 1 | **Record-based CloudKit** — one encrypted record per local row | Per-record LWW; no whole-file conflict data loss |
| 2 | **Thin Swift bridge + Dart sync engine; iOS 15 floor** | Engine unit-testable from Dart via a fake bridge; keeps current OS support. Forces a **custom record zone** (delta fetch needs zone change tokens) |
| 3 | **One generic `PrivateRecord` type** `{tableName, updatedAt, deleted, payload, asset?}`; `recordName = "<table>:<uuid>"` | Minimal CloudKit-visible metadata; one schema; deterministic convergence |
| 4 | **AES-256-GCM in Dart (pointycastle, no new dep)**; 256-bit **sync key in iCloud Keychain** (`synchronizable:true`), separate from the device-local SQLCipher key | True client-side E2E; Swift never sees plaintext; key auto-syncs to the user's devices |
| 5 | **Pure E2E, no backdoor** | Privacy-first identity; key-unavailable → wait; keychain-off → unrecoverable (warned) |
| 6 | **`sync_state` table + SQLite triggers + tombstones**; add `updated_at` to `macro_goal_categories` (schema **v3**) | Can't-forget dirty tracking; tombstones outlive deleted rows; domain tables/queries untouched |
| 7 | **Canonical sync-owner in iCloud Keychain + auto-merge** (union per-row, LWW singletons; second device re-keys `user_id`) | One identity across devices; no data loss when both devices had data |
| 8 | **Foreground + debounced after-write + manual "Sync now"** (iCloud entitlement only) | ~95% of value, minimal capability surface; push adds no rework |
| 9 | **Avatar via encrypted `CKAsset`** (`avatar:<owner>`), re-localized per device | Honors "all private data"; only encrypted-binary path |
| 10 | **"Delete private data" = full sync reset** (wipe local + delete zone + delete key/owner from Keychain + sync off; offline → queue wipe, pause pulls) | Can't silently resurrect; correct privacy posture |
| 11 | **LWW on device edit-time (`updated_at`)** + deterministic tie-break + future-skew guard | "Last actual edit wins" even for out-of-order offline syncs (server `modificationDate` would be wrong) |

**Determined (recommended) defaults:**
- Container `iCloud.com.simo.evolve`, **private database** scope; CloudKit *Development* during build, **promote schema to Production before App Store release**.
- Entitlements (manual): iCloud + CloudKit + the container. **No** push capability (deferred), **no** keychain-access-groups (`synchronizable` needs none).
- Record payload = the full row as JSON, encrypted (excludes the device-local `avatar_url` path). Apply = upsert-by-id with LWW.
- Disable sync = stop syncing, **leave** CloudKit data; re-enable resumes. (Cloud wipe is only via the delete action.)
- Settings UI is private-mode + iOS only; hidden on Android/Supabase.

---

## 3. Architecture overview

```
┌─────────────────────────── Dart (testable) ───────────────────────────┐
│ SettingsUI (sync section)                                               │
│   └─ syncStatusProvider / syncControllerProvider                       │
│ PrivateSyncService (real impl, replaces NoOpPrivateSyncService)        │
│   └─ SyncEngine                                                        │
│        ├─ SyncStateDao         (sync_state / sync_meta over the DB)    │
│        ├─ SyncCrypto           (AES-256-GCM, pointycastle)             │
│        ├─ SyncKeyStore         (key + canonical owner via iCloud KC)   │
│        ├─ RowCodec             (row JSON <-> table, per tableName)     │
│        └─ CloudKitBridge       (abstract; fakeable)                    │
└───────────────────────────────┬───────────────────────────────────────┘
                                 │ MethodChannel 'evolve/cloudkit'
                                 │ (encrypted bytes only — no plaintext)
┌───────────────────────────────▼───────────────────────────────────────┐
│ Swift CloudKitBridge (thin) — CKContainer.privateCloudDatabase         │
│   accountStatus · ensureZone · saveRecords · fetchChanges(token)       │
│   · deleteRecords · deleteZone                                          │
└────────────────────────────────────────────────────────────────────────┘
                                 │
                            iCloud (user's private CloudKit DB, PrivateZone)
```

Key separation of secrets:
- **SQLCipher DB key** — `flutter_secure_storage`, `first_unlock_this_device`, **never synced** (unchanged from Phase 1).
- **CloudKit sync key (new)** — `flutter_secure_storage`, `synchronizable: true` → iCloud Keychain, syncs to the user's devices.
- **Canonical owner id (new)** — same iCloud Keychain mechanism.

---

## 4. Data model & schema changes

### 4.1 Local schema migration → v3 (`PrivateLocalDatabase`)
1. `ALTER TABLE macro_goal_categories ADD COLUMN updated_at TEXT` (backfill existing rows to `created_at`). Update `addMacroGoalCategory`/`updateMacroGoalCategory`/`archiveMacroGoalCategory` to stamp `updated_at`.
2. Create sync tables:
```sql
CREATE TABLE sync_state (
  record_name     TEXT PRIMARY KEY,         -- "<table>:<rowId>" | "avatar:<owner>"
  table_name      TEXT NOT NULL,
  row_id          TEXT NOT NULL,
  updated_at      TEXT NOT NULL,            -- mirrors the row's edit time (UTC ISO)
  last_synced_at  TEXT,                     -- last confirmed in CloudKit
  dirty           INTEGER NOT NULL DEFAULT 1,  -- needs push
  deleted         INTEGER NOT NULL DEFAULT 0,  -- tombstone
  last_error      TEXT
);
CREATE INDEX idx_sync_state_dirty ON sync_state (dirty) WHERE dirty = 1;

CREATE TABLE sync_meta (
  id                  INTEGER PRIMARY KEY CHECK (id = 1),
  server_change_token TEXT,                 -- base64 CKServerChangeToken
  last_full_sync_at   TEXT,
  pending_zone_wipe   INTEGER NOT NULL DEFAULT 0
);
INSERT OR IGNORE INTO sync_meta (id) VALUES (1);
```
3. Triggers on each of the 7 synced tables (`profiles`, `goals`, `goal_logs`, `long_term_goals`, `daily_moods`, `goal_category_settings`, `macro_goal_categories`):
```sql
-- INSERT/UPDATE: mark dirty, not deleted
CREATE TRIGGER <t>_sync_aiu AFTER INSERT ON <t> BEGIN
  INSERT INTO sync_state(record_name, table_name, row_id, updated_at, dirty, deleted)
  VALUES ('<t>:'||NEW.id, '<t>', NEW.id, NEW.updated_at, 1, 0)
  ON CONFLICT(record_name) DO UPDATE SET updated_at=NEW.updated_at, dirty=1, deleted=0;
END;
-- (same AFTER UPDATE)
-- DELETE: tombstone
CREATE TRIGGER <t>_sync_ad AFTER DELETE ON <t> BEGIN
  INSERT INTO sync_state(record_name, table_name, row_id, updated_at, dirty, deleted)
  VALUES ('<t>:'||OLD.id, '<t>', OLD.id, strftime('%Y-%m-%dT%H:%M:%fZ','now'), 1, 1)
  ON CONFLICT(record_name) DO UPDATE SET updated_at=excluded.updated_at, dirty=1, deleted=1;
END;
```
- `profiles` uses `id` (the owner) as `row_id`; single-row tables behave identically.
- The avatar record (`avatar:<owner>`) is **not** trigger-managed; the profile/avatar write path marks it dirty explicitly (it carries no DB row of its own).

### 4.2 Apply-loop trigger suppression (critical)
Applying a *pulled* record writes the local row → fires the dirty trigger → would re-push (ping-pong). After applying pulled records inside the apply transaction, explicitly `UPDATE sync_state SET dirty=0, last_synced_at=? WHERE record_name=?` for each applied record (overriding the trigger). Documented invariant: **the only place that clears `dirty` is the apply/confirm step.**

### 4.3 CloudKit schema
- **Zone:** `PrivateZone` (custom) in `privateCloudDatabase`.
- **Record type:** `PrivateRecord` with fields:
  - `tableName` : String
  - `updatedAt` : Int64 (epoch ms, the row edit time)
  - `deleted`   : Int64 (0/1 tombstone)
  - `payload`   : Bytes (AES-GCM ciphertext of the row JSON; empty for tombstones)
  - `asset`     : CKAsset, optional (avatar only; AES-GCM ciphertext of image bytes)
- **`recordName`:** `"<tableName>:<rowUuid>"`, or `"avatar:<canonicalOwner>"`. Deterministic ⇒ both devices target the same record.
- **Key-check record:** `recordName = "keycheck"`, `payload = AES-GCM("evolve-keycheck:" + canonicalOwner)`. Lets a device validate that its iCloud-Keychain key matches the data in the zone before syncing.

---

## 5. Encryption & key management

- **Cipher:** AES-256-GCM (pointycastle `GCMBlockCipher(AESEngine())`). Per-encryption random 96-bit nonce; output = `nonce(12) || ciphertext || tag(16)`. Authenticated — tampered/garbage decrypts fail loudly.
- **Sync key:** 256-bit random. Stored at `private_sync_key_v1` via `IOSOptions(synchronizable: true, accessibility: first_unlock)`. (`SecureStorageUtils` gains a `synchronized` variant alongside the existing `deviceLocal` one.)
- **Canonical owner:** stored at `private_sync_owner_v1`, same options.
- **First enable (no key in iCloud Keychain):** generate key + set canonical owner = this device's current owner id; create the `keycheck` record in CloudKit.
- **Adopting device (key present from iCloud Keychain):** read key + canonical owner; **validate** by decrypting the `keycheck` record. If it can't decrypt → surface a key error (don't corrupt the zone).
- **Key not yet synced on a 2nd device:** sync state = `waitingForKeychain`; retry on next trigger. Local mode unaffected.
- **Key loss (user disables iCloud Keychain entirely):** existing cloud data becomes permanently undecryptable. **Surfaced as an explicit warning in the enable flow.** No recovery path in v1 (by design).

---

## 6. Native bridge contract (`MethodChannel 'evolve/cloudkit'`)

Swift is a thin pass-through over `CKContainer(identifier:).privateCloudDatabase`; it **never** decrypts. All payloads cross as bytes.

| Method | Args | Returns |
| --- | --- | --- |
| `accountStatus` | — | `"available"｜"noAccount"｜"restricted"｜"couldNotDetermine"｜"temporarilyUnavailable"` |
| `ensureZone` | — | ok / error |
| `saveRecords` | `[{recordName, tableName, updatedAt:int, deleted:int, payload:bytes?, assetPath:string?}]` | `{saved:[recordName], conflicts:[{recordName, serverUpdatedAt:int}], errors:[{recordName, code}]}` |
| `fetchChanges` | `{token: bytes?}` | `{records:[{recordName, tableName, updatedAt, deleted, payload:bytes?, assetPath:string?}], newToken:bytes, moreComing:bool}` |
| `deleteRecords` | `[recordName]` | `{deleted:[recordName], errors:[...]}` |
| `deleteZone` | — | ok / error |

- `saveRecords` uses `CKModifyRecordsOperation`, chunked ≤ 380 records/op, save policy `.ifServerRecordUnchanged`; a `serverRecordChanged` error returns the record in `conflicts` (with the server `updatedAt`) for Dart to LWW-resolve.
- `fetchChanges` uses `CKFetchRecordZoneChangesOperation` with the saved `serverChangeToken`; loops `moreComing` internally or surfaces it for Dart to re-call.
- Avatars: Dart writes encrypted bytes to a temp file → `assetPath`; Swift wraps as `CKAsset`. On fetch, Swift returns the downloaded (still-encrypted) asset temp path; Dart reads + decrypts.

---

## 7. Dart sync engine — algorithm

`CloudKitBridge` (abstract) has one real impl (MethodChannel) and one `FakeCloudKitBridge` for tests (in-memory zone with server-change-token semantics).

### 7.1 `enableSync()`
1. `accountStatus()`; if not `available` → set status, abort (local unaffected).
2. `ensureKeyAndOwner()`: read/generate sync key + canonical owner from iCloud Keychain; validate/create `keycheck`.
3. **Re-key migration** if `localOwner != canonicalOwner` (§8).
4. `ensureZone()`.
5. Mark everything dirty (first push) — i.e. ensure `sync_state` has a row per existing local row (a one-time backfill insert for pre-existing data), then `syncNow()` with `token = null` (full pull) so the union/merge happens.
6. Persist `syncEnabled = true` (a synced-but-also-local flag; sync is per-device opt-in, so store in `sync_meta`/prefs, **not** iCloud Keychain).

### 7.2 `syncNow()` (core loop, also the trigger target)
1. If `pending_zone_wipe` → `deleteZone()`, clear flag, return.
2. **Push:** read dirty rows from `sync_state`. For each, load the row (or build a tombstone), `RowCodec.encode` → JSON → `SyncCrypto.encrypt` → record; `saveRecords` in chunks.
   - On `saved` → `dirty=0, last_synced_at=now`.
   - On `conflict{serverUpdatedAt}` → pull that record, LWW-resolve (§7.3); if local still newer, re-push.
   - On `error` → record `last_error`, leave dirty for retry.
3. **Pull:** `fetchChanges(token)`; for each returned record:
   - `SyncCrypto.decrypt` → row JSON (or tombstone).
   - **LWW:** compare `record.updatedAt` vs local `sync_state.updated_at` (and presence). If server wins (or local absent): apply — upsert row via `RowCodec.decode`+`PrivateLocalDatabase`, or apply tombstone (delete local row); then set `sync_state dirty=0, last_synced_at`. If local wins: leave local dirty (it will push next).
   - Avatar record → decrypt asset → write `private_profile/`, set local `avatar_url`.
   - Persist `newToken`; loop while `moreComing`.
4. Update `last_full_sync_at`, status = idle.

### 7.3 Conflict / merge specifics
- **Comparator:** `updated_at` (UTC). Tie → higher `recordName` hash wins (deterministic). Guard: ignore a remote `updatedAt` more than a few minutes in the future (clock-skew defense).
- **Edit-vs-delete:** a tombstone has an `updated_at`; LWW applies — a later edit resurrects (intended), a later delete wins.
- **Singletons (profile/settings/category_settings):** identical LWW path; one record each under the canonical owner.

---

## 8. Cross-device identity & merge

- `canonicalOwner` lives in iCloud Keychain. First enabling device sets it = its owner id. Other devices adopt it.
- **Re-key migration** (adopting device where `localOwner != canonicalOwner`), in one transaction with FK handling:
  1. `PRAGMA foreign_keys = OFF` (within txn).
  2. If a `profiles` row with `id = canonicalOwner` already exists locally (rare) → merge fields LWW, delete the old `localOwner` profile; else `UPDATE profiles SET id = canonicalOwner WHERE id = localOwner`.
  3. `UPDATE <child> SET user_id = canonicalOwner WHERE user_id = localOwner` for goals, goal_logs, long_term_goals, daily_moods, goal_category_settings, macro_goal_categories.
  4. Rebuild `sync_state` record_names that embed the owner (profiles/category_settings) accordingly; mark all dirty.
  5. Update the device-local owner id (`SecureStorageUtils` `_ownerIdKey`) to `canonicalOwner` so `ownerId()` returns it thereafter.
  6. `PRAGMA foreign_keys = ON`; verify integrity (`PRAGMA foreign_key_check`).
- After re-key, per-row records union naturally (unique UUIDs); singletons converge under the canonical owner.
- **Second device empty** (common case) → no re-key; just pulls everything.

---

## 9. Sync triggers (v1)

- **App foreground/resume** — `syncNow()` (debounced; reuse the existing lifecycle observer in `main.dart`).
- **After local write** — Private-mode mutations enqueue a debounced (~3 s) `syncNow()`. Hook at the `PrivateSyncService` boundary or via the existing provider write paths.
- **Manual "Sync now"** — settings button.
- All are no-ops when `syncEnabled == false`, mode != private, or platform != iOS.

---

## 10. Delete / reset / disable

- **Delete private data (full reset, §Q9):** within the existing `deleteAllPrivateData` flow, when `syncEnabled`: set `pending_zone_wipe=1`; wipe local; if online → `deleteZone()` + delete `keycheck`; delete sync key + canonical owner from iCloud Keychain; `syncEnabled=false`. Offline → keep `pending_zone_wipe`, **pause pulls**, finish the wipe on next connectivity. A second device seeing zone/key gone → stop syncing (no re-upload).
- **Disable sync:** `syncEnabled=false`; stop triggers; leave CloudKit data + key intact; re-enable resumes from the saved token (or full reconcile).
- **Exit Private Mode (to login):** non-destructive; sync simply doesn't run in Supabase mode.

---

## 11. Account status & errors

`accountStatus` mapped to user-facing states; **iCloud unavailable never blocks local mode**:
- `available` → normal.
- `noAccount` → "Sign in to iCloud to enable sync."
- `restricted` → "iCloud is restricted on this device."
- `temporarilyUnavailable`/`couldNotDetermine` → retry with backoff; show "iCloud temporarily unavailable."
- `waitingForKeychain` (our state) → "Waiting for iCloud Keychain…".
- Per-record `last_error` retained for diagnostics; never surfaces raw errors to users (consistent with SEC-7).

---

## 12. UI (private-mode + iOS only)

New section in `privacy_settings_screen.dart` (or a dedicated screen), shown only when `isPrivateMode && Platform.isIOS`:
- **Enable iCloud Sync** toggle → first-enable disclosure sheet (E2E, uses *your* iCloud not our servers, keychain-off forfeits data) → `enableSync()`.
- **Sync now** button (disabled while syncing / not enabled).
- **Status row:** last-synced timestamp + state (idle/syncing/error/waiting/no-account).
- Hidden entirely on Android and in Supabase mode.
- All new strings localized **en/it/es/de** (slang); regenerate.

---

## 13. Testing strategy

- **Unit (Dart, no device) — the bulk:** `SyncEngine` against `FakeCloudKitBridge` (in-memory zone + change tokens). Cover: push dirty; pull apply; LWW both directions; edit-vs-delete tombstone; trigger ping-pong suppression; re-key migration; union of two datasets; singleton LWW; avatar encode/decode; key-check validate/fail; delete full-reset + offline pending wipe; account-unavailable no-op. Reuse the `PrivateDataStore` fake pattern.
- **Crypto unit:** AES-GCM round-trip; tamper → fail; wrong key → fail.
- **Migration unit:** v2→v3 (categories.updated_at backfill; sync tables/triggers created; trigger marks dirty; delete writes tombstone). (Needs a DB harness — add `sqflite_common_ffi` as a dev dep for migration/integration tests, or run as an integration test.)
- **Two-device manual matrix (release gate):** fresh 2nd device pulls; both-had-data merge; offline edits converge (LWW by edit time); delete-resets-and-doesn't-resurrect; iCloud signed-out; key-not-yet-synced; Android shows no UI; CloudKit dashboard shows only opaque encrypted payloads.

---

## 14. Manual prerequisites (owner: Simo)

Tracked in `TO_SIMO_DO.md`:
1. Create/enable the **CloudKit container `iCloud.com.simo.evolve`** + iCloud capability (CloudKit) in Xcode/Apple Developer; add the container to `Runner.entitlements`.
2. Before App Store release: **promote the CloudKit schema to Production**.
3. Update **App Store privacy** answers (data now syncs to the user's iCloud; still no third-party servers).
4. Confirm `ITSAppUsesNonExemptEncryption` remains correctly declared (already SQLCipher; AES adds no new export category but re-verify).

---

## 15. Phased build order (each: implement → test → commit)

| Step | Deliverable | Acceptance |
| --- | --- | --- |
| **1. Schema v3** | `macro_goal_categories.updated_at`; `sync_state`/`sync_meta`; triggers; trigger-suppression hook in apply | Migration tests green; existing 110 tests green; categories writes stamp `updated_at` |
| **2. Crypto + key store** | `SyncCrypto` (AES-GCM); `SyncKeyStore` (synced key + canonical owner via iCloud Keychain); `keycheck` | Crypto round-trip/tamper/wrong-key tests; key generate/read/validate tests |
| **3. Dart SyncEngine + FakeCloudKitBridge** | full push/pull/LWW/tombstone/merge/re-key/avatar logic against the fake | The full §13 unit matrix green; **no native code yet** |
| **4. Swift bridge + wiring** | thin `CloudKitBridge` + MethodChannel; real `PrivateSyncService`; entitlements/container (manual) | Builds with entitlements; manual single-device round-trip works |
| **5. UI + triggers + l10n + status** | settings section, disclosure, Sync now, status; foreground/after-write/manual triggers; account-status mapping | UI hidden on Android/Supabase; strings localized; manual enable→sync demo |
| **6. Delete-reset + enable/disable + 2nd-device merge** | full-reset path (incl. offline pending wipe); disable/resume; adopting-device merge | Delete doesn't resurrect; merge unions correctly; offline wipe completes |
| **7. Hardening + release** | two-device matrix, partial-failure/retry/backoff, Production schema promotion, App Store privacy | §13 manual matrix passes on real devices |
| **8. Fast-follow** | CKSubscription silent push + BGTaskScheduler refresh | Open 2nd device updates within seconds |

Steps 1–3 are **fully code-side and need no Apple provisioning** — the natural place to start.

---

## 16. Risks & edge cases

- **Trigger ping-pong** — mitigated by the apply-step `dirty=0` invariant (§4.2); covered by a dedicated test.
- **Re-key FK integrity** — transactional, `foreign_key_check` verified (§8).
- **Clock skew** — edit-time LWW + future-timestamp guard; acceptable for a single user's NTP-synced devices.
- **CloudKit limits / partial failures** — chunked saves ≤380, `serverRecordChanged` → LWW, retry/backoff on throttle (`CKError.requestRateLimited` honoring `retryAfter`).
- **Large histories** (thousands of `goal_logs`) — batched push + token-paged pull; first sync may take a while (show progress).
- **Distributed delete vs offline device** — documented: delete wipes this device + cloud; an offline device keeps its own local copy (its user deletes it there).
- **Key-not-synced race on 2nd device** — `waitingForKeychain` state + retry; `keycheck` prevents two-key divergence.

---

## 17. Open items to confirm before/at implementation

- Settings UI: extend `privacy_settings_screen.dart` vs a dedicated `icloud_sync_screen.dart` (lean: dedicated screen for the status/errors surface).
- Whether to add `sqflite_common_ffi` (dev) now for DB-backed migration/integration tests (recommended at Step 1).
- First-sync progress UX for large datasets (spinner vs progress count).
