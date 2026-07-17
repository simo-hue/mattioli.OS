/**
 * Ollama Integration Service
 * Handles communication with local Ollama API for AI Coach features
 */

const OLLAMA_BASE_URL = 'http://localhost:11434';

export interface OllamaModel {
    name: string;
    size: number;
    digest: string;
    modified_at: string;
}

export interface OllamaGenerateRequest {
    model: string;
    prompt: string;
    stream?: boolean;
}

export interface OllamaGenerateResponse {
    response: string;
    done: boolean;
}

/**
 * Check if Ollama service is running
 */
export async function checkOllamaAvailability(): Promise<boolean> {
    try {
        const response = await fetch(`${OLLAMA_BASE_URL}/api/tags`, {
            method: 'GET',
        });
        return response.ok;
    } catch (error) {
        return false;
    }
}

/**
 * Attempt to start Ollama service
 * Note: This requires Ollama to be installed on the system
 */
export async function startOllama(): Promise<boolean> {
    try {
        // Execute ollama serve in background
        // Note: This uses the browser's ability to make fetch requests
        // The actual service start needs to be done via system command
        // For web apps, we'll just wait and poll for availability

        // Poll for service availability (max 30 seconds)
        const maxAttempts = 30;
        for (let i = 0; i < maxAttempts; i++) {
            const isAvailable = await checkOllamaAvailability();
            if (isAvailable) return true;

            // Wait 1 second between attempts
            await new Promise(resolve => setTimeout(resolve, 1000));
        }

        return false;
    } catch (error) {
        console.error('Failed to start Ollama:', error);
        return false;
    }
}

/**
 * List all available models installed on the system
 */
export async function listAvailableModels(): Promise<OllamaModel[]> {
    try {
        const response = await fetch(`${OLLAMA_BASE_URL}/api/tags`);
        if (!response.ok) {
            throw new Error('Failed to fetch models');
        }

        const data = await response.json();
        return data.models || [];
    } catch (error) {
        console.error('Failed to list models:', error);
        return [];
    }
}

export type ReportType = 'weekly' | 'monthly' | 'focus';

/**
 * Generate AI coach report using Ollama
 */
export async function generateCoachReport(
    habitData: string,
    model: string,
    reportType: ReportType = 'weekly',
    onChunk?: (text: string) => void,
    abortSignal?: AbortSignal
): Promise<string> {
    try {
        // Build prompt based on report type
        let promptInstructions = '';

        switch (reportType) {
            case 'weekly':
                promptInstructions = `Analizza l'ultima settimana e fornisci:
1. **Risultati Chiave**: I 2-3 principali successi della settimana
2. **Pattern Identificati**: Tendenze e comportamenti ricorrenti (es: "fatica il lunedì", "ottimo nei weekend")
3. **Suggerimento Principale**: Un'azione concreta e specifica da implementare la prossima settimana`;
                break;

            case 'monthly':
                promptInstructions = `Analizza l'ultimo mese e fornisci:
1. **Panoramica Mensile**: Progressi generali e trend del mese
2. **Abitudini Consolidate**: Quali abitudini sono diventate più solide
3. **Aree di Miglioramento**: Quali abitudini necessitano più attenzione
4. **Piano per il Prossimo Mese**: 2-3 obiettivi concreti`;
                break;

            case 'focus':
                promptInstructions = `Fornisci un'analisi rapida e mirata:
1. **Stato Attuale**: Snapshot della situazione odierna
2. **Area Critica**: L'abitudine che necessita attenzione immediata
3. **Quick Win**: Un'azione veloce per oggi che può fare la differenza`;
                break;
        }

        const prompt = `Sei un coach personale esperto in abitudini e produttività. ${promptInstructions}

Usa un tono motivante ma realistico. Sii specifico e basati solo sui dati forniti. Rispondi in italiano.

DATI ABITUDINI:
${habitData}

REPORT:`;

        const response = await fetch(`${OLLAMA_BASE_URL}/api/generate`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                model,
                prompt,
                stream: !!onChunk,
            }),
            signal: abortSignal,
        });

        if (!response.ok) {
            throw new Error(`Ollama API error: ${response.statusText}`);
        }

        if (onChunk && response.body) {
            // Handle streaming response
            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let fullText = '';

            while (true) {
                const { done, value } = await reader.read();
                if (done) break;

                const chunk = decoder.decode(value);
                const lines = chunk.split('\n').filter(line => line.trim());

                for (const line of lines) {
                    try {
                        const json = JSON.parse(line);
                        if (json.response) {
                            fullText += json.response;
                            onChunk(json.response);
                        }
                    } catch (e) {
                        // Skip invalid JSON lines
                    }
                }
            }

            return fullText;
        } else {
            // Handle non-streaming response
            const data = await response.json();
            return data.response || '';
        }
    } catch (error: any) {
        if (error.name === 'AbortError') {
            throw new Error('Generazione interrotta dall\'utente');
        }
        console.error('Failed to generate coach report:', error);
        throw error;
    }
}

/**
 * Format habit data for AI analysis
 */
export function formatHabitDataForAI(
    goals: any[],
    logs: Record<string, Record<string, string>>,
    stats: any
): string {
    const last7Days = Object.keys(logs).slice(-7);

    let formatted = `### Abitudini Tracciate (${goals.length})\n`;
    goals.forEach(goal => {
        formatted += `- ${goal.title}\n`;
    });

    formatted += `\n### Performance Ultimi 7 Giorni\n`;
    last7Days.forEach(date => {
        const dayLogs = logs[date];
        const completed = Object.values(dayLogs).filter(status => status === 'done').length;
        const total = Object.keys(dayLogs).length;
        formatted += `- ${date}: ${completed}/${total} completate\n`;
    });

    formatted += `\n### Statistiche Globali\n`;
    formatted += `- Tasso di successo: ${stats.globalSuccessRate}%\n`;
    formatted += `- Migliore streak: ${stats.bestStreak} giorni\n`;
    formatted += `- Giorni attivi totali: ${stats.totalActiveDays}\n`;

    return formatted;
}
