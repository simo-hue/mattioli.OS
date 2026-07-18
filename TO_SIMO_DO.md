# TO_SIMO_DO.md
## h
- [ ] Widget for iPhone & MacOS
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] Curor of AI Coach Response
- [ ] From mobile implementation, in the settings the "App logs" field has to few bottom margin from the button "Go to login", I want you to increase it.
- [ ] mobile animation between lateral scroll on the goals page? Improve it

---
- [ ] **Confirm the `evolve/screentime` channel is reachable** under the SceneDelegate. CloudKit had to be re-registered in `SceneDelegate`; Screen Time is registered only in `AppDelegate.didFinishLaunching`. If the picker / auth prompt silently no-op on device, re-register the channel in `SceneDelegate` too.
- [ ] **Mode B (`screen_time_total`) is DARK** (`screenTimeTotalEnabled = false`). Flip it to true ONLY after a device test proves an empty `DeviceActivityEvent` actually fires `eventDidReachThreshold` on total usage — the exact unknown it's gated on. If it never fires, leave it off; Mode A stands alone.
- [ ] **Extension `PrivacyInfo.xcprivacy`** (new file) declares UserDefaults reason **`1C8F.1`** (App Group). Confirm it lands in the extension target's *Copy Bundle Resources*, and double-check `1C8F.1` against Apple's current "Describing use of required reason API" docs before submitting (ITMS-91053 risk if wrong).