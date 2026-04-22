# DOCUMENTATION

- [2026-04-22 09:15]: Implementazione Viste Dashboard
  *Details*: Implementate le visualizzazioni settimanale, annuale e vita per pareggiare le funzionalità della PWA.
  *Tech Notes*: 
    - Creato `WeeklyViewWidget`: visualizzazione a capsule colorate con navigazione settimanale.
    - Creato `YearlyViewWidget`: density plot mensile per l'intero anno.
    - Creato `LifeViewWidget`: griglia di mesi della vita con statistiche di longevità e produttività.
    - Integrati i nuovi widget in `dashboard_screen.dart`.
    - Pulizia lints e ottimizzazione performance (uso di `CustomPainter` per la vista vita).
