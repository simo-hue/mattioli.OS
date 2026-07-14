# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS


## DESKTOP + MOBILE — iCloud sync cross-platform (needs your Xcode machine)

### 2. CloudKit Console (before ANY release with avatars)
- [ ] In the `iCloud.com.simo.evolve` container: verify record type
      `PrivateRecord` exists with fields `tableName(String)`, `updatedAt(Int64)`,
      `deleted(Int64)`, `payload(Bytes)` **and `asset(Asset)`** in **Development**
      (a dev-build sync with an avatar creates it automatically), then
      **Deploy Schema Changes → Production**. The `asset` field is NEW in this
      release — without promoting it, avatar sync fails in Production.


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


## Local AI Coach — on-device QA (desktop, no Xcode on the dev machine)

The local-LLM coach is complete in Dart and unit/widget-tested, but the desktop macOS
build + real streaming against a local server can only be exercised on your Xcode machine.
No env-var or build changes are required (the cloud key is still `--dart-define=OPENROUTER_API_KEY`;
local needs no key).

- [ ] Install a local server and pull a model, e.g. **Ollama** (`ollama pull llama3.1:8b`,
      serves `http://localhost:11434/v1`) or **LM Studio** (start its local server on `:1234`).
- [ ] Launch the desktop app → AI Coach. Confirm the **"Local model detected"** banner appears
      (Cloud backend + a server running), and "Use local" switches the engine + hides the banner.
- [ ] Open the header **model chip** → verify Cloud + discovered local models list; picking a local
      model streams a reply with **no** private-mode consent dialog and **no** "no internet" error.
- [ ] Open **Server settings…** (chip menu or Settings → AI Coach): switch preset (Ollama/LM Studio),
      edit the base URL, hit refresh, confirm the status pill flips Connected/Offline, and that a
      **non-loopback** URL (e.g. a tunnel) shows the amber "Remote" badge + warning.
- [ ] Advanced: set a custom system prompt + change temperature; confirm both take effect and persist
      across relaunch. Stop the server mid-chat → confirm the actionable "server not reachable at {url}"
      message (not the cloud "check your internet" copy), and that a cold first model load doesn't
      false-timeout (first-token budget is 60s).
- [ ] **Arabic (`ar`) strings** in `ai.local.*` and `coachSettings.*` are machine-translated MSA —
      have a native speaker review (same standing caveat as the verification feature).

## Desktop continuous product tour (2026-07-14) — on-device QA
No Xcode on this Mac, so the tour was code-verified (analyze clean + `flutter test` green for all
tour suites) but NOT run on a real macOS build. Please run the desktop app and check:
- [ ] **First launch**: welcome dialog appears → "Start tour" → the tour runs continuously through
      **Overview → Habits → Insights → Goals → AI Coach**, then the "You're all set" completion dialog
      returns you to Overview. Confirm each of the 22 spotlights lands on the right widget (especially
      the new Habits check-off/streak targets on the injected demo habit, and the Coach model chip /
      context button / suggestion strip / input bar).
- [ ] **Lock is sealed**: during the tour, the sidebar, ⌘1–5 / ⌘, shortcuts, ⌘[ / ⌘] history, the
      two-finger trackpad swipe, ⌘K command palette, and taps on the page behind the scrim all do
      NOTHING — only the overlay's Back/Next/Finish (and →/←/Enter keys) advance it. Esc does nothing.
- [ ] **Resume**: force-quit mid-tour (e.g. on the Goals segment) → relaunch → it resumes at that
      segment (not from Overview), still locked.
- [ ] **Replay**: Settings → Application → "Ripristina tutorial" jumps to Overview, shows the welcome
      dialog, and re-runs the whole locked tour (no name prompt, since your name already exists).
- [ ] **Existing install**: because legacy `has_seen_*` flags are purged, an install that had already
      seen the old (broken) tutorial will see the new full tour once — confirm that's acceptable.
- [ ] **Native review** of the `t.tour.*` Spanish/German/Arabic copy (esp. `ar`, RTL) — machine-authored.

Note: running the FULL `flutter test` suite needs dummy dart-defines
(`--dart-define=EVOLVE_SUPABASE_URL=… --dart-define=EVOLVE_SUPABASE_ANON_KEY=… --dart-define=OPENROUTER_API_KEY=…`).
Two failures are PRE-EXISTING and unrelated to the tour: `desktop_supabase_config_security_test`
(credential-defines check) and `icloud_sync_card_test` (pumpAndSettle timeout).