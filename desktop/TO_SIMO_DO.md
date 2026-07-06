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
