# iCloud Sync & Privacy Mode — Bug Report

**Scope:** iOS iCloud (CloudKit) sync + Private/Privacy mode only. Other areas of the app were not audited.
**Audited:** 2026-06-26
**Reviewer:** automated code audit (read-only). Two of the critical findings were reproduced with `sqlite3` (see notes).

This document is written for a follow-up agent that will fix the bugs. Each finding has: location, severity, what's wrong, how it manifests, and a concrete recommended fix. Findings are ordered by severity. **Read CRITICAL/HIGH first — #1 and #2 each cause total, cross-device data loss and #3 makes sync non-functional on device.**

---

## Fix status (updated 2026-06-26)

All 11 findings have been addressed. Code fixes landed on branch `fix/icloud-sync-privacy-bugs`.

| # | Severity | Status | Notes |
|---|----------|--------|-------|
| #1 | CRITICAL | ✅ Fixed | `applyUpsert` now writes with FK enforcement OFF (option B), so REPLACE can't cascade-delete children. Regression test added. |
| #2 | HIGH | ✅ Fixed | New `PrivateLocalDatabase.adoptOwner` + `ownerWriter` wired into the sync service; second device persists the canonical owner after re-key. Test added. |
| #3 | HIGH | ✅ Fixed | `SceneDelegate` now registers `CloudKitSyncBridge`; Dart bridge degrades to `couldNotDetermine`/no-op on `MissingPluginException`. **Requires on-device verification.** |
| #4 | HIGH | ✅ Fixed | Native `savePolicy = .allKeys` + engine reordered to **pull-then-push** so a stale local edit never clobbers a newer cloud record. Tests updated. |
| #5 | MEDIUM | ✅ Fixed | In-flight `Future` lock (`_runExclusive`) serializes `enable`/`syncNow`/`disable`/`requestFullReset`. Test added. |
| #6 | MEDIUM | ✅ Fixed | `deleteAllPrivateData` now clears `sync_state` and resets the token/last-sync. Contract test added. |
| #7 | MEDIUM | ✅ Fixed | Same change as #6 **preserves `pending_zone_wipe`** so a queued offline wipe still runs. |
| #8 | MEDIUM/LOW | ✅ Fixed | `avatar_url` stripped from the push payload and the local value preserved on apply (`PrivateDbSchema.localOnlyColumns`). Test added. |
| #9 | LOW | ✅ Fixed | Future-skewed records are **deferred, not dropped** — the change token is held at its pre-fetch value until the record is no longer skewed. Test added. |
| #10 | LOW | 📌 Documented | Accepted known limitation — see below. |
| #11 | LOW | 📌 Documented | Accepted known limitation — see below. |
| identity-edge | LOW | 📌 Documented | Residual true-concurrent-edit window from the #4 LWW model — see below. |

See **Known limitations (accepted)** near the end for #10, #11, and the identity-edge case.

---

## Severity legend
- **CRITICAL** — silent data loss / corruption of user data.
- **HIGH** — feature is broken or unusable; or a strong correctness failure.
- **MEDIUM** — wrong behavior in a realistic scenario, but recoverable.
- **LOW** — edge case, cosmetic, or hardening.

---

## #1 — CRITICAL — Applying a pulled parent record cascade-deletes all its children (full account wipe)

**Files:**
- `lib/core/sync_local_store.dart` → `applyUpsert()` (uses `ConflictAlgorithm.replace`)
- `lib/core/private_local_database.dart` → `_open()` `onConfigure` sets `PRAGMA foreign_keys = ON`
- `lib/core/private_db_schema.dart` → all child tables declare `... REFERENCES profiles(id) ON DELETE CASCADE` (and `goal_logs` also `REFERENCES goals(id) ON DELETE CASCADE`), plus the `*_sync_ad` DELETE triggers.

**What's wrong:**
`applyUpsert` writes pulled rows with `ConflictAlgorithm.replace` (= `INSERT OR REPLACE`). In SQLite, when the primary key already exists, `INSERT OR REPLACE` **deletes the existing row first, then inserts**. With `foreign_keys = ON` (set in `onConfigure`), that delete triggers `ON DELETE CASCADE` on every child table.

