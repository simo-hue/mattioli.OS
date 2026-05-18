# 🔐 Guida Dettagliata: Configurazione "Sign in with Apple" e "Google Sign-In"

Ciao Simo! Ora che hai aggiunto la **Capability "Sign in with Apple"** su Xcode, sei a metà strada per avere i due flussi di login nativi più performanti e premium su iOS.

In Flutter, l'integrazione è già interamente implementata nel codice ([auth_provider.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/providers/auth_provider.dart#L187-L277)) ed è configurata in modo **nativo** (utilizzando i token d'identità diretti). Questo significa che l'esperienza utente sarà istantanea e utilizzerà FaceID/TouchID in modo integrato.

Ecco esattamente cosa devi fare adesso su **Supabase**, **Apple Developer Portal** e **Google Cloud Console**.

---

## 🍎 1. CONFIGURAZIONE: SIGN IN WITH APPLE

Poiché utilizziamo l'Apple Sign-In nativo (tramite il pacchetto `sign_in_with_apple`), il flusso è estremamente semplificato per te:

### A. Su Apple Developer Portal (Verifica)
Xcode solitamente lo configura in automatico quando aggiungi la capability, ma è sempre bene fare una rapida verifica:
1.  Accedi al tuo [Apple Developer Account](https://developer.apple.com/).
2.  Vai su **Certificates, Identifiers & Profiles** > **Identifiers**.
3.  Cerca il tuo App ID: **`com.simo.evolve`**.
4.  Scorri l'elenco delle Capability e verifica che la spunta su **Sign in with Apple** sia attiva (colore verde). Se è attiva, sei a posto!

### B. Su Supabase Dashboard (Abilitazione)
Questa è la parte migliore dell'integrazione nativa con Supabase:
1.  Vai sulla tua **Supabase Dashboard** > **Authentication** > **Providers** > **Apple**.
2.  **Attiva lo switch "Enable Apple Provider" su ON.**
3.  **IMPORTANTE (Il Segreto dell'Esperto):** **NON devi compilare i campi** *Services ID*, *Team ID*, *Key ID*, o *Private Key (.p8)* se pubblichi solo l'app nativa su iOS!
    *   *Perché?* Nel flusso nativo iOS, Apple rilascia un `identityToken` sicuro direttamente al dispositivo tramite il chip sicuro dell'iPhone. L'app passa questo token direttamente a Supabase tramite `signInWithIdToken`. Supabase è in grado di decodificare e verificare la firma di questo token utilizzando le chiavi pubbliche di Apple (che sono standard e accessibili a tutti), quindi non ha bisogno dei tuoi segreti di sviluppo privati!
    *   *Quando servono quei campi?* Servono solo se in futuro vorrai supportare Apple Sign-In su Android, Web o Windows (dove non essendoci le API native di iOS, bisogna passare per un redirect web che richiede le credenziali server-to-server di Apple). Per l'App Store, lascia quei campi vuoti e attiva solo lo switch.

---

## 🔑 2. CONFIGURAZIONE: GOOGLE SIGN-IN

Nel tuo codice Flutter sono già impostati i Client ID di Google in [supabase_config.dart](file:///Users/simo/Downloads/DEV/mattioli.OS/mobile/lib/core/supabase_config.dart#L5-L6):
*   `googleWebClientId`: `11071263331-b674gunj429vs8isnkoms7r6rnqukbm5.apps.googleusercontent.com`
*   `googleIosClientId`: `11071263331-qepubluq93tojdo3vti51ah3h09ss57m.apps.googleusercontent.com`

Ecco come configurarli lato Google e Supabase per far funzionare il login.

### A. Su Google Cloud Console (Configurazione)
1.  Accedi alla [Google Cloud Console](https://console.cloud.google.com/).
2.  Seleziona il progetto associato a Evolve (o creane uno nuovo).
3.  **OAuth Consent Screen (Schermata di Consenso)**:
    *   Vai in **APIs & Services** > **OAuth consent screen**.
    *   Imposta il tipo di utente come **External** (in modo che qualsiasi account Gmail possa loggarsi).
    *   Inserisci le informazioni di base dell'app: Nome (`Evolve`), Email di supporto e Dati di contatto dello sviluppatore.
    *   Nelle schede successive, mantieni gli scope di default (email, profile, openid) e completa.
    *   **Stato di Pubblicazione**: Clicca su **Publish App** per renderla attiva ed evitare che gli utenti ricevano un avviso di "App non verificata" (poiché usiamo solo scope non sensibili, non è necessaria alcuna verifica formale da parte di Google).
4.  **Verifica / Creazione Credenziali (OAuth Client IDs)**:
    *   Vai in **APIs & Services** > **Credentials**.
    *   Devi avere esattamente queste due credenziali create:
        1.  **OAuth Client ID di tipo "Web Application"**:
            *   Questo è il tuo `googleWebClientId` (già nel codice). Serve a Supabase per convalidare i token ricevuti dal tuo iPhone.
            *   Authorized Javascript origins / Redirect URIs: Puoi lasciarli vuoti.
        2.  **OAuth Client ID di tipo "iOS"**:
            *   Questo è il tuo `googleIosClientId` (già nel codice).
            *   Nel campo **Bundle ID**, inserisci esattamente **`com.simo.evolve`** (deve corrispondere al millimetro!).

### B. Su Supabase Dashboard (Integrazione Google)
1.  Vai sulla tua **Supabase Dashboard** > **Authentication** > **Providers** > **Google**.
2.  **Attiva lo switch "Enable Google Provider" su ON.**
3.  **Attiva lo switch "Skip Nonce Check" su ON.** *(Questo è fondamentale per le app mobili iOS nativa, in quanto Google e Apple generano i nonce in modo nativo sul dispositivo e saltare questo controllo su Supabase previene errori di mismatch durante la firma).*
4.  Nel campo **Authorized Client IDs** (in fondo alla configurazione Google di Supabase), **DEVI aggiungere entrambi i Client ID** inseriti nel codice, separati da una virgola:
    ```text
    11071263331-b674gunj429vs8isnkoms7r6rnqukbm5.apps.googleusercontent.com, 11071263331-qepubluq93tojdo3vti51ah3h09ss57m.apps.googleusercontent.com
    ```
    *Nota: Inserendo sia il Client ID Web sia quello iOS, Supabase saprà validare correttamente i token provenienti da entrambi i contesti durante il login nativo.*

---

## 🧪 3. COME TESTARE ENTRAMBI IN SIMULATORE / DISPOSITIVO FISICO

### Testare "Sign in with Apple"
*   **Sul Simulatore iOS**: Funziona! Apple ti chiederà di inserire le credenziali del tuo Apple ID (se non sei già loggato nel simulatore) o userà l'account iCloud del simulatore.
*   **Sul Dispositivo Fisico**: Utilizzerà il FaceID/TouchID istantaneo del tuo iPhone per autenticarsi in mezzo secondo.

### Testare "Google Sign-In"
*   **Sul Simulatore iOS**: Google aprirà un foglio Safari protetto all'interno dell'app per permetterti di inserire le tue credenziali Gmail ed effettuare il login.
*   **Sul Dispositivo Fisico**: Funziona allo stesso modo, consentendoti di selezionare al volo uno dei tuoi account Google già salvati sul telefono.

---

Ora hai la mappa del tesoro completa! Con questi switch attivi su Supabase e Google, i tuoi pulsanti premium diventeranno istantaneamente operativi al 100%. 

Se hai bisogno di aiuto per controllare le configurazioni o se incontri un errore specifico durante i test, sono qui per assisterti!
