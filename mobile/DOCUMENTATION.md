# DOCUMENTATION

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
