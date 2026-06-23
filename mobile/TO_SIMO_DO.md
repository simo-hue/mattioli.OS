# PROSSIME AZIONI MANUALI (SIMO)

## Sicurezza & Privacy
- [ ] **Configurazione `url_launcher` per Android (API 30+)**:
  Se l'app punta ad Android 11+ (API 30+), devi aggiungere questo blocco nel tuo `android/app/src/main/AndroidManifest.xml` (fuori dal blocco `<application>`):
  ```xml
  <queries>
      <intent>
          <action android:name="android.intent.action.VIEW" />
          <data android:scheme="https" />
      </intent>
  </queries>
  ```

---

## 🚀 Pubblicazione Android (Google Play Store)

- [ ] **4. Creare la chiave di firma (Keystore)**
  Per pubblicare devi firmare l'app. Da terminale crea una chiave (salvala al sicuro e non perderla mai!):
  `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
  Segui le istruzioni e inserisci una password.

- [ ] **5. Configurare la firma nel progetto (build.gradle)**
  Crea un file chiamato `key.properties` dentro la cartella `android/` con questi dati:
  ```properties
  storePassword=<la tua password>
  keyPassword=<la tua password>
  keyAlias=upload
  storeFile=/Users/simo/upload-keystore.jks
  ```
  Modifica poi il file `android/app/build.gradle` per caricare le configurazioni della chiave come spiegato nella [documentazione ufficiale Flutter](https://docs.flutter.dev/deployment/android#configure-signing-in-gradle).

- [ ] **6. Compilare l'App Bundle (.aab)**
  Genera il pacchetto ottimizzato da caricare sullo store:
  `flutter build appbundle`
  Questo creerà un file in `build/app/outputs/bundle/release/app-release.aab`.

- [ ] **7. Configurare Google Play Console**
  - Vai su [Google Play Console](https://play.google.com/apps/publish) (costa 25$ una tantum).
  - Crea l'app e compila tutti i dati (Screenshot, Descrizioni, Rating Età).
  - Crea una nuova "Release Interna" o "Produzione" e carica il file `.aab` appena generato.
  - Invia in revisione.

---

## 2026-06-17 - Private Mode Phase 1 manual QA before release

- [ ] On iOS, complete onboarding/consent, open the login screen, choose Private mode, create habits, macro goals, custom categories, moods, profile data, settings, reminders, and export/delete private data.
- [ ] Relaunch the app and confirm the saved active mode reopens Private mode automatically without Supabase login.
- [ ] Return to login from Private mode and confirm the Supabase login/sign-up path still behaves exactly as before.
- [ ] On Android, repeat the same Private mode local-storage flow and confirm iCloud/CloudKit options are not visible.

---

## 2026-06-18 - App Store encryption/export compliance check

- [ ] Before the next iOS release, confirm App Store Connect export-compliance answers for the new SQLCipher-based local database encryption. The app uses encryption for local private data protection, so keep `ITSAppUsesNonExemptEncryption` aligned with Apple's current compliance guidance.

---

## 2026-06-23 - Run flutter pub get after pulling test-infra changes

- [ ] `pubspec.yaml` gained a new dev dependency `plugin_platform_interface: ^2.1.8` (used by `test/settings_separation_test.dart`). It was already transitively present, so `pubspec.lock` only changed that entry to `direct dev` (same version). Run `flutter pub get` after pulling so your local `.dart_tool` package config is regenerated; otherwise the new test may fail to resolve the import.

---

## 2026-06-23 - Private Mode follow-ups: manual / external-only items

These are the items from PRIVATE_MODE_DISCOVERY.md that CANNOT be completed in code alone (all in-code fixes are done & committed):

- [x] **Arabic + RTL (5.11) — re-enabled in code (2026-06-23).** Done & verified (`dart run slang` + `flutter analyze` + `flutter test` all green, `slang analyze` → `ar: 0 missing`):
  - Precise MSA Arabic authored as nested `lib/i18n/ar.i18n.json` (908 leaves, full key/placeholder parity with `en`). NOTE: the old `tool/arb_to_slang.py` "add `ar` + regenerate" path is now obsolete — the slang JSON is hand-maintained nested namespaces, so `ar` is authored directly like the other locales (slang auto-discovers it). The legacy flat `lib/l10n/app_ar.arb` is left in place (removed in the plan's final demolition with the other ARBs).
  - Language picker option restored (`app_settings_screen.dart`); `AppLocale.ar` + `AppLocaleUtils.supportedLocales` now include Arabic; `main.dart` `_appLocaleFor` resolves `ar` correctly.
  - RTL pass: physical `EdgeInsets.only`/`Alignment`(content)/`Positioned` → `*Directional`; 17 directional chevrons mirrored via new `lib/core/rtl.dart` (`DirectionalIcon` / `directionalIcon`).

  **Still needs a human + a device (cannot be done in code):**
  - [ ] **Native-Arabic + VoiceOver visual QA on device** for every screen (the inherent RTL sign-off).
  - [ ] **Human translation review** of `lib/i18n/ar.i18n.json` (MSA quality/terminology; brand terms `Evolve`/`Pro`/`AI` kept in Latin by design).
  - [ ] **Verify the 3 intentionally-skipped physical spots in RTL** and convert if QA shows they should mirror: decorative gradients (`begin/end: topLeft/bottomRight`, cosmetic); the year/week slide-transition direction (`yearly_view_widget.dart:70-71`, `weekly_view_widget.dart:97-101`, logic-driven by `_slideDirection`); and `fl_chart` RTL layout incl. the y-axis label padding at `macro_goals_stats_view.dart:1528`.
- [ ] **Phase 2 — iCloud/CloudKit sync** — not started (intentional). Before any sync code can run/test: create & configure the CloudKit container in the Apple Developer portal, add the iCloud + (if used) Keychain-sharing entitlements to the iOS target, and plan two-device testing. The Dart `PrivateSyncService` is a no-op placeholder ready for the native bridge.
- [ ] **Optional future test infra** — delete-private-data and notification-action routing tests need either a real SQLCipher DB in tests (add `sqflite_common_ffi` + verify sqlcipher ffi support) or making `NotificationService`'s store injectable. Deferred (lower value; the no-Supabase-call + settings-separation guards already cover the core promise).
