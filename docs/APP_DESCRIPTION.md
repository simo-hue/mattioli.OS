# 🌿 Evolve - Daily Habits & Goals
> **"better each day, become who you're meant to be!"**

**Evolve** è un ecosistema premium di crescita personale, progettato per chi desidera costruire abitudini solide, definire obiettivi a lungo termine e comprendere a fondo i propri schemi comportamentali. L'applicazione si distingue per un'interfaccia minimale e raffinata, un design estremamente curato e un motore di analisi avanzato privo di distrazioni (zero pubblicità, nessun tracciamento invasivo e massima privacy).

Questo repository contiene il codice sorgente dell'applicazione **Mobile iOS / Android**, sviluppata con il framework **Flutter** e integrata con un backend scalabile e sicuro basato su **Supabase**.

---

## 🛠️ Stack Tecnologico & Architettura Mobile

L'architettura dell'applicazione è progettata seguendo i migliori standard dell'ecosistema Flutter: è **reattiva, robusta, altamente ottimizzata e "offline-first"**.

### 📱 Core Mobile
*   **Framework:** `Flutter (SDK ^3.11.5)` & `Dart` per un'esperienza nativa fluida a 60/120 FPS.
*   **State Management & Caching:** `Flutter Riverpod (^3.3.1)` per una gestione dello stato dichiarativa, combinato con la direttiva `ref.keepAlive()` per memorizzare nella cache locale le query complesse ed evitare continui caricamenti (loading spinners).
*   **Routing:** `Go Router (^17.2.2)` per una navigazione dichiarativa e una gestione pulita dei deep link e delle transizioni.
*   **Local Storage:** `Shared Preferences` (per le preferenze dell'app e stati leggeri) e `Flutter Secure Storage` (per chiavi e dati sensibili cifrati).
*   **Visualizzazione Dati:** `FL Chart (^0.69.0)` per grafici vettoriali premium, interattivi e con supporto alle gesture.
*   **Design & Visuals:** `Google Fonts` (Inter, Playfair Display) e `Lucide Icons Flutter` per un'estetica moderna "minimal-tech".
*   **Localizzazione:** Rilevamento automatico della lingua del dispositivo con supporto dinamico completo per **Italiano** e **Inglese**.

### 🔐 Sicurezza & System Integration
*   **Autenticazione Biometrica:** `Local Auth (^3.0.1)` per il blocco biometrico (Face ID / Touch ID) all'avvio dell'applicazione.
*   **Notifiche Locali ed Eseguibili:** `Flutter Local Notifications (^21.0.0)` con integrazione nativa delle **Notification Actions** (iOS/Android), che consente di registrare l'esito di un'abitudine senza aprire l'applicazione.
*   **Gestione Permessi:** `Permission Handler (^12.0.1)` per la richiesta dinamica e pulita dei permessi di sistema.
*   **Error Tracking:** `Sentry Flutter (^9.20.0)` per il monitoraggio dei crash e delle anomalie in tempo reale.

---

## 🗄️ Backend, Cloud & Database (Supabase)

Il backend dell'app si appoggia a **Supabase (PostgreSQL)**, offrendo un'infrastruttura di livello enterprise a bassissima latenza.

### 🏎️ Database Acceleration & Calcoli del Server
Per ottimizzare la batteria dello smartphone e velocizzare i tempi di risposta, **tutte le elaborazioni statistiche pesanti sono state rimosse dal client** ed esternalizzate a livello database tramite funzioni `PL/pgSQL (RPC)` ottimizzate:
*   `get_habit_analytics`: Estrae l'andamento delle singole abitudini e calcola dinamicamente il "giorno nero" (peggior giorno della settimana).
*   `get_global_trend`: Elabora il tasso di completamento aggregato per diversi orizzonti temporali (Settimana, Mese, Anno, Tutto).
*   `get_critical_habits` & `get_best_habits`: Identifica le abitudini migliori e quelle con il maggior calo di costanza.
*   `get_habit_correlations`: Analizza la correlazione statistica tra diverse abitudini (es. quanto fare sport incida sul leggere la sera).
*   `get_habit_yearly_grid`: Genera una mappa 365 giorni (griglia stile GitHub) per la visualizzazione annuale dello storico abitudini.
*   `get_macro_goals_stats`: Calcola le performance, stagionalità e distribuzione degli obiettivi a lungo termine.

### 🔐 Sicurezza RLS (Row Level Security)
Il database implementa policy RLS rigorose. Ogni tabella (`profiles`, `goals`, `goal_logs`, `macro_goals`, `daily_moods`) applica un isolamento totale basato sul JWT dell'utente autenticato:
```sql
ALTER TABLE macro_goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access their own data" 
ON macro_goals FOR ALL USING (auth.uid() = user_id);
```

---

## 💎 Funzionalità Chiave (Key Features)

### 1. Tracciamento Avanzato delle Abitudini (Habit Tracking)
*   **Notifiche Interattive:** All'orario programmato, l'utente riceve un promemoria personalizzato dinamico (più di 15 messaggi diversi generati per evitare "l'affaticamento da notifica"). Direttamente dalla notifica può cliccare su:
    *   **Fatto:** Segna l'abitudine come completata.
    *   **Salta:** Salta l'abitudine per quel giorno (non interrompe la serie e viene registrata come saltata).
    *   **Posticipa:** Snooza la notifica ri-schedulandola automaticamente dopo 10 minuti.
*   **Apple-style UX:** Inserimento e modifica delle abitudini tramite fogli modali Cupertino, con color picker e time-picker integrati a scomparsa con background blur (`BackdropFilter`).
*   **Streak Dinamici e Sicurezza:** Il calcolo delle serie consecutive viene effettuato a ritroso sui log reali del database. Per garantire l'integrità dei dati, non è possibile registrare o modificare log antecedenti a due giorni fa ("ieri l'altro").

### 2. Definizione e Sviluppo degli Obiettivi (Goal Setting)
*   **Ordinamento Temporale Multi-Livello:** Gestione degli obiettivi a lungo termine suddivisi in base all'orizzonte temporale: *Lifetime (Vita), Annuale, Trimestrale, Mensile e Settimanale*.
*   **Azioni Avanzate:** È possibile segnare un obiettivo come Completato, Fallito, Modificarlo o **Posticiparlo** (spostandolo automaticamente al periodo successivo se i piani sono cambiati).
*   **Categorie Personalizzate:** Creazione e assegnazione di categorie custom dotate di colori unici per un'organizzazione visiva ottimale.

### 3. Analisi Statistica e Correlazioni (Advanced Insights)
*   **Wellness vs Output:** Grafico a linee vettoriale che mette in relazione lo stato emotivo e i livelli di energia registrati (Mood & Energy) con il tasso di produttività reale giornaliero. Aiuta a riconoscere i pattern di burnout e a bilanciare il benessere mentale.
*   **Trend Carousel:** Schede informative che mostrano il confronto temporale rispetto al passato (es. questa settimana vs scorsa settimana), le abitudini più a rischio e le correlazioni (positive e negative) tra i diversi comportamenti.
*   **Analisi dei Fallimenti & Pattern di Recupero:** Monitora le serie negative peggiori (Worst Streaks) e stima il tempo medio di reazione dell'utente per riprendere un'abitudine dopo un giorno mancato.

### 4. Consapevolezza & "Memento Mori" (Life View)
*   **Daily Check-In:** Monitoraggio quotidiano dell'umore e dell'energia con persistenza cloud su Supabase e testi dinamici intelligenti ("Inserisci" o "Aggiorna" se è già stato effettuato).
*   **Life Panel:** Un potente widget basato sulla data di nascita reale inserita nel profilo (gestita con un CupertinoDatePicker) che rappresenta le settimane di vita trascorse e quelle rimanenti sotto forma di griglia visuale compatta. Funge da "Memento Mori" per stimolare a vivere ogni giorno con intenzione.

### 5. AI Coach Chat (Funzione PRO)
*   **Chat Avanzata & Ottimizzata:** Un'interfaccia chat premium con effetto vetro sfocato (glassmorphic), avatar AI con anello gradiente, indicatore di stato online ed entrate animate delle bolle di testo (`FadeInSlide`).
*   **Consigli Contestuali:** L'AI non è una chat generica. Integra automaticamente all'avvio i dati estratti da `macroGoalsProvider`, `goalsProvider` e `habitLogsProvider`. L'intelligenza artificiale risponde conoscendo perfettamente lo stato attuale delle abitudini e degli obiettivi dell'utente.
*   **Ergonomia & Suggerimenti Dinamici:** Suggerimenti di prompt rapidi collocati in basso (sopra la tastiera) che variano dinamicamente in base all'ora del giorno e ai progressi attuali. Supporto per la copia del testo dei messaggi con pressione prolungata e feedback aptico.

### 6. Onboarding Guidato (3-Stage Tutorial)
*   **Tutorial Unskippable:** All'avvio dell'applicazione per la prima volta, si attiva un tour interattivo sviluppato con `tutorial_coach_mark`.
*   **Esperienza Fluida a 3 Stadi:**
    1.  **Dashboard:** Presentazione del Daily Check-In, dell'AI Chat, della gestione abitudini e del calendario.
    2.  **Obiettivi:** Spostamento automatico alla scheda Obiettivi con focus sulla pianificazione, sulle azioni rapide e sui grafici.
    3.  **Statistiche:** Reindirizzamento finale alle schede statistiche generali per illustrare filtri e analisi.
*   **Blocco dell'Interazione:** Durante il tutorial, i tap esterni sono disabilitati e l'utente viene guidato esclusivamente tramite bottoni di controllo ("Avanti", "Indietro", "Fine") per massimizzare la comprensione del flusso.
*   **Schermata Finale Motivazionale:** Una schermata a tutto schermo accoglie l'utente al termine del tour con un messaggio ispiratore.
