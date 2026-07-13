# App Store publish checklist — Evolve 1.0.9 (build 13)

_(Note 2026-07-13: superseded — `mobile/pubspec.yaml` now declares 1.1.1+16, and 1.0.9/build 13 has already shipped. This checklist targets an old version.)_

Steps to do before submitting. Code is done (194/194 tests, `flutter analyze`
clean); everything below is setup/verification that can't be done from the repo.

## 1. Before building
- [ ] **Restore the real config files** — these are git-ignored and currently hold
      PLACEHOLDER values. Without the real ones, Cloud mode + login, crash
      reporting, and AI all ship broken:
  - `mobile/lib/core/supabase_config.dart` (URL + anon key + Google client IDs)
  - `mobile/lib/core/sentry_config.dart` (DSN)
  - `mobile/lib/core/openrouter_config.dart` (API key)
- [ ] `git push` — `main` is ahead of `origin`.

## 2. Build & verify (on your Mac — needs full Xcode + CocoaPods)
- [ ] `cd mobile && flutter build ios` — the real release build (couldn't be run
      in the dev environment; only Command Line Tools there).
- [ ] Launch on a device and eyeball the 3 recent visual changes:
      profile photo is not black on the dashboard · yearly-view month bars are
      colored red→green by performance · calendar day cells are a clean centered
      number (no dots).
- [ ] **Cloud-mode import smoke test** (logged into a cloud account): a merge
      import with a new category succeeds (no "Import Failed"); a replace import
      repopulates fully; a backup with a bad row imports the rest and shows the
      "⚠ N invalid record(s) skipped" note. (Detail in `mobile/TO_SIMO_DO.md`.)

## 3. App Store Connect & submit
- [ ] Create/prepare the **1.0.9** version in App Store Connect.
      _(Note 2026-07-13: app is now at 1.1.1 (build 16); this 1.0.9 step is stale.)_
- [ ] Publish release notes: `cd mobile/ios && fastlane ios update_notes`
      (needs the editable 1.0.9 version to exist + Apple ID login). Notes:
      "Smarter data import & fixes" (localized across 18 languages).
- [ ] Re-confirm **App Store privacy** answers and `ITSAppUsesNonExemptEncryption`.
- [ ] Archive in Xcode (or Transporter) → upload **build 13** → submit for review.
