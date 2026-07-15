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

## iCloud sync hardening (2026-07-15) — on-device QA + deferred native follow-ups
All Dart changes are `flutter analyze`-clean and unit-tested here (evolve_sync 78 green, mobile 230 green),
but no Xcode/CloudKit on this machine. The reported crash (`Using "ref" … unmounted`) was already fixed in
shipped source; this pass hardened the whole sync surface. Verify on real devices:

### On-device QA (mobile)
- [ ] **Toggle sync off while a sync is in flight, then immediately pop the iCloud Sync screen** (edge-swipe
      back) → no crash in the console (the `_refresh`/haptic ref-after-dispose class).
- [ ] **Two devices, an edit that can't apply**: force a transient apply failure (e.g. airplane-mode flap
      mid-pull) → the record is NOT lost; a later sync re-fetches and applies it (change token was held).
- [ ] **Locked-DB auto-recovery, DEFERRED enable**: enable sync on device A, then on a freshly-restored device B
      whose E2E key has synced but the canonical-owner Keychain item has NOT yet → recovery must show
      "waiting for iCloud key" (NOT a false "restored from iCloud" over an empty DB), and the real data must
      come back on a later retry once the owner propagates. The locked cache must be preserved (`.recovery-bak`),
      not destroyed.
- [ ] **Locked-DB auto-recovery, iCloud unavailable in the gap** → "can't unlock" recovery screen, data intact.
- [ ] **SyncOffBanner**: enable iCloud sync from the banner action → returning to the dashboard, the red
      "data lives only on this device" banner is GONE immediately (no app restart needed).

### Deferred native follow-ups (need an Xcode/device build — OPTIONAL hardening, not blockers)
These are in `mobile/ios/Runner/AppDelegate.swift` AND the line-for-line `desktop/macos/Runner/AppDelegate.swift`.
The Dart change-token-hold fix already prevents the *data loss* from the first two; these are defense-in-depth:
- [ ] **CKAsset temp-file lifetime** (`encodeFromRecord`, ~line 302): `asset.fileURL.path` is a CloudKit-owned
      temp path that can be purged after the fetch op is released. Copy the asset into an app-controlled file
      synchronously before returning it to Dart (and have the Dart avatar store delete that copy after reading).
- [ ] **Per-record fetch `.failure`** (`fetchChanges` `recordWasChangedBlock`, ~line 257): currently a per-record
      failure is silently dropped. At minimum `os_log` it so the drop is observable.
- [ ] **Honor CKError backoff** (`flutterError`, ~line 331): pass `(error as? CKError)?.retryAfterSeconds` in
      `FlutterError.details` and have the Dart service defer the next sync by that interval, so a rate-limit
      isn't immediately re-hit. Optionally add a small bounded native retry for transient CKErrors.

## FIX (2026-07-15 11:30) — desktop RELEASE grey screen in Private mode — VERIFY on Mac Mini
Real production ship-blocker, fixed in `desktop/lib/core/app_bootstrap.dart` (one line:
`on AssertionError` → `catch (_)` in `supabaseClientProvider`). Root cause: Private mode skips
`Supabase.initialize()`, and in a RELEASE build `Supabase.instance.client` throws
`LateInitializationError` (not `AssertionError`, because release strips asserts), which the old
narrow catch let escape → the app root crashed to a grey window for every Private-mode release user.

- [ ] **Get the fix onto the Mac Mini** (the edit is in the `/Users/simone.mattioli` working copy).
      If the Mini's repo isn't git-synced with it, apply the one-liner directly:
      in `desktop/lib/core/app_bootstrap.dart`, change `} on AssertionError {` to `} catch (_) {`.
- [ ] **Verify the grey screen is gone**: `flutter build macos --release --dart-define-from-file=.env`
      then `open build/macos/Build/Products/Release/Evolve.app` → it must now RENDER into Private mode
      (the recovery/home screen), not a blank grey window.
- [ ] **Then settle the keychain question (now unblocked)**: with the release build rendering, add a
      habit, Cmd-Q, and `open` the SAME .app again with NO rebuild → the habit must persist. If it does,
      the SQLCipher key is stable for a shipped binary (the every-launch lockout was only the
      `flutter run` re-signing loop). Signing was already verified correct (Apple Development, team
      8528AN28A3, keychain groups resolve WITH the prefix, provisioning profile embedded).
- [ ] If you want the dev `flutter run` loop to stop nagging with the reset screen, ask for the
      debug-only auto-reset (kDebugMode + macOS) — zero effect on release.

## Desktop test suite (2026-07-15) — run WITH the Supabase defines
Fixed the last hanging desktop test (`icloud_sync_card_test` "delete private data" — was a
loading-spinner `pumpAndSettle` hang; now verifies the card's contract with bounded pumps, no
product code change). The full desktop suite is **311/311 green** — but you must run it the same
way you run the app, or one intentional security guard (`desktop_supabase_config_security_test`,
which asserts the Supabase config is present via build-time defines) reports a false failure:
- [ ] Run desktop tests as: `cd desktop && flutter test --dart-define-from-file=.env`
      (a bare `flutter test` "fails" only that config-presence guard — by design, not a bug).
      Make sure CI passes the same defines.
