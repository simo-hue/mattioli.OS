# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Update for the habits to decide the day of the week to decide when it should be completed and obviously when it should appear on the day's pop up calendar view. The desktop UI element is already in place but from mobile is totally missing
- [ ] In the habits protocol tab view I want to see only the current habits and not also the past ones
- [ ] MacOS app doesn't have the log in phase, I want to have the same logic of the mobile iOS app as it's professional and complete
- [ ] Cloud mode for AI, in both mobile and desktop implementation, we need to implement the fact that they need to insert their API Keys, we can also give a possibility to add two of them so they can have a back up in case the first one is not working ( if you think it does make sense )
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] Curor of AI Coach Response
- [ ] 


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

### Auto-Verified Habits — deferred Dart follow-ups CLOSED (2026-07-14): on-device QA

- [ ] **Still deferred (intentionally, Screen Time only)**: `syncMonitoredGoals` diffing —
      not needed until `screenTimeEnabled` flips; the streak-tail cross-pass recompute is
      documented as acceptable (single-day, writes apply ascending).

## DESKTOP — ⌘K command palette on-device QA (needs your Xcode machine)
Built + `flutter analyze`-clean + unit-tested here, but no Xcode on this Mac means interaction/visual QA is
pending. Run `flutter run -d macos` and verify:
- [ ] **⌘K opens** the new palette; typing filters live (goals/habits/sections/actions grouped, goals first).
- [ ] **Arrow-key nav works while typing**: ↑/↓ move the highlight (they must NOT just move the text caret),
      ↵ activates the highlighted row, esc closes. This relies on the palette's `Shortcuts` out-ranking the
      text field's default arrow handling — the one thing I couldn't verify without running it.
- [ ] **Goal jump**: search a goal in a NON-current period → ↵ → Goals opens on that exact week/month/year and
      the row glows + scrolls into view. Test it both when starting from another section AND when already on
      the Goals page (the in-place `ref.listen` path).
- [ ] **Per-row menu**: the ⋯ button (and ⌘↵ on the highlighted row) opens Open/Complete/Reschedule/Edit/
      Delete for a goal; **Delete shows a confirmation dialog** before removing. Habits show Open/Delete.
- [ ] **Create-with-period**: type a new goal name → "Create goal “…”" → dialog is prefilled, pick an
      arbitrary year/month/week → save → it lands on that period. Repeat for "Create habit".
- [ ] **Actions**: "week 2 march"/"q2 2026"/"march" surface a Go-to-period row; toggle theme; manage
      categories; replay tour; go to this week.
- [ ] **BOTH DATA MODES**: run the above once in Cloud (Supabase) mode and once in Private mode — behaviour
      should be identical (search is in-memory; writes go through the active repository).
- [ ] **RTL**: with Arabic UI, confirm the palette + new period pickers read correctly.