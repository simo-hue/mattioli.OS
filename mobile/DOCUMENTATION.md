# DOCUMENTATION

- [2026-04-22 10:33]: Riavvio Applicazione e Guida Comandi
  *Details*: Riavviata l'app per visualizzare le modifiche alla schermata statistiche e creato il file di riferimento per i comandi Flutter.
  *Tech Notes*: 
    - Eseguito `flutter run` su iPhone 17.
    - Creato `mobile/FLUTTER_COMMANDS.md`.

- [2026-04-22 10:07]: Avvio Simulatore iOS e Debug
  *Details*: Avviato il simulatore iPhone 17 e lanciata l'applicazione in modalità debug per testare le ultime modifiche alle statistiche.
  *Tech Notes*: Eseguito `flutter run` con successo su iPhone 17.

- [2026-04-22 09:15]: Implementazione Viste Dashboard
  *Details*: Implementate le visualizzazioni settimanale, annuale e vita per pareggiare le funzionalità della PWA.
  *Tech Notes*: 
    - Creato `WeeklyViewWidget`: visualizzazione a capsule colorate con navigazione settimanale.
    - Creato `YearlyViewWidget`: density plot mensile per l'intero anno.
    - Creato `LifeViewWidget`: griglia di mesi della vita con statistiche di longevità e produttività.
    - Integrati i nuovi widget in `dashboard_screen.dart`.
    - Pulizia lints e ottimizzazione performance (uso di `CustomPainter` per la vista vita).
- [2026-04-22 09:16]: Build e Avvio su Simulatore
  *Details*: Riavviato il simulatore iPhone 17 e completata la build dell'applicazione per verificare le modifiche.
  *Tech Notes*: App lanciata con successo su iPhone 17 (SimRuntime.iOS-26-4).
- [2026-04-22 09:35]: [Flutter] Implementazione Daily Check-in Modal
  *Details*: Aggiunto il modale per il tracciamento giornaliero di umore ed energia (Mood & Energy).
  *Tech Notes*: 
    - Creato `DailyCheckInModal` utilizzando `showModalBottomSheet`.
    - Implementati slider personalizzati con feedback aptico e icone dinamiche.
    - Collegato all'icona del cuore nel `ProtocolloPanel`.

- [2026-04-22 09:38]: [Flutter] Gestione Abitudini e Refactoring State
  *Details*: Implementata la gestione completa delle abitudini (aggiunta, modifica, eliminazione e riordinamento manuale).
  *Tech Notes*: 
    - Refactor `goalsProvider` da `Provider` a `NotifierProvider` per supportare operazioni CRUD.
    - Creato `HabitManagementModal` con `ReorderableListView` per il drag & drop delle abitudini.
    - Implementata selezione colori e logica di editing/salvataggio.
    - Collegato all'icona dell'ingranaggio (Settings) nel `ProtocolloPanel`.

- [2026-04-22 09:40]: [Flutter] Ottimizzazione Responsività Globale
  *Details*: Tutte le visualizzazioni della dashboard sono state rese responsive per adattarsi perfettamente all'altezza di qualsiasi dispositivo iOS.
  *Tech Notes*: 
    - Implementato calcolo dinamico dell'aspect ratio per la vista annuale (6 righe fisse).
    - Utilizzato `Expanded` e `LayoutBuilder` per distribuire lo spazio tra header e area contenuti.
    - Aggiunto scorrimento interno ai singoli widget per mantenere fissi gli elementi di navigazione superiori.

- [2026-04-22 09:47]: [Flutter] Implementazione Note Veloci
  *Details*: Aggiunto un modale per le note veloci con salvataggio automatico persistente.
  *Tech Notes*: 
    - Aggiunto package `shared_preferences` per il salvataggio in locale.
    - Creato `NoteNotifier` (Riverpod `AsyncNotifier`) per gestire l'I/O asincrono su `SharedPreferencesAsync`.
    - Implementato `QuickNotesModal` con un'interfaccia pulita, text area full-screen e salvataggio con debouncing (800ms).
    - Collegato all'icona del documento in `ProtocolloPanel`.

- [2026-04-22 10:04]: [Flutter] Implementazione Statistiche (Tab Info)
  *Details*: Creata la base per la schermata delle statistiche e completata fedelmente l'implementazione del tab "Info".
  *Tech Notes*:
    - Refactor di `dashboard_screen.dart` per supportare navigazione a schede via `IndexedStack` collegato ad `AppBottomNavBar`.
    - Creato `StatisticsScreen` con header personalizzato, selettore dei goals (mockup basato sui dati reali) e barra dei tab (`Info`, `Trend`, `Alert`, `Abitudini`, `Mood`).
    - Modificata l'intera schermata per utilizzare `SingleChildScrollView`, permettendo ad header, tab e contenuto di scorrere come un'unica pagina fluida per massimizzare lo spazio dei contenuti.
    - Creato `InfoTabWidget` contenente la griglia delle metriche principali (Completamento, Miglior Serie, Top Performer, Giorno Peggiore).
    - Implementata la sezione "Abitudini Chiave" con scroll orizzontale, calcolo delle correlazioni e badge per connessioni e media.
    - Aggiunte le sezioni "Analisi Correlazioni", "Correlazioni Positive" e "Correlazioni Negative" utilizzando box e detail card stilizzate come da PWA.
    - Aggiunta la sezione "Attività Recente" in fondo al tab Info, implementata con una heatmap a griglia in stile GitHub (matrix di pallini con 5 livelli di intensità cromatica).
    - Implementato il selettore "Tutti gli Habits" tramite bottom sheet. La selezione di un habit specifico modifica dinamicamente i tab della pagina (`Overview`, `Calendario`, `Performance`, `Miglioramento`, `Mood`).
    - Creato `HabitOverviewTabWidget` per la visualizzazione "Overview" di un singolo habit. Include una griglia per le metriche chiave (Serie attuale, Record, Completamento, Mancati), un blocco "Trend Ultimi 30 Giorni" a griglia colorata per i successi/fallimenti e una sezione avanzata per le Correlazioni specifiche (Positive e Negative) isolate per l'abitudine selezionata.
    - Creato `HabitCalendarioTabWidget` per il tab "Calendario" del singolo habit, raffigurante un heatmap annuale esteso con dati mock per 365 giorni e relativa legenda (Completato, Mancato, Non tracciato).
    - Creato `HabitPerformanceTabWidget` per il tab "Performance". Include un grafico a barre responsive personalizzato per visualizzare il completamento per giorno della settimana (da Lun a Dom) e due box di approfondimento: "Giorno più debole" (rosso) e il nuovo richiesto "Giorno più forte" (verde).
    - Creato `HabitMiglioramentoTabWidget` per il tab "Miglioramento", comprendente la card "Serie Negativa Peggiore" con l'icona rossa, l'elenco degli "Streak Interrotti" in box arrotondati e la sezione "💡 Suggerimenti" finale, il tutto perfettamente fedele al design system.
    - Creato `HabitMoodTabWidget` per il tab "Mood", implementando una griglia di metriche di correlazione (Mood ed Energia), un grafico a barre comparativo "Completato vs Mancato" e un grafico a linee avanzato (tramite CustomPaint) per la "Performance per Livello" (Basso, Medio, Alto), completo di leggende animate e footer informativo.
    - Rinominate le label dei tab per una migliore visualizzazione su mobile: `Overview` -> `Info`, `Calendario` -> `Trend`, `Performance` -> `Stats`, `Miglioramento` -> `Alert`. Questo risolve i problemi di wrapping e sovrapposizione su schermi piccoli.

