# TO_SIMO_DO.md

- [ ] Widget for iPhone & MacOS
- [ ] Update for the habits to decide the day of the week to decide when it should be completed and obviously when it should appear on the day's pop up calendar view. The desktop UI element is already in place but from mobile is totally missing
- [ ] In the habits protocol tab view I want to see only the current habits and not also the past ones
- [ ] MacOS app doesn't have the log in phase, I want to have the same logic of the mobile iOS app as it's professional and complete
- [ ] Cloud mode for AI, in both mobile and desktop implementation, we need to implement the fact that they need to insert their API Keys, we can also give a possibility to add two of them so they can have a back up in case the first one is not working ( if you think it does make sense )
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] Curor of AI Coach Response
- [ ] From mobile implementation, in the settings the "App logs" field has to few bottom margin from the button "Go to login", I want you to increase it.
- [ ] mobile animation between lateral scroll on the goals page? Improve it

---


### Blocked on the implementation landing
- [ ] **Before Screen Time can ever ship, these are open (found 2026-07-17, none fixable without a device):**
  - **Nothing selects which apps to watch.** Every `DeviceActivityEvent` is built with `applications: []`, `categories: []`, `webDomains: []` (`AppDelegate.swift:638-643`), and there is **no `FamilyActivitySelection` / `FamilyActivityPicker` anywhere in the repo**. The design assumes an empty set means "all activity". I could not verify that from here and I do not believe it: the usual reading is that an event scoped to nothing never fires, which would make every Screen Time habit silently pass forever. **Settle this on device first** — it decides whether v1 needs a picker UI (a real design change from "total device usage").
  - **Nothing requests Family Controls authorization.** `requestIndividualAuthorization` is implemented natively and on the bridge but has zero production call sites. The request belongs at the Screen Time opt-in, which doesn't exist yet. (The reconcile now *checks* status and skips rather than throwing — 2026-07-17.)
  - **Register `com.simo.evolve.DeviceActivityMonitorExtension` in the developer portal** with Family Controls + the App Group, and give it a distribution profile. Your entitlement approval is per App ID: approval on `com.simo.evolve` does not cover the extension's App ID. Nothing in the repo suggests this was done. Archiving will fail to sign without it.
  - **Deployment-target split**: Runner is iOS 15.0, the extension is iOS 16.0 (`project.pbxproj`), and `syncMonitoredGoals` has no `#available` guard while `authorizationStatus` does. On iOS 15 the feature would report `notDetermined` forever and never load the extension. Decide: raise Runner to 16, or gate the Dart path on the OS version.
  - **`PrivacyInfo.xcprivacy` declares nothing for Screen Time**, and the extension bundle has no manifest at all despite reading/writing UserDefaults. The file's own recorded reasoning about Health ("declaring costs one nutrition label row; not declaring reads as concealment") applies verbatim here.