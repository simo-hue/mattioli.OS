# 🇮🇹 Guida Tecnica - Mattioli.OS

Guida completa per sviluppatori o per chi desidera ospitare l'applicazione autonomamente.

## 📋 Requisiti
- **Node.js** (Versione 20 o superiore)
- **NPM** o **Bun**
- Un account **Supabase** (Gratuito)

---

## 🛠 Installazione Locale

### 1. Clona la Repository
Scarica il codice sorgente sul tuo computer.
```bash
git clone https://github.com/TUA_USER/habit-tracker.git
cd habit-tracker
```

### 2. Installa le Dipendenze
Installa tutte le librerie necessarie per far girare l'app.
```bash
npm install
# oppure
bun install
```

### 3. Configurazione Supabase (Database)
Questa app utilizza Supabase per il database e l'autenticazione.
1.  Crea un nuovo progetto su [Supabase.com](https://supabase.com).
2.  Vai nelle **Project Settings** -> **API**.
3.  Copia `Project URL` e `anon public key`.
4.  Crea un file `.env` nella root del progetto e incolla i valori:

```env
VITE_SUPABASE_URL=tuo_url_supabase
VITE_SUPABASE_ANON=tua_chiave_anon
```

> [!IMPORTANT]
> **Setup del Database**: Troverai un file `schema.sql` nella root del progetto.
> 1. Apri l'SQL Editor nel tuo progetto Supabase.
> 2. Copia e incolla l'intero contenuto di `schema.sql`.
> 3. Esegui lo script per creare tutte le tabelle e le policy di sicurezza necessarie.
### 4. Avvia l'App
```bash
npm run dev
```
L'app sarà disponibile su `http://localhost:5173`.

---

## 🚢 Build & Deploy
Per creare una versione ottimizzata per la produzione:

```bash
npm run build
```

La cartella `dist` conterrà i file statici pronti per essere caricati su Vercel, Netlify o il tuo server web personale.

---

## 🗄 Struttura del Progetto
- `/src/components`: Componenti UI riutilizzabili.
- `/src/hooks`: Logica personalizzata (es. `useGoals`).
- `/src/integrations/supabase/client.ts`: Configurazione del client database.
- `/src/pages`: Le pagine principali dell'applicazione.

Per dettagli sull'architettura, vedi [TECHNICAL_DEEP_DIVE.md](./TECHNICAL_DEEP_DIVE.md).
