import JSZip from 'jszip';
import { saveAs } from 'file-saver';

/**
 * Crea la struttura ZIP organizzata per il backup completo
 */
export async function createBackupZip(backupData: any, timestamp: string): Promise<void> {
    const zip = new JSZip();
    const folderName = `mattioli-os-backup-${timestamp.split('T')[0]}`;

    // Root folder
    const root = zip.folder(folderName);
    if (!root) throw new Error('Failed to create root folder');

    // 1. File principale backup.json
    root.file('backup.json', JSON.stringify(backupData, null, 2));

    // 2. README.txt
    root.file('README.txt', generateReadmeContent(backupData));

    // 3. Cartella data/ organizzata
    const dataFolder = root.folder('data');
    if (!dataFolder) throw new Error('Failed to create data folder');

    // Habits
    const habitsFolder = dataFolder.folder('habits');
    if (habitsFolder) {
        habitsFolder.file('goals.json', JSON.stringify(backupData.goals || [], null, 2));
        habitsFolder.file('logs.json', JSON.stringify(backupData.goal_logs || [], null, 2));
    }

    // Macro Goals
    const macroFolder = dataFolder.folder('macro-goals');
    if (macroFolder) {
        macroFolder.file('long_term_goals.json', JSON.stringify(backupData.long_term_goals || [], null, 2));
    }

    // Categories
    const categoriesFolder = dataFolder.folder('categories');
    if (categoriesFolder) {
        categoriesFolder.file('settings.json', JSON.stringify(backupData.goal_category_settings || null, null, 2));
    }

    // Tracking
    const trackingFolder = dataFolder.folder('tracking');
    if (trackingFolder) {
        trackingFolder.file('reading.json', JSON.stringify(backupData.reading_logs || [], null, 2));
        trackingFolder.file('moods.json', JSON.stringify(backupData.daily_moods || [], null, 2));
    }

    // Settings
    const settingsFolder = dataFolder.folder('settings');
    if (settingsFolder) {
        settingsFolder.file('user_settings.json', JSON.stringify(backupData.user_settings || [], null, 2));
        settingsFolder.file('app_settings.json', JSON.stringify(backupData.app_settings || {}, null, 2));
    }

    // Notes
    const notesFolder = dataFolder.folder('notes');
    if (notesFolder && backupData.user_memos) {
        notesFolder.file('memo.md', backupData.user_memos.content || '# Note\n\nNessuna nota salvata.');
    }

    // 4. Database Schema
    const schemaFolder = root.folder('database-schema');
    if (schemaFolder) {
        // Include schema.sql if provided
        if (backupData.database_schema?.sql) {
            schemaFolder.file('schema.sql', backupData.database_schema.sql);
        }

        // Include database metadata
        if (backupData.database_schema?.metadata) {
            schemaFolder.file('database_info.json', JSON.stringify(backupData.database_schema.metadata, null, 2));
        }

        // Include table structure summary
        if (backupData.database_schema?.tables_summary) {
            schemaFolder.file('tables_summary.json', JSON.stringify(backupData.database_schema.tables_summary, null, 2));
        }
    }

    // 5. Restore Instructions (Bilingual: IT + EN)
    root.file('RESTORE_INSTRUCTIONS_IT.md', generateRestoreInstructionsIT(backupData));
    root.file('RESTORE_INSTRUCTIONS_EN.md', generateRestoreInstructionsEN(backupData));

    // Genera e scarica il ZIP
    const blob = await zip.generateAsync({ type: 'blob' });
    saveAs(blob, `${folderName}.zip`);
}

/**
 * Genera il contenuto del file README.txt
 */
