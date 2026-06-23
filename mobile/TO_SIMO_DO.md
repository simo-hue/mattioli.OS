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
