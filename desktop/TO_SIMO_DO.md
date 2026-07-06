# Manual Actions Required

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

## Data import/export rework (2026-07-07)

- **Rebuild once on the Xcode machine**: `file_picker` was bumped 3.0.4 → 11.0.2 and `share_plus` 13.1.0 → 12.0.2 (matching mobile's pair), so the macOS pods change — run `flutter run -d macos --dart-define-from-file=.env` (CocoaPods will re-install automatically; if it complains, `cd macos && pod install`). No Xcode build was possible on this machine.
- **Manually verify the new export Save dialog** (needs real macOS UI): Settings → Export data in BOTH Private and Cloud mode — a native Save panel should appear with `evolve_private_export.json` / `mattioli_os_export.json` pre-filled; cancel must do nothing; save must write the JSON. The sandbox entitlement was changed to `com.apple.security.files.user-selected.read-write` in Debug+Release — if the Save panel writes nothing, double-check Xcode picked up the entitlement change (clean build).
- **Cloud import/export smoke test against real Supabase** (cannot be tested headless): run one export + one merge-mode import + one replace-mode import while logged in. The cloud import path is now plan-based (fetch → plan → upserts) and was verified by pure unit tests only.
- **Cross-device check**: export from desktop Private mode and import the file on the iPhone app (and vice versa) — the desktop export shape changed to the mobile-canonical camelCase shape precisely so this works.

## Apple-like control kit — visual QA (2026-07-07)

No Xcode on the dev machine: everything below verified by `flutter analyze` + 140 widget tests only. Run `flutter run -d macos --dart-define-from-file=.env` and eyeball each surface **in dark AND light theme** (Settings → Dark mode toggle), plus the Arabic RTL spot-checks at the end.

**Settings (all four sections):**
1. Every toggle row is now the kit `EvolveSwitch` (macOS-style green pill, white thumb): dark mode, 24h format, AI & System group (AI Suggestions / Focus / Milestones / Deep work), notifications toggles, biometric lock, crash reports, iCloud sync enable (Private mode). Check ON=green / OFF=gray in both themes, hover lightens the track, and the thumb animates.
2. AI Suggestions row shows the small amber **PRO** badge next to the title (like mobile). Toggling while not Pro still opens the Pro modal.
3. Calendar view + Language rows are the new pop-up selects (bordered pill + up/down chevrons, hover, checkmark on the current option). Menu opens under the control, matches Evolve panel styling.
4. Morning brief / Evening review time rows: new clock-chip trigger; clicking opens the Evolve time dialog (hour/minute steppers + direct typing). With 24h format OFF, the dialog shows the AM/PM toggle and the trigger shows e.g. "8:00 AM".
5. Profile → Personal info: Date of birth is now a calendar field (no free typing) — opens the Evolve calendar popover; double-chevrons jump years (relevant for DOB), X clears the date. Confirm the saved value still round-trips (profile shows the same date after reopen).
6. Privacy → Import data: pick a backup — the preview dialog is now Evolve-styled (icon rows for counts, amber-free warning chip when records will be skipped, Replace/Merge as bordered radio cards). The in-progress dialog and the post-import summary should look consistent. Copy check: the Import row's subtitle now says "JSON or ZIP" (all 5 languages).

**Other surfaces:**
7. Statistics → habit scope picker (top bar in habit scope): pop-up select with the habit's color dot; long habit titles ellipsize.
8. Goals: period dropdown (month/quarter/year selector, 44px) is the kit select; the 44px category dot button opens an Evolve menu (default + colored categories + "create new category" accent item, current one checked); goal edit dialog's category select shows color dots.
9. Habits: habit editor's category select + reminder time (tap the reminder field → Evolve time dialog; the X still clears the reminder).
10. Dashboard → New goal dialog: Timeline select (This week / This month / …).
11. AI Coach: gear (context dialog) — Evolve dialog with the two share-toggles as kit switches; in Private mode, the external-AI consent dialog is Evolve-styled too.
12. Consent/onboarding page: crash diagnostics row uses the kit switch (row tap toggles it as before); the terms checkbox now has the rounded accent style.

**Theme + RTL spot-checks:**
13. Light theme: open one select menu, the time dialog, and the calendar — menu/dialog surfaces must read as light panels with visible hover states (hover was retuned to work on light).
14. Arabic (Settings → Language → Arabic): settings rows mirror (icon chips right, switches left); select menus open aligned to their control; calendar header chevrons point the mirrored way and the day grid runs right-to-left; the time dialog's HH:MM cluster stays left-to-right (correct — clock readings don't mirror) and shows ص/م for AM/PM when 24h is off.
15. Quick pointer sweep: every new control shows a pointer cursor on hover (switches, selects, menu items, radio cards, calendar days, steppers).
