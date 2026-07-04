# Manual Actions Required

- You have a running `flutter run` instance in your terminal. You need to stop it and restart it manually (`flutter run --dart-define-from-file=.env`) so that the newly added `sqflite_sqlcipher` native macOS dependencies are properly linked via CocoaPods. Hot restart might not be enough for a native dependency addition.

## Private Mode parity build (2026-07-04)

- **(Optional) AI Coach key.** The desktop AI Coach is intentionally inert until you supply an OpenRouter key. To enable it, run with `--dart-define=OPENROUTER_API_KEY=<your key>` (never commit the key). In Private mode the app now requires the user's explicit one-time consent before any external AI send, so this is safe to enable.
- **(Future — Phase 2 / iCloud sync, not built yet).** When the macOS CloudKit sync milestone starts, you'll need to add **macOS** to the `iCloud.com.simo.evolve` CloudKit container in the Apple Developer portal and add the iCloud/CloudKit entitlements to the macOS Runner target. Windows/Linux remain local-only forever (no action).
