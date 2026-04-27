# DOCUMENTATION

- [2026-04-23 12:15]: Backend Architecture Guide
  *Details*: Created a detailed guide for transitioning the mobile app from a personal tool with Supabase to a professional, multi-user production backend.
  *Tech Notes*: 
    - Comparative analysis of Supabase, Firebase, and Appwrite.
    - Recommended implementation of Row Level Security (RLS) for multi-tenancy.
    - Architecture proposal using the Repository Pattern with Riverpod.
    - Roadmap for App Store publication (Scaling, Offline support, Monitoring).

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
    - Aggiornata la barra di navigazione inferiore (Bottom NavBar): rinominata l'etichetta `Stats` in `Statistiche` per coerenza con la lingua italiana del resto dell'app.


- [2026-04-22 11:20]: [Flutter] Implementazione Dettaglio Giorno e Ciclo Stati Habit
  *Details*: Implementata la visualizzazione del dettaglio giornaliero al click su un giorno del calendario mensile. Aggiunto il ciclo a 3 stati per il tracciamento delle abitudini.
  *Tech Notes*:
    - Aggiornato `HabitLogsNotifier` per supportare il ciclo a 3 stati: `null` -> `completato` (verde) -> `fallito` (rosso) -> `null`.
    - Implementato `_showDayDetails` in `HabitCalendarWidget` tramite `showModalBottomSheet`.
    - Creato il widget `_GoalLogCard` con estetica premium: bordi e background colorati in base allo stato, icone dinamiche (check/x/circle) e supporto per testo sbarrato (strikethrough) in caso di fallimento.
    - Aggiunto il badge `_StreakBadge` per visualizzare la serie attuale (mock) con icone dinamiche (fiamma/cuore spezzato) e colori coordinati.
    - Integrato feedback aptico al tocco delle card.

- [2026-04-22 11:22]: [Flutter] Bug Fix e Allineamento Stati
  *Details*: Corretti errori di compilazione e allineata la logica di tracciamento in tutte le visualizzazioni.
  *Tech Notes*:
    - Corretti errori di sintassi (parentesi e punti e virgola mancanti) in `habit_calendar_widget.dart`.
    - Aggiunti import mancanti (`flutter/services.dart` e `lucide_icons_flutter`).
    - Aggiornato `weekly_view_widget.dart` per utilizzare il nuovo metodo `cycleStatus` invece del vecchio `toggle`.
    - Aggiornato il widget `_HabitCapsule` nella vista settimanale per visualizzare correttamente lo stato "fallito" (rosso), garantendo coerenza visiva in tutta l'app.

- [2026-04-22 11:23]: [Flutter] Refactor e Integrazione Modale Dettaglio
  *Details*: Estratto il modale di dettaglio giorno come componente riutilizzabile e integrato nella vista settimanale.
  *Tech Notes*:
    - Creato `day_details_modal.dart` contenente `DayDetailsModal`, `GoalLogCard` e `StreakBadge`.
    - Refactor di `habit_calendar_widget.dart` per utilizzare il nuovo componente esterno.
    - Aggiornata la vista settimanale (`weekly_view_widget.dart`) per aprire il pannello di dettaglio al click su una "capsula" di abitudine, permettendo la gestione degli stati (fatto/fallito) tramite lo stesso pannello premium usato nel calendario mensile.

- [2026-04-22 11:27]: [Flutter] Implementazione Tab Trend Globale (Statistiche)
  *Details*: Creata la visualizzazione "Trend" per tutti i goals nella schermata statistiche.
  *Tech Notes*:
    - Creato `GlobalTrendTabWidget` con un grafico ad area smooth personalizzato tramite `CustomPaint`.
    - Implementati selettori di timeframe (Sett, Mese, Anno, Tutto) con feedback aptico e animazioni di selezione.
    - Implementata la sezione "Confronto Temporale" con una griglia responsive di card che mostrano il delta percentuale rispetto al periodo precedente.
    - Integrata la nuova visualizzazione in `StatisticsScreen.dart` per il caso "Tutti gli Habits".
- [2026-04-23 18:10]: Cost Analysis & Backend Deep Dive
  *Details*: Riscritto il backend architecture con focus su costi reali, database schema e integrazione AI.
  *Tech Notes*: 
    - Definizione costi fissi: $99/anno (Apple), $25/una tantum (Google), $25/mese (Supabase Pro).
    - Schema DB dettagliato (profiles, goals, habits, logs).
    - Architettura Edge Functions per AI Coach.
    - Strategia Sync Offline-First.

- [2026-04-25 21:44]: Financial Plan Strategy v2.0
  *Details*: Espansione massiva del piano di business con 4 modelli di monetizzazione.
  *Tech Notes*: 
    - Analisi ricavi netti post-tasse e commissioni store (15%).
    - Inserimento modelli: Subscription, Lifetime, AI Tokens, B2B/Corporate.
    - Definizione metriche KPI (LTV, CAC, Churn Rate).
    - Strategia di mitigazione rischi per costi AI e scalabilità DB.

- [2026-04-27 10:35]: [Flutter] Allineamento Style Selettori (Home vs Obiettivi vs Stats)
  *Details*: Modificato lo stile grafico del selettore del calendario nella Home e del selettore di modalità nella schermata Obiettivi per corrispondere a quello utilizzato nel pannello Statistiche.
  *Tech Notes*:
    - Aggiornato `ViewTabBar` in `lib/ui/widgets/view_tab_bar.dart`.
    - Aggiornato `MacroGoalsScreen` in `lib/ui/screens/macro_goals_screen.dart` (selettore "I miei obiettivi" / "Analisi Performance").
    - Ridotta l'altezza a 44px e raggio bordi a 14px.
    - Rimossi i selettori a icone in entrambi i componenti per una pulizia visiva identica alle statistiche.
    - Allineati i colori: `AppColors.foreground` per il tab attivo e `AppColors.background` per il testo attivo.
    - Regolata la tipografia (Inter, 11px, Bold per attivo) e le ombre.
    - Aggiunto `HitTestBehavior.opaque` per migliorare la reattività del tocco.
- [2026-04-27 10:45]: [Flutter] Sistema Notifiche Mattutine e Serale (21:00)
  *Details*: Integrato il sistema di notifiche programmato con una notifica mattutina per il focus e una serale per il tracciamento e il diario di bordo. Risolto un bug che rendeva lo switch poco reattivo.
  *Tech Notes*: 
    - Aggiunto campo `eveningReview` in `AppSettings` (con persistenza tramite `NotifierProvider`).
    - Aggiornato `NotificationService` con messaggi professionali in stile "mattioli.OS".
    - Mattutina (09:00): "mattioli.OS • Morning Brief".
    - Serale (21:00): "mattioli.OS • Review Serale".
    - Corretto l'uso di `ref.read` nelle callback dei toggle in `NotificationSettingsScreen` per evitare stati obsoleti e garantire la reattività dello switch.
    - Inizializzati esplicitamente tutti i campi in `AppSettings.build()` per prevenire inconsistenze di stato.