Because `_ensureProfile` always creates a local `profiles` row, *every* pulled `profiles` record hits the REPLACE-deletes-existing path → it cascade-deletes **all** of the user's `goals`, `goal_logs`, `long_term_goals`, `daily_moods`, `macro_goal_categories`, and `goal_category_settings`. The same applies to a pulled `goals` record wiping that goal's `goal_logs`.

**Blast radius (verified with sqlite3):**
1. Cascade delete removes children that were **not** part of the current pull batch (steady-state data).
2. The cascade delete **fires the `*_sync_ad` DELETE triggers** → writes a tombstone (`dirty=1, deleted=1`) into `sync_state` for every cascaded child. (Confirmed this fires even with `recursive_triggers` OFF, which is the default.)
3. `applyUpsert` only clears `dirty` for the single `profiles` record being applied — the child tombstones stay dirty.
4. Next `_push` uploads those tombstones → **deletes the records from the CloudKit zone**.
5. Other devices pull the tombstones → delete locally too.

**Manifestation:** Two devices in steady state. User edits their profile (e.g. display name) on device A → push. Device B resumes → pulls `profiles` (newer) → `applyUpsert` REPLACE → **device B's entire local dataset is cascade-deleted**, child tombstones are queued, and on B's next push the whole account is deleted from the cloud and then from device A. A single profile edit ⇒ total account wipe across all devices.

**Reproduction (minimal, confirmed):**
```sql
PRAGMA foreign_keys = ON;
CREATE TABLE profiles (id TEXT PRIMARY KEY, name TEXT);
CREATE TABLE goals (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, title TEXT);
INSERT INTO profiles VALUES ('o1','old');
INSERT INTO goals VALUES ('g1','o1','G');
INSERT OR REPLACE INTO profiles (id,name) VALUES ('o1','new');  -- simulates applyUpsert
SELECT count(*) FROM goals;   -- => 0  (cascade-wiped)
```

**Recommended fix (pick one, prefer A):**
- **A. Make `applyUpsert` a true upsert that never deletes the parent.** Replace the `INSERT ... ConflictAlgorithm.replace` with an explicit "UPDATE; if 0 rows changed, INSERT" within the existing transaction, or raw `INSERT ... ON CONFLICT(id) DO UPDATE SET ...`. An `ON CONFLICT DO UPDATE` does **not** delete the row, so no cascade fires. (Be sure to still clear `dirty` in the same txn as today.)
- **B.** Disable foreign keys for the duration of the apply transaction (`PRAGMA foreign_keys = OFF` outside the txn, like `reKeyOwner` already does) — weaker, leaves a window where integrity isn't enforced and still does delete+insert; only acceptable if A is impractical.
- After fixing, add a regression test: insert parent+children, run `applyUpsert` on the parent, assert children still present and `sync_state` has **no** new child tombstones.

---

## #2 — HIGH — Second device sees NO data after enabling sync (owner-id mismatch after re-key)

**Files:**
- `lib/core/sync_local_store.dart` → `reKeyOwner()`
- `lib/core/private_local_database.dart` → `ownerId()` (reads device-local `private_mode_owner_id_v1`) and all `loadXxx()` queries that filter `where: 'user_id = ?'` with `ownerId()`
- `lib/core/sync_key_store.dart` → canonical owner stored separately under `private_sync_owner_v1` (iCloud-synced)

