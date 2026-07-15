# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Update for the habits to decide the day of the week to decide when it should be completed and obviously when it should appear on the day's pop up calendar view. The desktop UI element is already in place but from mobile is totally missing
- [ ] In the habits protocol tab view I want to see only the current habits and not also the past ones
- [ ] MacOS app doesn't have the log in phase, I want to have the same logic of the mobile iOS app as it's professional and complete
- [ ] Cloud mode for AI, in both mobile and desktop implementation, we need to implement the fact that they need to insert their API Keys, we can also give a possibility to add two of them so they can have a back up in case the first one is not working ( if you think it does make sense )
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] Curor of AI Coach Response
- [ ] From mobile implementation, in the settings the "App logs" field has to few bottom margin from the button "Go to login", I want you to increase it.
- [ ] mobile animation between lateral scroll on the goals page? Improve it


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


## Private-mode locked-DB recovery + iCloud onboarding — on-device QA (desktop + mobile)
Built + `flutter analyze`-clean + unit-tested here, but no Xcode/CloudKit on this Mac. The dead-end where
"continue privately" showed "Operazione non riuscita" is replaced by a recovery gate. To unblock the Mac Mini
you can now just enter Private mode → **Reset & start fresh** on the recovery screen (dev data is disposable),
OR delete `~/Library/Containers/com.simo.evolve/.../evolve_private_v2.db*`. Then verify on a real device:
- [ ] **Sync OFF, locked DB** → the recovery screen appears ("Can't unlock private data"), **Reset & start
      fresh** works (fresh empty DB, no crash), **Back to sign in** returns to the login page (not stranded).
- [ ] **Sync ON, locked DB** (enable iCloud sync on another device first, then lock/rotate signing) → the gate
      **auto-resets + re-pulls from iCloud** and shows the "restored from iCloud" toast — data is back, no prompt.
- [ ] **Onboarding prompt**: first time entering Private mode on an iCloud-signed-in device with sync OFF, the
      one-time "enable iCloud sync?" (E2E disclosure) prompt shows; **Not now** = stays off; **Enable** turns sync
      on. It must NOT reappear on later entries, and must NOT show when iCloud is signed out (offer later instead).
- [ ] **Startup path**: with `active_data_mode = private` persisted and a locked DB, cold-launch routes through
      the gate (not a broken empty dashboard).
- [ ] **Coherence**: confirm desktop and mobile behave identically for all of the above.
- [ ] **Signing (prevention)**: keep the `Apple Development` cert/team `8528AN28A3` present on BOTH Macs so
      `flutter run` never falls back to ad-hoc (`CODE_SIGN_IDENTITY = "-"`), which is what orphans the key.

### Follow-up fix (2026-07-15): recovery-screen crash via automatic sync — RE-VERIFY on-device
The **Back to sign in** / recovery-screen flows above were crashing on a locked DB: the automatic iCloud-sync
lifecycle (`DesktopSyncLifecycle`, which wraps the recovery screen) fired `syncNow()` on window refocus / its
15-min timer / launch and let `PrivateDatabaseLockedException` escape unhandled (`_sync()` now try/catches it).
Fixed + Dart-verified here; confirm on the actual different Mac (the one that showed the crash):
- [ ] With a locked DB, sit on the recovery screen, click away and back to the window (triggers refocus sync),
      then click **Back to sign in** → it must reach the login page with **no crash** in the `flutter run` console.