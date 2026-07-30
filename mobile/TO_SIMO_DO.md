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
- **App Review resubmission (2026-07-30): the metadata is fixed in the repo but is NOT yet on the App Store.** Everything below needs your Apple account and cannot be done from code.

  1. **Upload the metadata.** From `mobile/ios/`:

     ```bash
     fastlane upload_metadata
     ```

     The lane validates all 39 localisations first and aborts if anything is wrong, so a partial upload cannot happen. It uploads metadata only (no binary, no screenshots) and never auto-submits.

  2. **Verify German and French afterwards.** These two storefronts are currently live with **no Terms of Use link and no privacy link at all** — this is what got 3.1.2(c) cited twice. Confirm the fix actually landed:

     ```bash
     curl -s "https://itunes.apple.com/lookup?id=6770482363&country=de" | grep -c stdeula
     ```

     Expect `1`. Repeat with `country=fr` and `country=mx`. If any returns `0`, the upload did not take and resubmitting will fail on the same guideline.

  3. **Paste the App Review notes.** `mobile/metadata/review_information/notes.txt` is rewritten but `deliver` does not push the App Review Information section — copy it into App Store Connect by hand.

  4. **Record the screen recording Apple asked for.** One continuous take, no cuts, roughly 60 seconds: launch → consent → tap **"Continue without an account"** → create a 6th habit to show no paywall appears → open Profile > Subscription to show "Nothing to buy here" → back out → relaunch and sign in → open Subscription → hold still on the paywall so the plan name, duration, price, per-month price, renewal terms and both links are legible in one frame → tap **Terms of Use (EULA)** and let Apple's page load → back → tap **Privacy Policy** and let it load. The first half answers 5.1.1(v), the second half answers 3.1.2(c), and tapping the links is what proves they are *functional* rather than merely present.

  5. **Reply in the Resolution Center** of submission `70f9af73-8af2-4680-af51-756a2937d273` with that recording. Apple explicitly asked for a reply; leaving it unanswered is worse than a late one.

  6. **Confirm the yearly IAP price is still EUR 49.99.** The descriptions no longer state a price (the app reads it from StoreKit), but `subscription_pane.dart:753` and both `subscription_saving_percent_test.dart` files still use 29.99 as an illustrative figure. They are comments and unit-test inputs, not shipped values, so nothing is broken — but if the real price ever changes, they are the stale documentation you will trip over.

  7. **On-device QA before archiving.** The new `/choose` screen and the Private-mode Subscription screen are covered by widget tests but have never run on hardware. Check specifically: the chooser appears after consent on a fresh install, "Continue without an account" reaches the dashboard, and Settings > Legal opens all four links.
