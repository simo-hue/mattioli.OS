# 🍎 Guida Completa alla Pubblicazione di Evolve su App Store Connect

Questa guida ti accompagna passo dopo passo nella configurazione di **Evolve - Daily Habits & Goals** su App Store Connect. Ogni sezione corrisponde esattamente ai pannelli che troverai sulla dashboard di Apple Developer.

---

## 📋 Indice dei Pannelli da Configurare
1. [Informazioni sull'App (App Information)](#1-informazioni-sullapp-app-information)
2. [Prezzi e Disponibilità (Pricing & Availability)](#2-prezzi-e-disponibilità-pricing--availability)
3. [Privacy dell'App (App Privacy) - *FONDAMENTALE*](#3-privacy-dellapp-app-privacy)
4. [Preparazione per la Sottomissione (Versione 1.0.0)](#4-preparazione-per-la-sottomissione-versione-100-prepare-for-submission)
5. [Accordi e Acquisti In-App (Subscriptions & Paid Agreements)](#5-accordi-e-acquisti-in-app-subscriptions--agreements)

---

## 1. Informazioni sull'App (App Information)
Questo pannello contiene i dati globali dell'applicazione, visibili a livello internazionale sull'App Store.

| Campo | Valore Consigliato | Limiti & Regole di Apple | Note dell'Esperto |
| :--- | :--- | :--- | :--- |
| **Nome (Name)** | `Evolve - Daily Habits & Goals` | Max 30 caratteri | **29 caratteri.** Perfetto. Evita parole come "App", "Best", "Free". |
| **Sottotitolo (Subtitle)** | `Build Routines & Grow Daily` | Max 30 caratteri | **27 caratteri.** Perfetto. Spiega brevemente il valore fondamentale. |
| **Lingua Principale** | `Italiano` (o `Inglese` se la lingua di default è EN) | - | Se l'app è localizzata in più lingue, configurala qui. |
| **ID Bundle** | `com.simo.evolve` | Deve corrispondere a Xcode | Assicurati che corrisponda esattamente all'App ID registrato su Apple Developer Portal. |
| **SKU** | `com.simo.evolve.sku` | Identificatore interno univoco | Non visibile agli utenti. Usato solo per reportistica interna e finanziaria. |
| **Categoria Primaria** | `Produttività` (Productivity) | Obbligatorio | Rispecchia la natura principale dell'app per habit tracking e goal setting. |
| **Categoria Secondaria** | `Salute e benessere` (Health & Fitness) o `Stile di vita` (Lifestyle) | Opzionale | Ottimo per intercettare utenti interessati al benessere mentale/mood tracking. |
| **Diritti sui Contenuti** | Seleziona: *"No, questa app non contiene... o mostra contenuti di terze parti"* | Obbligatorio | Evolve utilizza contenuti interamente proprietari. |
| **Classificazione Età** | Clicca su **Modifica** e completa il questionario | Obbligatorio | Rispondi **"No"** o **"Mai"** a tutte le domande su violenza, sesso, droghe o gioco d'azzardo. Per la domanda sul "Contenuto web o accesso a internet", rispondi **"No"** (l'app si collega a Supabase ma non ha un browser web aperto all'utente). L'app riceverà una classificazione **4+**. |

---

## 2. Prezzi e Disponibilità (Pricing & Availability)
Gestisce le modalità di distribuzione e il prezzo iniziale di download.

> [!NOTE]
> Poiché Evolve prevede un modello freemium (download gratuito con funzioni statistiche premium bloccate), la configurazione iniziale deve riflettere questo schema.

*   **Prezzo (Price Schedule)**: Seleziona **Gratuita (Free)**.
*   **Disponibilità (Availability)**: Seleziona **Tutti i paesi e territori** (175 paesi) o seleziona solo l'Italia/Europa se vuoi fare un soft-launch.
*   **Metodo di Distribuzione**: Seleziona **Pubblica (Public)**.
*   **Pre-ordine (Pre-orders)**: Lascia disattivato a meno che tu non voglia fare una campagna marketing strutturata prima del lancio (in tal caso dovrai fornire una build approvata con largo anticipo).

---

## 3. Privacy dell'App (App Privacy)
Questo è il pannello più insidioso e spesso causa di rigetti se non compilato correttamente. Apple richiede trasparenza assoluta su come i dati vengono gestiti tramite i tuoi servizi (Supabase per database/auth e Sentry per i crash).

### Step 1: Inserimento degli URL
*   **Privacy Policy URL**: Inserisci `https://simo-hue.github.io/mattioli.OS/` (assicurati che sia online e contenga i dettagli descritti nel file `TO_SIMO_DO.md`!).
*   **User Privacy Choices URL**: Opzionale. Puoi inserire lo stesso URL della Privacy Policy.

### Step 2: Questionario sulla Raccolta Dati (Data Collection)
Alla domanda *"Raccogliete dati da questa app?"*, rispondi **SÌ**. Successivamente, seleziona esattamente le seguenti categorie:

1.  **Informazioni di Contatto (Contact Info)**
    *   Spunta: **Indirizzo email (Email Address)** e **Nome (Name)** (se usi il nome nel profilo).
    *   *Configurazione per l'Email*:
        *   **Utilizzo dei dati (Data Use)**: Seleziona **Funzionalità dell'app (App Functionality)** e **Configurazione dell'account (Account Setup)**.
        *   **Collegato all'utente (Linked to User)**: Seleziona **SÌ** (l'email identifica l'account dell'utente).
        *   **Tracciamento (Tracking)**: Seleziona **NO** (non usi l'email per tracciare l'utente su app/siti di altre aziende).
2.  **Contenuto dell'Utente (User Content)**
    *   Spunta: **Altri contenuti dell'utente (Other User Content)**.
    *   *Configurazione per i Contenuti*:
        *   **Utilizzo dei dati (Data Use)**: Seleziona **Funzionalità dell'app (App Functionality)** (qui risiedono le abitudini, gli obiettivi e il mood dell'utente su Supabase).
        *   **Collegato all'utente (Linked to User)**: Seleziona **SÌ** (le abitudini sono associate al suo account).
        *   **Tracciamento (Tracking)**: Seleziona **NO**.
3.  **Diagnostica (Diagnostics)**
    *   Spunta: **Dati sui crash (Crash Data)** e **Altri dati diagnostici (Other Diagnostic Data)** (dovuto all'integrazione di Sentry).
    *   *Configurazione per la Diagnostica*:
        *   **Utilizzo dei dati (Data Use)**: Seleziona **Funzionalità dell'app (App Functionality)** e **Diagnostica (Diagnostics)**.
        *   **Collegato all'utente (Linked to User)**: Seleziona **NO** (se Sentry è configurato per non inviare l'identificativo dell'utente, altrimenti seleziona SÌ se colleghi i crash log all'UUID di Supabase. Ti consiglio **NO** per semplificare la sottomissione).
        *   **Tracciamento (Tracking)**: Seleziona **NO**.

Al termine, ricordati di **Pubblicare** le risposte sulla privacy (pulsante in alto a destra nel pannello).

---

## 4. Preparazione per la Sottomissione (Versione 1.0.0 Prepare for Submission)
Questo è il pannello operativo principale dove caricherai gli asset visivi e definirai la build.

### A. Screenshot (Screenshot di App Store)
Apple richiede screenshot specifici per i dispositivi con display differenti. I formati obbligatori attuali per iPhone sono:

1.  **Display da 6,7 pollici (iPhone 15 Pro Max / 14 Pro Max)**:
    *   Risoluzione: `1290 x 2796 pixel` (Verticale) o `2796 x 1290 pixel` (Orizzontale).
    *   Quantità: Da 1 a 10 screenshot.
2.  **Display da 6,5 pollici (iPhone 11 Pro Max / Xs Max)**:
    *   Risoluzione: `1242 x 2688 pixel` (Verticale) o `2688 x 1242 pixel` (Orizzontale).
    *   *Nota*: Spesso puoi lasciar scalare gli screenshot da 6.7" a meno che tu non voglia grafiche pixel-perfect dedicate.
3.  **Display da 5,5 pollici (iPhone 8 Plus / 7 Plus)**:
    *   Risoluzione: `1242 x 2208 pixel` (Verticale) o `2208 x 1242 pixel` (Orizzontale).
    *   **MANDATORIO**: Non è bypassabile e serve per i vecchi dispositivi con tasto Home.

> [!TIP]
> **Como generarli velocemente**: Usa il simulatore Xcode. Esegui l'app su un *iPhone 15 Pro Max* (per i 6.7") e su un *iPhone 8 Plus* (per i 5.5"). Premi `CMD + S` sul simulatore per salvare lo screenshot direttamente sul desktop senza alcuna cornice. Puoi poi caricarli direttamente o inserirli in un template Figma premium.

---

### B. Metadati della Versione 1.0.0
Ecco i metadati pronti all'uso basati sul tuo file `app_info.txt`, ottimizzati per i limiti di Apple:

*   **Testo Promozionale (Promotional Text)** *(Max 170 car.)* - **164 caratteri**:
    ```text
    Supera la procrastinazione e migliora te stesso un giorno alla volta. Un'interfaccia premium, statistiche evolute e zero pubblicità per la tua crescita consapevole.
    ```
*   **Parole Chiave (Keywords)** *(Max 100 car.)* - **Esattamente 100 caratteri**:
    ```text
    abitudini,obiettivi,tracker,routine,streak,produttività,crescita,mindset,sfide,diario,grow,self,mood
    ```
    > [!WARNING]
    > **Attenzione**: Questa stringa è di esattamente 100 caratteri (inclusi i separatori). Non aggiungere spazi prima o dopo le virgole. Non aggiungere altri caratteri o Apple restituirà un errore di validazione.
*   **Descrizione (Description)** *(Max 4000 car.)*:
    *(Copia e incolla il testo completo del tuo file `app_info.txt`, a partire da "Evolve è lo strumento definitivo..." fino a "...become who you're meant to be."). Il testo descrive splendidamente l'app ed è perfettamente conforme.*
*   **URL di Supporto (Support URL)**:
    ```text
    https://simo-hue.github.io/mattioli.OS/
    ```
*   **URL di Marketing**: Opzionale. Puoi lasciarlo vuoto o usare lo stesso di supporto.
*   **Copyright**:
    ```text
    2026 Evolve App. All rights reserved.
    ```

---

### C. Caricamento della Build
Per associare la build dell'app al pannello:

1.  Assicurati di aver incrementato la versione e il numero build in `pubspec.yaml`:
    ```yaml
    version: 1.0.0+1
    ```
2.  Genera l'archivio iOS da terminale nella cartella `mobile`:
    ```bash
    flutter build ipa --release
    ```
3.  Apri **Xcode**, vai su *Product* > *Archive*.
4.  Una volta completato l'archivio, clicca su **Distribute App** e seleziona **App Store Connect** > **Upload**.
5.  Attendi la mail di Apple che conferma l'elaborazione della build (solitamente 5-15 minuti).
6.  Torna su App Store Connect, nella sezione **Build**, clicca sul pulsante **+** e seleziona la build appena caricata.

---

### D. Informazioni per la Verifica dell'App (Review Settings)
*Questo è lo scoglio principale in cui cadono gli sviluppatori Supabase / Apple Sign-In.*

Poiché l'app richiede un'autenticazione per funzionare, **DEVI** fornire ad Apple un modo per testarla senza che debbano registrare una vera carta o un vero numero di telefono, e bypassando Apple Sign-In nativo (visto che i tester Apple non hanno il tuo stesso account).

> [!IMPORTANT]
> **🚀 STRATEGIA PURE FREE (CON BYPASS PREMIUM PER IL REVIEWER):**
> Poiché hai deciso di lanciare la versione 1.0.0 completamente **gratuita** con le funzionalità Premium bloccate per tutti gli utenti pubblici (visualizzando il bellissimo popup *"Coming Soon"*), c'è un rischio concreto:
> **La linea guida 2.1 (App Completeness) di Apple vieta esplicitamente pulsanti o sezioni dichiarate come "Coming Soon" o "Under Construction"**, e il reviewer potrebbe rifiutare l'app vedendo il popup di blocco.
>
> **La Soluzione di Ingegneria Geniale (Bypass tramite Supabase):**
> Non devi cambiare una sola riga del codice Flutter! Il tuo `SettingsProvider` carica lo stato `isPro` direttamente dal database Supabase (`data['is_pro'] ?? state.isPro`).
> 1. Registra l'account di test `apple-tester@evolve.com` all'interno della tua app (o crealo da Supabase).
> 2. Vai sul tuo **Supabase Dashboard** > **Table Editor** > seleziona la tabella `profiles`.
> 3. Cerca la riga corrispondente a `apple-tester@evolve.com` e imposta il valore della colonna **`is_pro` su `true`**.
>
> **Il Risultato:**
> * Quando l'**Apple Reviewer** effettua il login, l'app lo riconoscerà istantaneamente come utente **Pro/Premium**, sbloccando tutte le statistiche, i colori accentati e l'AI Coach. Non vedrà mai nessun blocco né il popup *"Coming Soon"*, certificando l'app come completa al 100%!
> * I **normali utenti pubblici**, registrandosi, avranno `is_pro` impostato su `false` di default, visualizzando regolarmente i blocchi premium e il paywall teaser *"Coming Soon"*, pronti per quando attiverai gli acquisti in-app nelle versioni 1.1+.

1.  **Spunta "Accesso richiesto" (Sign-in required)**.
2.  **Nome utente (Username)**: Fornisci la mail di test configurata come PRO su Supabase: `apple-tester@evolve.com`.
3.  **Password**: La password per l'account di test (es. `TesterPass123!`).
4.  **Note per la verifica (Review Notes)**: Incolla queste istruzioni dettagliate in inglese (i reviewer sono spesso internazionali):
    ```text
    Hello Apple Review Team,
    
    To facilitate your review, we have provided a pre-configured, fully unlocked test account:
    - Username: apple-tester@evolve.com
    - Password: TesterPass123!
    
    This account has been pre-granted full "Pro" tier privileges, giving you immediate access to all statistical analysis, habit tracking, goal settings, custom accent colors, and wellness correlations without any paywall gates or restrictions.
    
    Authentication is handled securely via Supabase. If you have any questions or require further access, please contact us at simo.dev.contact@gmail.com.
    
    Thank you for your time and review!
    ```
5.  **Informazioni di Contatto per la Verifica**:
    *   Nome: `Simo`
    *   Cognome: `Hue` (o il tuo cognome reale)
    *   Email: `simo.dev.contact@gmail.com` (o la tua email)
    *   Telefono: `+39 3XX XXXXXXX` (Inserisci il prefisso internazionale `+39` seguito dal tuo cellulare. È obbligatorio in caso Apple debba chiamarti per chiarimenti critici).
6.  **Rilascio della Versione**:
    *   Seleziona **Rilascia manualmente questa versione** (consigliato). In questo modo, una volta approvata l'app, sarai tu a decidere il secondo esatto in cui renderla pubblica nello store.


---

## 5. Accordi e Acquisti In-App (Subscriptions & Agreements)
Se decidi di bloccare le statistiche avanzate o inserire il piano *Lifetime Access* (€99):

### Accordi Finanziari
1.  In App Store Connect, vai su **Business** (nella barra superiore o nel menu principale).
2.  Devi firmare l'accordo **Paid Applications (Applicazioni a pagamento)**.
3.  Fornisci le informazioni fiscali (modulo W-8BEN per gli USA) e le coordinate bancarie (IBAN) per ricevere i pagamenti da Apple. *Senza questo accordo firmato, nessun acquisto In-App funzionerà nei test o in produzione.*

### Creazione dell'In-App Purchase
1.  Vai su **Funzionalità (Features)** > **Acquisti In-App (In-App Purchases)** o **Abbonamenti (Subscriptions)**.
2.  Se offri un accesso a vita una tantum (Lifetime):
    *   Clicca su **+** sotto *Acquisti In-App*.
    *   Seleziona **Non consumabile (Non-Consumable)**.
    *   ID Prodotto: `com.simo.evolve.lifetime` (deve corrispondere all'ID usato nel codice Flutter o su RevenueCat).
    *   Nome di riferimento: `Evolve Lifetime Access`.
    *   Imposta il prezzo (es. Tier equivalente a €99).
3.  Se offri abbonamenti ricorrenti:
    *   Crea un **Gruppo di abbonamento** (es. `Evolve_Premium_Group`).
    *   Crea l'abbonamento all'interno del gruppo (es. Mensile/Annuale).
4.  **IMPORTANTE**: Per ogni acquisto o abbonamento creato, devi caricare uno screenshot dell'app che mostra chiaramente il paywall in cui l'utente può acquistare quel prodotto. Risoluzione richiesta: standard di un qualsiasi iPhone (es. `1242 x 2688`).

---

### 🚀 Checklist Finale Prima di Cliccare "Invia per la Verifica" (Submit for Review)
- [ ] La build è caricata e associata alla versione 1.0.0.
- [ ] Tutti gli screenshot (6.7" e 5.5") sono caricati.
- [ ] Le risposte sulla Privacy dell'App sono state compilate e pubblicate.
- [ ] Le credenziali dell'account di test Supabase sono state inserite e verificate (prova a loggarti sul tuo telefono con quell'account per assicurarti che funzioni!).
- [ ] L'accordo Paid Applications è attivo (se hai acquisti In-App).
- [ ] Gli URL della Privacy Policy e del Supporto sono online e funzionanti.

*Buona fortuna per il lancio di Evolve! Se hai bisogno di aiuto per integrare RevenueCat o configurare i certificati nativi iOS in Flutter, sono qui per guidarti.*
