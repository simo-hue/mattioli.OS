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

## Verifica App Store - Evolve Pro Restore
- [ ] In RevenueCat, verificare che l'entitlement Pro sia attivo e che includa entrambi gli SKU App Store Connect: `com.simo.evolve.pro.monthly` e `com.simo.evolve.pro.yearly`.
- [ ] In App Store Connect, confermare che il gruppo abbonamenti e i due prodotti siano nello stato corretto per la review e associati alla build inviata.
- [ ] Prima della nuova submission, testare su sandbox iOS il flusso completo: acquisto, chiusura app, riapertura, logout/login se previsto, e pulsante `Ripristina acquisti`.
- [ ] Nelle note di review, indicare che il restore ora richiama RevenueCat `restorePurchases`, sincronizza `CustomerInfo` e sblocca Pro se trova entitlement o StoreKit subscription attivi.
