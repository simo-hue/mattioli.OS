# Documentation - Habit Tracker (Flutter)

## [2026-04-27 10:50] Global Accent Color Implementation
- *Details*: Fixed the "Accent Color" implementation to work globally across the application. Previously, the accent color was only applied in the settings screen, while the rest of the app used hardcoded white (AppColors.primary).
- *Tech Notes*:
  - Replaced `AppColors.primary` and `AppColors.foreground` with `Theme.of(context).colorScheme.primary` in key UI components.
  - Updated `AppTheme.darkTheme` to correctly inject the accent color into the `ColorScheme`.
  - Affected files:
    - `lib/ui/screens/personal_info_screen.dart`: Updated Save button and focus borders.
    - `lib/ui/widgets/habit_calendar_widget.dart`: Updated "Today" highlight and selection borders.
    - `lib/ui/widgets/quick_notes_modal.dart`: Updated loading indicator.
    - `lib/ui/widgets/daily_check_in_modal.dart`: Updated "Update" button and sliders.
    - `lib/ui/widgets/view_tab_bar.dart`: Updated active tab indicator.
    - `lib/ui/screens/macro_goals_screen.dart`: Updated filter toggle.
    - `lib/ui/screens/statistics_screen.dart`: Updated tab navigation.
    - `lib/ui/widgets/macro_goals/add_goal_bar.dart`: Updated submit button.

## [2026-04-27 11:40] Deep Color Consistency: Timeframe Selectors & Heatmaps
- *Details*: Estesa la coerenza del colore accento ai selettori temporali dei grafici e alle mappe di calore (heatmap).
- *Tech Notes*:
    - Aggiornati `_buildSmallTimeframeSelector` e `_buildTimeSelector` per utilizzare `Theme.of(context).colorScheme.primary` per l'elemento selezionato.
    - Aggiornata la heatmap in `HabitCalendarioTabWidget` per utilizzare il colore accento invece del verde standard per i giorni completati.
    - Sostituiti riferimenti a `AppColors.foreground` e `AppColors.muted` con colori dinamici del tema nei toggle.


## [2026-04-27 10:55] Implementazione Feedback Aptico Professionale
- *Details*: Implementato un sistema centralizzato per il feedback aptico che rispetta le impostazioni dell'utente e ottimizza la percezione su iOS.
- *Tech Notes*: 
    - Creato `AppHaptics` in `lib/core/haptics.dart` con alias semantici (`success`, `error`, `action`).
    - Ottimizzato per iOS: `hapticAction` utilizza `mediumImpact` invece di `lightImpact` per essere più percepibile.
    - Convertiti i widget principali (`GoalLogCard`, `AppBottomNavBar`, `HabitCalendarWidget`, etc.) in `ConsumerWidget` per accedere alle impostazioni dell'utente tramite `WidgetRef`.
    - Sostituite tutte le chiamate dirette a `HapticFeedback` con il sistema centralizzato che controlla il flag `hapticFeedback`.
