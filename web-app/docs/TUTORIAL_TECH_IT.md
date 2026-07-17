# 🇮🇹 Guida Tecnica - Mattioli.OS

Guida completa per sviluppatori o per chi desidera ospitare l'applicazione autonomamente.

## 📋 Requisiti
- **Node.js** (Versione 20.19+ oppure 22.12+, richiesta da Vite 7)
- **NPM**
- Un account **Supabase** (Gratuito)

---

## 🛠 Installazione Locale

### 1. Clona la Repository
Scarica il codice sorgente sul tuo computer. L'app web si trova in `web-app/`;
la repository contiene anche i client Flutter `mobile/` e `desktop/`.
```bash
git clone https://github.com/simo-hue/mattioli.OS.git
cd mattioli.OS/web-app
```

### 2. Installa le Dipendenze
Installa tutte le librerie necessarie per far girare l'app.
```bash
npm install
```

### 3. Configurazione Supabase (Database)
Questa app utilizza Supabase per il database e l'autenticazione.
1.  Crea un nuovo progetto su [Supabase.com](https://supabase.com).
2.  Vai nelle **Project Settings** -> **API**.
3.  Copia `Project URL` e `anon public key`.
4.  Crea un file `.env` dentro `web-app/` (accanto a `package.json`) e incolla i
    valori — vedi `env_example` per l'elenco completo delle chiavi accettate:

```env
VITE_SUPABASE_URL=tuo_url_supabase
VITE_SUPABASE_ANON=tua_chiave_anon
```

> [!IMPORTANT]
> **Setup del Database**: `schema.sql` si trova nella **root della repository** —
> un livello sopra (`../schema.sql`), perché è condiviso con i client mobile e
> desktop.
> 1. Apri l'SQL Editor nel tuo progetto Supabase.
> 2. Copia e incolla l'intero contenuto di `../schema.sql`.
> 3. Esegui lo script per creare tutte le tabelle e le policy di sicurezza necessarie.

### 4. Avvia l'App
```bash
npm run dev
```
L'app sarà disponibile su `http://localhost:8080`.

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
