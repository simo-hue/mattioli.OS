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

- [ ] **AI key (5.9)** — `lib/core/openrouter_config.dart` has `apiKey = ''`, so the AI Coach is inert (returns "API key missing"). If AI should function, supply the OpenRouter key via a secure mechanism (e.g. `--dart-define=OPENROUTER_KEY=...` wired into the config), NOT a committed literal. The Private-mode AI external-send consent flow is already implemented and will gate the first call.
- [ ] **Arabic + RTL (5.11)** — deferred by design (see LOCALIZATION_PLAN.md). Re-enabling `ar` requires: add `ar` to `tool/arb_to_slang.py` LOCALES + regenerate, restore the language-picker option, then the RTL pass (physical `Alignment`/`EdgeInsets` → `*Directional`, mirror directional icons, fix `Positioned`), and native-Arabic + VoiceOver visual QA on device. Source is preserved at `lib/l10n/app_ar.arb`. Needs human translation review + device QA.
- [ ] **Phase 2 — iCloud/CloudKit sync** — not started (intentional). Before any sync code can run/test: create & configure the CloudKit container in the Apple Developer portal, add the iCloud + (if used) Keychain-sharing entitlements to the iOS target, and plan two-device testing. The Dart `PrivateSyncService` is a no-op placeholder ready for the native bridge.
- [ ] **Optional future test infra** — delete-private-data and notification-action routing tests need either a real SQLCipher DB in tests (add `sqflite_common_ffi` + verify sqlcipher ffi support) or making `NotificationService`'s store injectable. Deferred (lower value; the no-Supabase-call + settings-separation guards already cover the core promise).
