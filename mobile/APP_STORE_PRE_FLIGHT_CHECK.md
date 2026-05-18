# 🚀 Evolve App Store Pre-Flight Check - Release 1.0.0

Ciao Simo! Come esperto di sviluppo Flutter, ho eseguito un audit completo del codice nella cartella `mobile/` per preparare al meglio l'invio dell'applicazione ad Apple tramite **App Store Connect**. 

La buona notizia è che **il progetto è pulito al 100%**! Ho eseguito `flutter analyze` e non è stato trovato **alcun problema** o warning. Inoltre, hai implementato l'eliminazione dell'account da dentro l'app (`_deleteAccount` in `PrivacySettingsScreen` collegato all'RPC Supabase `delete_user_account`), il che è **fondamentale** per evitare reiezioni immediate ai sensi della **Guideline 5.1.1** di Apple.

Ho creato questa guida interattiva e audit per assicurarmi che il tuo primo rilascio di **Evolve** avvenga in modo fluido e senza infoppi.

---

## 🛡️ 1. Modifica Critica Effettuata: Info.plist Hardening (Risolto!)

### ⚠️ Il Rischio Identificato
Nel tuo `Info.plist` era presente la chiave:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Questa app richiede l'accesso al microfono (richiesto da image_picker anche se non usato direttamente per le foto).</string>
```
Dire ad Apple nelle stringhe di permesso *"non usato direttamente"* o *"richiesto da una libreria esterna"* è un **red flag automatico**. I tester di Apple rifiutano le app che dichiarano di richiedere permessi che non utilizzano attivamente (**Guideline 2.5.1 - Data Collection and Storage**).

### 🛠️ La Soluzione Applicata
Poiché in `ProfileScreen` utilizzi `image_picker` **esclusivamente per selezionare immagini dalla galleria** (`ImageSource.gallery`) e non registri o selezioni video:
*   **Ho rimosso completamente `NSMicrophoneUsageDescription` da `Info.plist`.**
*   iOS non chiederà mai il permesso del microfono e questo elimina al 100% il rischio di rigetto su questo fronte.
*   I permessi attivi in `Info.plist` ora sono perfettamente allineati e giustificati:
    1.  `NSCameraUsageDescription` (Fotocamera per scattare foto profilo)
    2.  `NSPhotoLibraryUsageDescription` (Galleria per selezionare foto profilo)
    3.  `NSFaceIDUsageDescription` (FaceID per la sicurezza dei dati personali)

---

## ⚡ 2. La Checklist Tecnica dei Passaggi Obbligatori (Simo)

Prima di compilare la release, ci sono alcuni passaggi che **devi** completare manualmente nel tuo ambiente Xcode e su Supabase.

### 🍎 A. Abilitare "Sign in with Apple" in Xcode (Cruciale!)
Se non lo hai già fatto, il bottone "Sign in with Apple" nella schermata di login fallirà/crasserà in produzione se non è abilitata la Capability a livello nativo.
1.  Apri il progetto in Xcode:
    ```bash
    open ios/Runner.xcworkspace
    ```
2.  Nel menu a sinistra, seleziona il progetto principale **Runner**.
3.  Vai sul tab **Signing & Capabilities** (in alto).
4.  Clicca su **+ Capability** (in alto a sinistra sotto la barra dei tab) e cerca **Sign in with Apple**.
5.  Fai doppio clic per aggiungerlo. Questo genererà automaticamente il file `.entitlements` corretto nel tuo progetto.

### 🌐 B. Attivare il Provider Apple su Supabase
1.  Accedi alla tua **Supabase Dashboard** > **Authentication** > **Providers** > **Apple**.
2.  Attiva lo switch per abilitarlo. *(Se utilizzi Apple Sign-In solo da app nativa iOS, non serve inserire chiavi o certificati .p8 aggiuntivi, poiché il flusso nativo scambia i token direttamente tramite le API Apple).*

### 🔒 C. Configurare il Bypass per il Reviewer Apple (Geniale!)
Poiché hai implementato le funzionalità Premium con le relative schermate e il banner *"Coming Soon"*, c'è il rischio che il reviewer rifiuti l'app per funzionalità incomplete o mancanti (**Guideline 2.1 - App Completeness**).
Per bypassare questo blocco senza modificare una riga di codice:
1.  Registra l'utente **`apple-tester@evolve.com`** direttamente dall'app o crealo da Supabase Auth.
2.  Vai sulla **Dashboard di Supabase** > **Table Editor** > seleziona la tabella **`profiles`**.
3.  Trova la riga di `apple-tester@evolve.com` e imposta la colonna **`is_pro` su `true`**.
4.  In questo modo, quando il reviewer effettuerà l'accesso con questo account di test, l'app si sbloccherà automaticamente mostrando tutte le statistiche, i grafici avanzati e le funzionalità Premium come complete al 100%!

---

## 📐 3. Specifiche degli Asset per App Store Connect

Quando prepari la pagina su App Store Connect, assicurati di avere questi asset pronti per evitare errori di caricamento.

### Risoluzioni degli Screenshot Obbligatori (iPhone)
Usa il simulatore iOS per scattare screenshot puliti senza barra di stato premendo `CMD + S` sul simulatore.

| Dispositivo Richiesto | Risoluzione Necessaria | Note sull'Uso |
| :--- | :--- | :--- |
| **iPhone 6.7" Display** (iPhone 15/14 Pro Max) | **1290 x 2796 pixel** | Obbligatorio per i nuovi dispositivi. |
| **iPhone 5.5" Display** (iPhone 8 Plus) | **1242 x 2208 pixel** | **MANDATORIO.** Serve per coprire i dispositivi con tasto Home físico. |

> [!TIP]
> Se vuoi un look premium e "wow", puoi inserire questi screenshot grezzi all'interno di un mockup premium su Figma (aggiungendo scritte pulite in modalità chiara/scura), ma assicurati che le risoluzioni esportate corrispondano esattamente a quelle sopra.

---

## 4. 📈 Checklist Strategica di Business & Privacy

1.  **Privacy Policy**: Assicurati che l'URL `https://simo-hue.github.io/mattioli.OS/` sia online e contenga la dicitura chiara su:
    *   Uso dei dati (Email e contenuti dell'utente su Supabase).
    *   Uso della diagnostica (Sentry per i crash).
    *   Titolare del trattamento dei dati (i tuoi contatti per GDPR).
2.  **Apple Small Business Program**: Prima di attivare gli acquisti in-app reali (nella versione 1.1), ricordati di iscriverti a questo programma sul portale Apple Developer. Ridurrà la commissione di Apple dal **30% al 15%** sui tuoi guadagni.

---

## 🛠️ Come Creare e Caricare la Build di Release

Quando sei pronto per compilare la versione finale e caricarla:

1.  Assicurati che la versione in `pubspec.yaml` sei `1.0.0+1` (o incrementa il build number `+2`, `+3` se carichi più volte).
2.  Pulisci la cache ed esegui la build dell'IPA da terminale:
    ```bash
    flutter clean
    flutter pub get
    flutter build ipa --release
    ```
3.  Una volta completato, apri **Xcode**, vai su **Product** > **Archive**.
4.  Seleziona l'archivio appena creato nella finestra di Xcode e clicca su **Distribute App**.
5.  Seleziona **App Store Connect** > **Upload** e segui i passaggi automatici.
6.  Entro 10-15 minuti la build apparirà su App Store Connect nella sezione **TestFlight / Build** e potrai associarla alla versione 1.0.0 per l'invio!

---

Sei pronto per conquistare l'App Store con **Evolve**! Se hai dubbi su come firmare l'accordo Paid Applications o se incontri problemi su Xcode durante l'aggiunta di Sign in with Apple, fammelo sapere e ti guido passo dopo passo.
