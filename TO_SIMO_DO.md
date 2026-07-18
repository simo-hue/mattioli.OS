# TO_SIMO_DO.md
## h
- [ ] Widget for iPhone & MacOS
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] Curor of AI Coach Response
- [ ] From mobile implementation, in the settings the "App logs" field has to few bottom margin from the button "Go to login", I want you to increase it.
- [ ] mobile animation between lateral scroll on the goals page? Improve it

---
 - [ ] **Device-verify Mode A end-to-end** (iPhone): Settings → Screen Time → enable (grant Family Controls + notifications) → create a "Time in chosen apps" habit → Choose apps → use them past the limit across several app foregrounds → confirm the localized "limit reached" notification fires and the habit logs a miss.
- [ ] **Confirm the `evolve/screentime` channel is reachable** under the SceneDelegate. CloudKit had to be re-registered in `SceneDelegate`; Screen Time is registered only in `AppDelegate.didFinishLaunching`. If the picker / auth prompt silently no-op on device, re-register the channel in `SceneDelegate` too.
- [ ] **Mode B (`screen_time_total`) is DARK** (`screenTimeTotalEnabled = false`). Flip it to true ONLY after a device test proves an empty `DeviceActivityEvent` actually fires `eventDidReachThreshold` on total usage — the exact unknown it's gated on. If it never fires, leave it off; Mode A stands alone.
- [ ] **Extension `PrivacyInfo.xcprivacy`** (new file) declares UserDefaults reason **`1C8F.1`** (App Group). Confirm it lands in the extension target's *Copy Bundle Resources*, and double-check `1C8F.1` against Apple's current "Describing use of required reason API" docs before submitting (ITMS-91053 risk if wrong).
- [ ] **Appex version** was aligned to Runner (`MARKETING_VERSION 1.1.0`, `CURRENT_PROJECT_VERSION $(FLUTTER_BUILD_NUMBER)`) — this fixed a validation blocker. Just confirm Validate is clean.

### Blocked on the implementation landing
- [ ] **Before Screen Time can ever ship, these are open (found 2026-07-17, none fixable without a device):**
  - **Nothing selects which apps to watch.** Every `DeviceActivityEvent` is built with `applications: []`, `categories: []`, `webDomains: []` (`AppDelegate.swift:638-643`), and there is **no `FamilyActivitySelection` / `FamilyActivityPicker` anywhere in the repo**. The design assumes an empty set means "all activity". I could not verify that from here and I do not believe it: the usual reading is that an event scoped to nothing never fires, which would make every Screen Time habit silently pass forever. **Settle this on device first** — it decides whether v1 needs a picker UI (a real design change from "total device usage").
  - **Nothing requests Family Controls authorization.** `requestIndividualAuthorization` is implemented natively and on the bridge but has zero production call sites. The request belongs at the Screen Time opt-in, which doesn't exist yet. (The reconcile now *checks* status and skips rather than throwing — 2026-07-17.)
  - **Register `com.simo.evolve.DeviceActivityMonitorExtension` in the developer portal** with Family Controls + the App Group, and give it a distribution profile. Your entitlement approval is per App ID: approval on `com.simo.evolve` does not cover the extension's App ID. Nothing in the repo suggests this was done. Archiving will fail to sign without it.
  - **Deployment-target split**: Runner is iOS 15.0, the extension is iOS 16.0 (`project.pbxproj`), and `syncMonitoredGoals` has no `#available` guard while `authorizationStatus` does. On iOS 15 the feature would report `notDetermined` forever and never load the extension. Decide: raise Runner to 16, or gate the Dart path on the OS version.
  - **`PrivacyInfo.xcprivacy` declares nothing for Screen Time**, and the extension bundle has no manifest at all despite reading/writing UserDefaults. The file's own recorded reasoning about Health ("declaring costs one nutrition label row; not declaring reads as concealment") applies verbatim here.
