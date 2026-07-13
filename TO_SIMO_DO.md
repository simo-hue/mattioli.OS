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