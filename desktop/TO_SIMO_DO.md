# Manual Actions Required

## Private Mode parity build (2026-07-04)

- **(Future — Phase 2 / iCloud sync, not built yet).** When the macOS CloudKit sync milestone starts, you'll need to add **macOS** to the `iCloud.com.simo.evolve` CloudKit container in the Apple Developer portal and add the iCloud/CloudKit entitlements to the macOS Runner target. Windows/Linux remain local-only forever (no action).

## macOS Keychain entitlement fix (2026-07-06)

- **Rebuild the desktop app to apply the Keychain entitlement fix.** The Debug macOS build was missing `keychain-access-groups`, which caused the `-34018 "A required entitlement isn't present"` errors and the failed private-profile / analytics / macro-goal-categories loads. It's now added to `desktop/macos/Runner/DebugProfile.entitlements`. Because entitlements are baked in at code-sign time, **quit the running app and do a full `flutter run` (not hot reload / hot restart)** so it re-signs. If the `-34018` still appears, run `flutter clean` then `flutter run`. After launch, confirm the log no longer shows `-34018` and that `[DesktopPrivateDb] Opened schema v…` appears — this is the verification I could not run here (no Xcode on this machine, only the Command Line Tools).
