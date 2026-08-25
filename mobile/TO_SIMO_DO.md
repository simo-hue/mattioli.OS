# PROSSIME AZIONI MANUALI (SIMO)

## ▶ 1.3.1 (build 50) — release steps

Version and metadata are done and committed. What is left needs your Apple
account, so it cannot be run from here.

1. **Archive and upload the build.** From `mobile/`:

   ```bash
   flutter build ipa --release
   ```

   Version comes from `pubspec.yaml` (`1.3.1+50`) — nothing else to edit.

2. **Upload the metadata.** From `mobile/ios/`:

   ```bash
   fastlane upload_metadata
   ```

   Validates all 39 localisations first and aborts on failure, so a partial
   upload cannot happen. Metadata only — no binary, no screenshots, never
   auto-submits.

3. **Release notes are already in `metadata/`** and go up with step 2. The
   separate `fastlane update_notes` lane now reads the same `locales.json`, so
   the two can no longer disagree — but you only need it if you are editing
   notes on a version already created in App Store Connect.

4. **Verify the storefronts afterwards**, as before:

   ```bash
   for cc in us es de fr mx gb it; do echo -n "$cc "; curl -s "https://itunes.apple.com/lookup?id=6770482363&country=$cc" | grep -c stdeula; done
   ```

   Expect `1` on every line.

5. **Do NOT add demo account fields in App Store Connect.** `demo_user.txt` and
   `demo_password.txt` stay deleted — see the note further down for why.

Note the live listing is **1.1.3**, not 1.3.0: users are upgrading across two
versions, which is why the notes cover 1.3.0's changes too.

---


Manual / on-device / Apple-account steps that can't be done from code. The
in-code work behind each of these is implemented and committed.

---

- ~~**App Store Metadata**: Run fastlane deliver or manually upload the updated metadata (name changes) via App Store Connect since the localized `name.txt` files have been set to "Evolve: Habits & Goals Tracker".~~ *(Completed via Antigravity)*

- **iOS pod warnings (2026-07-30): run `pod install` on the Mac mini, then confirm the archive log is clean.** `ios/Podfile` changed, so the `PODFILE CHECKSUM` in `ios/Podfile.lock` is stale and the per-pod `.xcconfig` files under `ios/Pods/` still carry the old settings — **archiving straight from the Xcode GUI would rebuild with the old flags and the ~260 warnings would still be there.** From `mobile/`:

  ```bash
  cd ios && pod install && cd .. && flutter build ipa
  ```

  (`flutter build ipa` re-runs `pod install` itself when it notices the Podfile changed, so either half is enough — but running it explicitly is what tells you the CocoaPods side is happy.) Then archive as usual and check the log: expected result is **zero** warnings from `SQLCipher`, `FMDB` and `permission_handler_apple`, while any warning in `Runner` or `DeviceActivityMonitorExtension` still shows. Commit the regenerated `ios/Podfile.lock` (its checksum line will have changed) — it is a tracked file. This could not be verified from the laptop: it has Command Line Tools only, no Xcode and no CocoaPods.
- **App Review resubmission (2026-07-30): the metadata is fixed in the repo but is NOT yet on the App Store.** Everything below needs your Apple account and cannot be done from code.

  1. **Upload the metadata.** From `mobile/ios/`:

     ```bash
     fastlane upload_metadata
     ```

     The lane validates all 39 localisations first and aborts if anything is wrong, so a partial upload cannot happen. It uploads metadata only (no binary, no screenshots) and never auto-submits.

  2. **Verify the storefronts afterwards — including US and ES.** Six are currently wrong live, and **two of them are showing a completely different app**:

     | storefront | live state today |
     |---|---|
     | **us** | **description is "Wealth Compass", a personal finance app** — not Evolve, no EULA |
     | **es** | **same Wealth Compass copy, in Spanish** — no EULA |
     | de / fr / fr-CA / el | truncated, no EULA and no privacy link |
     | mx | EULA present, privacy URL cut mid-string |

     en-US is the locale App Review reads first, so this matters more than the guideline that was actually cited. Confirm each one after uploading:

     ```bash
     for cc in us es de fr mx gb it; do echo -n "$cc "; curl -s "https://itunes.apple.com/lookup?id=6770482363&country=$cc" | grep -c stdeula; done
     ```

     Expect `1` on every line. Any `0` means the upload did not take and resubmitting will fail on the same guideline.

  3. **Do NOT paste the demo credentials into App Store Connect's demo-account fields.** `demo_user.txt` and `demo_password.txt` have been deleted on purpose. Fastlane's `deliver` sets `demoAccountRequired = true` whenever both are non-empty, and that flag tells App Review a sign-in is required — the exact opposite of the 5.1.1(v) fix, on the exact submission arguing no account is needed. The credentials are in the notes body instead, framed as optional. If those two fields are already ticked in App Store Connect from a previous submission, **untick them by hand**.

     Note that `deliver` *does* push the rest of the App Review Information section (notes, contact name, email, phone), so `notes.txt` uploads automatically — an earlier version of this file wrongly said it did not.

  4. **Record the screen recording Apple asked for.** One continuous take, no cuts, roughly 60 seconds: launch → consent → tap **"Continue without an account"** → create a 6th habit to show no paywall appears → open Profile > Subscription to show "Nothing to buy here" → back out → relaunch and sign in → open Subscription → hold still on the paywall so the plan name, duration, price, per-month price, renewal terms and both links are legible in one frame → tap **Terms of Use (EULA)** and let Apple's page load → back → tap **Privacy Policy** and let it load. The first half answers 5.1.1(v), the second half answers 3.1.2(c), and tapping the links is what proves they are *functional* rather than merely present.

  5. **Reply in the Resolution Center** of submission `70f9af73-8af2-4680-af51-756a2937d273` with that recording. Apple explicitly asked for a reply; leaving it unanswered is worse than a late one.

  6. **Confirm the yearly IAP price is still EUR 49.99.** The descriptions no longer state a price (the app reads it from StoreKit), but `subscription_pane.dart:753` and both `subscription_saving_percent_test.dart` files still use 29.99 as an illustrative figure. They are comments and unit-test inputs, not shipped values, so nothing is broken — but if the real price ever changes, they are the stale documentation you will trip over.

  7. **On-device QA before archiving.** The new `/choose` screen and the Private-mode Subscription screen are covered by widget tests but have never run on hardware. Check specifically: the chooser appears after consent on a fresh install, "Continue without an account" reaches the dashboard, and Settings > Legal opens all four links.

  8. **Mac claim removed from the descriptions.** All 39 previously said "One app for iPhone, iPad and Mac". The App Store record is `iosUniversal` with `TARGETED_DEVICE_FAMILY = "1,2"` — iPhone and iPad only — so that was a Guideline 2.3.1 exposure on a listing already twice-rejected for metadata. If the Mac app ships later, put the claim back then, not before.

  9. **Promotional text is no longer uploaded.** All 39 `promotional_text.txt` files were deleted: 38 contained only a newline, so `deliver` would have pushed an empty string and *cleared* whatever is live, and the one exception (Italian) was pre-rewrite copy. `deliver` skips fields whose file is absent, so the live values are now left alone. If you want promotional text, add the files back with real content in every locale.
