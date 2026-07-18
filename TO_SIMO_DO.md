# TO_SIMO_DO.md
## h
- [ ] Widget for iPhone & MacOS
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] Curor of AI Coach Response
- [ ] From mobile implementation, in the settings the "App logs" field has to few bottom margin from the button "Go to login", I want you to increase it.
- [ ] mobile animation between lateral scroll on the goals page? Improve it

---

### Blockers — the app is broken or unuploadable without these
- [ ] **Deploy the AI Coach proxy BEFORE submitting** (migration + `supabase secrets set OPENROUTER_API_KEY` + deploy + pin check — see the AI Coach section below). A Pro reviewer opens the coach → Standard mode → your function. If it's not live, the headline feature fails in review = rejection.
- [ ] **macOS build number**: confirm the last build you uploaded and set `desktop/pubspec.yaml version:` past it (currently `1.0.0+4`).

### Screen Time (Guideline 2.1) — NOW SHIPPING (Mode A live) — device work required
Screen Time verification is implemented and ON (`screenTimeAppsEnabled = true`); the 2.1 answer is now **yes**. This is the top risk to re-clear **on a device** before you submit — none of the native Swift has run here (no iOS SDK; FamilyControls does not run in the Simulator).
- [ ] **Register the extension App ID** in the Developer portal: `com.simo.evolve.DeviceActivityMonitorExtension` needs **Family Controls + App Groups** capabilities and its own distribution profile. The Family Controls approval is **per-App-ID** — the approved `com.simo.evolve` does NOT cover the extension. Archiving fails to sign without this.
- [ ] **App Group** `group.com.simo.evolve.verification`: confirm it exists in the portal and is enabled on BOTH App IDs (both `.entitlements` already list it).
- [ ] **`pod install`** in `mobile/ios` — Runner's deployment target was raised **15 → 16** (DeviceActivity threshold APIs need 16; `project.pbxproj` + `Podfile` already changed). Then Archive → Validate.
- [ ] **Device-verify Mode A end-to-end** (iPhone): Settings → Screen Time → enable (grant Family Controls + notifications) → create a "Time in chosen apps" habit → Choose apps → use them past the limit across several app foregrounds → confirm the localized "limit reached" notification fires and the habit logs a miss.
- [ ] **Confirm the `evolve/screentime` channel is reachable** under the SceneDelegate. CloudKit had to be re-registered in `SceneDelegate`; Screen Time is registered only in `AppDelegate.didFinishLaunching`. If the picker / auth prompt silently no-op on device, re-register the channel in `SceneDelegate` too.
- [ ] **Mode B (`screen_time_total`) is DARK** (`screenTimeTotalEnabled = false`). Flip it to true ONLY after a device test proves an empty `DeviceActivityEvent` actually fires `eventDidReachThreshold` on total usage — the exact unknown it's gated on. If it never fires, leave it off; Mode A stands alone.
- [ ] **Extension `PrivacyInfo.xcprivacy`** (new file) declares UserDefaults reason **`1C8F.1`** (App Group). Confirm it lands in the extension target's *Copy Bundle Resources*, and double-check `1C8F.1` against Apple's current "Describing use of required reason API" docs before submitting (ITMS-91053 risk if wrong).
- [ ] **Appex version** was aligned to Runner (`MARKETING_VERSION 1.1.0`, `CURRENT_PROJECT_VERSION $(FLUTTER_BUILD_NUMBER)`) — this fixed a validation blocker. Just confirm Validate is clean.

### Xcode (both apps)
- [ ] **Archive → Validate** before uploading — catches version/entitlement/signing errors before a human does.
- [ ] iOS capabilities: **Family Controls + App Groups** now required on BOTH the Runner and the extension App IDs (for Screen Time), plus HealthKit, Sign in with Apple, iCloud/CloudKit on Runner. macOS = none of HealthKit/Family Controls (correct — the Screen Time engine is iOS/iPadOS-only; the Mac app shows only a read-only "Verified" badge).
- [ ] **Run on a physical iPad** (Apple reviewed 1.1.2 on an iPad Air): the Health, paywall, and coach flows must all work there.

### App Store Connect — metadata (this is where 4 of the 6 rejections live)
- [ ] **Support URL** (1.5) → `https://simo-hue.github.io/evolve/support.html`. NOT the old root that was rejected.
- [ ] **Privacy Policy URL**, per localization → `…/evolve/privacy.html` (it), `…/evolve/en/privacy.html`, `/es/`, `/de/`, `/ar/`.
- [ ] **EULA** (3.1.2c): App Description → append `Termini di utilizzo (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`. Leave the **License Agreement** field as Apple's Standard EULA — do NOT paste a custom one.
- [ ] **App Privacy → nutrition labels → add Health** (Linked to You · App Functionality · not used for tracking). Must match `PrivacyInfo.xcprivacy`, which already declares it. Keep Email + Name. **Screen Time adds no new row**: the extension collects nothing off-device (only threshold verdicts/rules travel, same minimisation as Health), and the picked app selection never leaves the phone.
- [ ] **Reviewer Notes:** (a) 2.1 → "**Yes.** Screen Time habit verification is at **Settings → Screen Time** (tap to enable and grant access). Per-habit app selection is in the habit editor: Auto-verify → **Time in chosen apps** → **Choose apps & categories**. A screen recording of this path is attached."; (b) Health identification lives at Settings → Apple Health; (c) account deletion at Settings → Delete Account; (d) support/privacy/EULA links. **Attach a device screen recording of the Settings → Screen Time path.**

