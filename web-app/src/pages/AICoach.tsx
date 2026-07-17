import { useState, useEffect, useRef } from 'react';
import { useGoals } from '@/hooks/useGoals';
import { useHabitStats } from '@/hooks/useHabitStats';
import { usePrivacy } from '@/context/PrivacyContext';
import { useAI } from '@/context/AIContext';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Sparkles, Loader2, AlertTriangle, Download, Cpu, StopCircle, FileText, Calendar, Zap, Bot } from 'lucide-react';
import { toast } from 'sonner';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import {
    checkOllamaAvailability,
    listAvailableModels,
    generateCoachReport,
    formatHabitDataForAI,
    type OllamaModel,
    type ReportType,
} from '@/integrations/ollama';

const AICoach = () => {
    const { goals, logs } = useGoals();
    const stats = useHabitStats(goals, logs, 'weekly');
    const { isPrivacyMode } = usePrivacy();
    const { isAIEnabled } = useAI();
    const abortControllerRef = useRef<AbortController | null>(null);

    const [models, setModels] = useState<OllamaModel[]>([]);
    const [selectedModel, setSelectedModel] = useState<string>('');
    const [reportType, setReportType] = useState<ReportType>('weekly');
    const [isChecking, setIsChecking] = useState(true);
    const [isOllamaRunning, setIsOllamaRunning] = useState(false);
    const [isGenerating, setIsGenerating] = useState(false);
    const [report, setReport] = useState<string>('');
    const [streamingText, setStreamingText] = useState<string>('');
    const [wordCount, setWordCount] = useState(0);

    // Check Ollama availability on mount
    useEffect(() => {
        checkOllamaStatus();
    }, []);

    // Load saved preferences
    useEffect(() => {
        if (models.length > 0) {
            const savedModel = localStorage.getItem('ollama_preferred_model');
            if (savedModel && models.find(m => m.name === savedModel)) {
                setSelectedModel(savedModel);
            } else {
                setSelectedModel(models[0].name);
            }
        }

        const savedReportType = localStorage.getItem('ollama_report_type') as ReportType;
        if (savedReportType && ['weekly', 'monthly', 'focus'].includes(savedReportType)) {
            setReportType(savedReportType);
        }
    }, [models]);

    // Update word count when streaming text changes
    useEffect(() => {
        if (streamingText) {
            const words = streamingText.trim().split(/\s+/).length;
            setWordCount(words);
        }
    }, [streamingText]);

    const checkOllamaStatus = async () => {
        setIsChecking(true);
        try {
            const running = await checkOllamaAvailability();
            setIsOllamaRunning(running);

            if (running) {
                const availableModels = await listAvailableModels();
                setModels(availableModels);

                if (availableModels.length === 0) {
                    toast.error('Nessun modello installato. Esegui: ollama pull llama3.2');
                }
            }
        } catch (error) {
            console.error('Failed to check Ollama:', error);
        } finally {
            setIsChecking(false);
        }
    };

    const handleGenerateReport = async () => {
        if (!selectedModel) {
            toast.error('Seleziona un modello prima di generare il report');
            return;
        }

        setIsGenerating(true);
        setReport('');
        setStreamingText('');
        setWordCount(0);

        // Create abort controller
        abortControllerRef.current = new AbortController();

        try {
            // Prepare data
            const habitData = formatHabitDataForAI(goals, logs, stats);

            // Generate with streaming
            const fullReport = await generateCoachReport(
                habitData,
                selectedModel,
                reportType,
                (chunk) => {
                    setStreamingText(prev => prev + chunk);
                },
                abortControllerRef.current.signal
            );

            setReport(fullReport);
            toast.success('Report generato con successo!');
        } catch (error: any) {
            console.error('Failed to generate report:', error);
            if (error.message?.includes('interrotta')) {
                toast.info('Generazione interrotta');
            } else {
                toast.error('Errore durante la generazione del report');
            }
        } finally {
            setIsGenerating(false);
            abortControllerRef.current = null;
        }
    };

    const handleStopGeneration = () => {
        if (abortControllerRef.current) {
            abortControllerRef.current.abort();
            setIsGenerating(false);
            toast.info('Generazione arrestata');
        }
    };

    const handleModelChange = (value: string) => {
        setSelectedModel(value);
        localStorage.setItem('ollama_preferred_model', value);
    };

    const handleReportTypeChange = (value: ReportType) => {
        setReportType(value);
        localStorage.setItem('ollama_report_type', value);
    };

    const handleExportReport = () => {
        if (!report) return;

        const blob = new Blob([report], { type: 'text/markdown' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `ai-coach-report-${reportType}-${new Date().toISOString().split('T')[0]}.md`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
        toast.success('Report esportato!');
    };

    const formatModelSize = (bytes: number) => {
        const gb = bytes / (1024 ** 3);
        return gb.toFixed(1) + ' GB';
    };

    // Se AI disabilitato, mostra messaggio
    if (!isAIEnabled) {
        return (
            <div className="container mx-auto px-4 py-6 max-w-4xl animate-fade-in pb-32">
                <div className="glass-panel rounded-3xl p-12 text-center space-y-4">
                    <Bot className="w-16 h-16 mx-auto text-muted-foreground opacity-50" />
                    <div>
                        <h2 className="text-2xl font-display font-semibold text-foreground mb-2">AI Coach Disabilitato</h2>
                        <p className="text-muted-foreground">
                            Attiva lo switch "AI" nel Protocollo per utilizzare questa funzionalità.
                        </p>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="container mx-auto px-4 py-6 max-w-4xl animate-fade-in pb-32 space-y-6">
            {/* Background Glow */}
            <div className="fixed top-20 left-1/2 -translate-x-1/2 w-[800px] h-[800px] bg-primary/5 blur-[120px] rounded-full pointer-events-none -z-10" />

            {/* Header */}
            <div className="space-y-2">
                <h1 className="text-2xl sm:text-3xl font-display font-bold text-foreground flex items-center gap-3">
                    <Sparkles className="w-8 h-8 text-primary" />
                    AI Coach
                </h1>
                <p className="text-muted-foreground font-light text-sm sm:text-base">
                    Analisi intelligente delle tue abitudini con Ollama
                </p>
            </div>

            {/* Ollama Status */}
            {isChecking ? (
                <Alert>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    <AlertDescription>Controllo Ollama...</AlertDescription>
                </Alert>
            ) : !isOllamaRunning ? (
                <Alert variant="destructive">
                    <AlertTriangle className="h-4 w-4" />
                    <AlertDescription>
                        Ollama non è attivo. Avvia Ollama con <code className="bg-black/20 px-2 py-1 rounded">ollama serve</code> e{' '}
                        <button onClick={checkOllamaStatus} className="underline font-semibold">
                            riprova
                        </button>
                    </AlertDescription>
                </Alert>
            ) : models.length === 0 ? (
                <Alert variant="destructive">
                    <AlertTriangle className="h-4 w-4" />
                    <AlertDescription>
                        Nessun modello installato. Esegui: <code className="bg-black/20 px-2 py-1 rounded">ollama pull llama3.2</code>
                    </AlertDescription>
                </Alert>
            ) : (
                <>
                    {/* Configuration Card */}
                    <Card className="glass-panel">
                        <CardHeader>
                            <CardTitle className="text-lg flex items-center gap-2">
                                <Cpu className="w-5 h-5" />
                                Configura Analisi
                            </CardTitle>
                            <CardDescription>Seleziona modello e tipo di report</CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            {/* Report Type Selector */}
                            <div className="space-y-2">
                                <label className="text-sm font-medium">Tipo di Report</label>
                                <Select value={reportType} onValueChange={handleReportTypeChange}>
                                    <SelectTrigger className="glass-panel border-white/10">
                                        <SelectValue />
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="weekly">
                                            <div className="flex items-center gap-2">
                                                <FileText className="w-4 h-4" />
                                                <div>
                                                    <div className="font-medium">Settimanale</div>
                                                    <div className="text-xs text-muted-foreground">Analisi ultimi 7 giorni</div>
                                                </div>
                                            </div>
                                        </SelectItem>
                                        <SelectItem value="monthly">
                                            <div className="flex items-center gap-2">
                                                <Calendar className="w-4 h-4" />
                                                <div>
                                                    <div className="font-medium">Mensile</div>
                                                    <div className="text-xs text-muted-foreground">Panoramica del mese</div>
                                                </div>
                                            </div>
                                        </SelectItem>
                                        <SelectItem value="focus">
                                            <div className="flex items-center gap-2">
                                                <Zap className="w-4 h-4" />
                                                <div>
                                                    <div className="font-medium">Focus Rapido</div>
                                                    <div className="text-xs text-muted-foreground">Analisi mirata immediata</div>
                                                </div>
                                            </div>
                                        </SelectItem>
                                    </SelectContent>
                                </Select>
                            </div>

                            {/* Model Selector */}
                            <div className="space-y-2">
                                <label className="text-sm font-medium">Modello AI</label>
                                <Select value={selectedModel} onValueChange={handleModelChange}>
                                    <SelectTrigger className="glass-panel border-white/10">
                                        <SelectValue placeholder="Seleziona modello" />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {models.map((model) => (
                                            <SelectItem key={model.name} value={model.name}>
                                                <div className="flex items-center justify-between gap-3">
                                                    <span className="font-medium">{model.name}</span>
                                                    <span className="text-xs text-muted-foreground">
                                                        {formatModelSize(model.size)}
                                                    </span>
                                                </div>
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>

                            {/* Generate / Stop Buttons */}
                            <div className="flex gap-2">
                                {!isGenerating ? (
                                    <Button
                                        onClick={handleGenerateReport}
                                        disabled={!selectedModel || isPrivacyMode}
                                        className="flex-1"
                                        size="lg"
                                    >
                                        <Sparkles className="w-4 h-4 mr-2" />
                                        Genera Report
                                    </Button>
                                ) : (
                                    <Button
                                        onClick={handleStopGeneration}
                                        variant="destructive"
                                        className="flex-1"
                                        size="lg"
                                    >
                                        <StopCircle className="w-4 h-4 mr-2" />
                                        Ferma Generazione
                                    </Button>
                                )}
                            </div>

                            {isPrivacyMode && (
                                <p className="text-xs text-muted-foreground text-center">
                                    Disattiva la modalità privacy per usare l'AI Coach
                                </p>
                            )}
                        </CardContent>
                    </Card>

                    {/* Report Display */}
                    {(streamingText || report) && (
                        <Card className="glass-panel">
                            <CardHeader className="flex flex-row items-center justify-between">
                                <div className="space-y-1">
                                    <CardTitle className="text-lg">Report AI</CardTitle>
                                    {isGenerating && (
                                        <p className="text-sm text-muted-foreground flex items-center gap-2">
                                            <Loader2 className="w-3 h-3 animate-spin" />
                                            <span className="font-mono">{wordCount} parole generate</span>
                                        </p>
                                    )}
                                </div>
                                {report && !isGenerating && (
                                    <Button variant="outline" size="sm" onClick={handleExportReport}>
                                        <Download className="w-4 h-4 mr-2" />
                                        Esporta
                                    </Button>
                                )}
                            </CardHeader>
                            <CardContent>
                                <div className="prose prose-invert prose-sm max-w-none">
                                    <ReactMarkdown remarkPlugins={[remarkGfm]}>
                                        {isGenerating ? streamingText : report}
                                    </ReactMarkdown>
                                </div>
                            </CardContent>
                        </Card>
                    )}
                </>
            )}
        </div>
    );
};

export default AICoach;