function generateReadmeContent(backupData: any): string {
    const stats = calculateBackupStats(backupData);

    return `HABIT TRACKER - BACKUP COMPLETO
================================

Data Backup: ${backupData.timestamp}
Versione: ${backupData.version}

CONTENUTO DEL BACKUP
--------------------
Questo backup contiene TUTTI i tuoi dati dell'applicazione:

✓ ${stats.goals} Abitudini giornaliere (daily habits)
✓ ${stats.goalLogs} Log di completamento abitudini
✓ ${stats.longTermGoals} Obiettivi macro (annuali, mensili, settimanali, etc.)
✓ Impostazioni colori e categorie personalizzate
✓ ${stats.readingLogs} Log di lettura
✓ ${stats.moods} Registrazioni mood & energy
✓ ${stats.userSettings} Impostazioni utente
✓ Note personali (memo)

TOTALE RECORD: ${stats.total}

COME RIPRISTINARE
-----------------
1. Apri l'applicazione Habit Tracker
2. Vai alla pagina Backup Completo (/complete-backup)
3. Trascina questo file ZIP nell'area di importazione
4. Conferma il ripristino
5. Attendi il completamento dell'operazione

NOTA: Il ripristino sovrascriverà i dati esistenti.
Si consiglia di fare un backup prima di importare.

STRUTTURA FILE
--------------
- backup.json: File completo con tutti i dati
- README.txt: Questo file
- database-schema/: Schema del database Supabase
  - schema.sql: Script SQL completo per ricreare il database
  - database_info.json: Metadata e informazioni del database  - tables_summary.json: Riepilogo struttura tabelle
- data/: Cartella con dati organizzati per tipologia
  - habits/: Abitudini giornaliere e log
  - macro-goals/: Obiettivi a lungo termine
  - categories/: Impostazioni categorie
  - tracking/: Dati di tracking (lettura, mood)
  - settings/: Impostazioni utente e app
  - notes/: Note personali

Per assistenza o segnalazioni: https://github.com/simo-hue/mattioli.OS/issues
`;
}

/**
 * Calcola le statistiche del backup
 */
function calculateBackupStats(backupData: any) {
    return {
        goals: Array.isArray(backupData.goals) ? backupData.goals.length : 0,
        goalLogs: Array.isArray(backupData.goal_logs) ? backupData.goal_logs.length : 0,
        longTermGoals: Array.isArray(backupData.long_term_goals) ? backupData.long_term_goals.length : 0,
        readingLogs: Array.isArray(backupData.reading_logs) ? backupData.reading_logs.length : 0,
        moods: Array.isArray(backupData.daily_moods) ? backupData.daily_moods.length : 0,
        userSettings: Array.isArray(backupData.user_settings) ? backupData.user_settings.length : 0,
        total: (
            (Array.isArray(backupData.goals) ? backupData.goals.length : 0) +
            (Array.isArray(backupData.goal_logs) ? backupData.goal_logs.length : 0) +
            (Array.isArray(backupData.long_term_goals) ? backupData.long_term_goals.length : 0) +
            (Array.isArray(backupData.reading_logs) ? backupData.reading_logs.length : 0) +
            (Array.isArray(backupData.daily_moods) ? backupData.daily_moods.length : 0) +
            (Array.isArray(backupData.user_settings) ? backupData.user_settings.length : 0) +
            (backupData.goal_category_settings ? 1 : 0) +
            (backupData.user_memos ? 1 : 0)
        )
    };
}

/**
 * Valida la struttura di un backup importato
 */
export function validateBackupData(data: any): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (!data.version) {
        errors.push('Missing backup version');
    }

    if (!data.timestamp) {
        errors.push('Missing backup timestamp');
    }

    // Verifica che almeno alcune tabelle siano presenti
    const hasSomeData =
        (Array.isArray(data.goals) && data.goals.length > 0) ||
        (Array.isArray(data.long_term_goals) && data.long_term_goals.length > 0) ||
        (Array.isArray(data.goal_logs) && data.goal_logs.length > 0) ||
        (Array.isArray(data.reading_logs) && data.reading_logs.length > 0) ||
        (Array.isArray(data.daily_moods) && data.daily_moods.length > 0) ||
        data.user_memos;

    if (!hasSomeData) {
        errors.push('Backup appears to be empty - no data found');
    }

    return {
        valid: errors.length === 0,
        errors
    };
}

/**
 * Legge un file ZIP o JSON e restituisce i dati del backup
 */
