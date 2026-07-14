# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] Update for the habits to decide the day of the week to decide when it should be completed and obviously when it should appear on the day's pop up calendar view. The desktop UI element is already in place but from mobile is totally missing
- [ ] In the habits protocol tab view I want to see only the current habits and not also the past ones
- [ ] MacOS app doesn't have the log in phase, I want to have the same logic of the mobile iOS app as it's professional and complete


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
- [ ] **Name popup fires once** (the fixed bug): in Private mode with no name yet, the profile-name
      prompt appears exactly ONCE (not twice at startup), and after you enter your name it never comes
      back when you navigate away from and back to Overview. Same for the welcome dialog.
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


## In-app "Start Ollama" launcher — on-device QA (desktop macOS, sandboxed)

The app launches the installed Ollama desktop app via `NSWorkspace` (sandbox blocks running
`ollama serve` directly). Code-verified here (Swift typechecks, Dart tests green) but the real
launch can only be checked on your Mac. Requires the Ollama **desktop app** installed (not a
Homebrew CLI-only install).

- [ ] **#1 risk — confirm the sandbox actually allows the launch.** Quit Ollama from its menu-bar
      icon, open the coach on the local **Ollama** preset (server down) → the amber "Ollama isn't
      running" banner appears → tap **Start Ollama**. If the daemon comes up (pill flips Connected
      within ~30s, banner disappears), the sandbox `NSWorkspace.openApplication` path works. If it
      silently does nothing (status "failed"), we likely need a temporary-exception entitlement —
      tell me and I'll add it.
- [ ] **Confirm the Ollama bundle id.** Run `osascript -e 'id of app "Ollama"'`. If it's NOT one of
      `com.electron.ollama` / `ai.ollama.app` / `com.ollama.ollama` / `com.ollama.app` in
      `LocalLlmBridge.ollamaBundleIds` (`macos/Runner/AppDelegate.swift`), the path fallback may or
      may not fire under the sandbox — send me the real id and I'll make it the primary.
- [ ] **First-ever launch** may trigger a Gatekeeper / "downloaded from the internet" prompt or take
      longer — confirm the soft timeout hint copy ("check the Ollama icon in your menu bar…") reads well.
- [ ] **Not-installed fallback**: temporarily rename `/Applications/Ollama.app` → the button becomes
      **Get Ollama** and opens `ollama.com/download` in the browser.
- [ ] **Both surfaces**: the affordance shows on the coach page banner AND in Settings → AI Coach →
      Server settings (below the Offline status pill) — both only while local+Ollama+unreachable.

Note: running the FULL `flutter test` suite needs dummy dart-defines
(`--dart-define=EVOLVE_SUPABASE_URL=… --dart-define=EVOLVE_SUPABASE_ANON_KEY=… --dart-define=OPENROUTER_API_KEY=…`).
Two failures are PRE-EXISTING and unrelated to the tour: `desktop_supabase_config_security_test`
(credential-defines check) and `icloud_sync_card_test` (pumpAndSettle timeout).


## AI Coach panel polish — on-device QA (visual + keyboard, no macOS build here)

- [ ] **Scrollbar**: with a long chat, confirm there is now exactly ONE scrollbar (at the panel's right
      edge), not two.
- [ ] **Answering animation**: send a message → the assistant bubble shows animated dots while waiting,
      then streams text with a blinking caret; new bubbles fade+slide in. Verify it feels smooth on both a
      fast cloud reply and a slow cold local model.
