# PROSSIME AZIONI MANUALI (SIMO)

## Configurazione Backend & Store
- [ ] Creare account **Google Play Console** ($25 una tantum).

## Verifica White Mode (Post-Implementazione)
- [ ] Verificare che tutte le pagine siano correttamente in modalità chiara quando lo switch è attivo.
- [ ] Controllare la leggibilità del testo (evitare testo bianco su sfondo bianco) in:
  - Schermata di Login/Registrazione (AuthScreen).
  - Impostazioni > Informazioni Personali / Privacy / Notifiche.
  - Modali di gestione abitudini e check-in.
  - Tutte le schede delle Statistiche (Trend, Mood, Performance, etc.).
- [ ] Verificare che i grafici (fl_chart) abbiano legende e assi leggibili sia in Light che in Dark Mode.
- [ ] Confermare che il colore accento cambi automaticamente se quello selezionato è troppo chiaro per lo sfondo bianco (gestito da `SettingsProvider`).

---

## Sicurezza & Privacy
- [ ] **Configurazione `url_launcher` per Android (API 30+)**:
  Se l'app punta ad Android 11+ (API 30+), devi aggiungere questo blocco nel tuo `android/app/src/main/AndroidManifest.xml` (fuori dal blocco `<application>`):
  ```xml
  <queries>
      <intent>
          <action android:name="android.intent.action.VIEW" />
          <data android:scheme="https" />
      </intent>
  </queries>
  ```

- [ ] **Inizializzazione Cartella Android**: Se prevedi di pubblicare l'app anche sul Google Play Store, tieni presente che attualmente manca la cartella `android/` nel progetto. Puoi rigenerarla eseguendo `flutter create --org com.simo --platforms android .` nella cartella principale (`mobile/`), per poi configurare icone, permessi e integrazioni native (come per Supabase e Sentry).
## [2026-05-22 18:23 CEST]: App Store Connect Upload

- Build and upload a new iOS archive to App Store Connect using version `1.0.1` and build `5`.
- In App Store Connect, attach build `5` to the new app version/update submission before releasing.
