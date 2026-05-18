# DA FARE NEL BREVE TERMINE
[ ] Tradurre in inglese le schermate dell'app ( copertine per app store )
[ ] Verificare che siano collegati i prodotti da RevenueCat a app store connect
[ ] Sostituire la chiave API di test con la chiave live di iOS ('appl_...') in `mobile/lib/core/revenuecat_config.dart`
[ ] Caricare la chiave StoreKit 2 (file `.p8`) e l'Issuer ID / Key ID su RevenueCat (generati da Apple Developer > Users and Access > Integrations)
[ ] Creare un account utente per la verifica di Apple (es. `apple-tester@evolve.com`) su Supabase Auth
[ ] Impostare manualmente `is_pro = true` per l'utente di test nella tabella `profiles` di Supabase per bypassare il pagamento per i recensori di Apple
[ ] Inserire le credenziali di test (`apple-tester@evolve.com`) nella sezione "App Review Information" durante la sottomissione su App Store Connect
[ ] Configurare i link legali obbligatori in App Store Connect:
    - Privacy Policy: `https://simo-hue.github.io/mattioli.OS/privacy`
    - Terms of Service / EULA: `https://simo-hue.github.io/mattioli.OS/terms`
[ ] Assicurarsi che l'accordo per le applicazioni a pagamento ("Paid Applications Agreement") sia attivo e firmato in App Store Connect > Agreements, Tax, and Banking

# Feature Premium
    [ ] Analytics as a PRO Plan per quelle avanzate
    [ ] App per Mac ( non solo tramite webApp salvata )
    [ ] Per Apple watch ( servono in swift, comming soon )
    [ ] Widget per schermata Home ( servono in swift, comming soon )

# LONG TERM FEATURES ( da implementare in futuro )
[ ] Goals non solamente come tick
    [ ] come barre di progresso ( con % ) 
    [ ] oppure altri tipi 

[ ] Goals phone related
    [ ] accedo ai dati del telefono ( screen time, apps used, ecc )
    [ ] Cambiare icona dell'app
    [ ] 

[ ] Opzione "Local-First" / Modalità solo Offline
    [ ] Usare un DB Locale
    [ ] Usare LLM Locale

[ ] Gamification
    [ ] icone profilo in base a #goals completati