export async function readBackupFile(file: File): Promise<any> {
    if (file.name.endsWith('.zip')) {
        // Leggi ZIP
        const zip = await JSZip.loadAsync(file);

        // Cerca backup.json nella root o in una sottocartella
        let backupFile = zip.file('backup.json');

        if (!backupFile) {
            // Cerca in sottocartelle
            const files = Object.keys(zip.files);
            const backupFilePath = files.find(f => f.endsWith('backup.json'));
            if (backupFilePath) {
                backupFile = zip.file(backupFilePath);
            }
        }

        if (!backupFile) {
            throw new Error('File backup.json non trovato nel ZIP');
        }

        const content = await backupFile.async('text');
        return JSON.parse(content);
    } else if (file.name.endsWith('.json')) {
        // Leggi JSON diretto
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => {
                try {
                    const content = e.target?.result as string;
                    resolve(JSON.parse(content));
                } catch (error) {
                    reject(new Error('File JSON non valido'));
                }
            };
            reader.onerror = () => reject(new Error('Errore lettura file'));
            reader.readAsText(file);
        });
    } else {
        throw new Error('Formato file non supportato. Usa .zip o .json');
    }
}

/**
 * Genera le istruzioni di ripristino in ITALIANO
 */
export function generateRestoreInstructionsIT(backupData: any): string {
    const stats = calculateBackupStats(backupData);
    const date = backupData.metadata?.exportDate || 'N/A';

    return `# ISTRUZIONI DI RIPRISTINO COMPLETO
# Habit Tracker - Full Disaster Recovery

**Data Backup:** ${backupData.timestamp}  
**Record Totali:** ${stats.total}

---

## 📋 SCENARIO 1: Ripristino Dati su App Esistente

### Prerequisiti
- Applicazione Habit Tracker già installata e funzionante
- Account Supabase configurato
- File di backup ( mattioli.OS-backup-*.zip)

### Passaggi

**1. Accedi all'Applicazione**
- Apri il browser e vai all'app Habit Tracker
- Effettua il login con le tue credenziali

**2. Naviga alla Pagina Backup**
- Menu → Backup Completo
- Oppure vai direttamente a: \`/#/complete-backup\`

**3. Importa il Backup**
- Trascina il file ZIP nell'area di drop
- Oppure clicca "Seleziona file" e scegli il ZIP
- Attendi il completamento (potrebbero volerci alcuni secondi per ${stats.total} record)

**4. Verifica il Ripristino**
- Controlla che le abitudini siano visibili nella home
- Verifica i macro obiettivi in "Macro Goals"
- Controlla le statistiche in "Stats"

✅ **Fatto!** I tuoi dati sono stati ripristinati.

---

## 🆕 SCENARIO 2: Ripristino Completo da Zero (Disaster Recovery)

### Prerequisiti
- Niente! Partirai da zero
- File di backup (mattioli.OS-backup-*.zip)
- Account GitHub (opzionale, per deploy)

### FASE 1: Crea Nuovo Progetto Supabase

**1.1 Crea Account / Progetto**
- Vai su https://supabase.com
- Clicca "Start your project"
- Crea una nuova organization (se necessario)
- Crea un nuovo progetto:
  - Nome: \`mattioli.OS-restore\` (o quello che preferisci)
  - Database Password: **SALVALA!** Ti servirà
  - Region: Scegli la più vicina a te

**1.2 Attendi Provisioning**
- Supabase creerà il database (1-2 minuti)
- Vedrai "Project is ready" quando completato

**1.3 Configura il Database**
- Vai su: SQL Editor (icona </> nella sidebar)
- Apri il file \`database-schema/schema.sql\` dal backup ZIP
- Copia **TUTTO** il contenuto
- Incollalo nel SQL Editor di Supabase
- Clicca "RUN" (o premi Ctrl+Enter)
- Vedrai "Success. No rows returned" → ✅ Schema creato!

**1.4 Salva le Credenziali Supabase**
- Vai su: Settings → API (⚙️ Settings in basso)
- Copia e salva:
  - **Project URL**: \`https://xxxxx.supabase.co\`
  - **anon/public API key**: \`eyJhbG....\`

### FASE 2: Clona e Configura l'Applicazione

**2.1 Clona Repository**
\`\`\`bash
git clone https://github.com/simo-hue/mattioli.OS.git
cd mattioli.OS
\`\`\`

**2.2 Installa Dipendenze**
\`\`\`bash
npm install
\`\`\`

**2.3 Configura Variabili d'Ambiente**
Crea file \`.env.local\` con:
\`\`\`
VITE_SUPABASE_URL=https://tuo-progetto.supabase.co
VITE_SUPABASE_ANON_KEY=tua-anon-key
\`\`\`

Sostituisci con i valori salvati al punto 1.4

**2.4 Testa in Locale**
\`\`\`bash
npm run dev
\`\`\`
Apri http://localhost:8080/mattioli.OS/

### FASE 3: Ripristina i Dati

**3.1 Crea Account**
- Nell'app locale, clicca "Registrati"
- Usa una email valida
- Conferma l'email (controlla inbox)

**3.2 Importa il Backup**
- Login nell'app
- Vai a: Menu → Backup Completo
- Trascina il file ZIP
- Attendi completamento

**3.3 Verifica Dati**
- ✅ ${stats.goals} abitudini
- ✅ ${stats.longTermGoals} macro obiettivi
- ✅ ${stats.moods} registrazioni mood
- ✅ Note personali

### FASE 4: Deploy (Opzionale)

**4.1 Deploy su GitHub Pages**
\`\`\`bash
npm run deploy
\`\`\`

**4.2 Configura GitHub Pages**
- Vai su GitHub → Repository Settings → Pages
- Source: \`gh-pages\` branch
- Salva

La tua app sarà online su:  
\`https://tuo-username.github.io/mattioli.OS/\`

---

## 🔧 RISOLUZIONE PROBLEMI

### Errore: "Non autenticato"
- Verifica di aver fatto login
- Controlla che le credenziali Supabase siano corrette nel file .env.local

### Errore: "Backup non valido"
- Verifica che il file sia .zip o .json
- Controlla che il file non sia corrotto
- Prova a estrarre manualmente il ZIP e usa backup.json

### Schema SQL Error
- Assicurati di aver copiato TUTTO il contenuto di schema.sql
- Verifica che non ci siano caratteri strani
- Esegui lo script una riga alla volta se necessario

### Import Parziale
- Controlla la console del browser (F12) per errori
- Prova a importare il backup.json manualmente
- Verifica le policy RLS su Supabase

---

## 📞 SUPPORTO

- GitHub Issues: https://github.com/simo-hue/mattioli.OS/issues
- Documentazione: https://github.com/simo-hue/mattioli.OS

---

**Nota Importante sullo Schema:**  
Lo schema SQL incluso potrebbe non essere aggiornato all'ultima versione.
Per ottenere lo schema più recente:
1. Vai su Supabase Dashboard
2. SQL Editor → Schema tab
3. Copia lo schema completo
4. Sostituisci il contenuto di \`database-schema/schema.sql\`
`;
}