Already verified in code (no action): `screenTimeEnabled = false`; ungated coach entry (`protocollo_panel.dart:101`, 3.1.1); `NSHealthShareUsageDescription` present + no write-usage key; `PrivacyInfo` Health declared + tracking = false; legal/support URLs point at the live site; consent (5.1.2i) per-mode + revocable.

### Blocked on the implementation landing
- [ ] **Before Screen Time can ever ship, these are open (found 2026-07-17, none fixable without a device):**
  - **Nothing selects which apps to watch.** Every `DeviceActivityEvent` is built with `applications: []`, `categories: []`, `webDomains: []` (`AppDelegate.swift:638-643`), and there is **no `FamilyActivitySelection` / `FamilyActivityPicker` anywhere in the repo**. The design assumes an empty set means "all activity". I could not verify that from here and I do not believe it: the usual reading is that an event scoped to nothing never fires, which would make every Screen Time habit silently pass forever. **Settle this on device first** — it decides whether v1 needs a picker UI (a real design change from "total device usage").
  - **Nothing requests Family Controls authorization.** `requestIndividualAuthorization` is implemented natively and on the bridge but has zero production call sites. The request belongs at the Screen Time opt-in, which doesn't exist yet. (The reconcile now *checks* status and skips rather than throwing — 2026-07-17.)
  - **Register `com.simo.evolve.DeviceActivityMonitorExtension` in the developer portal** with Family Controls + the App Group, and give it a distribution profile. Your entitlement approval is per App ID: approval on `com.simo.evolve` does not cover the extension's App ID. Nothing in the repo suggests this was done. Archiving will fail to sign without it.
  - **Deployment-target split**: Runner is iOS 15.0, the extension is iOS 16.0 (`project.pbxproj`), and `syncMonitoredGoals` has no `#available` guard while `authorizationStatus` does. On iOS 15 the feature would report `notDetermined` forever and never load the extension. Decide: raise Runner to 16, or gate the Dart path on the OS version.
  - **`PrivacyInfo.xcprivacy` declares nothing for Screen Time**, and the extension bundle has no manifest at all despite reading/writing UserDefaults. The file's own recorded reasoning about Health ("declaring costs one nutrition label row; not declaring reads as concealment") applies verbatim here.

## Habit day-of-week scheduling — on-device QA (added 2026-07-17)

- [ ] **Verified (HealthKit/Screen Time) habits** with a restricted schedule only verify/nag on scheduled days (verification already maps `frequencyDays → activeWeekdays`; confirm end-to-end on device).

## Desktop "Sign in with Apple" — make native flow work (added 2026-07-18)

Code + entitlements are fixed in the repo (native flow now has the required
`com.apple.developer.applesignin` entitlement in `macos/Runner/*.entitlements`,
and `EVOLVE_DESKTOP_NATIVE_APPLE_SIGN_IN` now defaults to `true`). Remaining
**manual** steps, all on the Mac with Xcode:

- [ ] **Update your local `desktop/.env`** (gitignored, so the repo change didn't
  touch it): set `EVOLVE_DESKTOP_NATIVE_APPLE_SIGN_IN=true` (it is currently
  `false`, which overrides the new code default at compile time). Do this on
  **both** Macs. Then rebuild — a define change requires a full rebuild, not hot
  reload.
- [ ] **Supabase dashboard → Authentication → Providers → Apple:** enable the
  provider and add `com.simo.evolve` to the **authorized client IDs** list. The
  native flow verifies the Apple identity token's `aud` against this list. The
  Apple **OAuth secret / Services ID is NOT required** for native sign-in — leave
  it blank unless you also want the browser flow (Windows/Linux). This is what
  fixes the `validation_failed: missing OAuth secret` you saw in the browser.
- [ ] **Apple Developer portal:** confirm the App ID `com.simo.evolve` has the
  **Sign in with Apple** capability enabled (already true for iOS, same App ID).
  With automatic signing (team `8528AN28A3`, already set in `Runner.xcodeproj`),
  Xcode regenerates the macOS provisioning profile to include the capability on
  the next signed build. If a stale profile is cached, delete it from
  `~/Library/MobileDevice/Provisioning Profiles` or let Xcode re-fetch.
- [ ] **Verify on device:** `flutter run -d macos --dart-define-from-file=.env`,
  click "Continua con Apple" → the native macOS Apple sheet should appear (not a
  browser) and complete sign-in. If the browser opens instead, the define is
  still `false`; if the sheet appears but sign-in is rejected, the Supabase
  client-ID allowlist (step 2) is missing `com.simo.evolve`.