- [ ] **Enter vs Shift+Enter** (the one behavior I couldn't verify without a run): **Enter sends**,
      **Shift+Enter inserts a newline**, and the input grows to ~5 lines then scrolls. If Enter instead
      inserts a newline (i.e. the `Focus(onKeyEvent)` interception doesn't beat the multiline field), tell me
      and I'll switch to a `Shortcuts`/`Actions` intercept. Also check an IME/accented compose doesn't send.
- [ ] **Smart scroll**: while a reply streams, scroll UP to re-read — confirm you are NOT yanked back to the
      bottom; when near the bottom it should stick.
- [ ] **New chat**: the header new-chat button clears the thread (with a confirm when there's a real
      conversation) and cancels an in-flight reply.
- [ ] **Copy / links / code**: hover an assistant reply → a "Copy" affordance appears and copies the text;
      a link in a reply opens the browser; a code block renders monospaced/tinted.
- [ ] **Reduce Motion**: with macOS System Settings → Accessibility → Display → Reduce Motion ON, confirm
      the dots/caret/entrance degrade to static (no animation).


## Private DB locked-key recovery — on-device QA + hardening (no build here)

Context: the "Private database key unavailable while the database file exists" lockout now has an in-app
recovery flow (desktop + mobile). Verified in Dart (analyze + unit tests) but the dialogs and the real
reset-and-import round-trip could not be run here.

- [ ] **Reproduce the lockout** (desktop): with an existing `~/Library/Containers/com.simo.evolve/Data/
      Library/Application Support/com.simo.evolve/evolve_private_v2.db`, remove the Keychain key (or trigger a
      signing change) so the app is locked, then relaunch.
- [ ] **Import recovery**: Settings → Import a backup in Private mode → confirm the new "Reset locked private
      database?" dialog appears, and that confirming resets + imports cleanly onto a fresh key (habits/logs
      show up, and sync/categories/analytics stop erroring).
- [ ] **Delete-private-data recovery** (no-backup path): while locked, tap "Delete private data" → confirm it
      succeeds (file-level reset) instead of erroring, and the app is usable in Private mode afterward.
- [ ] **Cancel path**: decline the reset dialog → confirm nothing is deleted and the app stays as-is.
- [ ] **Mobile**: repeat the import + delete recovery checks on iOS.
- [ ] **PREVENT RECURRENCE (signing)**: the dev-machine lockout is caused by Debug builds flipping between
      ad-hoc (`CODE_SIGN_IDENTITY = "-"`) and `Apple Development` (team `8528AN28A3`), which rotates the
      Keychain access-group prefix and orphans the SQLCipher key. Keep every macOS build on ONE signing
      identity — ensure the `Apple Development` cert/team is always available so it never silently falls back
      to ad-hoc. (The `CODE_SIGN_IDENTITY[sdk=macosx*] = "Apple Development"` override should already force
      this; just don't build without the team.)
- [ ] **Commit the uncommitted work**: a concurrent session's commits swept most of these edits into HEAD,
      but `desktop/lib/features/settings/presentation/settings_page.dart` and the two new
      `{desktop,mobile}/test/private_db_recovery_test.dart` files are still uncommitted in the working tree —
      review `git diff` / `git status` and commit them.


## DESKTOP — ⌘K command palette on-device QA (needs your Xcode machine)
Built + `flutter analyze`-clean + unit-tested here, but no Xcode on this Mac means interaction/visual QA is
pending. Run `flutter run -d macos` and verify:
- [ ] **⌘K opens** the new palette; typing filters live (goals/habits/sections/actions grouped, goals first).
- [ ] **Arrow-key nav works while typing**: ↑/↓ move the highlight (they must NOT just move the text caret),
      ↵ activates the highlighted row, esc closes. This relies on the palette's `Shortcuts` out-ranking the
      text field's default arrow handling — the one thing I couldn't verify without running it.
- [ ] **Goal jump**: search a goal in a NON-current period → ↵ → Goals opens on that exact week/month/year and
      the row glows + scrolls into view. Test it both when starting from another section AND when already on
      the Goals page (the in-place `ref.listen` path).
- [ ] **Per-row menu**: the ⋯ button (and ⌘↵ on the highlighted row) opens Open/Complete/Reschedule/Edit/
      Delete for a goal; **Delete shows a confirmation dialog** before removing. Habits show Open/Delete.
- [ ] **Create-with-period**: type a new goal name → "Create goal “…”" → dialog is prefilled, pick an
      arbitrary year/month/week → save → it lands on that period. Repeat for "Create habit".
- [ ] **Actions**: "week 2 march"/"q2 2026"/"march" surface a Go-to-period row; toggle theme; manage
      categories; replay tour; go to this week.
- [ ] **BOTH DATA MODES**: run the above once in Cloud (Supabase) mode and once in Private mode — behaviour
      should be identical (search is in-memory; writes go through the active repository).
- [ ] **RTL**: with Arabic UI, confirm the palette + new period pickers read correctly.


## DESKTOP — Private-mode category create: recover the locked device + on-device QA
The graceful-failure code change (category create mirrors mobile's swallow-return-null) is `flutter analyze`-clean
but was NOT run here (no Xcode / you run macOS on another Mac). On that Mac:
- [ ] **Recover the locked device FIRST** — the code only makes the *failure* graceful; the private DB is still
      locked (SQLCipher key orphaned by a signing/team-prefix rotation — see the 2026-07-14 20:30 doc entry).
      Get back in via **Settings → Private data → Delete** (falls back to `resetLockedDatabase()`), or restore the
      original `Apple Development` signing identity/team so the key reads again. NOTE: reset is **destructive** to
      the local private data (its key is gone) — prefer the signing fix if the data matters and iCloud sync
      hadn't already pushed it.
- [ ] **QA the graceful failure**: in a locked-DB state, adding a category from BOTH the add-goal picker action
      and the inline "+ category" now shows the "category create failed" toast (no red screen, no console-spammed
      `PrivateDatabaseLockedException`) and leaves **no phantom category** in the picker.
- [ ] **QA the happy path**: on a healthy Private DB (and in Cloud mode), category create + auto-select still
      works and the new category persists across an app restart.