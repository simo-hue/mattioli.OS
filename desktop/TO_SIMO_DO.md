# TO_SIMO_DO

## ▶ 1.4.0 (build 30) — macOS release steps

Version (`pubspec.yaml` `1.4.0+30` — `Info.plist` reads `FLUTTER_BUILD_NAME` /
`FLUTTER_BUILD_NUMBER`, nothing else to edit) and metadata are committed. What
is left needs your Apple account.

1. **Build and upload.** From `desktop/macos/`, with `desktop/.env` in place:

   ```bash
   fastlane release
   ```

   `build_mac_app` runs the Xcode archive, which needs the Supabase dart
   defines — if the archive stops on "Missing required Flutter dart define(s)",
   build the app first with Flutter and archive from Xcode instead:

   ```bash
   cd .. && flutter build macos --release --dart-define-from-file=.env
   ```

   Build 30 assumes 29 was the last one App Store Connect saw for macOS; if
   ASC rejects it, raise the number in `pubspec.yaml` and rebuild.

   **Verified 2026-09-12 on this Mac:** the archive builds (1.4.0 / 30) once
   `pod install` has been run in `macos/` — the `The sandbox is not in sync
   with the Podfile.lock` failure was `Podfile.lock` carrying the FlutterMacOS
   checksum of an older Flutter than the one installed here; the regenerated
   lock is committed. The **export** then stops with `No signing certificate
   "Mac App Distribution" found` / `"Mac Installer Distribution" found` /
   `Unable to log in with account`: the keychain has no distribution
   certificates and Xcode cannot sign in from a shell. Fix once in Xcode →
   Settings → Accounts → sign in → Manage Certificates → **+ Apple
   Distribution** and **+ Mac Installer Distribution**, then re-run `fastlane
   release`. Or open the archive under
   `~/Library/Developer/Xcode/Archives/` in Organizer and use Distribute App.

2. **Release notes** are `macos/fastlane/metadata/<locale>/release_notes.txt`
   (new in this release — there were none before) and go up with `fastlane
   release` or `fastlane metadata`. Localized in the five languages the app
   speaks, English elsewhere. `fastlane update_notes` now reads the same files,
   so the two cannot disagree; it is only needed to edit a version already
   created in App Store Connect.

3. **Check the "Save" flow once on the uploaded build**: open the Habits
   calendar, click a day older than yesterday, Edit, change a number and a
   check-box, Save — the row must show the new values and the streak as of
   that day.

_Added 2026-09-12._
