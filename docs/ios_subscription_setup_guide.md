# Guida Step-by-Step alla Configurazione Esterna per gli Abbonamenti (App Store Connect & RevenueCat)

Questa guida illustra dettagliatamente tutte le operazioni manuali da eseguire al di fuori del codice per attivare, configurare e testare gli abbonamenti di **Evolve** su iOS utilizzando **RevenueCat** e **App Store Connect**.

---

## 📌 PARTE 1: Configurazione su App Store Connect

Prima di poter vendere qualsiasi prodotto, Apple richiede che il tuo account sviluppatore sia in regola con i contratti commerciali e che i prodotti siano registrati correttamente.

### Step 1: Firmare l'accordo "Paid Applications" (Obbligatorio)
Se non hai completato questo passaggio, i tuoi prodotti risulteranno invisibili (*invalid product identifiers*) durante i test.
1. Accedi a [App Store Connect](https://appstoreconnect.apple.com/).
2. Vai nella sezione **Business** (o *Accordi, codice tributario e dati bancari*).
3. Sotto la scheda **Agreements** (Accordi), individua la riga **Paid Applications** (Applicazioni a pagamento).
4. Clicca su **View and Agree** (Visualizza e accetta) e accetta i termini.
5. Inserisci le tue informazioni fiscali (*Tax Info*) e i tuoi dati bancari (*Banking*) per ricevere i pagamenti. Lo stato deve diventare **Active** (Attivo).

### Step 2: Creare il Gruppo di Abbonamenti
Tutti gli abbonamenti auto-ricorrenti su iOS devono appartenere a un "Gruppo di Abbonamenti". Apple offre agli utenti la possibilità di passare facilmente da un piano all'altro all'interno dello stesso gruppo.
1. Su App Store Connect, vai su **My Apps** (Le mie app) e seleziona **Evolve** (`com.simo.evolve`).
2. Nel menu laterale sinistro, sotto la sezione **Features** (Funzionalità), clicca su **Subscriptions** (Abbonamenti).
3. Clicca sul pulsante **+** accanto a **Subscription Groups** (Gruppi di abbonamento).
4. Assegna un nome al gruppo (es. `Evolve Premium Group`) e clicca su **Create**.

### Step 3: Creare i Prodotti In-App (Mensile, Annuale, Lifetime)
Dobbiamo creare i 3 prodotti che abbiamo definito nel codice Flutter.
_(Nota 2026-07-13: il codice Flutter attuale definisce solo DUE prodotti Pro, mensile e annuale (`proProductIds` in `mobile/lib/core/subscription_service.dart` contiene solo `com.simo.evolve.pro.monthly` e `com.simo.evolve.pro.yearly`, e `subscription_screen.dart` gestisce solo i pacchetti mensile/annuale). Il prodotto Lifetime (`com.simo.evolve.pro.lifetime`) non è supportato dal codice: crealo solo se prima aggiungi il relativo supporto nell'app.)_

#### A. Prodotto Mensile (Abbonamento Auto-Rinnovabile)
1. Dentro il gruppo di abbonamenti appena creato, sotto la sezione **Subscriptions**, clicca su **Create** (o sul pulsante **+**).
2. Compila i campi:
   * **Reference Name**: `Evolve Pro Mensile` (nome visibile solo a te).
   * **Product ID**: `com.simo.evolve.pro.monthly` (deve corrispondere a quello configurato su RevenueCat).
3. Clicca su **Create**.
4. Nella scheda del prodotto mensile:
   * **Subscription Duration**: Seleziona **1 Month** (1 mese).
   * **Subscription Price**: Clicca su **Set Price** e inserisci il prezzo desiderato (es. `€4.99`). Apple calcolerà automaticamente i prezzi corrispondenti per tutte le altre valute del mondo.
   * **App Store Information (Localizzazioni)**: Clicca su **+** sotto la sezione *App Store Information* per aggiungere la lingua italiana (e inglese). Inserisci il titolo visibile agli utenti (es. `Evolve Pro Mensile`) e una breve descrizione (es. `Sblocca AI Coach, statistiche avanzate, FaceID e cloud sync.`).
5. Clicca su **Save**.

#### B. Prodotto Annuale (Abbonamento Auto-Rinnovabile)
1. Torna nel gruppo di abbonamenti, clicca su **+** sotto **Subscriptions** per creare il piano annuale.
2. Compila i campi:
   * **Reference Name**: `Evolve Pro Annuale`.
   * **Product ID**: `com.simo.evolve.pro.yearly` (o `com.simo.evolve.pro.annual`).
3. Nella scheda del prodotto:
   * **Subscription Duration**: Seleziona **1 Year** (1 anno).
   * **Subscription Price**: Imposta il prezzo annuale (es. `€39.99`).
   * **App Store Information**: Aggiungi le localizzazioni compilando titolo (es. `Evolve Pro Annuale`) e descrizione.
4. Clicca su **Save**.

#### C. Prodotto Lifetime (Acquisto In-App Singolo / Non-Consumable)
Il piano Lifetime non è un abbonamento ricorrente, ma un acquisto singolo "una tantum". Va creato in una sezione diversa!
1. Nel menu laterale sinistro di App Store Connect, sotto **Features**, clicca su **In-App Purchases** (e non su Subscriptions).
2. Clicca su **+** per creare un nuovo acquisto In-App.
3. Seleziona **Non-Consumable** (Non consumabile: un acquisto che l'utente effettua una sola volta e non scade mai).
4. Compila i campi:
   * **Reference Name**: `Evolve Pro Lifetime`.
   * **Product ID**: `com.simo.evolve.pro.lifetime`.
5. Clicca su **Create**.
6. Nella scheda del prodotto Non-Consumable:
   * **Price**: Seleziona la fascia di prezzo desiderata (es. `€79.99`).
   * **App Store Information**: Inserisci titolo (es. `Evolve Pro Lifetime`) e descrizione localizzati.
7. Clicca su **Save**.

---

### Step 4: Generare la Chiave "Shared Secret" (Per RevenueCat)
RevenueCat ha bisogno di una chiave condivisa per connettersi ai server Apple e convalidare le ricevute StoreKit 1.
1. Su App Store Connect, vai su **Subscriptions** nel menu a sinistra.
2. Sotto la sezione **Subscription Groups**, individua il pulsante **App-Specific Shared Secret** (Chiave segreta condivisa specifica dell'app).
3. Clicca su di esso e poi su **Generate**.
4. Copia il codice alfanumerico generato (ti servirà tra poco su RevenueCat).

### Step 5: Generare la chiave In-App Purchase Key (Per StoreKit 2 - Consigliato)
Le ultime versioni di RevenueCat (compresa la v10.x.x che abbiamo installato) utilizzano le moderne API StoreKit 2 di Apple.
1. Vai su [App Store Connect > Users and Access](https://appstoreconnect.apple.com/access/users).
2. Seleziona la scheda **Integrations** (Integrazioni) in alto, quindi clicca su **In-App Purchase** nel menu a sinistra.
3. Clicca su **Generate In-App Purchase Key** (o sul pulsante **+**).
4. Assegna un nome alla chiave (es. `RevenueCat Key`) e clicca su **Generate**.
5. Vedrai tre dati fondamentali:
   * **Key ID**: Un codice corto (es. `ABCD1234EF`).
   * **Issuer ID**: Un codice UUID presente in alto nella pagina delle chiavi.
   * **File della chiave privata (.p8)**: Scarica questo file immediatamente (puoi farlo una sola volta!). Tienilo al sicuro.

---

## 💎 PARTE 2: Configurazione sul Dashboard di RevenueCat

RevenueCat funge da cervello centralizzato per i tuoi acquisti. Assocerà i prodotti fisici dell'App Store ai privilegi digitali dell'app.

### Step 1: Creare il Progetto
1. Accedi a [RevenueCat Dashboard](https://app.revenuecat.com/).
2. Clicca su **Create New Project** (Crea nuovo progetto) e assegna il nome `Evolve`.

### Step 2: Aggiungere l'Applicazione iOS
1. All'interno del progetto, clicca su **Apps** nel menu a sinistra e seleziona **Add App**.
2. Scegli **App Store** (iOS).
3. Compila le informazioni:
   * **App Name**: `Evolve`
   * **App Bundle ID**: `com.simo.evolve`
   * **App Store Specific Shared Secret**: Incolla il codice generato al **Step 4 della Parte 1**.
4. Clicca su **Save**.
5. **Opzionale (StoreKit 2)**: Nella scheda dell'app iOS appena creata, abilita StoreKit 2 caricando il file `.p8` scaricato al **Step 5 della Parte 1**, inserendo il relativo *Key ID* e *Issuer ID*. Questo renderà la sincronizzazione degli abbonamenti incredibilmente robusta e veloce.

### Step 3: Registrare i Prodotti su RevenueCat
RevenueCat deve conoscere i Product ID esatti dell'App Store.
1. Clicca su **Products** nel menu a sinistra del dashboard di RevenueCat.
2. Clicca su **New Product**.
3. Registra i tuoi 3 prodotti uno per uno:
   * **Prodotto 1**:
     * Product ID: `com.simo.evolve.pro.monthly`
     * Store: Seleziona **App Store**
   * **Prodotto 2**:
     * Product ID: `com.simo.evolve.pro.yearly`
     * Store: Seleziona **App Store**
   * **Prodotto 3**:
     * Product ID: `com.simo.evolve.pro.lifetime`
     * Store: Seleziona **App Store**

### Step 4: Creare l'Entitlement "Evolve Pro"
Un *Entitlement* rappresenta il livello di accesso o feature sbloccata dal pagamento. Nel nostro codice abbiamo configurato l'Entitlement ID esatto: **`Evolve Pro`**.
1. Clicca su **Entitlements** nel menu a sinistra.
2. Clicca su **New Entitlement**.
3. Imposta l'ID esatto: **`Evolve Pro`** (fai attenzione a maiuscole, minuscole e spazi).
4. Clicca su **Add**.
5. Associa i prodotti creati allo Step 3 a questo Entitlement:
   * Clicca sull'Entitlement `Evolve Pro` appena creato.
   * Clicca su **Attach Product** e seleziona `com.simo.evolve.pro.monthly`.
   * Ripeti e associa `com.simo.evolve.pro.yearly`.
   * Ripeti e associa `com.simo.evolve.pro.lifetime`.

Ora, se un utente acquista uno qualsiasi di questi tre prodotti, RevenueCat saprà che l'utente possiede l'accesso attivo a `Evolve Pro`!

### Step 5: Creare l'Offerta (Offering)
L'offering definisce quali prodotti mostrare all'utente all'interno del Paywall.
1. Clicca su **Offerings** nel menu a sinistra.
2. Clicca su **New Offering**.
3. Imposta come ID: `default` (l'offering predefinita usata dall'app).
4. Clicca su **Add**.
5. Clicca sull'offering `default` appena creata per entrare nel dettaglio.
6. Aggiungiamo i 3 pacchetti standard (*Packages*) richiesti dall'app:
   * **Mensile**:
     * Clicca su **New Package**.
     * Seleziona l'ID standard: **`Monthly`**.
     * Associa questo pacchetto al prodotto: `com.simo.evolve.pro.monthly`.
   * **Annuale**:
     * Clicca su **New Package**.
     * Seleziona l'ID standard: **`Annual`**.
     * Associa questo pacchetto al prodotto: `com.simo.evolve.pro.yearly`.
   * **Lifetime**:
     * Clicca su **New Package**.
     * Seleziona l'ID standard: **`Lifetime`**.
     * Associa questo pacchetto al prodotto: `com.simo.evolve.pro.lifetime`.

Assicurati che l'Offering `default` sia contrassegnata con la spunta **Current** (Attiva) nella lista delle offerte.

### Step 6: Configurare il "RevenueCat Paywall" Grafico (Opzionale)
Hai la possibilità di usare il fantastico builder visivo di RevenueCat direttamente dal browser!
1. Entra nell'offering `default` creata al passaggio precedente.
2. Fai clic sulla scheda **Paywall**.
3. Scegli uno dei bellissimi template moderni pre-costruiti forniti da RevenueCat.
4. Personalizza i colori (puoi usare i codici esatti del tema scuro di Evolve), le icone, i testi dei vantaggi Pro e inserisci le immagini di sfondo.
5. Fai clic su **Save and Publish**.
6. Quando gli utenti cliccheranno su *"Mostra Paywall Grafico di RevenueCat"* all'interno della schermata dell'abbonamento nell'app Evolve, vedranno apparire istantaneamente questo paywall caricato dal cloud!
_(Nota 2026-07-13: nel codice attuale questo pulsante non esiste. I metodi `presentPaywall()`/`presentPaywallIfNeeded()` sono definiti in `subscription_service.dart` ma non vengono richiamati da nessuna schermata, quindi il paywall grafico non è ancora collegato all'interfaccia. È invece collegato il `presentCustomerCenter()`.)_

### Step 7: Configurare il "Customer Center"
Il Customer Center è lo strumento moderno che gestisce rimborsi e cancellazioni per te senza scrivere codice.
1. Clicca su **Customer Center** nel menu a sinistra del dashboard RevenueCat.
2. Clicca su **Enable Customer Center**.
3. Scegli le opzioni da mostrare all'utente:
   * Consenti richiesta di rimborso (*Refund Requests*).
   * Consenti cancellazione dell'abbonamento (*Cancellation Flow*).
   * Mostra lo storico delle fatture (*Billing History*).
4. Definisci le domande a scelta multipla per capire perché l'utente cancella l'abbonamento (es. *"Troppo costoso"*, *"Non lo uso abbastanza"*).
5. Salva. Il Customer Center è ora attivo e risponderà automaticamente alla chiamata `RevenueCatUI.presentCustomerCenter()` che ho implementato nel codice del tuo tasto *"Gestisci Abbonamento"*.

---

## 🧪 PARTE 3: Testare il Flusso in Sandbox (Simulatore o Dispositivo)

Per simulare acquisti reali su iOS senza spendere soldi veri, devi utilizzare un account **Sandbox Tester**.

### Step 1: Creare un utente Sandbox Tester
1. Vai su [App Store Connect > Users and Access](https://appstoreconnect.apple.com/access/users).
2. Sotto la sezione **Sandbox**, clicca su **Testers** (Verificatori).
3. Clicca sul pulsante **+** in alto.
4. Compila i campi usando un indirizzo email reale o fittizio (deve essere un indirizzo email non associato ad alcun Apple ID esistente).
5. Completa la registrazione e imposta una password.

### Step 2: Configurare il Dispositivo di Test (Consigliato dispositivo fisico)
Se usi un dispositivo iOS reale:
1. Vai sulle **Impostazioni** dell'iPhone.
2. Clicca su **App Store** (o *Sottoscrizioni e App Store*).
3. Scorri fino in fondo fino alla sezione **Sandbox Account** (Account Sandbox).
4. Clicca su Accedi e inserisci le credenziali del tester Sandbox creato al passaggio precedente.
*(Nota: Non devi disconnettere il tuo Apple ID principale dall'iPhone! Apple separa l'account App Store principale da quello Sandbox per i test).*

### Step 3: Avviare i Test!
1. Avvia l'applicazione Flutter sul tuo simulatore o iPhone fisico (`flutter run`).
2. Accedi all'applicazione con un account utente.
3. Entra nella pagina degli Abbonamenti.
4. **Verifica**: i prezzi dovrebbero caricarsi istantaneamente mostrando la tua valuta locale (es. `€4.99` o il prezzo da te impostato).
5. Clicca su **Attiva Abbonamento**: vedrai apparire il foglio di pagamento di Apple con la dicitura **[Environment: Sandbox]**.
6. Conferma l'acquisto inserendo la password del Sandbox Tester o usando il FaceID simulato.
7. Una volta completato, l'app si aggiornerà istantaneamente sbloccando le funzionalità PRO ed aggiornando lo stato sia sul database locale che sul cloud di RevenueCat!
