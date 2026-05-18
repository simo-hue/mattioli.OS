## 📋 INDICE DELLE FASI
- [x] [FASE 3: Verifica Configurazione RevenueCat](#fase-3-verifica-configurazione-revenuecat)
- [ ] [FASE 4: Preparazione, Firma e Compilazione Release Build (Xcode)](#fase-4-preparazione-firma-e-compilazione-release-build-xcode)
- [ ] [FASE 5: Configurazione App Privacy su App Store Connect](#fase-5-configurazione-app-privacy-su-app-store-connect)
- [ ] [FASE 6: Compilazione Note di Verifica (Review Notes) e Invio](#fase-6-compilazione-note-di-verifica-review-notes-e-invio)

### FASE 3: Verifica Configurazione RevenueCat
*Verifica che l'SDK di RevenueCat possa comunicare correttamente con App Store Connect e che le chiavi API nel codice corrispondano.*

- [x] 1. Accedi alla dashboard di [RevenueCat](https://www.revenuecat.com/).
- [x] 2. Assicurati che nel tuo progetto sia presente l'App iOS con il Bundle ID esatto `com.simo.evolve` (Nome: *Evolve (App Store)*, App ID: *appa1177cd260*).
- [x] 3. Controlla che le chiavi di connessione con Apple siano caricate:
  - Genera uno **Shared Secret in-app** su App Store Connect (in *Abbonamenti* > *Shared Secret*) e incollalo su RevenueCat.
  - Carica la **StoreKit 2 API Key** (.p8 file generato in *App Store Connect* > *Utenti e Accesso* > *Chiavi*) su RevenueCat per una sincronizzazione degli acquisti ultra-veloce.
- [x] 4. Nella sezione **Entitlements** di RevenueCat, verifica che sia presente l'entitlement `Evolve Pro` (Perfettamente configurato e allineato al codice!).
- [x] 5. Nella sezione **Products**, aggiungi i due prodotti Apple appena creati:
  - `com.simo.evolve.pro.monthly`
  - `com.simo.evolve.pro.yearly`
- [x] 6. Nella sezione **Offerings**, crea un offering `default`, aprilo e inserisci all'interno:
  - Un package Monthly collegato a `com.simo.evolve.pro.monthly`.
  - Un package Yearly collegato a `com.simo.evolve.pro.yearly`.
- [x] 7. Verifica che nel codice Flutter, all'interno del file di configurazione di RevenueCat (`lib/core/revenuecat_config.dart`), la **chiave API pubblica di iOS** corrisponda a quella generata sulla dashboard (`appl_goBFEcuJEbZZeifRFXecOGHFmhN`).

---

### FASE 4: Preparazione, Firma e Compilazione Release Build (Xcode)
*Prepara Xcode per firmare correttamente l'applicazione ed esegui la compilazione pulita offuscando il codice contro il reverse engineering.*

- [ ] 1. Apri il terminale del tuo Mac.
- [ ] 2. Posizionati nella cartella del progetto Flutter mobile:
  ```bash
  cd /Users/simo/Downloads/DEV/mattioli.OS/mobile
  ```
- [ ] 3. Apri il workspace del progetto iOS su Xcode per impostare le firme automatiche:
  ```bash
  open ios/Runner.xcworkspace
  ```
- [ ] 4. In Xcode (barra a sinistra):
  - Clicca sull'icona blu principale del progetto **Runner**.
  - Seleziona la scheda **Signing & Capabilities**.
  - Spunta la casella **Automatically manage signing**.
  - Alla voce **Team**, seleziona il tuo account Apple Developer attivo.
  - Verifica che **Bundle Identifier** sia configurato esattamente come `com.simo.evolve`.
- [ ] 5. Torna al terminale del Mac ed esegui la pulizia e compilazione offuscata della build di rilascio:
  ```bash
  flutter clean
  flutter pub get
  flutter build ipa --release --obfuscate --split-debug-info=build/app/outputs/symbols
  ```
- [ ] 6. Una volta terminato il comando, troverai il file pronto in `build/ios/ipa/Runner.ipa`.
- [ ] 7. **Caricamento della build**:
  - Apri l'applicazione **Transporter** sul tuo Mac (scaricabile gratuitamente dal Mac App Store).
  - Trascina il file `Runner.ipa` all'interno di Transporter.
  - Clicca sul pulsante **Invia** per caricarlo sui server Apple.

---

### FASE 5: Configurazione App Privacy su App Store Connect
*Risolve il problema originario dell'**App Tracking Transparency (ATT)**. Dobbiamo dichiarare che non tracciamo in alcun modo gli utenti.*

- [ ] 1. Torna su App Store Connect > seleziona la tua app > clicca su **Privacy dell'app** (App Privacy) nel menu a sinistra.
- [ ] 2. Identifica i dati che l'app dichiara di raccogliere (Diagnostica/Sentry, Email, Contenuto dell'Utente).
- [ ] 3. Per ciascuna di queste categorie di dati, fai clic su **Modifica** e alla domanda **"Tu o i tuoi partner di terze parti utilizzate questo dato per scopi di tracciamento?"** (Is this data used for tracking purposes?, rispondi categoricamente **NO**.
  *Spiegazione: L'app non effettua profilazione pubblicitaria, non vende dati e non condivide informazioni con broker di terze parti. L'uso di Sentry per i crash log o l'autenticazione tramite Supabase sono fini esclusivamente funzionali, non di tracciamento.*
- [ ] 4. Salva e pubblica le modifiche.

---

### FASE 6: Compilazione Note di Verifica (Review Notes) e Invio
*Fornisce ai reviewer le risposte formali e le spiegazioni puntuali che superano i vecchi rejections.*

- [ ] 1. Su App Store Connect, clicca sulla build appena caricata per prepararla alla sottomissione.
- [ ] 2. Assicurati di **associare i due Prodotti di abbonamento** creati nella Fase 2 alla build prima di inviarla.
- [ ] 3. Scorri in basso fino alla sezione **Note di verifica** (Review Notes / App Review Information) ed inserisci le credenziali di test per consentire l'accesso all'app (email e password di un account utente di prova).
- [ ] 4. Nel box di testo **Note** (Notes) in questa sezione, copia e incolla integralmente il seguente testo in inglese, che affronta e risolve in modo trasparente tutti e tre i vecchi punti bloccanti:

```text
Dear Apple Review Team,

We have carefully addressed all the points identified in the previous review session to ensure Evolve is fully compliant with the App Store Review Guidelines. Below are the details of the improvements and fixes implemented in this build:

1. Regarding App Tracking Transparency (Guideline 2.1a & 5.1.2):
We have completely removed the custom switch card related to Sentry diagnostics during the onboarding screen to avoid any confusion regarding data tracking. We do not perform any third-party user tracking, ad-targeting, or behavioral profile sharing. Sentry is used strictly for diagnostic, stability, and crash-reporting purposes. Consequently, no custom prompts related to tracking are displayed, and we have updated our App Privacy configuration to reflect that we do not track users.

2. Regarding Sign in with Apple compliance (Guideline 4.0):
We have fully redesigned the authentication UX. The application now harvests the user's name and email automatically from the native Authentication Services framework during the initial sign-in and saves it directly to their user profile. Any secondary, custom, or mandatory registration dialog asking for the user's name has been completely bypassed for users authenticating via Sign in with Apple, ensuring a perfectly compliant, native, and consistent experience.

3. Regarding Biometric Authentication Lock (Guideline 4.10):
To comply with the rule against monetizing native iOS capabilities, we have completely opened the biometric lock feature (Face ID / Touch ID) to all users. It is now 100% free and fully functional in the Privacy and Security settings of the app, without requiring any premium subscription or locked states. All visual references to biometric security as a paid premium benefit have been removed from our paywall and onboarding screens and replaced with other app-specific features ("Unlimited Habits").

4. Regarding In-App Purchases (Guideline 2.1b & 2.2):
The in-app purchase subscription products (Monthly and Yearly) are now fully submitted for review alongside this binary build. With the correct store products configured, the dynamic paywall loads successfully and the premium features are fully unlockable and ready for test.

Thank you very much for your time and guidance in helping us deliver a premium, compliant, and safe experience to our users!

Best regards,
Simone Mattioli
```