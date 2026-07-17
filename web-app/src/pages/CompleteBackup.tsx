import { useState, useCallback } from 'react';
import { useCompleteBackup, ImportDetailedReport } from '@/hooks/useCompleteBackup';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Separator } from '@/components/ui/separator';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import {
    Download,
    Upload,
    Database,
    CheckCircle2,
    XCircle,
    AlertCircle,
    FileArchive,
    Calendar,
    Target,
    BookOpen,
    Smile,
    Settings,
    FileText,
    Palette,
    Loader2
} from 'lucide-react';

export default function CompleteBackup() {
    const { exportCompleteBackup, importCompleteBackup, isExporting, isImporting } = useCompleteBackup();
    const [importReport, setImportReport] = useState<ImportDetailedReport | null>(null);
    const [isDragging, setIsDragging] = useState(false);

    const handleExport = async () => {
        await exportCompleteBackup();
    };

    const handleImport = async (file: File) => {
        const report = await importCompleteBackup(file);
        setImportReport(report);
    };

    const handleDrop = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        setIsDragging(false);

        const files = Array.from(e.dataTransfer.files);
        if (files.length > 0) {
            handleImport(files[0]);
        }
    }, []);

    const handleDragOver = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        setIsDragging(true);
    }, []);

    const handleDragLeave = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        setIsDragging(false);
    }, []);

    const handleFileSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const files = e.target.files;
        if (files && files.length > 0) {
            handleImport(files[0]);
        }
    }, []);

    const dataItems = [
        { icon: Target, label: 'Abitudini giornaliere', key: 'goals', color: 'text-blue-500' },
        { icon: CheckCircle2, label: 'Log completamento abitudini', key: 'goal_logs', color: 'text-green-500' },
        { icon: Calendar, label: 'Obiettivi macro (annuali, mensili, etc.)', key: 'long_term_goals', color: 'text-purple-500' },
        { icon: Palette, label: 'Categorie e colori personalizzati', key: 'goal_category_settings', color: 'text-pink-500' },
        { icon: BookOpen, label: 'Log di lettura', key: 'reading_logs', color: 'text-amber-500' },
        { icon: Smile, label: 'Registrazioni Mood & Energy', key: 'daily_moods', color: 'text-cyan-500' },
        { icon: Settings, label: 'Impostazioni utente', key: 'user_settings', color: 'text-slate-500' },
        { icon: FileText, label: 'Note personali (memo)', key: 'user_memos', color: 'text-orange-500' },
    ];

    return (
        <div className="container mx-auto p-4 sm:p-6 max-w-4xl">
            <div className="space-y-6">
                {/* Header */}
                <div className="space-y-2">
                    <h1 className="text-3xl font-bold tracking-tight flex items-center gap-2">
                        <Database className="h-8 w-8 text-primary" />
                        Backup Completo
                    </h1>
                    <p className="text-muted-foreground">
                        Esporta o importa tutti i dati dell'applicazione in un unico archivio organizzato
                    </p>
                </div>

                {/* Info Card */}
                <Alert>
                    <AlertCircle className="h-4 w-4" />
                    <AlertTitle>Cosa viene salvato nel backup?</AlertTitle>
                    <AlertDescription>
                        Il backup include <strong>tutti i tuoi dati</strong>: abitudini, obiettivi, log, impostazioni,
                        categorie personalizzate, note e registrazioni mood. Il file sarà scaricato come archivio ZIP ben organizzato.
                    </AlertDescription>
                </Alert>

                {/* Export Section */}
                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <Download className="h-5 w-5" />
                            Esporta Backup
                        </CardTitle>
                        <CardDescription>
                            Scarica un backup completo di tutti i tuoi dati in formato ZIP
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                        {/* Data Items Grid */}
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                            {dataItems.map((item) => (
                                <div
                                    key={item.key}
                                    className="flex items-center gap-3 p-3 rounded-lg bg-muted/50 hover:bg-muted transition-colors"
                                >
                                    <item.icon className={`h-5 w-5 ${item.color}`} />
                                    <span className="text-sm font-medium">{item.label}</span>
                                </div>
                            ))}
                        </div>

                        <Separator />

                        <Button
                            onClick={handleExport}
                            disabled={isExporting}
                            className="w-full sm:w-auto"
                            size="lg"
                        >
                            {isExporting ? (
                                <>
                                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                    Creazione backup...
                                </>
                            ) : (
                                <>
                                    <FileArchive className="mr-2 h-4 w-4" />
                                    Esporta Backup Completo
                                </>
                            )}
                        </Button>
                    </CardContent>
                </Card>

                {/* Import Section */}
                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <Upload className="h-5 w-5" />
                            Importa Backup
                        </CardTitle>
                        <CardDescription>
                            Ripristina i tuoi dati da un file di backup precedente (ZIP o JSON)
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                        {/* Drop Zone */}
                        <div
                            onDrop={handleDrop}
                            onDragOver={handleDragOver}
                            onDragLeave={handleDragLeave}
                            className={`
                                border-2 border-dashed rounded-lg p-8 text-center transition-all
                                ${isDragging
                                    ? 'border-primary bg-primary/5 scale-105'
                                    : 'border-muted-foreground/25 hover:border-muted-foreground/50'
                                }
                            `}
                        >
                            <FileArchive className="h-12 w-12 mx-auto mb-4 text-muted-foreground" />
                            <p className="text-sm font-medium mb-2">
                                Trascina qui il file di backup
                            </p>
                            <p className="text-xs text-muted-foreground mb-4">
                                Supporta file .zip e .json
                            </p>
                            <label htmlFor="backup-file-input">
                                <Button variant="outline" size="sm" asChild disabled={isImporting}>
                                    <span className="cursor-pointer">
                                        {isImporting ? (
                                            <>
                                                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                                Importazione...
                                            </>
                                        ) : (
                                            'Oppure clicca per selezionare'
                                        )}
                                    </span>
                                </Button>
                            </label>
                            <input
                                id="backup-file-input"
                                type="file"
                                accept=".zip,.json"
                                onChange={handleFileSelect}
                                className="hidden"
                                disabled={isImporting}
                            />
                        </div>

                        {/* Import Progress */}
                        {isImporting && (
                            <div className="space-y-2">
                                <div className="flex items-center justify-between text-sm">
                                    <span className="text-muted-foreground">Ripristino in corso...</span>
                                </div>
                                <Progress value={undefined} className="h-2" />
                            </div>
                        )}

                        {/* Import Report */}
                        {importReport && (
                            <Alert className="border-green-500/50 bg-green-500/10">
                                <CheckCircle2 className="h-4 w-4 text-green-500" />
                                <AlertTitle className="text-green-500">Backup importato con successo!</AlertTitle>
                                <AlertDescription className="mt-2">
                                    <ScrollArea className="h-48 w-full rounded-md border p-4 bg-background/50">
                                        <div className="space-y-3 text-sm">
                                            <div className="font-semibold">
                                                Record totali processati: {importReport.totalProcessed}
                                            </div>

                                            <Separator />

                                            <div className="space-y-2">
                                                {Object.entries(importReport.byTable).map(([table, stats]) => (
                                                    <div key={table} className="space-y-1">
                                                        <div className="font-medium capitalize">
                                                            {table.replace(/_/g, ' ')}
                                                        </div>
                                                        <div className="pl-4 text-xs space-y-0.5 text-muted-foreground">
                                                            {stats.inserted > 0 && (
                                                                <div className="flex items-center gap-2">
                                                                    <CheckCircle2 className="h-3 w-3 text-green-500" />
                                                                    <span>{stats.inserted} nuovi record</span>
                                                                </div>
                                                            )}
                                                            {stats.updated > 0 && (
                                                                <div className="flex items-center gap-2">
                                                                    <AlertCircle className="h-3 w-3 text-blue-500" />
                                                                    <span>{stats.updated} aggiornati</span>
                                                                </div>
                                                            )}
                                                            {stats.unchanged > 0 && (
                                                                <div className="flex items-center gap-2">
                                                                    <span className="text-muted-foreground">
                                                                        {stats.unchanged} invariati
                                                                    </span>
                                                                </div>
                                                            )}
                                                            {stats.errors.length > 0 && (
                                                                <div className="flex items-center gap-2 text-destructive">
                                                                    <XCircle className="h-3 w-3" />
                                                                    <span>{stats.errors.join(', ')}</span>
                                                                </div>
                                                            )}
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>

                                            {importReport.settingsRestored.length > 0 && (
                                                <>
                                                    <Separator />
                                                    <div>
                                                        <div className="font-medium">Impostazioni ripristinate:</div>
                                                        <div className="pl-4 text-xs text-muted-foreground">
                                                            {importReport.settingsRestored.join(', ')}
                                                        </div>
                                                    </div>
                                                </>
                                            )}
                                        </div>
                                    </ScrollArea>
                                </AlertDescription>
                            </Alert>
                        )}
                    </CardContent>
                </Card>

                {/* Warning */}
                <Alert variant="destructive">
                    <AlertCircle className="h-4 w-4" />
                    <AlertTitle>Attenzione</AlertTitle>
                    <AlertDescription>
                        L'importazione di un backup <strong>sovrascriverà i dati esistenti</strong>.
                        Assicurati di aver effettuato un backup prima di procedere se hai dati da conservare.
                    </AlertDescription>
                </Alert>
            </div>
        </div>
    );
}
