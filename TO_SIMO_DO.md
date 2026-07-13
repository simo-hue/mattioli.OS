# TO_SIMO_DO.md
- [ ] Local AI Models ( Ollama for desktop? Other solutions? For mobile what can we do? )


## DESKTOP + MOBILE — iCloud sync cross-platform (needs your Xcode machine)

All code is done and committed (see `desktop/ICLOUD_SYNC_PLAN.md` §3b). The steps
below are the Apple-side setup and device QA that cannot be done from this dev
environment (no Xcode here; the macOS Swift bridge is `swiftc`-typechecked but
not compiled).

### 1. Xcode capabilities (one-time)
- [ ] **mobile/ios Runner target** → Signing & Capabilities → add **Keychain
      Sharing** with group `com.simo.evolve.sync` (the entitlements file already
      lists `$(AppIdentifierPrefix)com.simo.evolve` + `…sync`; the capability
      toggle makes Xcode/provisioning accept it). iCloud/CloudKit capability is
      already there from 1.0.8.
- [ ] **desktop/macos Runner target** → Signing & Capabilities → add **iCloud
      (CloudKit)** with container `iCloud.com.simo.evolve` (existing container,
      same team) **and Keychain Sharing** with groups
      `com.simo.evolve` + `com.simo.evolve.sync` — must match
      DebugProfile.entitlements / Release.entitlements, which are already
      updated. Signing team `8528AN28A3`.

### 2. CloudKit Console (before ANY release with avatars)
- [ ] In the `iCloud.com.simo.evolve` container: verify record type
      `PrivateRecord` exists with fields `tableName(String)`, `updatedAt(Int64)`,
      `deleted(Int64)`, `payload(Bytes)` **and `asset(Asset)`** in **Development**
      (a dev-build sync with an avatar creates it automatically), then
      **Deploy Schema Changes → Production**. The `asset` field is NEW in this
      release — without promoting it, avatar sync fails in Production.

### 3. Two-pass QA matrix (per the sequencing decision)
Pass A — both apps Xcode-run (**Development** environment):
- [ ] Mac first-enable: creates key/owner/keycheck; iPhone (dev build) adopts and pulls all.
- [ ] iPhone-had-data + Mac-had-data → union merge, no data loss, owner unified.
- [ ] Edit on iPhone → appears on Mac ≤15 min (periodic) or on window refocus / after-write on the other side.
- [ ] Avatar: set on iPhone → appears on Mac (and reverse); remove propagates.
- [ ] Edit-vs-delete LWW; offline edits converge on reconnect.
- [ ] Delete private data on Mac with sync on → confirm dialog shows the multi-device note; zone wiped; iPhone stops syncing (keycheck/key gone); local iPhone copy intact.
- [ ] Old-iOS simulation (1.0.9 build) + new Mac → Mac shows "Waiting for iCloud Keychain — make sure the app on your iPhone is up to date"; updating the iPhone app unblocks it.
- [ ] macOS sandbox: avatar CKAsset upload/download temp files work (flagged risk).

Pass B — **TestFlight iOS 1.0.10 + TestFlight Mac** (Production environment) — release gate:
- [ ] Repeat the core matrix (fresh pull, merge, edit propagation, avatar, delete).
---

fastlane ios update_notes

## DESKTOP ONBOARDING TUTORIAL
- [ ] Reset tutorials from Settings (or use a fresh install state).
- [ ] Launch the app and verify the Overview (Dashboard) tutorial starts automatically.
- [ ] Complete the Overview tutorial and confirm that pressing "Next" on the final step automatically switches the tab to "Goals".
- [ ] Confirm the Goals tutorial starts immediately. Complete it and confirm the final step says "Next" and switches the tab to "Insights".
- [ ] Confirm the Statistics (Insights) tutorial starts immediately. Complete it and confirm the final step says "Finish" and returns you to the "Overview" tab.

