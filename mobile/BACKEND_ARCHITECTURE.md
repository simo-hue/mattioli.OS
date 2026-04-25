# 🏗️ Backend Architecture: Mattioli.OS (Enterprise Grade)

Questa documentazione definisce l'infrastruttura backend necessaria per scalare **Mattioli.OS** da strumento personale ad applicazione multi-utente pronta per App Store e Google Play Store.

---

## 📋 1. Stack Tecnologico & Costi Operativi

Per garantire affidabilità e costi prevedibili, l'architettura si basa su **Supabase** (PostgreSQL as a Service).

### 💳 Analisi dei Costi (Piano Lancio)
1.  **Supabase Pro Plan ($25/mese):**
    *   **Perché:** Previene l'ibernazione del DB, offre backup giornalieri e gestisce fino a 100,000 utenti attivi mensili (MAU).
    *   **Incluso:** 8GB di storage DB, 100GB di file storage (per foto profilo/allegati).
2.  **Store Fees:**
    *   **Apple Developer:** $99/anno.
    *   **Google Play:** $25 (una tantum).
3.  **AI Logic (Pay-as-you-go):**
    *   Utilizzo di OpenAI GPT-4o-mini via Edge Functions (~$0.10 per 1000 interazioni medie).

---

## 🗄️ 2. Schema del Database (PostgreSQL)

La struttura è relazionale e ottimizzata per le performance. Ogni tabella utilizza l'UUID di Supabase Auth come chiave di isolamento.

### Principali Entità:
*   **`profiles`**: Dati utente, preferenze, lingua, impostazioni abbonamento.
*   **`macro_goals`**: Obiettivi principali (Titolo, Colore, Scadenza, User_ID).
*   **`habits`**: Abitudini collegate ai macro goal (Frequenza, Streak).
*   **`daily_logs`**: Record giornalieri che collegano Mood, Note e completamento Abitudini.
*   **`ai_insights`**: Cache delle analisi generate dall'AI per risparmiare token e tempo di caricamento.

---

## 🔐 3. Sicurezza: Row Level Security (RLS)

Il cuore della sicurezza non è nel codice Flutter, ma nel Database. Ogni tabella deve avere l'RLS attivo.

**Esempio di Policy di Sicurezza:**
```sql
-- Abilita RLS sulla tabella goals
ALTER TABLE macro_goals ENABLE ROW LEVEL SECURITY;

-- Crea una policy che permette agli utenti di vedere solo i propri dati
CREATE POLICY "Users can only access their own data"
ON macro_goals
FOR ALL -- SELECT, INSERT, UPDATE, DELETE
USING (auth.uid() = user_id);
```

---

## 🤖 4. Integrazione AI (Edge Functions)

Per mantenere segrete le API Key e non pesare sulla batteria dello smartphone, la logica AI risiede su **Supabase Edge Functions** (Deno).

### Flusso AI Coach:
1.  **Trigger:** L'utente preme "Analizza i miei Trend".
2.  **Request:** L'app invia un token JWT alla Edge Function.
3.  **Processing:** La funzione recupera i dati degli ultimi 30 giorni dal DB (lato server, molto veloce).
4.  **LLM:** Invia i dati a OpenAI/Anthropic con un system prompt specifico.
5.  **Response:** Restituisce un JSON strutturato con suggerimenti e statistiche.

---

## 🔄 5. Sincronizzazione & Stato Offline

L'app mobile deve essere "Offline-First" per una UX fluida.
*   **Local Cache:** Utilizzo di **Isar/Hive** per salvare i dati localmente.
*   **Sync Strategy:** All'avvio, l'app confronta il `last_updated_at` locale con quello del server.
*   **Real-time:** Utilizzo dei **Postgres Changes** di Supabase per aggiornare la UI istantaneamente se l'utente modifica qualcosa da un altro dispositivo (es. iPad o Web).

---

## 🚀 6. Roadmap di Implementazione

1.  **Phase 1 (Settimana 1):** Configurazione progetto Supabase, tabelle e RLS.
2.  **Phase 2 (Settimana 1):** Migrazione del sistema di Auth (Email/Google/Apple Sign-in).
3.  **Phase 3 (Settimana 2):** Creazione del layer Repository in Flutter per sostituire i dati Mock.
4.  **Phase 4 (Settimana 3):** Implementazione Edge Functions per l'AI Coach.
5.  **Phase 5 (Settimana 4):** Test di carico, implementazione Sentry per i crash e sottomissione agli Store.

---
*Documentazione tecnica aggiornata da Antigravity - Database & Mobile Architect*