**What's wrong:**
On a second device, `SyncEngine.enable()` adopts the canonical owner (device A's id) and calls `store.reKeyOwner(localOwnerB, canonicalA)`, which rewrites every row's `user_id` and `profiles.id` to `canonicalA`. **But the device's own owner id (`PrivateLocalDatabase.ownerId()` → device-local keychain key `private_mode_owner_id_v1`) is never updated.** It still returns `localOwnerB`.

Every data query (`loadGoals`, `loadMacroGoals`, `loadDailyMoods`, `loadProfileRow`, …) filters by `ownerId()` = `localOwnerB`, but all rows are now keyed to `canonicalA`.

**Manifestation:** Immediately after enabling sync on the second device, the user's goals/moods/categories all disappear from the UI (queries match nothing). Worse, `loadProfileRow()` finds no row for `localOwnerB` and calls `_ensureProfile`, which **inserts a second `profiles` row** with id `localOwnerB` — creating a duplicate profile and a new dirty `profiles:localOwnerB` record that then syncs out.

**Recommended fix:**
After a successful `reKeyOwner`, persist the canonical owner as this device's owner id: write `private_mode_owner_id_v1 = canonicalOwner` (via `SecureStorageUtils.writeDeviceLocal`) and update the in-memory `_ownerId` cache. The cleanest place is to have `enable()` / the sync service write the canonical owner back into `PrivateLocalDatabase` after `reKeyOwner` (e.g. add a `setOwnerId(canonical)` method on the store/db and call it). Add a test: enable on a device whose local owner ≠ canonical, then assert `ownerId() == canonical` and `loadGoals()` returns the re-keyed rows.

---

## #3 — HIGH — CloudKit MethodChannel is never registered under the Scene lifecycle (sync entirely dead on device)

**Files:**
- `ios/Runner/AppDelegate.swift` → `didFinishLaunchingWithOptions` registers `CloudKitSyncBridge.register(controller)` **only inside** `if let controller = window?.rootViewController as? FlutterViewController`
- `ios/Runner/SceneDelegate.swift` → `scene(willConnectTo:)` registers **only** `registerPrivateStorageChannel`, **not** `CloudKitSyncBridge.register`
- `ios/Runner/Info.plist` → declares `UIApplicationSceneManifest` with `UISceneDelegateClassName = $(PRODUCT_MODULE_NAME).SceneDelegate`

**What's wrong:**
The app uses the UIScene lifecycle (Info.plist has a scene manifest pointing at `SceneDelegate`). Under scene-based lifecycle, `window` / `window?.rootViewController` is **nil** in `AppDelegate.didFinishLaunchingWithOptions` (the window is created by the scene delegate). So the `if let controller = window?.rootViewController` block in `AppDelegate` does not execute, and `CloudKitSyncBridge.register` is never called there.

`SceneDelegate.scene(willConnectTo:)` *does* register the private-storage channel but **omits the CloudKit channel**. Result: the `evolve/cloudkit` channel handler is never installed → every CloudKit call from Dart (`accountStatus`, `ensureZone`, `saveRecords`, `fetchChanges`, …) throws `MissingPluginException`. iCloud sync silently never works on a real (scene-based) launch.

(Note: the Dart side calls `channel.invokeMethod` without catching `MissingPluginException`, so `accountStatus()` etc. will throw; the UI's `_runAction` swallows it and the user just sees sync "not working" with no obvious cause.)

**Recommended fix:**
Register the CloudKit channel in the scene path alongside the private-storage channel:
```swift
// SceneDelegate.swift, inside scene(willConnectTo:)
if let controller = window?.rootViewController as? FlutterViewController {
  AppDelegate.registerPrivateStorageChannel(controller)
  CloudKitSyncBridge.register(controller)   // <-- add this
}
```
Verify on a device/simulator that `accountStatus` returns a real value (no `MissingPluginException`). Consider also defensively catching `MissingPluginException` on the Dart side in `MethodChannelCloudKitBridge` so a missing handler degrades to "unavailable" rather than throwing.

---

## #4 — HIGH — Updates to already-synced records never propagate (`.ifServerRecordUnchanged` + change-tag-less records)

**Files:**
- `ios/Runner/AppDelegate.swift` → `saveRecords()` sets `op.savePolicy = .ifServerRecordUnchanged`; `encodeToRecord()` builds a **fresh** `CKRecord` every push with no system fields / change tag
- `lib/core/sync_engine.dart` → `_push()` (leaves conflicted records dirty, relies on pull to resolve) and `_applyRemote()` (LWW)

**What's wrong:**
`saveRecords` builds a brand-new `CKRecord` from the payload on every push, so the record never carries the server's `recordChangeTag`. With `savePolicy = .ifServerRecordUnchanged`, CloudKit rejects a save whose change tag doesn't match the server's. For a record that already exists on the server, a freshly-minted record has a nil tag ⇒ **`serverRecordChanged` conflict every time**.

The engine's design says conflicts are "intentionally left dirty; the pull resolves them via LWW." But when the **local** edit is the newer one (the normal case — the user just edited it), the pull fetches the server's *older* copy, `_applyRemote` skips it (`rec.updatedAtMs <= localMs`), and `dirty` is never cleared. The record stays dirty forever and re-conflicts on every sync. **The local edit never reaches the cloud.**

**Manifestation:** First creation of a record syncs (no server record yet). Any subsequent **edit** to that record (rename a goal, change a category color, update profile, re-log a habit for the same day) never propagates to other devices. Sync appears to "work once then stop" per record.

**Recommended fix:**
The Dart engine already performs authoritative client-side LWW, so server-side change-tag gating is redundant and harmful here. Change the save policy to overwrite:
```swift
op.savePolicy = .allKeys   // client already decided the winner via updatedAt LWW
```
(Optionally drop the now-unused conflict plumbing, or keep it but ensure conflicted records aren't left permanently dirty.) If you instead want to keep `.ifServerRecordUnchanged`, you must cache and re-send each record's CloudKit system fields (`encodeSystemFields`) so the change tag matches — significantly more work. **`.allKeys` is the recommended minimal fix.** Add a test/manual check: create a goal, sync, edit it, sync, confirm the edit lands on the second device.

---

## #5 — MEDIUM — No concurrency guard around `syncNow` (resume sync races manual sync / double resume)

**Files:** `lib/main.dart` → `_syncOnResume()` (fires on every `resumed`); `lib/ui/screens/icloud_sync_screen.dart` → `_runAction(... syncNow())`; `lib/core/cloudkit_private_sync_service.dart` → `syncNow()`/`enable()`

**What's wrong:**
Nothing serializes sync runs. A foreground-resume sync can overlap with a user-tapped "Sync now", or two rapid `resumed` events can overlap. Two concurrent `SyncEngine.syncNow` runs share the same `sync_meta.server_change_token` and the same dirty set, and both call `fetchChanges` / `setChangeToken`. Interleaving can advance the change token past records the other run hasn't applied (records silently skipped on both), or double-apply a batch.

**Manifestation:** Occasional missing pulled changes or duplicated work after rapid foreground/background transitions; hard to reproduce deterministically.

**Recommended fix:** Add a simple in-process mutex / "sync in flight" guard in `CloudKitPrivateSyncService` (e.g. hold a `Future?` and return/await it if a sync is already running, or use a lock). Ensure `enable`, `syncNow`, and `requestFullReset` all serialize through it.

---

## #6 — MEDIUM — `deleteAllPrivateData` never clears `sync_state` / `sync_meta` (stale tombstones leak into a later re-enable)

**Files:** `lib/core/private_local_database.dart` → `deleteAllPrivateData()`; `lib/ui/screens/privacy_settings_screen.dart` → `_resetData()`

**What's wrong:**
`deleteAllPrivateData` deletes the domain rows (firing DELETE triggers that write tombstones into `sync_state`) and re-creates a profile, but it never clears `sync_state` or resets `sync_meta`. After a "delete private data":
- `sync_state` is full of `dirty=1, deleted=1` tombstones for the wiped rows, plus fresh dirty rows for the re-created profile/category-settings.
- These persist (the reset's zone wipe only clears `pending_zone_wipe` and the change token, not `sync_state`).

If the user later re-enables sync, `enable()` → `markAllDirty()` re-marks only the *existing* rows, but the orphaned tombstones remain dirty and get pushed as deletes for records that no longer exist — noisy errors, and a risk of deleting freshly-recreated cloud records depending on timing.

**Recommended fix:** In `deleteAllPrivateData`, within the same transaction, also `DELETE FROM sync_state` and reset `sync_meta` (`server_change_token = NULL`, `last_full_sync_at = NULL`; leave/handle `pending_zone_wipe` carefully so a queued reset isn't lost — coordinate ordering with `requestFullReset`, which writes `pending_zone_wipe` *before* this runs). Re-creating the profile after clearing `sync_state` will re-mark it dirty via the trigger, which is fine.

---

## #7 — MEDIUM — `requestFullReset` ordering vs. local wipe leaves the queued-wipe flag in a table that survives, but tombstones never reconcile

**Files:** `lib/core/cloudkit_private_sync_service.dart` → `requestFullReset()`; `lib/ui/screens/privacy_settings_screen.dart` → `_resetData()`

**What's wrong / to verify:**
`_resetData` calls `requestFullReset()` (sets `pending_zone_wipe`, deletes keys, attempts cloud wipe) and *then* `deleteAllPrivateData()`. If the device is **offline** during reset:
- The zone wipe stays queued (`pending_zone_wipe=1`) — good, it's in `sync_meta` which `deleteAllPrivateData` doesn't currently clear.
- But the keys are already deleted (`keys.deleteAll()`), and `deleteAllPrivateData` then repopulates `sync_state` with tombstones. A later `syncNow` will run the queued wipe (which doesn't need the key) — OK — but the leftover tombstones from #6 remain.

This finding overlaps #6; the fix for #6 must be coordinated with the `pending_zone_wipe` flag so the queued wipe is **not** lost when `sync_state`/`sync_meta` are cleared. Recommend: clear `sync_state` and the token/last-sync in `deleteAllPrivateData`, but preserve `pending_zone_wipe`. Add a test covering "reset while offline → reopen online → zone actually wiped and no stale tombstones pushed."

---

## #8 — MEDIUM/LOW — `avatar_url` (a device-local file path) is synced verbatim to other devices

**Files:** `lib/core/private_db_schema.dart` (`profiles.avatar_url`), `lib/core/sync_engine.dart` `_push`/`_applyRemote` (whole-row payload), `lib/core/private_local_database.dart` `updateProfile`

**What's wrong:**
The `profiles` row is encrypted and synced as-is, including `avatar_url`, which is an absolute on-device file path (e.g. under `getApplicationSupportDirectory()/private_profile/...`). That path is meaningless on another device, and the avatar file itself is never synced (the CKAsset/`assetPath` path in `CloudKitBridge`/`CloudRecord` exists but the engine never populates it). The receiving device stores a dangling path → broken/missing avatar, possibly a broken-image state in the UI.

**Recommended fix:** Either (a) exclude `avatar_url` from the synced payload (strip it in `_push` / restore the local value in `_applyUpsert`), or (b) actually sync the avatar as a CKAsset and rewrite the path on apply. Short term, (a) avoids the dangling-path bug. Note this in the avatar/asset "later step" work.

---

## #9 — LOW — Clock-skew-rejected records are dropped permanently (change token advances past them)

**File:** `lib/core/sync_engine.dart` → `_pull()` + `_applyRemote()`

**What's wrong:** `_pull` fetches all changed records, then unconditionally `setChangeToken(token)` after the apply loop. A record rejected by the future-skew guard (`rec.updatedAtMs > now + 5min`, returns false/skipped) is counted as `skipped` but the token still advances past it, so it is **never re-fetched** even after the clock corrects. A legitimately slightly-future record (device clock skew > 5 min) is lost.

**Recommended fix:** This is an edge case; options: widen/remove the skew guard for pulls (the LWW comparator already handles ordering), or don't advance the token past skipped-future records (harder with CloudKit's opaque token). At minimum, document the trade-off. Low priority.

---

## #10 — LOW — Cross-schema-version apply can silently drop records

**File:** `lib/core/sync_local_store.dart` → `applyUpsert` (catches exceptions in `_applyRemote`, marks error, skips)

**What's wrong:** If two devices run different schema versions (e.g. one before, one after a future migration), a pulled row may contain a column the local table doesn't have → the insert throws → `_applyRemote` catches, `markError`, and skips. The record is counted as skipped and (per #9) the token may advance past it, so it isn't retried after the lagging device upgrades. Acceptable for now (both clients ship together) but worth a guard/migration-gating note before adding columns to synced tables.

---

## #11 — LOW — Multi-device "delete private data" only wipes the originating device's cloud copy

**Files:** `lib/core/cloudkit_private_sync_service.dart` `requestFullReset`, `ios/Runner/AppDelegate.swift` `deleteZone`

**What's wrong (design limitation, document it):** `requestFullReset` deletes the CloudKit zone and the shared keys from *this* device's iCloud Keychain. Another signed-in device that still has sync enabled and local data will, on its next sync, `ensureZone` (recreating the zone) and re-upload everything — effectively resurrecting the "deleted" data in the cloud. The keychain key deletion also propagates via iCloud Keychain, which can leave the other device unable to decrypt/sync. This is an inherent multi-device wipe limitation; at minimum surface it in the disclosure copy ("delete on each device") and confirm the intended behavior.

---

## Known limitations (accepted)

These three are **deliberately not code-fixed** — they are edge cases or inherent design trade-offs. Documented here so a future change is made with eyes open.

### #10 — Cross-schema-version apply can silently drop records
**Status: accepted.** Both clients ship together today, so a pulled row never contains a column the local table lacks. The guard already in place: `_applyRemote` catches the insert exception, calls `markError`, and skips the record. With the #9 fix the change token is **not** advanced past a record that throws only if it was future-skewed; a schema-mismatch row still advances the token (it's an apply error, not a skew defer), so it would not be retried after the lagging device upgrades.
**Trip-wire for the future:** before ever adding a column to a synced table (`PrivateDbSchema.syncedTables`) in a release that can run side-by-side with an older one, gate the apply on schema version (or make unknown columns non-fatal — filter the payload to known columns before `applyUpsert`). Until then this cannot fire.

### #11 — Multi-device "delete private data" only wipes the originating device's cloud copy
**Status: accepted design limitation.** `requestFullReset` deletes the CloudKit zone + the shared keys from *this* device's iCloud Keychain. Another signed-in device that still has sync enabled will, on its next sync, `ensureZone` (recreating the zone) and re-upload its local data — resurrecting the "deleted" cloud data. Truly wiping every device would require a server-side tombstone/epoch that all devices honor, which is out of scope.
**Mitigation (product, not code):** the reset disclosure copy must tell the user to run "delete private data" on **each** device. Confirm the settings/disclosure UI says this before release.

### identity-edge — Residual true-concurrent-edit window under `.allKeys` LWW
**Status: accepted.** The #4 fix (pull-then-push + `.allKeys`) makes last-write-wins correct for **sequential** edits: pulling first overwrites a stale local copy and clears its dirty flag, so an older edit is never pushed over a newer cloud record. The residual gap is only a **true simultaneous edit**: devices A and B both edit the same record in the same sync window, each having pulled before the other pushed. With `.allKeys` (no server-side change-tag gate) the **last push to land wins by wall-clock arrival**, not by `updatedAt`. For a single user across their own devices this window is vanishingly small and self-heals on the next sync (both converge to one value); no data is lost beyond the losing edit. Closing it fully would require server-side conditional writes (re-sending CloudKit system fields / change tags), which #4 explicitly traded away to make edits propagate at all.

---

## Notes for the fixer
- **Order of work:** fix **#1** and **#2** before anything else (both cause data loss / unusable second device), then **#3** (without it nothing syncs on device) and **#4** (without it edits don't propagate). #5–#11 are correctness/hardening.
- **#1 and #4 interact:** once #4 is fixed (`.allKeys`), genuinely-newer remote records will start being applied via `applyUpsert` more often — which makes the #1 cascade bug fire more frequently. Fix #1 first or together.
- The Private/Privacy-mode no-network guarantees (mode-gated providers, `PrivacyUtils` sanitization, device-local DB password, backup exclusion) looked sound and are **not** flagged here. The bugs above are all in the iCloud sync layer and its interaction with the local store.
- Suggested regression tests live alongside `test/` (the engine/store are already designed for in-memory FFI testing): add cases for (a) parent-apply-preserves-children, (b) second-device enable owner reconciliation, (c) edit-propagates-after-first-sync.
