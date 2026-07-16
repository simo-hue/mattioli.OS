# TO_SIMO_DO
## macOS archive dSYM fix — verify on the Mac mini (has Xcode)
The code fix is in (`desktop/scripts/copy_archive_dsyms.sh` + the "Copy SPM dSYMs"
build phase). To confirm it resolves the App Store Connect warning, re-archive on
the Mac mini:

1. In `desktop/`: `flutter build macos --release` (or open
   `desktop/macos/Runner.xcworkspace` in Xcode → Product ▸ Archive).
2. In Xcode Organizer, either:
   - Right-click the new archive ▸ **Show in Finder** ▸ Show Package Contents,
     and confirm `dSYMs/objective_c.framework.dSYM` now exists (alongside
     `Sentry.framework.dSYM`, `App.framework.dSYM`, etc.), OR
   - **Distribute App / Upload** again and confirm the "Upload Symbols Failed /
     did not include a dSYM" warning is gone.
3. The "Copy SPM dSYMs will be run during every build…" yellow warning in the
   Issue navigator should also be gone.

Note: the separate "objective_c.dylib has different framework names for different
architectures" warning is a harmless Flutter SDK bug and is expected to remain —
it does not block App Store submission.
