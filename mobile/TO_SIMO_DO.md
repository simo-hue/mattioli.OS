# PROSSIME AZIONI MANUALI (SIMO)

## 2026-06-17 - Private Mode Phase 1 manual QA before release

- [ ] On iOS, complete onboarding/consent, open the login screen, choose Private mode, create habits, macro goals, custom categories, moods, profile data, settings, reminders, and export/delete private data.
- [ ] Relaunch the app and confirm the saved active mode reopens Private mode automatically without Supabase login.
- [ ] Return to login from Private mode and confirm the Supabase login/sign-up path still behaves exactly as before.
- [ ] On Android, repeat the same Private mode local-storage flow and confirm iCloud/CloudKit options are not visible.

---

## 2026-06-23 - Private Mode follow-ups: manual / external-only items

These are the items from PRIVATE_MODE_DISCOVERY.md that CANNOT be completed in code alone (all in-code fixes are done & committed):

  - Precise MSA Arabic authored as nested `lib/i18n/ar.i18n.json` (908 leaves, full key/placeholder parity with `en`). NOTE: the old `tool/arb_to_slang.py` "add `ar` + regenerate" path is now obsolete — the slang JSON is hand-maintained nested namespaces, so `ar` is authored directly like the other locales (slang auto-discovers it). The legacy flat `lib/l10n/app_ar.arb` is left in place (removed in the plan's final demolition with the other ARBs).
  - Language picker option restored (`app_settings_screen.dart`); `AppLocale.ar` + `AppLocaleUtils.supportedLocales` now include Arabic; `main.dart` `_appLocaleFor` resolves `ar` correctly.
  - RTL pass: physical `EdgeInsets.only`/`Alignment`(content)/`Positioned` → `*Directional`; 17 directional chevrons mirrored via new `lib/core/rtl.dart` (`DirectionalIcon` / `directionalIcon`).

  **Still needs a human + a device (cannot be done in code):**
  - [ ] **Native-Arabic + VoiceOver visual QA on device** for every screen (the inherent RTL sign-off).
  - [ ] **Human translation review** of `lib/i18n/ar.i18n.json` (MSA quality/terminology; brand terms `Evolve`/`Pro`/`AI` kept in Latin by design).
  - [ ] **Verify the 3 intentionally-skipped physical spots in RTL** and convert if QA shows they should mirror: decorative gradients (`begin/end: topLeft/bottomRight`, cosmetic); the year/week slide-transition direction (`yearly_view_widget.dart:70-71`, `weekly_view_widget.dart:97-101`, logic-driven by `_slideDirection`); and `fl_chart` RTL layout incl. the y-axis label padding at `macro_goals_stats_view.dart:1528`.
- [ ] **Phase 2 — iCloud/CloudKit sync** — not started (intentional). Before any sync code can run/test: create & configure the CloudKit container in the Apple Developer portal, add the iCloud + (if used) Keychain-sharing entitlements to the iOS target, and plan two-device testing. The Dart `PrivateSyncService` is a no-op placeholder ready for the native bridge.
- [ ] **Optional future test infra** — delete-private-data and notification-action routing tests need either a real SQLCipher DB in tests (add `sqflite_common_ffi` + verify sqlcipher ffi support) or making `NotificationService`'s store injectable. Deferred (lower value; the no-Supabase-call + settings-separation guards already cover the core promise).

---

## 2026-06-23 - iCloud Sync (Private Mode Phase 2): manual Apple steps

The full Dart sync stack + native Swift bridge are implemented and unit-tested
(see ICLOUD_SYNC_PLAN.md). These steps require your Apple account / a device and
CANNOT be done from code:

- [ ] In the Apple Developer portal / Xcode (Runner target → Signing &
      Capabilities): add the **iCloud** capability with **CloudKit** and create/
      select the container **`iCloud.com.simo.evolve`** (already referenced in
      `ios/Runner/Runner.entitlements`). Without the provisioned container a
      signed build will fail.
- [ ] First run on a device: the CloudKit **schema auto-creates in Development**
      (record type `PrivateRecord`, zone `PrivateZone`). Then **promote the
      schema to Production** in the CloudKit Dashboard before App Store release.
- [ ] **Two-device QA** (the parts unit tests can't cover): enable on a fresh
      2nd device (pulls all); both-had-data merge; offline edits converge;
      delete-private-data wipes iCloud and doesn't resurrect; iCloud signed-out
      shows status but never blocks local mode; confirm CloudKit Dashboard shows
      only opaque encrypted `payload` blobs.
- [ ] Update **App Store privacy** answers (data now syncs to the user's own
      iCloud; still no third-party servers) and re-confirm
      `ITSAppUsesNonExemptEncryption`.
- [ ] Remaining in-app refinements (not blocking; the settings UI, foreground
      sync, manual "Sync now", UI-refresh-after-pull, and delete-reset wiring are
      DONE): the debounced **after-write** sync trigger and **avatar CKAsset**
      sync. The engine/service/bridge/UI they build on are complete.

### 2026-07-01: Fix Statistics for imported data
The backup import service now correctly calculates streaks. If your statistics page is still showing 0 for past data, you will need to **re-import your backup** or manually trigger a recalculation on the local database for historical logs.
---

## iCloud Sync / Privacy bug-fix pass (2026-06-26, branch `fix/icloud-sync-privacy-bugs`)

Manual actions required for the fixes landed this session (see `ICLOUD_SYNC_PRIVACY_BUGS.md` for full status table):

- [ ] **On-device verify #3 (CloudKit channel under Scene lifecycle).** The fix
      registers `CloudKitSyncBridge` in `SceneDelegate.scene(willConnectTo:)`.
      This cannot be unit-tested — run on a real device/simulator and confirm
      `accountStatus` returns a real value (no `MissingPluginException`) and a
      first sync works. The Dart bridge now degrades gracefully if the channel
      is ever missing, so a regression would show as "sync unavailable" rather
      than a crash.
- [ ] **#11 disclosure copy (product, not code).** "Delete private data" only
      wipes the originating device's iCloud copy; another enabled device will
      resurrect the data on its next sync. The settings/reset disclosure must
      tell the user to run delete on **each** device. Confirm the copy before
      release.
- [ ] **(Pre-existing, not from this work) Full `flutter test` is blocked
      locally** by two missing files that this environment doesn't generate:
      `lib/core/sentry_config.dart` (git-ignored secret) and
      `lib/i18n/translations.g.dart` (code-gen output). 16 non-sync suites fail
      to *load* because of them. All iCloud-sync/privacy suites compile and pass.
      Run `dart run slang` (or your i18n codegen) and provide `sentry_config.dart`
      to exercise the full suite.
