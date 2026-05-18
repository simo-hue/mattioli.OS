# PROSSIME AZIONI MANUALI (SIMO)

## Configurazione Backend & Store
- [ ] Creare account **Apple Developer Program** ($99/anno).
- [ ] Creare account **Google Play Console** ($25 una tantum).
- [ ] Configurare **Sign in with Apple** (Integrazione a 360°):
  - [ ] **In Xcode**: Apri il progetto con `open ios/Runner.xcworkspace`. Seleziona il target `Runner` a sinistra, vai sulla scheda **Signing & Capabilities**, clicca in alto su **+ Capability** e fai doppio clic su **Sign in with Apple**. Questo genererà automaticamente il file `.entitlements` corretto.
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

## Dettagli Obbligatori per la Privacy Policy (Sito Web)
- [ ] **Aggiorna la pagina web della Privacy Policy** (`https://simo-hue.github.io/mattioli.OS/`) includendo questi elementi essenziali per la compliance GDPR:
  - **Titolare del Trattamento**: Nome, Cognome (o ragione sociale) e un indirizzo email di contatto per esercitare i diritti.
  - **Dati Raccolti**: Specifica che raccogli l'email (per l'autenticazione) e i dati inseriti dall'utente (abitudini, obiettivi, mood).
  - **Finalità del Trattamento**: Spiega che i dati servono esclusivamente per fornire il servizio dell'app e non vengono ceduti a terzi.
  - **Responsabili del Trattamento (Sub-processors)**:
    - **Supabase**: Specifica che è il provider cloud per il database e l'autenticazione.
    - **Sentry**: Specifica che è il servizio usato per monitorare i crash e migliorare l'app (indicando che l'invio è facoltativo e basato sul consenso).
  - **Diritti dell'Utente**: Elenca il diritto di accesso, rettifica, cancellazione (diritto all'oblio) e revoca del consenso (tutti esercitabili direttamente dalle impostazioni dell'app).
  - **Base Giuridica**: Specifica che il trattamento si basa sull'Esecuzione di un contratto (per l'uso dell'app) e sul Consenso (per i crash log di Sentry).

- [ ] **Inizializzazione Cartella Android**: Se prevedi di pubblicare l'app anche sul Google Play Store, tieni presente che attualmente manca la cartella `android/` nel progetto. Puoi rigenerarla eseguendo `flutter create --org com.simo --platforms android .` nella cartella principale (`mobile/`), per poi configurare icone, permessi e integrazioni native (come per Supabase e Sentry).
