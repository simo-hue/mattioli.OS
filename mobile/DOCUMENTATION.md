# Project Documentation

## [2026-04-27 18:55]: Authentication UI & Supabase Integration
*Details*: Implemented a premium Login and Signup screen matching the application's tech-focused aesthetic. The system now handles authentication states and persists sessions locally via SharedPreferences, serving as a robust foundation for backend integration.
*Tech Notes*:
- **New Dependency**: Added `supabase_flutter` to `pubspec.yaml`.
- **AuthProvider**: Created a Riverpod `Notifier` to manage authentication state (`isLoggedIn`, `email`, `isLoading`).
- **AuthScreen**: Implemented a glassmorphic login/signup screen with support for Apple and Google login buttons.
- **Navigation**: Updated `GoRouter` in `main.dart` with redirection logic to enforce login.
- **Logout**: Integrated session disconnection in the Profile screen.

---
## [2026-04-28 21:37]: Database Schema Design — Production Mobile

*Details*: Analisi completa del database della web app (`schema.sql`) e design dello schema ufficiale per la versione mobile da pubblicare su App Store e Google Play. Creato `mobile_schema.sql` con le tabelle aggiuntive necessarie.
*Tech Notes*:
- **Nuovo file**: `mobile/mobile_schema.sql` — da eseguire nel SQL Editor di Supabase.
- **Nuova tabella `profiles`**: hub centrale utente. Gestisce impostazioni app, piano PRO, preferenze notifiche/UI. Si auto-crea via trigger `on_auth_user_created` su `auth.users`.
- **Nuova tabella `ai_insights`**: cache JSONB delle analisi AI per tipo+periodo. Evita chiamate duplicate all'LLM.
- **5 nuovi indici**: su `goal_logs`, `goals`, `long_term_goals`, `daily_moods`, `ai_insights` — ottimizzano le query più frequenti dell'app.
- **RLS**: tutte le nuove tabelle usano policy strict `auth.uid() = user_id`. Zero policy open.
- **Compatibilità**: nessuna tabella web viene modificata. Operazione 100% additiva.
- **Bug documentato**: `user_settings` e `reading_logs` della web hanno RLS aperta — NON replicato nella mobile.

---
## [2026-04-30 23:10]: Real Supabase Auth Integration

*Details*: Sostituito il mock login con un'autenticazione reale e funzionante tramite Supabase Auth.
*Tech Notes*:
- **Inizializzazione**: Aggiunto `Supabase.initialize()` nel `main.dart`.
- **Configurazione**: Creato `lib/core/supabase_config.dart` per isolare e gestire URL e Anon Key (aggiungerlo al .gitignore).
- **Provider Auth**: Riscritto `AuthNotifier` in `auth_provider.dart` per utilizzare i metodi reali di Supabase (`signInWithPassword`, `signUp`, `resetPassword`, `signOut`). Implementato l'ascolto di `supabase.auth.onAuthStateChange` per mantenere lo stato costantemente sincronizzato.
- **Provider User**: Modificato `user_provider.dart` per derivare il profilo direttamente dall'utente Supabase connesso.
- **Aggiornamento Dati Utente**: Sostituito il mock update nel `personal_info_screen.dart` con un update reale ai metadati di Supabase Auth (`supabase.auth.updateUser`) e contestualmente alla tabella `profiles`.
- **UI & Errori**: Validazioni reali nei campi input del login, gestione degli errori restituiti da Supabase, e implementazione del "Password Dimenticata".

---
## [2026-04-30 23:40]: Offline-First Settings Sync (Supabase)

*Details*: Riscritto il `settings_provider.dart` per rendere tutte le impostazioni personali persistenti in cloud mantenendo un'esperienza offline istantanea.
*Tech Notes*:
- **SharedPreferences Sincrono**: Caricato `SharedPreferences` in modo sincrono nel `main.dart` prima del `runApp` per evitare flash della UI.
- **Sync Locale/Cloud**: Ogni volta che l'utente cambia un'impostazione (tema, colore, notifiche, privacy) lo stato viene salvato istantaneamente sia localmente (`SharedPreferences`) che remotamente (tabella `profiles` su Supabase).
- **Auto-Restore**: Al login, l'app scarica il profilo Supabase in background e aggiorna le impostazioni locali automaticamente.

