# TO_SIMO_DO.md
- [ ] Local AI Models ( Ollama for desktop? Other solutions? For mobile what can we do? )
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
The Keychain entitlement needs a real signing certificate (ad-hoc `"-"` is rejected), so `DEVELOPMENT_TEAM = 8528AN28A3` (your mobile team) + automatic signing is now set on the desktop macOS Runner target. **Next step: just run `flutter run` again.** On first build, automatic signing registers `com.simo.evolve.evolveDesktop` and creates a development cert/profile.
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
