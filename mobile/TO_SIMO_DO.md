# TO DO (Simo)

## Configurazione Backend & Store
- [ ] Creare account **Apple Developer Program** ($99/anno).
- [ ] Creare account **Google Play Console** ($25 una tantum).
- [ ] Creare progetto su **Supabase** e attivare il **Pro Plan** ($25/mese) per evitare ibernazione e avere backup.
- [ ] Configurare le **Row Level Security (RLS)** su Supabase seguendo la guida in `BACKEND_ARCHITECTURE.md`.
- [ ] Recuperare le API Key di **OpenAI** o **Anthropic** per l'AI Coach.
- [ ] Configurare **Google Sign-In**: creare Web e iOS Client ID su Google Cloud Console e incollarli in `lib/providers/auth_provider.dart`.
- [ ] Configurare **Sign in with Apple**: abilitare Apple Provider su Supabase e la Capability in Xcode.
- [ ] Inserire `SUPABASE_URL` e `SUPABASE_ANON_KEY` nel file `lib/core/supabase_config.dart` per l'integrazione reale.

## Strategia Business & Revenue
- [ ] Decidere se lanciare l'offerta **Lifetime Access** (€99) per i primi 500 utenti.
- [ ] Verificare i requisiti per l'**Apple Small Business Program** (commissione al 15% invece di 30%).
- [ ] Definire i limiti di utilizzo AI per i vari piani (Basic, Premium, Elite).
- [ ] Valutare l'implementazione di **RevenueCat** o **Glassfy** per gestire gli abbonamenti in modo semplice.

## Verifica UI (Post-Fix Colore Accento)
- [ ] Effettuare un **Hot Reload / Restart** dell'applicazione per forzare il refresh del tema globale in tutti i componenti.
- [ ] Verificare che il colore selezionato nelle Impostazioni sia ora visibile in:
  - Bottone "Salva Modifiche" in Informazioni Personali.
  - Indicatori del calendario nel dashboard.
  - Selettori delle schede (Tabs) in Statistiche e Obiettivi.
  - Bottoni principali nei vari Modal (es. Check-in Giornaliero).

## Verifica Localizzazione (Post-Implementazione)
- [ ] Cambiare la lingua da Italiano a Inglese nelle Impostazioni.
- [ ] Verificare che l'animazione di transizione sia fluida.
- [ ] Controllare che TUTTE le scritte nella pagina Statistiche (Grafici, Legende, Insight) cambino correttamente.
- [ ] Verificare che i nomi dei giorni nei grafici e nelle heatmap siano tradotti.

## Verifica Animazioni Premium (Post-Implementazione)
- [ ] Verificare che lo switch tra le schede (Home, Statistiche, Obiettivi) sia fluido.
- [ ] Testare lo swipe orizzontale tra le schede principali.
- [ ] Verificare che lo stato (es. scroll o filtri selezionati) venga mantenuto quando si cambia tab e si torna indietro.
- [ ] Confermare che il feedback aptico (vibrazione leggera) sia piacevole al cambio tab.

## Future Features
- [ ] Implementare la sincronizzazione reale con **iCloud** (attualmente solo placeholder).
