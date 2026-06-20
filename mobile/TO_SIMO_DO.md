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
---

## 🍏 Pubblicazione iOS (App Store Connect)
- [ ] Incrementa versione e build number in `pubspec.yaml` (es. `1.0.0+2`).
- [ ] Esegui `flutter clean`, `flutter pub get`, e poi genera l'IPA con `flutter build ipa --release`.
- [ ] Apri Xcode, vai su **Product > Archive**, quindi clicca **Distribute App** e seleziona **App Store Connect > Upload**.
- [ ] Per tutti i dettagli su Privacy, Review Settings (bypass per l'Apple Reviewer) e acquisti In-App, fai sempre riferimento al file [app_store_connect_guide.md](app_store_connect_guide.md).
