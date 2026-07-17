# Handoff — Implement Screen Time verification (Evolve, iOS)

Paste everything below into a fresh Claude Code session in `~/Developer/mattioli.OS`.

---

You are implementing **Screen Time habit verification** in the Evolve iOS app
(Flutter + native Swift), so it can ship in the next App Store submission. The
Family Controls **distribution entitlement is approved** and the owner wants the
feature ON. Today it is compiled out: `mobile/lib/core/verification_config.dart:23`
sets `screenTimeEnabled = false`.

**Why this matters:** Apple rejected build 1.1.2(20) under Guideline 2.1 asking
"Does the app include any Screen Time functionality? If so, identify the steps to
navigate to it." We are now answering **yes** — which means the feature must
actually work, be reachable by a clear click-path, and be demonstrable in a
screen recording on a physical device.

## Hard constraints — read first
- **You cannot compile or run the Swift here** (no Xcode/iOS SDK on this machine).
  Write native code carefully; the owner builds and tests on a real device.
- **FamilyControls / DeviceActivity does NOT work in the iOS Simulator at all** —
  authorization fails, the extension never fires. Every native behaviour claim is
  an *inference* until the owner confirms on hardware. Never state runtime
  framework behaviour as fact; label it as needs-device-verification.
- The Dart layer IS testable here (`flutter test`), and there are existing tests
  in `mobile/test/screen_time_sync_test.dart` — keep them green and add to them.
- Run `flutter analyze` in `mobile/` after every change; keep it clean.

## ⚠️ DECISION #1 — settle this BEFORE writing any code; it forks the whole design
Every `DeviceActivityEvent` is currently built with **empty** token sets —
`applications: []`, `categories: []`, `webDomains: []`
(`mobile/ios/Runner/AppDelegate.swift:638-643`). The design assumes *"empty set =
all device activity."* **This is very likely wrong** — the common reading is that
an event scoped to nothing never reaches its threshold, so every Screen Time
habit would silently pass forever. There is **no `FamilyActivitySelection` /
`FamilyActivityPicker` anywhere in the repo** (grep confirms), so there is no way
for a user to pick which apps/categories to watch.

Resolve this first, on a real device (a 2-line test app or a throwaway build):
- **If empty-set really means "all activity"** → keep the current shape; no picker
  needed; proceed to the plan below.
