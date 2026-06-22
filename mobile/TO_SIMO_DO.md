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

## 2026-06-22 - Migrazione Localizzazione a slang (Phase 0)

Vedi `LOCALIZATION_PLAN.md` per il piano completo. La Phase 0 è puramente additiva (il vecchio sistema resta intatto), ma richiede questi passi manuali perché l'SDK Flutter non era disponibile nell'ambiente:

- [x] **Risolvere le dipendenze**: `flutter pub get` (fatto — `pubspec.lock` aggiornato).
- [x] **Generare il codice slang** (prima passata): `dart run slang`.
- [x] **Integrazione slang**: app avvolta in `TranslationProvider`, locale guidato da slang (`settings.language` → `LocaleSettings`), Arabic differito (escluso dall'input slang + rimosso dal picker; sorgente preservata in `lib/l10n/app_ar.arb`). Fatto in `lib/main.dart` + `app_settings_screen.dart` + `tool/arb_to_slang.py`.
- [ ] **⚠️ RI-GENERARE + VERIFICARE** (necessario: ho cambiato l'input slang escludendo `ar`): da `mobile/` esegui di nuovo `dart run slang` (rigenera 4 locale, rimuove `ar` da `AppLocale`), poi `flutter analyze` e `flutter test`. Se `analyze` segnala qualcosa su `TranslationProvider.of(context).flutterLocale` o sulle API `LocaleSettings`/`AppLocaleUtils`, segnalamelo: dipende dalla versione esatta di slang e lo adatto.
- [ ] **Workflow traduzioni**: l'inglese (`lib/i18n/en.i18n.json`) è la sorgente di verità; traduci con AI dall'inglese SOLO chiavi nuove/mancanti, preservando le copie umane esistenti (specialmente la voce italiana di notifiche/AI).
