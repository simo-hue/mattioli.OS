# Implementazione Statistiche Correlazione Mood & Energia

## Data: 14 Gennaio 2026

### Panoramica
Ho implementato un sistema completo di analisi della correlazione tra mood/energia e le abitudini giornaliere. Questa funzionalità permette di capire quali abitudini performano bene quando sei di buon umore o hai energia, e quali invece soffrono quando mood ed energia sono bassi.

### Componenti Implementati

#### 1. Hook: `useHabitMoodCorrelation`
**Percorso**: `/src/hooks/useHabitMoodCorrelation.ts`

Hook personalizzato che calcola statistiche di correlazione tra abitudini e mood/energia:
- **Calcolo medie**: mood medio ed energia media nei giorni completati vs mancati
- **Tassi di completamento per range**: calcola il tasso di completamento per mood/energia basso (1-4), medio (5-7), alto (8-10)
- **Coefficiente di correlazione**: usa la correlazione di Pearson per misurare la relazione tra mood/energia e completamento
- **Classificazione abitudini**:
  - **Mood-sensitive**: abitudini che calano di >30% dal mood alto al mood basso
  - **Energy-sensitive**: abitudini che calano di >30% dall'energia alta all'energia bassa  
  - **Resilient**: abitudini mantenute con >60% di completamento anche con mood/energia bassi

#### 2. Componente: `HabitMoodCorrelationChart`
**Percorso**: `/src/components/stats/HabitMoodCorrelationChart.tsx`

Visualizzazione dettagliata della correlazione per una singola abitudine:
- **Card KPI**: mostrano correlazione mood, correlazione energia, mood medio e energia media quando completata
- **Badge di classificazione**: indicano se l'abitudine è sensibile al mood, sensibile all'energia, resiliente o neutrale
- **Grafico 1**: bar chart che confronta mood/energia media nei giorni completati vs mancati
- **Grafico 2**: line chart che mostra il tasso di completamento per livelli bassi/medi/alti di mood ed energia
- **Info dati**: numero di giorni analizzati per validità statistica

#### 3. Componente: `MoodEnergyHabitMatrix`
**Percorso**: `/src/components/stats/MoodEnergyHabitMatrix.tsx`

Matrice heatmap che mostra tutte le abitudini vs mood/energia:
- **Righe**: ogni abitudine attiva
- **Colonne**: mood basso/medio/alto ed energia bassa/media/alta
- **Celle colorate**: l'intensità del colore rappresenta il tasso di completamento
- **Interattiva**: hover sulle celle per vedere percentuali esatte
- Permette di vedere a colpo d'occhio pattern generali

#### 4. Componente: `MoodEnergyInsights`
**Percorso**: `/src/components/stats/MoodEnergyInsights.tsx`

Pannello di insights azionabili con tre sezioni:
- **Abitudini Sensibili al Mood**: lista delle top 3 abitudini che calano molto con mood basso
- **Abitudini Sensibili all'Energia**: lista delle top 3 abitudini che richiedono alta energia
- **Abitudini Resilienti**: lista delle top 3 abitudini mantenute anche con mood/energia bassi
- **Suggerimenti**: consigli pratici basati sui dati (es. "Pianifica X al mattino quando hai più energia")

### Integrazione nella Pagina Stats

#### Vista Globale (Tutti i Goals)
Nuovo tab dedicato **"Mood & Energia"** (5° tab):
1. `MoodCorrelationChart`: grafico esistente di correlazione mood/energia vs produttività generale
2. `MoodEnergyInsights`: pannello con insights sulle abitudini sensibili e resilienti
3. `MoodEnergyHabitMatrix`: matrice heatmap di tutte le abitudini vs mood/energia

Questo tab è completamente separato dagli altri e contiene TUTTE le statistiche relative a mood ed energia.

#### Vista Singola Abitudine
Nuovo tab **"Mood & Energia"** (5° tab):
- Mostra `HabitMoodCorrelationChart` per l'abitudine selezionata
- Include tutti i grafici e statistiche di correlazione
- Gestisce il caso con dati insufficienti mostrando un messaggio appropriato

### Caratteristiche Tecniche

#### Calcolo Statistico
- **Correlazione di Pearson**: misura la relazione lineare tra mood/energia e completamento (-1 a +1)
- **Classificazione automatica**: basata su soglie definite (30% drop per sensitivity, 60% per resilienza)
- **Filtro dati**: richiede minimo 5 giorni con dati mood per validità statistica

#### Design & UX
- **Colori abitudine**: ogni visualizzazione usa il colore specifico dell'abitudine
- **Responsive**: tutti i componenti adattati per mobile e desktop
- **Dark mode compatible**: tutti i grafici e componenti funzionano in modalità scura
- **Icone semantiche**: uso di icone Lucide per migliorare la comprensibilità

#### Performance
- **Memoization**: uso di `useMemo` per evitare ricalcoli inutili
- **Query ottimizzate**: fetch dei dati mood solo una volta tramite React Query
- **Rendering condizionale**: componenti mostrati solo con dati sufficienti

### Flusso Dati

```
1. useHabitMoodCorrelation hook
   ↓ (fetches)
2. daily_moods table (Supabase)
   ↓ (joins with)
3. goal_logs table
   ↓ (calculates)
4. Correlation statistics
   ↓ (renders in)
5. Visualization components
```

### File Modificati

1. **`/src/hooks/useHabitMoodCorrelation.ts`** (nuovo)
2. **`/src/components/stats/HabitMoodCorrelationChart.tsx`** (nuovo)
3. **`/src/components/stats/MoodEnergyHabitMatrix.tsx`** (nuovo)
4. **`/src/components/stats/MoodEnergyInsights.tsx`** (nuovo)
5. **`/src/pages/Stats.tsx`** (modificato)
   - Aggiunto import dei nuovi componenti
   - Aggiunto hook `useHabitMoodCorrelation`
   - Aggiunto tab "Mood & Energia" nella vista singola abitudine
   - Aggiunti pannelli insights e matrix nel tab "Analisi" della vista globale

### Dependencies
Nessuna nuova dependency richiesta. Utilizza:
- Recharts (già presente)
- Lucide React icons (già presente)
- React Query (già presente)
- Date-fns (già presente)

### Note per il Futuro
- I dati di mood/energia devono essere registrati quotidianamente per ottenere insights accurati
- Minimo 5 giorni di dati mood/energia per abitudine per mostrare statistiche
- La correlazione diventa più accurata con più dati nel tempo
- Possibilità di estendere con ML per predizioni future basate su mood/energia