- **If it does not** (expected) → you must add Apple's `FamilyActivityPicker` so
  the user selects apps/categories, persist the `FamilyActivitySelection` tokens
  (they are opaque; store via the shared App Group), and pass real tokens into the
  `DeviceActivityEvent`. **This is a real product + UX change** ("total device
  usage" → "these apps") and changes the habit-creation flow. Confirm the desired
  UX with the owner before building it.

Do not skip this. Everything downstream depends on the answer.

## What already exists (do not rebuild — extend)
Native (iOS):
- `mobile/ios/Runner/AppDelegate.swift` — MethodChannel **`evolve/screentime`**
  (`:577`) with 4 methods: `authorizationStatus`, `requestIndividualAuthorization`,
  `syncMonitoredGoals` (`:619`, the `stopMonitoring()`+`startMonitoring` loop at
  `:624`/`:644`), `drainSignals`. Results flow back via the App Group, not a push.
- `mobile/ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift`
  — the monitor callbacks; posts a local notification with **hardcoded English**
  strings (`:49-50`); writes threshold signals to App Group
  `group.com.simo.evolve.verification`, key `pending_screen_time_signals` (`:24-25`).
- Entitlements: `Runner.entitlements` and the extension's `.entitlements` both
  declare `family-controls`, `family-controls.app-and-website-usage`, and the App
  Group. The extension IS embedded in the build (Runner "Embed Foundation
  Extensions" phase).

Dart:
- `packages/evolve_verification/lib/src/screen_time_bridge.dart` — the
  `ScreenTimeBridge` interface + `ScreenTimeGoalSpec` (goalId, thresholdMinutes,
  activeWeekdays) + `ScreenTimeAuthorizationStatus` enum + a fake in `testing/`.
- `mobile/lib/core/method_channel_screen_time_bridge.dart` — the real bridge over
  the `evolve/screentime` channel. **Method names + arg keys must match the Swift
  side exactly** — a mismatch is a silent runtime failure no test catches.
- `mobile/lib/core/verification_wiring.dart` — `syncScreenTimeMonitoring` (`:189`)
  already: diffs against a per-process cache (skips re-sync when unchanged),
  **checks authorization and skips (never requests) if not approved** (`:213`),
  and syncs an empty list so deleting the last habit stops monitoring. Reconcile
  runs on foreground (`:379`). `screenTimeSpecsFrom` (`:110`) builds the specs.
- `mobile/lib/core/verification_config.dart` — the `screenTimeEnabled` flag (`:23`)
  and `enabled = healthKitEnabled || screenTimeEnabled` (`:27`).
- `mobile/lib/ui/widgets/habit_management_modal.dart:213` — the Screen Time habit
  option, gated on `screenTimeEnabled`, inside the habit create/edit modal behind
  an "Auto-verify" toggle (default OFF).
- Tests: `mobile/test/screen_time_sync_test.dart` (the reconcile/diff/auth logic).

## The open work (ordered)
Only after Decision #1 is settled:

1. **Authorization request has no call site.** `requestIndividualAuthorization`
   exists but nothing production calls it (grep confirms). Add a Screen Time
   **opt-in** where the user turns on Screen Time auto-verify — request
   authorization there (a system prompt fired from a background reconcile is wrong;
   the reconcile deliberately only *checks*). Show a clear denied/undetermined
   state.

2. **Navigation / Guideline 2.1 answer.** Apple wants a click-path. The option is
   currently 2+ levels deep in the habit modal behind a default-off toggle — the
   same burial depth Apple rejected for HealthKit under 2.5.1. Mirror the HealthKit
   remedy: add a **Settings → Screen Time** section (see
   `mobile/lib/ui/widgets/apple_health_form.dart` and the "Apple Health" section in
   `mobile/lib/ui/screens/app_settings_screen.dart` for the pattern). This both
   answers 2.1 and gives the reviewer a screen-recordable path.

3. **iOS 15 vs 16 deployment split.** Runner targets iOS **15.0**, the extension
   **16.0** (`project.pbxproj`; DeviceActivity threshold APIs need 16). Native
   `syncMonitoredGoals` has **no `#available` guard** while `authorizationStatus`
   does. On iOS 15 the feature would report `notDetermined` forever and the
   extension can never load. Decide: **raise Runner to iOS 16**, or gate the whole
   Dart Screen Time path on the OS version (and hide the UI below 16). Raising to
   16 is simpler and cleaner if the owner accepts dropping iOS 15.

4. **Extension App ID registration (owner, in the Apple Developer portal).** The
   Family Controls approval is per-App-ID. `com.simo.evolve` is approved;
   `com.simo.evolve.DeviceActivityMonitorExtension` is a **separate** App ID that
   must be registered with Family Controls + the App Group and get its own
   distribution profile, or archiving fails to sign. Flag this to the owner; you
   cannot do it from here.

5. **Localise the extension notification.** `:49-50` are hardcoded English in a
   5-language app. An extension cannot read Flutter's slang translations — use
   `NSLocalizedString` with the extension's own `.lproj` bundles, or write the
   localized strings into the shared App Group from the app for the extension to
   read. Also: the notification posts with **no permission check** — the app only
   requests notification permission from unrelated reminder toggles, so a reviewer
   may get no visible artifact. Request/verify notification authorization on the
   Screen Time opt-in.

6. **20-activity cap.** Apple caps `DeviceActivityCenter` at 20 simultaneous
   activities. `startMonitoring` runs in an unguarded loop (`:632-660`). Pre-check
   the count and surface the typed `monitor_limit` error to the user (the Dart
   `ScreenTimeMonitorLimitException` mapping exists but the sole caller currently
   only logs — wire it to real UI).

7. **PrivacyInfo manifest.** `mobile/ios/Runner/PrivacyInfo.xcprivacy` declares
   nothing for Screen Time, and the extension bundle has no manifest at all despite
   reading/writing UserDefaults. Add the appropriate declarations (mirror how
   Health is declared there). Then the **App Store Connect nutrition labels** must
   match.

8. **Flip the flag** `screenTimeEnabled = true` (`verification_config.dart:23`) —
   LAST, only once 1–7 are done and the owner has confirmed the on-device behaviour.

## Note on the accumulation concern
A prior session added the diff-cache so the foreground reconcile does NOT
stop/restart monitoring when the goal set is unchanged (`syncScreenTimeMonitoring`,
in-memory cache, order-independent). Whether the native `stopMonitoring()` +
`startMonitoring()` resets DeviceActivity's accumulated usage counters mid-interval
is **unverifiable without a device** — do not claim it either way; have the owner
watch a real threshold cross after several app foregrounds.

## Definition of done
- Decision #1 settled on-device and the design matches it.
- A user can enable Screen Time auto-verify from Settings, grant authorization, and
  a habit verifies against real usage on a physical device (real elapsed time, real
  threshold cross).
- `flutter analyze` clean; `flutter test` green (extend `screen_time_sync_test.dart`
  and any new pure logic).
- Extension notification localised and permission-gated.
- Owner registers the extension App ID; PrivacyInfo + App Store nutrition labels
  updated; the 2.1 reviewer note now says **yes** with the exact click-path, plus a
  device screen recording.

## Reference in the repo
- `TO_SIMO_DO.md` → "Blocked on the implementation landing" (the open Screen Time
  items) and the "PRE-SUBMISSION CHECKLIST".
- `DOCUMENTATION.md` → search "Screen Time" for the 2026-07-17 survey findings and
  the two reconcile bugs already fixed.
- Do NOT remove the Family Controls entitlement/extension (the pre-submission
  checklist's alternative path) — the owner has chosen to ship the feature instead.
