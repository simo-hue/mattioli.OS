# Test Manuali - Soft-Delete Abitudini

## Test 5: Database Verification
1. [ ] Aprire Supabase Dashboard
2. [ ] Navigare a Table Editor → goals
3. [ ] Cercare il record con title = "Test Soft Delete"
4. [ ] **Verifica**:
   - [ ] Il record esiste ancora (non è stato eliminato fisicamente)
   - [ ] `end_date` è uguale alla data odierna nel formato 'YYYY-MM-DD'
   - [ ] `start_date` e tutti gli altri campi sono invariati

## Test 6: Cleanup
1. [ ] Eliminare definitivamente "Test Soft Delete" dal database (opzionale)
2. [ ] Oppure lasciarlo come esempio di abitudine archiviata

---

## Test Riordino Abitudini (test esistenti)

#### Step 5: Test Aggiungi Nuova Abitudine
- [ ] Riordina alcune abitudini esistenti in modo custom
- [ ] Aggiungi una nuova abitudine
- [ ] Verifica che la nuova abitudine appaia **in fondo** alla lista
- [ ] Verifica che sia trascinabile immediatamente
- [ ] Spostala in cima
- [ ] Ricarica → verifica che rimanga in cima

#### Step 6: Test Eliminazione Abitudine
- [ ] Riordina abitudini in modo custom
- [ ] Elimina un'abitudine nel **mezzo** della lista
- [ ] Verifica che le rimanenti mantengano l'ordine relativo
- [ ] Ricarica → verifica ordine ancora corretto

#### Step 7: Test Edit Mode Durante Drag
- [ ] Apri edit mode di un'abitudine (click icona matita)
- [ ] Verifica che durante edit NON puoi trascinare (grip disabilitato)
- [ ] Salva edit
- [ ] Verifica che ora puoi trascinare di nuovo

#### Step 9: Test con Molte Abitudini
- [ ] Crea almeno 10-15 abitudini
- [ ] Prova a trascinare dalla cima al fondo
- [ ] Prova a trascinare dal fondo alla cima
- [ ] Verifica smooth scroll durante drag
- [ ] Verifica performance (no lag)

#### Step 10: Browser Compatibility
- [ ] Testa su Chrome
- [ ] Testa su Firefox
- [ ] Testa su Safari (se su Mac)
- [ ] Verifica funzionamento identico

### 5. README.md Links (Da Verificare)
Controlla che i seguenti link nel README.md siano corretti:
- [ ] `YOUR_YOUTUBE_VIDEO_LINK_HERE` → Inserisci link tutorial se disponibile
