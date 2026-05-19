# PROSSIME AZIONI MANUALI (SIMO)

## Configurazione Backend & Store
- [x] **Accettare l'accordo Paid Apps (Contratti per App a Pagamento) su App Store Connect**:
  - Accedi ad [App Store Connect](https://appstoreconnect.apple.com/).
  - Vai alla sezione **Business** (o *Accordi, codice fiscale e dati bancari* / *Agreements, Tax, and Banking*).
  - Trova l'accordo **Paid Apps** (Applicazioni a pagamento) e clicca su **Accept** (Accetta) o compila le informazioni fiscali/bancarie se richieste.
  - *Stato attuale*: **ATTIVO & APPROVATO!** (Verificato da screenshot).
- [ ] Creare account **Google Play Console** ($25 una tantum).
  - [ ] **Su Apple Developer Portal**: Accedi a *Certificates, Identifiers & Profiles* > *Identifiers*. Seleziona l'App ID `com.simo.evolve` e verifica che la spunta su **Sign in with Apple** sia attiva.
  - [ ] **Su Supabase Dashboard**: Vai in *Authentication* > *Providers* > *Apple*. Abilita il provider. Se intendi supportare Apple Sign-In esclusivamente su iOS nativo (come è attualmente configurato), ti basta attivare lo switch. Se in futuro vorrai supportarlo su Android/Web, dovrai generare e inserire le chiavi *Services ID*, *Team ID* e il file `.p8` privato forniti da Apple.

## Strategia Business & Revenue
- [ ] Decidere se lanciare l'offerta **Lifetime Access** (€99) per i primi 500 utenti.
- [ ] Verificare i requisiti per l'**Apple Small Business Program** (commissione al 15% invece di 30%).
- [ ] Definire i limiti di utilizzo AI per i vari piani (Basic, Premium, Elite).
- [ ] Valutare l'implementazione di **RevenueCat** o **Glassfy** per gestire gli abbonamenti in modo semplice.

## Verifica White Mode (Post-Implementazione)
- [ ] Verificare che tutte le pagine siano correttamente in modalità chiara quando lo switch è attivo.
- [ ] Controllare la leggibilità del testo (evitare testo bianco su sfondo bianco) in:
  - Schermata di Login/Registrazione (AuthScreen).
  - Impostazioni > Informazioni Personali / Privacy / Notifiche.
  - Modali di gestione abitudini e check-in.
  - Tutte le schede delle Statistiche (Trend, Mood, Performance, etc.).
- [ ] Verificare che i grafici (fl_chart) abbiano legende e assi leggibili sia in Light che in Dark Mode.
- [ ] Confermare che il colore accento cambi automaticamente se quello selezionato è troppo chiaro per lo sfondo bianco (gestito da `SettingsProvider`).

---

comando sentry-cli durante il build di release, ma è un passaggio che va configurato quando sarai pronto per la submission all'App Store.

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

- [ ] **Inizializzazione Cartella Android**: Se prevedi di pubblicare l'app anche sul Google Play Store, tieni presente che attualmente manca la cartella `android/` nel progetto. Puoi rigenerarla eseguendo `flutter create --org com.simo --platforms android .` nella cartella principale (`mobile/`), per poi configurare icone, permessi e integrazioni native (come per Supabase e Sentry).

## 🚀 Preparazione Submission App Store (iOS)
- [x] **Accettare l'accordo Paid Apps** nella sezione *Business* di App Store Connect. (COMPLETATO!)
- [ ] **Aggiornare i Link Legali (EULA & Privacy)** nelle schede informative di App Store Connect.
- [x] **Incrementare il Build Number** in `pubspec.yaml` a `1.0.0+4`.
- [ ] **Verificare RevenueCat prima del nuovo upload**:
  - Entitlement consigliato: `Evolve Pro` oppure `evolve_pro`.
  - Associa entrambi gli SKU App Store Connect all'entitlement Pro:
    - `com.simo.evolve.pro.monthly`
    - `com.simo.evolve.pro.yearly`
  - L'app ora riconosce anche gli SKU StoreKit attivi come fallback, ma la mappatura RevenueCat corretta mantiene dashboard, restore e analytics coerenti.
- [ ] **Rigenerare il pacchetto iOS offuscato per build `1.0.0+4`** eseguendo `flutter build ipa --release --obfuscate --split-debug-info=build/app/outputs/symbols` nella cartella `mobile/`.
- [ ] **Caricare la build tramite Transporter o Xcode Organizer**.
- [ ] **Configurare le credenziali dell'account di test** e le note di risposta nel Resolution Center prima dell'invio.
- [ ] **Risposta suggerita per Resolution Center**:
  - "We fixed the Sign in with Apple post-login crash by making iOS Keychain persistence resilient to duplicate keychain items (`-25299`) during review reinstall/update flows. We also fixed subscription activation/restoration by refreshing RevenueCat customer info after purchase/restore and accepting active StoreKit subscription product IDs as Pro access in addition to RevenueCat entitlements. The new build is `1.0.0+4`."