/**
 * Genera le istruzioni di ripristino in INGLESE
 */
export function generateRestoreInstructionsEN(backupData: any): string {
    const stats = calculateBackupStats(backupData);

    return `# COMPLETE RESTORE INSTRUCTIONS
# Habit Tracker - Full Disaster Recovery

**Backup Date:** ${backupData.timestamp}  
**Total Records:** ${stats.total}

---

## 📋 SCENARIO 1: Restore Data on Existing App

### Prerequisites
- Habit Tracker app already installed and running
- Supabase account configured
- Backup file (mattioli.OS-backup-*.zip)

### Steps

**1. Access the Application**
- Open browser and go to Habit Tracker app
- Login with your credentials

**2. Navigate to Backup Page**
- Menu → Complete Backup
- Or go directly to: \`/#/complete-backup\`

**3. Import Backup**
- Drag and drop the ZIP file into the drop area
- Or click "Browse file" and select the ZIP
- Wait for completion (may take a few seconds for ${stats.total} records)

**4. Verify Restore**
- Check that habits are visible on home page
- Verify macro goals in "Macro Goals"
- Check statistics in "Stats"

✅ **Done!** Your data has been restored.

---

## 🆕 SCENARIO 2: Complete Restore from Scratch (Disaster Recovery)

### Prerequisites
- Nothing! You'll start from zero
- Backup file (mattioli.OS-backup-*.zip)
- GitHub account (optional, for deployment)

### PHASE 1: Create New Supabase Project

**1.1 Create Account / Project**
- Go to https://supabase.com
- Click "Start your project"
- Create a new organization (if needed)
- Create a new project:
  - Name: \`mattioli.OS-restore\` (or whatever you prefer)
  - Database Password: **SAVE IT!** You'll need it
  - Region: Choose closest to you

**1.2 Wait for Provisioning**
- Supabase will create the database (1-2 minutes)
- You'll see "Project is ready" when completed

**1.3 Configure Database**
- Go to: SQL Editor (</> icon in sidebar)
- Open the \`database-schema/schema.sql\` file from backup ZIP
- Copy **ALL** the content
- Paste it into Supabase SQL Editor
- Click "RUN" (or press Ctrl+Enter)
- You'll see "Success. No rows returned" → ✅ Schema created!

**1.4 Save Supabase Credentials**
- Go to: Settings → API (⚙️ Settings at bottom)
- Copy and save:
  - **Project URL**: \`https://xxxxx.supabase.co\`
  - **anon/public API key**: \`eyJhbG....\`

### PHASE 2: Clone and Configure Application

**2.1 Clone Repository**
\`\`\`bash
git clone https://github.com/simo-hue/mattioli.OS.git
cd mattioli.OS
\`\`\`

**2.2 Install Dependencies**
\`\`\`bash
npm install
\`\`\`

**2.3 Configure Environment Variables**
Create \`.env.local\` file with:
\`\`\`
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
\`\`\`

Replace with values saved in step 1.4

**2.4 Test Locally**
\`\`\`bash
npm run dev
\`\`\`
Open http://localhost:8080/mattioli.OS/

### PHASE 3: Restore Data

**3.1 Create Account**
- In the local app, click "Sign Up"
- Use a valid email
- Confirm email (check inbox)

**3.2 Import Backup**
- Login to the app
- Go to: Menu → Complete Backup
- Drag and drop the ZIP file
- Wait for completion

**3.3 Verify Data**
- ✅ ${stats.goals} habits
- ✅ ${stats.longTermGoals} macro goals
- ✅ ${stats.moods} mood records
- ✅ Personal notes

### PHASE 4: Deploy (Optional)

**4.1 Deploy to GitHub Pages**
\`\`\`bash
npm run deploy
\`\`\`

**4.2 Configure GitHub Pages**
- Go to GitHub → Repository Settings → Pages
- Source: \`gh-pages\` branch
- Save

Your app will be live at:  
\`https://your-username.github.io/mattioli.OS/\`

---

## 🔧 TROUBLESHOOTING

### Error: "Not authenticated"
- Verify you're logged in
- Check that Supabase credentials are correct in .env.local file

### Error: "Invalid backup"
- Verify file is .zip or .json
- Check that file is not corrupted
- Try manually extracting ZIP and using backup.json

### Schema SQL Error
- Make sure you copied ALL content from schema.sql
- Verify there are no strange characters
- Run script one line at a time if necessary

### Partial Import
- Check browser console (F12) for errors
- Try importing backup.json manually
- Verify RLS policies on Supabase

---

## 📞 SUPPORT

- GitHub Issues: https://github.com/simo-hue/mattioli.OS/issues
- Documentation: https://github.com/simo-hue/mattioli.OS

---

**Important Note about Schema:**  
The included SQL schema may not be updated to the latest version.
To get the most recent schema:
1. Go to Supabase Dashboard
2. SQL Editor → Schema tab
3. Copy the complete schema
4. Replace content of \`database-schema/schema.sql\`
`;
}
