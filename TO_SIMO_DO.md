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


### AI Coach — the free-model switch (2026-07-17), before it goes live
- [ ] **The migration and the Edge Function BOTH changed** for the free-model switch, so if you applied/deployed the earlier versions, redo them. `migrations/20260717_add_ai_coach_proxy.sql` now defaults `model` to `google/gemma-4-26b-a4b-it:free`, `providers` to `ARRAY['google-ai-studio']`, and adds `zero_data_retention`/`data_collection` columns. If you already ran the old migration, either drop the table and re-run, or `ALTER TABLE` to add the two columns and `UPDATE` model+providers — otherwise the function's SELECT gets the old paid Vertex row.
- [ ] **Verify the pin against the NEW target.** The live SSE chunks must report `"provider":"google-ai-studio"`, not `google-vertex` and never `darkbloom` (the free model's other server — the function logs `PROVIDER PIN LEAKED` and it is NOT named in the privacy policy). This is the same load-bearing check as before, just a different expected provider.
- [ ] **Confirm Google AI Studio's current free-tier terms** actually match what the privacy policy now says in your name: that Google may retain the text for a limited period and use it to improve their services (incl. training). If Google's terms are stricter or looser, adjust the policy copy (all 5 locales) to match. This is a legal claim you are the controller for.
- [ ] **Sanity note:** the proxy is a free tier — 20 req/min, 50/day (1000/day with ≥$10 credits) across ALL Pro users on your one key. Fine for a handful of users; if the base grows, tighten `ai_coach_limits` or switch back to a paid Vertex model (one `UPDATE` of model+providers+the two privacy columns, plus reverting the privacy-copy change).

### Blocked on the implementation landing
- [ ] **Before Screen Time can ever ship, these are open (found 2026-07-17, none fixable without a device):**
  - **Nothing selects which apps to watch.** Every `DeviceActivityEvent` is built with `applications: []`, `categories: []`, `webDomains: []` (`AppDelegate.swift:638-643`), and there is **no `FamilyActivitySelection` / `FamilyActivityPicker` anywhere in the repo**. The design assumes an empty set means "all activity". I could not verify that from here and I do not believe it: the usual reading is that an event scoped to nothing never fires, which would make every Screen Time habit silently pass forever. **Settle this on device first** — it decides whether v1 needs a picker UI (a real design change from "total device usage").
  - **Nothing requests Family Controls authorization.** `requestIndividualAuthorization` is implemented natively and on the bridge but has zero production call sites. The request belongs at the Screen Time opt-in, which doesn't exist yet. (The reconcile now *checks* status and skips rather than throwing — 2026-07-17.)
  - **Register `com.simo.evolve.DeviceActivityMonitorExtension` in the developer portal** with Family Controls + the App Group, and give it a distribution profile. Your entitlement approval is per App ID: approval on `com.simo.evolve` does not cover the extension's App ID. Nothing in the repo suggests this was done. Archiving will fail to sign without it.
  - **Deployment-target split**: Runner is iOS 15.0, the extension is iOS 16.0 (`project.pbxproj`), and `syncMonitoredGoals` has no `#available` guard while `authorizationStatus` does. On iOS 15 the feature would report `notDetermined` forever and never load the extension. Decide: raise Runner to 16, or gate the Dart path on the OS version.
  - **`PrivacyInfo.xcprivacy` declares nothing for Screen Time**, and the extension bundle has no manifest at all despite reading/writing UserDefaults. The file's own recorded reasoning about Health ("declaring costs one nutrition label row; not declaring reads as concealment") applies verbatim here.