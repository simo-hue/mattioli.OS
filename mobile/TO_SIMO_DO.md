# PROSSIME AZIONI MANUALI (SIMO)

## Configurazione Backend & Store
- [ ] Creare account **Apple Developer Program** ($99/anno).
- [ ] Creare account **Google Play Console** ($25 una tantum).
- [ ] Creare progetto su **Supabase** e attivare il **Pro Plan** ($25/mese) per evitare ibernazione e avere backup.
- [ ] Configurare le **Row Level Security (RLS)** su Supabase seguendo la guida in `BACKEND_ARCHITECTURE.md`.
- [ ] Recuperare le API Key di **OpenAI** o **Anthropic** per l'AI Coach.
- [ ] Configurare **Google Sign-In**:
    - Creare un progetto su **Google Cloud Console**.
    - Creare un Client ID OAuth 2.0 di tipo **Applicazione Web** (indispensabile per Supabase, anche per Android).
    - Creare un Client ID OAuth 2.0 di tipo **iOS** (necessario per l'app iOS).
    - Incollare i Client ID nel file `lib/core/supabase_config.dart`.
    - Per iOS, aggiungere lo schema URL (reversed client ID) in `ios/Runner/Info.plist`.
- [ ] Configurare **Sign in with Apple**: abilitare Apple Provider su Supabase e la Capability in Xcode.

## Strategia Business & Revenue
- [ ] Decidere se lanciare l'offerta **Lifetime Access** (€99) per i primi 500 utenti.
- [ ] Verificare i requisiti per l'**Apple Small Business Program** (commissione al 15% invece di 30%).
- [ ] Definire i limiti di utilizzo AI per i vari piani (Basic, Premium, Elite).
- [ ] Valutare l'implementazione di **RevenueCat** o **Glassfy** per gestire gli abbonamenti in modo semplice.

## Verifica White Mode (Post-Implementazione)
- [ ] Verificare che tutte le pagine siano correttamente in modalità chiara quando lo switch è attivo.
- [ ] Controllare la leggibilità del testo (evitare testo bianco su sfondo bianco) in:
  - Schermata di Login/Registrazione (AuthScreen).
  - Impostazioni > Informazioni Personali / Privacy / Notifiche.
  - Modali di gestione abitudini e check-in.
  - Tutte le schede delle Statistiche (Trend, Mood, Performance, etc.).
- [ ] Verificare che i grafici (fl_chart) abbiano legende e assi leggibili sia in Light che in Dark Mode.
- [ ] Confermare che il colore accento cambi automaticamente se quello selezionato è troppo chiaro per lo sfondo bianco (gestito da `SettingsProvider`).