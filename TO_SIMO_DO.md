# TO_SIMO_DO.md
- [ ] Local AI Models ( Ollama for desktop? Other solutions? For mobile what can we do? )


## DESKTOP + MOBILE — iCloud sync cross-platform (needs your Xcode machine)

### 2. CloudKit Console (before ANY release with avatars)
- [ ] In the `iCloud.com.simo.evolve` container: verify record type
      `PrivateRecord` exists with fields `tableName(String)`, `updatedAt(Int64)`,
      `deleted(Int64)`, `payload(Bytes)` **and `asset(Asset)`** in **Development**
      (a dev-build sync with an avatar creates it automatically), then
      **Deploy Schema Changes → Production**. The `asset` field is NEW in this
      release — without promoting it, avatar sync fails in Production.

- [ ] Widget for iPhone & MacOS

## Auto-Verified Habits — Xcode setup (feature is dark behind `VerificationConfig.enabled`)

Native code is written but UNVERIFIED (no iOS SDK on the dev machine — compile in Xcode).
The app-side bridges now live INSIDE `mobile/ios/Runner/AppDelegate.swift` (like
CloudKitSyncBridge), so **no files need adding to the Runner target**. Steps:

- [ ] Runner target → Signing & Capabilities: add **HealthKit** + **Family Controls** capabilities.
- [ ] Add `NSHealthShareUsageDescription` to the Runner Info.plist (read-only; specific text).
- [ ] Create the **DeviceActivityMonitor** app-extension target (iOS 16+); add ONLY
      `mobile/ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` to it
      (it's self-contained). Its Info.plist: `NSExtensionPointIdentifier =
      com.apple.deviceactivity.monitor-extension`, `NSExtensionPrincipalClass =
      $(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension`. Enable Family Controls on it too.
- [ ] Create an **App Group** and add it to BOTH Runner + the extension. Set its id in TWO
      places (must match): `VerificationAppGroup.suiteName` in `AppDelegate.swift` and
      `AppGroup.suiteName` in the extension (currently `group.com.simo.evolve.verification`).
- [ ] Request the **Family Controls DISTRIBUTION entitlement** (one per bundle id: Runner +
      extension) — needed even for TestFlight; ~2–4 wk Apple approval. File early.
- [ ] Apply `migrations/20260713_add_goal_verification_columns.sql` to Supabase.
- [ ] Once it builds on device + entitlement approved: flip `VerificationConfig.enabled = true`
      in `mobile/lib/core/verification_config.dart` (HealthKit can go before Screen Time).

### Auto-Verified Habits — deferred Dart follow-ups CLOSED (2026-07-14): on-device QA

All the deferred Dart follow-ups are now implemented + tested (see DOCUMENTATION.md
2026-07-14 entries). Nothing here blocks the build; these are on-device eyeball checks
for when you run the HealthKit build (`VerificationConfig.healthKitEnabled` is already true):

- [ ] **Couldn't-verify "?"**: a HealthKit goal that can't be verified shows a "?" corner
      badge on the calendar day + a "?" row in the day-details sheet; tapping it on
      today/yesterday resolves the day by hand (older days respect the existing edit window).
- [ ] **Notification toggles**: Settings → Notifications now has a "HABIT VERIFICATION"
      section (nudges ON by default; celebration + missed-habit summary OFF/opt-in). Toggle
      each and confirm the notifications fire/stop as expected.
- [ ] **Translations review (optional)**: the verification strings were added to all 5
      locales; the **Arabic** copy is machine-authored MSA (and the "≥ N unit label" summary
      is assembled LTR) — worth a native eyeball for the ar locale + RTL layout. Keys live
      under `verification.*` and `notifications.verification*` in `mobile/lib/i18n/*.i18n.json`.
- [ ] **Still deferred (intentionally, Screen Time only)**: `syncMonitoredGoals` diffing —
      not needed until `screenTimeEnabled` flips; the streak-tail cross-pass recompute is
      documented as acceptable (single-day, writes apply ascending).

## Habit-log data-loss hardening (2026-07-13) — manual items

Code fixes are done + tested (see DOCUMENTATION.md). These need YOU:

- [ ] **iOS build/QA (no Xcode here)**: compile + run on device, then verify the fixes:
      (1) in Private mode, add a habit and log a few days → **edit** the habit (rename/color)
      → logs must **survive** (this was the main bug); (2) **drag-reorder** habits → all
      histories survive; (3) Import dialog now defaults to **Merge**, and choosing
      **Replace** shows a second "Delete & Replace" confirmation with a live count;
      (4) a Private-mode user with iCloud sync OFF sees the red "sync is off" banner on the
      dashboard.
- [ ] **Supabase config — `db-max-rows`**: confirm the project's PostgREST `db-max-rows` is
      **≥ 1000**. The `goal_logs` sync pages in 1000-row slices and (intentionally) stops on
      the first short page; if an admin lowered the cap below 1000, long histories would
      silently truncate. If you must lower it, also lower `kGoalLogsSyncPageSize`
      (`mobile/lib/providers/goal_provider.dart`) below the cap.
- [ ] **Already-lost data (cloud accounts)**: if any account was emptied by the OLD
      delete-then-upsert replace-import, check whether Supabase **point-in-time recovery /
      backups** can restore `goal_logs` for that user (server-side, owner-only — I can't do
      this). The new import order can't cause this going forward.
- [ ] **Already-lost data (private mode)**: logs destroyed by the OLD cascade bug are gone
      and can't be recovered in-app (the rows were DELETEd, and with sync on, tombstoned to
      iCloud). If an affected user has an **export file**, import it in **Merge** mode (never
      Replace) to restore. The new owner self-heal *does* auto-recover data that was merely
      *orphaned* (owner-id regeneration / interrupted second-device sync) on next launch —
      no action needed for that class.
- [ ] **Encourage backups**: the private DB is excluded from device backups and its key is
      device-only, so a new phone / erase-restore loses everything unless iCloud sync is on.
      The new dashboard banner nudges this; consider prompting an export before risky ops.