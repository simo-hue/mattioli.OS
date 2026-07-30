# PROSSIME AZIONI MANUALI (SIMO)

Manual / on-device / Apple-account steps that can't be done from code. The
in-code work behind each of these is implemented and committed.

---

- ~~**App Store Metadata**: Run fastlane deliver or manually upload the updated metadata (name changes) via App Store Connect since the localized `name.txt` files have been set to "Evolve: Habits & Goals Tracker".~~ *(Completed via Antigravity)*

- **iOS pod warnings (2026-07-30): run `pod install` on the Mac mini, then confirm the archive log is clean.** `ios/Podfile` changed, so the `PODFILE CHECKSUM` in `ios/Podfile.lock` is stale and the per-pod `.xcconfig` files under `ios/Pods/` still carry the old settings — **archiving straight from the Xcode GUI would rebuild with the old flags and the ~260 warnings would still be there.** From `mobile/`:

  ```bash
  cd ios && pod install && cd .. && flutter build ipa
  ```

  (`flutter build ipa` re-runs `pod install` itself when it notices the Podfile changed, so either half is enough — but running it explicitly is what tells you the CocoaPods side is happy.) Then archive as usual and check the log: expected result is **zero** warnings from `SQLCipher`, `FMDB` and `permission_handler_apple`, while any warning in `Runner` or `DeviceActivityMonitorExtension` still shows. Commit the regenerated `ios/Podfile.lock` (its checksum line will have changed) — it is a tracked file. This could not be verified from the laptop: it has Command Line Tools only, no Xcode and no CocoaPods.