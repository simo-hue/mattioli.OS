# PROSSIME AZIONI MANUALI (SIMO)

Manual / on-device / Apple-account steps that can't be done from code. The
in-code work behind each of these is implemented and committed.

---
## 2026-07-16 — iOS IPA build

- [ ] **Get the cycle fix onto the Mac mini and re-archive.** The fix is a
  reorder in `ios/Runner.xcodeproj/project.pbxproj` (moved "Embed Foundation
  Extensions" before "Thin Binary"). On the Mac mini: `git pull`, then
  `flutter build ipa`. It should now archive past the previous
  `Cycle inside Runner` error. (Couldn't be verified here — this Mac has no full
  Xcode.)

- [x] **DONE (code): DeviceActivityMonitorExtension deployment target 26.5 → 16.0.**
  Was pinned to `IPHONEOS_DEPLOYMENT_TARGET = 26.5` (Xcode auto-set it), which
  meant iOS would not load the extension below 26.5 and Screen-Time
  auto-verification would silently never run for ~all users. Lowered to **16.0**
  in all three configs. **On-device follow-up:** confirm the feature actually
  runs on an iOS 16–17 device (real-device check, not simulator).