---
## [2026-04-30 23:45]: Offline-First Macro Goals Sync

*Details*: Riscritto il `macro_goals_provider.dart` per integrarsi con Supabase in modalità Offline-First.
*Tech Notes*:
- **Cache Locale**: I macro goals vengono salvati e letti localmente come JSON cache in `SharedPreferences`.
- **Ottimizzazione UI (Optimistic Updates)**: Durante la creazione, modifica o eliminazione, l'interfaccia si aggiorna istantaneamente e il caricamento verso Supabase avviene asincronamente in background (senza mostrare caricamenti visivi bloccanti).
- **Integrazione Modello**: Creati `fromJson` e `toJson` nel modello `MacroGoal` compatibili con la tabella `long_term_goals` di Supabase.

---
## [2026-04-30 23:55]: iOS Build Fixes & Dependency Alignment

*Details*: Risolti molteplici errori di compilazione iOS relativi a incompatibilità di versioni dei plugin e errori di tipizzazione Dart.
*Tech Notes*:
- **Google Sign-In**: Downgrade di `google_sign_in` alla versione `^6.2.1` per risolvere errori di costruttore e metodi mancanti riscontrati con la versione 7.2.0. Allineato il `Podfile` con `pod update GoogleSignIn`.
- **Lucide Icons**: Corretto l'utilizzo dell'icona `alertCircle` in `circleAlert` nel `auth_screen.dart`, allineandola con la versione corrente di `lucide_icons_flutter`.
- **Null Safety Fix**: Corretto errore di tipizzazione nel `profile_screen.dart` aggi_fallback per campi opzionali.
- **Ambiente**: Eseguito `flutter clean` e rigenerati i CocoaPods per garantire la pulizia dell'ambiente di build.

---
## [2026-05-01 00:05]: Offline-First Daily Habits (Abitudini Quotidiane) Sync

*Details*: Implementazione completa del sistema di abitudini quotidiane e check-in (Abitudini Quotidiane) sincronizzato con Supabase in modalità Offline-First.
*Tech Notes*:
- **Riscritura Modello**: `lib/models/goal.dart` ora supporta `fromJson`, `toJson` e `copyWith`. Rimosso `isCompleted` statico, ora gestito dinamicamente tramite i log.
- **GoalsNotifier**: Sincronizza la lista delle abitudini con la tabella `goals` di Supabase. Supporta il riordinamento (drag & drop) persistente.
- **HabitLogsNotifier**: Gestisce i log quotidiani (completato/fallito) nella tabella `goal_logs`. Utilizza una mappa locale per una risposta istantanea della UI.
- **Fixed Type Errors**: Corretti gli errori di compilazione in `day_details_modal.dart` e `habit_calendar_widget.dart` dovuti al cambio di tipo del campo `startDate` da `String` a `DateTime`.
- **Google Sign-In API Fix**: Corretto `auth_provider.dart` per essere compatibile con la versione `6.3.0` di `google_sign_in` risolta in `pubspec.lock`.

---
## Current Status
- Authentication UI: **COMPLETED**
- Database Schema Design: **COMPLETED v2**
- Real Supabase Auth: **COMPLETED**
- Personal Settings Sync: **COMPLETED**
- Macro Goals Sync: **COMPLETED**
- Daily Habits Sync: **COMPLETED**
- iOS Build Stability: **COMPLETED**

**Immediate Next Step**:
1. Eseguire uno smoke test completo: Registrazione -> Creazione Macro Goal -> Creazione Abitudine -> Check-in quotidiano.
2. Procedere con le Statistiche (Statistics) se necessario, o l'integrazione AI.

