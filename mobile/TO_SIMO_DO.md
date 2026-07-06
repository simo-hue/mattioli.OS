# PROSSIME AZIONI MANUALI (SIMO)

Manual / on-device / Apple-account steps that can't be done from code. The
in-code work behind each of these is implemented and committed.

## Release prep — before the next App Store build

- [ ] **Restore real config credentials.** Three git-ignored config files were
      regenerated from their `.example` templates with PLACEHOLDER values and
      must get your real values back before a release build (they're git-ignored,
      so they never get committed):
      `lib/core/sentry_config.dart` (empty DSN), `lib/core/supabase_config.dart`
      (`YOUR_SUPABASE_URL` / `YOUR_SUPABASE_ANON_KEY`),
      `lib/core/openrouter_config.dart` (`YOUR_OPENROUTER_API_KEY`).
      Without them, Cloud mode/auth, crash reporting, and AI ship broken.
- [ ] **One real release build** (`flutter build ios`) + a device boot smoke
      test — unit tests and `flutter analyze` don't exercise codesigning, pods,
      or tree-shaking.

## Data-import merge — on-device cloud verification

The cloud import path is unit-tested at the decision layer (`planCloudImport`)
but can't run against a real Supabase in tests. On a logged-in cloud account:

- [ ] **Cloud MERGE with a new category** — import a backup containing a category
      you don't already have; it must succeed (not an "Import Failed" error).
- [ ] **Cloud REPLACE** — a normal replace import fully repopulates the account.
- [ ] **Invalid-row skipping** — import a backup with a bad row (e.g. a habit log
      with `"status":"pending"`); the rest imports and the preview + summary show
      a "⚠ N invalid record(s) skipped" count.
- [ ] **(Optional) Round-trip** — export in Private mode, re-import the `.json`
      in Merge mode; everything should report as *unchanged* (no duplicates).

## iCloud / CloudKit sync — Apple-account steps

The Dart sync stack + native Swift bridge are implemented and unit-tested. These
require your Apple account / a device:

- [ ] Xcode (Runner → Signing & Capabilities): iCloud + CloudKit capability, with
      the container `iCloud.com.simo.evolve` (referenced in
      `ios/Runner/Runner.entitlements`) — a signed build fails without it.
- [ ] Promote the CloudKit schema from Development to **Production** in the
      CloudKit Dashboard before release.
- [ ] **Two-device QA**: enable on a fresh 2nd device (pulls all); both-had-data
      merge; offline edits converge; delete-private-data wipes iCloud without
      resurrecting; signed-out shows status but never blocks local mode.
- [ ] Re-check **App Store privacy** answers (data syncs to the user's own iCloud,
      still no third-party servers) and `ITSAppUsesNonExemptEncryption`.

## Arabic / RTL — human sign-off

The `ar` locale and the RTL pass are implemented. What's left needs a person:

- [ ] Native-Arabic + VoiceOver visual QA on device.
- [ ] Human translation review of `lib/i18n/ar.i18n.json` (MSA quality; brand
      terms Evolve / Pro / AI intentionally kept in Latin).