- [ ] Widget for iPhone & MacOS
- [ ] Implementing iPhone data's based like screen time, fitness ( Data iPhone already collect so I can read them )
- [ ] /grill-me While trying the macOS implementation from another device ( not this one here ) when I clicked on the circular user’s profile image the Evolve desktop app suddently crashed

---

# 🔍 APPLE-STYLE VISUAL QA — do on BOTH devices (2026-07-11)

The Apple-style coherence work is code-complete and verified (iOS: `flutter analyze` 16 pre-existing / `flutter test` 144 pass; macOS: `flutter analyze` clean / `flutter test` 144 pass + 1 pre-existing unrelated fail). **Only the on-device visuals need your eyes** — no new deps, env vars, or setup. Do each in **light AND dark**, and iOS additionally with a **non-Pro** account.

## 📱 iOS (the `mobile/` app — run on an iPhone / the iOS Simulator on your Mac)

**A. Dialogs (Cupertino confirm/alert).** Trigger each and confirm native iOS look, correct destructive-red, and that the dialog's light/dark matches the app (not the system): delete a habit, delete a goal, **Logout** (Profile), **iCloud** enable disclosure (Private mode), **cancel subscription**, AI Coach **consent** + **delete chat**, App Logs **clear**, Privacy **reset/delete** confirms + **import completed/failed**.
**B. Segmented controls (sliding thumb, equal width, bold selected):** the home **Month/Week/Year/Life** bar, **Statistics** tabs (Info/Trend/Alert/Abitudini/Mood — the 5-tab one is the tightest; check labels don't clip), **Goals** My-Goals/Performance toggle, **Mood** + **Trend** time-range rows.
**C. Buttons (`EvolveButton`):** daily check-in **Enter/Update**, habit editor **Cancel/Update** pair, day-details + dashboard **empty-state** CTAs, **app-locked retry**. Check press-fade + text contrast on your accent.
**D. Switches (now iOS `CupertinoSwitch` — there were none before):** App Settings **Dark Mode / Haptics / 24h**, Notifications toggles, Privacy **biometric / crash-report**, iCloud **sync**. With haptics ON, confirm the toggle taps buzz; with haptics OFF (Settings), confirm they DON'T (this was a real bug fixed).
**E. Section headers / field labels:** Settings section headers + the habit editor's **Habit name / Color / Reminder** labels — should be clean sentence-case, **not** tiny UPPERCASE.
**F. Toasts (`showEvolveToast`, replaced ~20 SnackBars):** save success (green) / error (red) on Personal Info, Privacy export/import, Auth (email sent / reset), Consent, AI Coach connection error, App Logs copy. Confirm a bottom banner fades in, sits ~2s, fades out, and floats above open sheets.
**G. Sheets (grabber + 17pt centered title + detents + grouped rows):** Statistics **Select Habit**, Goals **Choose Category** (+ its editor + delete), App Settings **Default view / Language / Accent**, **planning-type**, **Sort by**, **Year** picker (Pro-locks!), **change-password** (2-step: verify → new), Privacy **delete/reset** chooser, the **time/date** pickers (Notifications, Personal Info, habit Reminder), and the **daily check-in / day-details / habit / error / pro-features** sheet grabbers.
**H. Lists:** Settings cards + Profile rows — grouped-inset with hairline dividers (not floating bordered boxes).
**I. Spinner + color:** the amber Subscription/paywall spinner (now iOS-style); day-details renders correctly in **light** mode (was a theme bug).
**J. Pro-gating (log in NON-Pro):** accent-color **custom** lock, habit **5/5** limit CTA, Goals Pro-locks, **Year picker** locked years → Pro modal.

## 🖥️ macOS (the `desktop/` app — `flutter run -d macos --dart-define-from-file=.env`)

Full detail lives in **`desktop/TO_SIMO_DO.md`** ("Apple-style coherence pass — visual QA, 2026-07-11"). Summary, in light + dark:
1. **Toasts** (new bottom-center banner, replaced 9 SnackBars): Settings import **error** (red), gate/log-copy (neutral), Goals category create/archive/edit failures (red), Auth messages, AI Coach stream error — each fades in/out, floats above dialogs.
2. **Spinners** (`EvolveSpinner`, 10 sites): Statistics/Goals-stats/Auth/Consent/shell-sync/Settings loading + Save-password + create-habit/goal Add buttons — sizing matches the old footprints.
3. **Goals-stats Year picker**: now a centered Evolve **dialog** (was a mobile bottom-sheet) — All-years/year selection, accent check, and non-Pro lock → Pro dialog all still work.
4. **Biometric** lock/fingerprint glyphs → Lucide (were Material).
5. **De-capped labels** (matches the iOS de-cap): section/field/stat labels are now sentence-case — **except** the home **PROTOCOLLO** strip + Auth **OR** divider stay uppercase (same as iOS).


---


## Private Mode parity build (2026-07-04)

- **(Future — Phase 2 / iCloud sync, not built yet).** When the macOS CloudKit sync milestone starts, you'll need to add **macOS** to the `iCloud.com.simo.evolve` CloudKit container in the Apple Developer portal and add the iCloud/CloudKit entitlements to the macOS Runner target. Windows/Linux remain local-only forever (no action).

## macOS Keychain entitlement fix (2026-07-06)

- **Rebuild the desktop app to apply the Keychain entitlement fix.** The Debug macOS build was missing `keychain-access-groups`, which caused the `-34018 "A required entitlement isn't present"` errors and the failed private-profile / analytics / macro-goal-categories loads. It's now added to `desktop/macos/Runner/DebugProfile.entitlements`. Because entitlements are baked in at code-sign time, **quit the running app and do a full `flutter run` (not hot reload / hot restart)** so it re-signs. If the `-34018` still appears, run `flutter clean` then `flutter run`. After launch, confirm the log no longer shows `-34018` and that `[DesktopPrivateDb] Opened schema v…` appears — this is the verification I could not run here (no Xcode on this machine, only the Command Line Tools).

### Update (2026-07-06) — desktop macOS signing wired in
The Keychain entitlement needs a real signing certificate (ad-hoc `"-"` is rejected), so `DEVELOPMENT_TEAM = 8528AN28A3` (your mobile team) + automatic signing is now set on the desktop macOS Runner target. **Next step: just run `flutter run` again.** On first build, automatic signing registers `com.simo.evolve` and creates a development cert/profile.
- If `flutter run` errors with a signing/provisioning failure (e.g. "No profiles / No signing certificate / requires a development team"), open `desktop/macos/Runner.xcworkspace` in Xcode → Runner target → **Signing & Capabilities** → ensure "Automatically manage signing" is checked and your team (`8528AN28A3`) is selected / you're signed into that Apple ID, then rerun.
- Success check: no `-34018` in the logs and `[DesktopPrivateDb] Opened schema v…` appears.

### Update 2 (2026-07-06) — added CODE_SIGN_IDENTITY override
Setting the team wasn't enough: the Runner app target inherited `CODE_SIGN_IDENTITY = "-"` (ad-hoc) from the project, which can't sign the Keychain entitlement. Added `CODE_SIGN_IDENTITY = "Apple Development"` to the three Runner app configs. **Run `flutter run` again.** If it now complains about "No signing certificate" / "No account for team 8528AN28A3", your Xcode isn't signed into that Apple ID — add the account in Xcode ▸ Settings ▸ Accounts (the same Apple ID your mobile app / signed Release uses), or set the team via Runner ▸ Signing & Capabilities, then rerun.

## iOS-parity visual restyle (2026-07-06)

- **Run the app once to visually verify the new design.** The whole desktop UI was restyled to match the iOS app (Inter font, translucent cards, white-pill segmented controls, lucide icons — see DOCUMENTATION.md entry). Everything is analyzer-clean and all 96 tests pass, but this machine has no Xcode, so `flutter build macos` / `flutter run` could not be executed here. Run `flutter run -d macos --dart-define-from-file=.env` and eyeball each section (Home, Habits incl. Calendar views, Statistics tabs, Goals + Stats, AI Coach, Settings, and the Auth/Consent screens in both dark and light theme). No other manual steps: the Inter fonts are bundled in `desktop/assets/fonts/` (no network fetch, no new env vars, no new dependencies).
- Spot-check the points the restyle flagged as worth an eyeball: Statistics Trend chart with sparse data, the Alert cards side-by-side around ~760px width, the habits month-calendar density (cells are taller now, like mobile), the settings import dialog Replace/Merge radio flow, and the Auth screen's sign-in/sign-up segmented switch.

## Desktop-first layout round (2026-07-06, round 2)

- **Re-run the visual pass**: Habits, Statistics and Goals were recomposed desktop-first (side-by-side habits protocol+calendar, stats hero+rail and 3-up alerts, goals board+summary rail with the consolidated command bar). Same command: `flutter run -d macos --dart-define-from-file=.env`. Eyeball specifically: the habits page around the 1120px breakpoint (resize across it), the dense protocol metrics at ~1440px, the goals command bar at the 960px minimum window, the stats Alert tab 3-up row, and the goals right-rail items with long titles.

## Round 3 — fluid + pinned + polish (2026-07-06)

- **Visual pass on your machine** (`flutter run -d macos --dart-define-from-file=.env`), ideally on BOTH the MacBook Pro 14" and the external monitor:
  1. Resize the window from 960px up to full width on every page — nothing should overflow and width should be absorbed by columns/density (no giant buttons).
  2. Habits: the new Protocollo/Calendario switch; calendar month view must fill the window height with no page scroll (day cells grow on the big monitor); protocol table scrolls internally.
  3. Statistics: habit selector now sits in the page header (top-right); check the header at narrow widths ~960-1000px.
  4. Goals: goal cards go 2-up above ~1400 and 3-up above ~1760 content width.
  5. Settings: group cards tile 2-up above ~1568px window width.
  6. AI Coach: chat fills the window, thread centered at 900px.
  7. Toggle light theme once across all pages (audited in code, worth one visual sweep).
  8. Keyboard: ⌘1–⌘5, ⌘, and ⌘K are now covered by tests, but give them a real-hardware tap.

## Apple-style coherence pass — visual QA (2026-07-11)

- **Eyeball the new toast/spinner/dialog/year-picker on-device** (`flutter run -d macos --dart-define-from-file=.env`). This machine has no Xcode, so only `flutter analyze` (clean) and `flutter test` (144 pass / 1 pre-existing fail) were run here — the visuals need a human pass. No new env vars, dependencies, or manual setup; purely presentational. Check in BOTH dark and light themes:
  1. **Toasts** (new bottom-center `showEvolveToast` banner replacing SnackBars): trigger a Settings **import error** (should read as a red/destructive toast with an alert icon), the settings gate/`_showGate` message and App Logs copy/export (neutral), Goals category create/archive/edit failures (error), Auth confirm-email/reset-sent messages, and an AI Coach stream error. Confirm each fades in bottom-center, sits ~2s, and fades out without leaving artefacts (and floats above any open dialog).
  2. **Spinners** (`EvolveSpinner` = Cupertino activity indicator): Statistics loading, Settings loading dialog + Save/Update-password buttons, Goals-stats loading, Auth/Consent submit buttons (on-accent tint), the shell sync/refresh button, and the create-habit/create-goal dialog Add buttons. Verify size/centering match the old footprints (no clipping in the small button variants).
  3. **Goals-stats year picker**: now a centered Evolve dialog (not a bottom sheet). Verify "All years" + year selection still works, the selected row shows the accent check, and — when NOT Pro — the years show the lock, and tapping one closes the dialog, resets to "All years", and opens the Pro-features dialog.
  4. **Biometric lock screen**: the lock + fingerprint glyphs are now Lucide (were Material) — confirm they render.
  5. **De-capped labels** (owner-approved 2026-07-11 — match iOS sentence-case): `EvolveSectionLabel` section headers, the field labels above form inputs (Auth, Habits, Create-Habit, Create-Goal), and the Statistics + Goals-stats stat-card micro-labels are now **sentence-case** (13px, no forced UPPERCASE) instead of the old 10px uppercase. Confirm they read cleanly and the hairline rule still looks right next to sentence-case text. **Intentional exceptions kept UPPERCASE** (to match iOS): the home **'PROTOCOLLO'** strip, and the Auth **'OR'** divider (a divider, not a section label).

## Two iOS crash fixes — on-device re-verification (2026-07-11)

- **Re-run the two QA repros on the iOS Simulator** (debug build) to confirm the crashes are gone. This machine has no Xcode, so both fixes were code-verified only — `flutter analyze` (16 pre-existing infos, 0 errors/warnings) and `flutter test` (**147 pass**, +3 new regression tests). No new env vars, dependencies, or setup; pure code fixes.
  1. **AI Coach opens cleanly**: from the home "Protocollo" panel, tap the AI Chat tile. The screen must open and show the "Hello! I'm your Discipline Coach…" greeting (previously crashed with an `InheritedLocaleData … before initState() completed` error). Also tap the trash/new-chat action and confirm it re-seeds the greeting fine.
  2. **Settings → back-to-login is crash-free, especially with a toast on screen**: trigger any toast (e.g. long-press-copy an AI Coach message, or a Settings import error) and, **within ~2s while the toast is still visible**, log out / go back to login (cloud logout via Settings, and the Private-mode "Go to login" path). No `_dependents.isEmpty is not true` assertion should fire. Confirm toasts still fade in/out normally elsewhere.

## Auto-Verified Habits — front-loaded Apple setup (2026-07-13)

The auto-verified-habits feature (HealthKit + Screen Time goals) is being built behind a feature flag. The **Screen Time distribution entitlement is the launch long-pole** — Apple approval takes ~2 weeks–1 month, is required even for **TestFlight** (not just App Store), and must be requested **once per extension bundle ID**. **Please start item 1 as early as possible — the code can be finished while it's pending.** None of this blocks the current pure-Dart core (it builds + tests here); these are needed before the feature can run on-device or ship.

1. **[DO FIRST — long lead time] Request the Family Controls *distribution* entitlement.** In Xcode create the `DeviceActivityMonitor` app-extension target first (so its bundle ID exists), then file the request for **both** bundle IDs (the Runner app *and* the extension) at <https://developer.apple.com/contact/request/family-controls-distribution> (or the Capabilities requests tab in the developer portal — must be filed by the **Account Holder**). Describe it as an **individual self-monitoring** focus/habit app (not parental/MDM). Two separate requests.
2. **Xcode target + capabilities** (this machine has no Xcode, so all of this is yours):
   - Create the **`DeviceActivityMonitor`** app-extension target in the Runner project (deployment target iOS 16+).
   - Create an **App Group** (e.g. `group.<your-bundle>.evolve`) and add it to **both** the Runner and the extension entitlements — it's how the extension hands verdicts back to the app.
   - Enable the **Family Controls** capability on both Runner and the extension (the free *development* entitlement; the *distribution* one comes from item 1).
   - Enable the **HealthKit** capability on the Runner (no Apple approval needed — HealthKit only).
3. **Info.plist usage strings** (App Store rejects vague ones):
   - `NSHealthShareUsageDescription` — why the app reads Health data (read-only; we never write, so no `NSHealthUpdateUsageDescription`). Make it specific: "to automatically verify your health habits (steps, exercise, sleep…)".
4. **Supabase migration**: apply the additive `goals` verification-rule columns migration (will be added under `migrations/` in the schema slice) to the cloud project, and confirm RLS still passes.
5. **On-device / Apple Watch testing** (delegated to your Xcode machine): HealthKit goals need real Health data; **Stand hours + richer Exercise/Move require an Apple Watch**; Screen Time verdicts must be tested on a real device (the DeviceActivity extension does not fire reliably in the Simulator).
6. **App Store privacy labels**: declare that raw Health/Screen-Time data stays on-device and is **not collected/transmitted** — only the derived `done`/`missed` verdict syncs via the user's own iCloud/Supabase.

### The native Swift is now written — compile it in Xcode (2026-07-13)

⚠️ **None of the verification Swift could be compiled or typechecked on the dev machine (no iOS SDK — Command Line Tools only).** It's a careful scaffold matching the verified Dart channel contract; expect to fix a few API details when you first build. Each file has an `UNVERIFIED` header.

Files created:
- `mobile/ios/Runner/VerificationAppGroup.swift` — shared App Group constant. **Must be a member of BOTH the Runner target AND the DeviceActivityMonitor extension target** (the extension references it). **Set `suiteName`** to the App Group id you actually create (currently the placeholder `group.com.simo.evolve.verification`).
- `mobile/ios/Runner/HealthKitBridge.swift` — `evolve/healthkit` channel (Runner target). Needs the HealthKit capability.
- `mobile/ios/Runner/ScreenTimeBridge.swift` — `evolve/screentime` channel (Runner target). Needs the Family Controls capability; iOS 16+.
- `mobile/ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` — the extension principal class (**new extension target**). Its Info.plist needs `NSExtensionPointIdentifier = com.apple.deviceactivity.monitor-extension` and `NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension`.
- `mobile/ios/Runner/AppDelegate.swift` — already registers both channels (no action; safe — the Dart side only invokes them when `VerificationConfig.enabled` is true).

Steps:
- Add `HealthKitBridge.swift`, `ScreenTimeBridge.swift`, `VerificationAppGroup.swift` to the **Runner** target; add `DeviceActivityMonitorExtension.swift` + `VerificationAppGroup.swift` to the **extension** target.
- Build `Runner` (fix any HealthKit/DeviceActivity API drift the compiler flags), then build the extension.
- Once green on device + the distribution entitlement is approved, flip `VerificationConfig.enabled = true` in `mobile/lib/core/verification_config.dart` to un-dark the feature (HealthKit can be enabled before Screen Time via the separate flags).

---

## Biometric (Face ID) lock fix — 2026-07-13

The Face-ID app lock never engaged (dead state machine). Fixed in code; two
manual checks remain, plus one device verification:

1. **Verify the iOS plugin wiring before building.** In this checkout the
   generated SPM package (`mobile/ios/Flutter/ephemeral/Packages/.../Package.swift`)
   had an EMPTY plugin `dependencies` array and `ios/.symlinks/plugins` was
   empty — if a build is produced from that state, `local_auth_darwin` is not
   linked and every Face-ID call throws `MissingPluginException` (silently
   caught → app stays unlocked). Run `flutter clean && flutter pub get` in
   `mobile/`, then confirm `Package.swift` lists a `local_auth_darwin` entry
   before archiving. (Likely just an incomplete `pub get` on this Xcode-less
   Mac; verify on your build machine.)
2. **Device test (needs a real iPhone with Face ID / Touch ID enrolled):**
   Settings → Privacy → enable the biometric lock (prompts once). Then
   force-quit & relaunch → app must show the lock screen and prompt Face ID.
   Background the app (app switcher) & return → must re-prompt. Also confirm
   the app-switcher snapshot shows the lock screen, not your data.
3. **No Supabase migration required.** The `biometric_lock` column is now
   treated as a per-device preference: it is still uploaded, but the local
   value is authoritative on pull (a stale/false server row can no longer
   silently disable a lock enabled on the device).
