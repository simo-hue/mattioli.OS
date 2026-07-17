import { useState, useEffect, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Checkbox } from '@/components/ui/checkbox';
import { Trash2, Plus, Calendar as CalendarIcon, Loader2, Download, Upload, PieChart, Pencil, ArrowRightToLine } from 'lucide-react';
import { toast } from 'sonner';
import { cn } from '@/lib/utils';
import { MacroGoalsStats } from './MacroGoalsStats';
import { GoalCategorySettingsDialog } from './GoalCategorySettingsDialog';
import { useGoalCategories } from '@/hooks/useGoalCategories';
import { useGoalBackup, ImportReport } from '@/hooks/useGoalBackup';
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Label } from "@/components/ui/label";
import { usePrivacy } from '@/context/PrivacyContext';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
    AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { format, getQuarter } from 'date-fns';
import { getLogicalWeekOfMonth, getLogicalWeeksInMonth } from '@/lib/dateUtils';
import { it } from 'date-fns/locale';

import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog";

type GoalType = 'annual' | 'quarterly' | 'monthly' | 'weekly' | 'lifetime' | 'stats';

export interface LongTermGoal {
    id: string;
    title: string;
    status: 'active' | 'completed' | 'failed';
    type: GoalType;
    year: number;
    quarter: number | null;
    month: number | null;
    week_number: number | null;
    created_at: string;
    color: string | null;
}

const goalColors = [
    { name: 'Nessuno', value: null, class: 'bg-card/20 border-white/5' },
    { name: 'Rosso', value: 'red', class: 'bg-rose-500/15 border-rose-500/30 hover:bg-rose-500/25' },
    { name: 'Arancione', value: 'orange', class: 'bg-orange-500/15 border-orange-500/30 hover:bg-orange-500/25' },
    { name: 'Giallo', value: 'yellow', class: 'bg-amber-400/15 border-amber-400/30 hover:bg-amber-400/25' },
    { name: 'Blu', value: 'blue', class: 'bg-blue-600/15 border-blue-600/30 hover:bg-blue-600/25' },
    { name: 'Viola', value: 'purple', class: 'bg-violet-600/15 border-violet-600/30 hover:bg-violet-600/25' },
    { name: 'Rosa', value: 'pink', class: 'bg-fuchsia-500/15 border-fuchsia-500/30 hover:bg-fuchsia-500/25' },
    { name: 'Ciano', value: 'cyan', class: 'bg-cyan-500/15 border-cyan-500/30 hover:bg-cyan-500/25' },
];

export function LongTermGoals() {
    const [selectedYear, setSelectedYear] = useState<string>(new Date().getFullYear().toString());
    const [selectedQuarter, setSelectedQuarter] = useState<number>(getQuarter(new Date()));
    const [selectedMonth, setSelectedMonth] = useState<number>(new Date().getMonth() + 1);
    // Initialize with current week dynamically
    const [selectedWeek, setSelectedWeek] = useState<number>(getLogicalWeekOfMonth(new Date()));
    // Default view set to weekly as requested
    const [view, setView] = useState<GoalType>('weekly');
    const [exportScope, setExportScope] = useState<'all' | 'year'>('all');
    const [importReport, setImportReport] = useState<ImportReport | null>(null);
    const [newGoalTitle, setNewGoalTitle] = useState('');
    const [newGoalColor, setNewGoalColor] = useState<string | null>(null);
    const [editingGoal, setEditingGoal] = useState<{ id: string, title: string } | null>(null);

    const queryClient = useQueryClient();

    const [pendingUpdates, setPendingUpdates] = useState<Record<string, 'active' | 'completed' | 'failed'>>({});
    const updateTimeouts = useRef<Record<string, NodeJS.Timeout>>({});

    // Cleanup timeouts on unmount
    useEffect(() => {
        return () => {
            Object.values(updateTimeouts.current).forEach(clearTimeout);
        };
    }, []);

    const { getLabel, getColor, categoryLabels, activeCategoryLabels } = useGoalCategories();
    const { isPrivacyMode } = usePrivacy();

    // Helper to generate dynamic styles based on category color
    const getGoalStyle = (colorKey: string | null) => {
        const color = getColor(colorKey);
        if (!color) return {};

        // Assume HSL format from system
        if (color.startsWith('hsl')) {
            return {
                backgroundColor: color.replace(')', ' / 0.15)'),
                borderColor: color.replace(')', ' / 0.3)'),
            };
        }
        return { borderColor: color }; // Fallback
    };

    // Helper for pure color (no opacity)
    const getGoalColor = (colorKey: string | null) => {
        const color = getColor(colorKey);
        return color || 'transparent'; // or some default
    };

    const getGoalColorClass = (colorValue: string | null) => {
        // Keep base classes, but remove specific color classes as they will be overridden by style
        return "bg-card/20 border-white/5 hover:bg-card/40 relative overflow-hidden";
    };



    const quarters = [
        { value: 1, label: '1° Trimestre (Q1)' },
        { value: 2, label: '2° Trimestre (Q2)' },
        { value: 3, label: '3° Trimestre (Q3)' },
        { value: 4, label: '4° Trimestre (Q4)' },
    ];

    // Sort keys: defaults first (in specific order if possible), then custom
    // Use activeCategoryLabels to only show available options in dropdowns
    const categoryKeys = Object.keys(activeCategoryLabels).sort((a, b) => {
        // Simple sort: if one is default and other is not...
        // Actually, relying on object order or simple alpha sort for now is fine,
        // but maybe defaults should come first.
        const defaults = ['red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink', 'cyan'];
        const ia = defaults.indexOf(a);
        const ib = defaults.indexOf(b);
        if (ia !== -1 && ib !== -1) return ia - ib;
        if (ia !== -1) return -1;
        if (ib !== -1) return 1;
        return a.localeCompare(b);
    });

    const { data: goals, isLoading } = useQuery({
        queryKey: ['longTermGoals', view, selectedYear, selectedQuarter, selectedMonth, selectedWeek],
        queryFn: async () => {
            let query = supabase.from('long_term_goals')
                .select('*')
                .eq('type', view)
                .order('status', { ascending: true }) // active -> completed -> failed
                .order('color', { ascending: true }) // Group by color
                .order('created_at', { ascending: true });

            if (selectedYear !== 'all' && view !== 'lifetime') {
                query = query.eq('year', parseInt(selectedYear));
            }

            if (view === 'quarterly') {
                query = query.eq('quarter', selectedQuarter);
            } else if (view === 'monthly') {
                query = query.eq('month', selectedMonth);
            } else if (view === 'weekly') {
                query = query.eq('month', selectedMonth).eq('week_number', selectedWeek);
            }

            const { data, error } = await query;
            if (error) throw error;
            return data as LongTermGoal[];
        },
        enabled: view !== 'stats', // Disable query when in stats view
    });

    const createGoalMutation = useMutation({
        mutationFn: async ({ title, color }: { title: string; color: string | null }) => {
            const { data: { user } } = await supabase.auth.getUser();
            if (!user) throw new Error('Not authenticated');

            const newGoal = {
                user_id: user.id,
                title,
                type: view,
                year: view === 'lifetime' ? null : (selectedYear === 'all' ? new Date().getFullYear() : parseInt(selectedYear)),
                quarter: view === 'quarterly' ? selectedQuarter : null,
                month: (view === 'monthly' || view === 'weekly') ? selectedMonth : null,
                week_number: view === 'weekly' ? selectedWeek : null,
                status: 'active', // Default to active
                color: color,
            };

            const { data, error } = await (supabase
                .from('long_term_goals') as any)
                .insert(newGoal)
                .select()
                .single();

            if (error) throw error;
            return data;
        },
        onSuccess: () => {
            setNewGoalTitle('');
            setNewGoalColor(null);
            queryClient.invalidateQueries({ queryKey: ['longTermGoals'] });
            toast.success('Obiettivo creato!');
        },
        onError: (error) => {
            toast.error(`Errore durante la creazione: ${error.message}`);
        },
    });

    const updateStatusMutation = useMutation({
        mutationFn: async ({ id, status }: { id: string; status: 'active' | 'completed' | 'failed' }) => {
            const { error } = await (supabase
                .from('long_term_goals') as any)
                .update({ status })
                .eq('id', id);

            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['longTermGoals'] });
        },
    });

    const updateColorMutation = useMutation({
        mutationFn: async ({ id, color }: { id: string, color: string | null }) => {
            const { error } = await (supabase.from('long_term_goals') as any).update({ color }).eq('id', id);
            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['longTermGoals'] });
        },
        onError: () => {
            toast.error('Errore aggiornamento colore');
        }
    });

    const updateTitleMutation = useMutation({
        mutationFn: async ({ id, title }: { id: string, title: string }) => {
            const { error } = await (supabase.from('long_term_goals') as any).update({ title }).eq('id', id);
            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['longTermGoals'] });
            setEditingGoal(null);
            toast.success('Obiettivo aggiornato');
        },
        onError: () => {
            toast.error('Errore aggiornamento titolo');
        }
    });

    // Segna come fallito e copia nella settimana successiva
    const failAndCopyToNextWeekMutation = useMutation({
        mutationFn: async (goal: LongTermGoal) => {
            const { data: { user } } = await supabase.auth.getUser();
            if (!user) throw new Error('Not authenticated');

            // Step 1: segna l'obiettivo corrente come fallito
            const { error: failError } = await (supabase.from('long_term_goals') as any)
                .update({ status: 'failed' })
                .eq('id', goal.id);
            if (failError) throw failError;

            // Step 2: calcola settimana e mese successivi
            const currentWeekNum = goal.week_number ?? 1;
            const currentMonthNum = goal.month ?? 1;
            const currentYearNum = goal.year ?? new Date().getFullYear();

            // Quante settimane ha il mese corrente?
            const weeksInCurrentMonth = getLogicalWeeksInMonth(
                new Date(currentYearNum, currentMonthNum - 1, 1)
            );

            let nextWeek: number;
            let nextMonth: number;
            let nextYear: number;

            if (currentWeekNum < weeksInCurrentMonth) {
                // Stessa mese, settimana successiva
                nextWeek = currentWeekNum + 1;
                nextMonth = currentMonthNum;
                nextYear = currentYearNum;
            } else {
                // Vai al mese successivo, prima settimana
                nextWeek = 1;
                nextMonth = currentMonthNum === 12 ? 1 : currentMonthNum + 1;
                nextYear = currentMonthNum === 12 ? currentYearNum + 1 : currentYearNum;
            }

            // Step 3: crea il goal nella settimana successiva
            const nextGoal = {
                user_id: user.id,
                title: goal.title,
                type: 'weekly',
                year: nextYear,
                quarter: null,
                month: nextMonth,
                week_number: nextWeek,
                status: 'active',
                color: goal.color,
            };

            const { error: createError } = await (supabase.from('long_term_goals') as any)
                .insert(nextGoal);
            if (createError) throw createError;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['longTermGoals'] });
            toast.success('Goal segnato come fallito e copiato nella settimana successiva! 🚀');
        },
        onError: (error) => {
            toast.error(`Errore: ${error.message}`);
        }
    });

    const deleteGoalMutation = useMutation({
        mutationFn: async (id: string) => {
            const { error } = await supabase
                .from('long_term_goals')
                .delete()
                .eq('id', id);
            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['longTermGoals'] });
            toast.success('Obiettivo eliminato');
        },
    });

    const handleCreate = (e: React.FormEvent) => {
        e.preventDefault();
        if (!newGoalTitle.trim()) return;
        createGoalMutation.mutate({ title: newGoalTitle, color: newGoalColor });
    };

    const fileInputRef = useRef<HTMLInputElement>(null);

    const { exportBackup, importBackup, isExporting, isImporting } = useGoalBackup();

    const handleImportClick = () => {
        fileInputRef.current?.click();
    };

    const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
        const file = event.target.files?.[0];
        if (!file) return;

        const report = await importBackup(file);
        if (report) {
            setImportReport(report);
        }

        // Reset input
        if (fileInputRef.current) {
            fileInputRef.current.value = '';
        }
    };

    const months = [
        { value: 1, label: 'Gennaio' },
        { value: 2, label: 'Febbraio' },
        { value: 3, label: 'Marzo' },
        { value: 4, label: 'Aprile' },
        { 'value': 5, 'label': 'Maggio' },
        { value: 6, label: 'Giugno' },
        { value: 7, label: 'Luglio' },
        { value: 8, label: 'Agosto' },
        { value: 9, label: 'Settembre' },
        { value: 10, label: 'Ottobre' },
        { value: 11, label: 'Novembre' },
        { value: 12, label: 'Dicembre' },
    ];


    // Fetch minimum year from database
    const { data: minYearData } = useQuery({
        queryKey: ['longTermGoals', 'minYear'],
        queryFn: async () => {
            const { data, error } = await supabase
                .from('long_term_goals')
                .select('year')
                .order('year', { ascending: true })
                .limit(1)
                .single();

            if (error && error.code !== 'PGRST116') console.error('Error fetching min year:', error);
            // Default to 2022 if no data or error, or the found year if valid
            const year = (data as any)?.year || 2022;
            return year;
        }
    });

    const startYear = minYearData || 2022;

    // Generate year range: startYear to (Current Year + 5)
    const currentYear = new Date().getFullYear();
    const currentMonth = new Date().getMonth() + 1;
    const currentWeek = getLogicalWeekOfMonth(new Date());
    const years = Array.from({ length: (currentYear + 5) - startYear + 1 }, (_, i) => startYear + i);

    return (
        <div className="space-y-6 animate-fade-in p-2 md:p-0">
            {/* Edit Dialog */}
            <Dialog open={!!editingGoal} onOpenChange={(open) => !open && setEditingGoal(null)}>
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>Modifica Obiettivo</DialogTitle>
                        <DialogDescription>
                            Modifica il titolo del tuo obiettivo.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="py-4">
                        <Input
                            value={editingGoal?.title || ''}
                            onChange={(e) => setEditingGoal(prev => prev ? { ...prev, title: e.target.value } : null)}
                            placeholder="Titolo obiettivo..."
                        />
                    </div>
                    <DialogFooter>
                        <Button variant="outline" onClick={() => setEditingGoal(null)}>Annulla</Button>
                        <Button
                            onClick={() => editingGoal && updateTitleMutation.mutate({ id: editingGoal.id, title: editingGoal.title })}
                            disabled={updateTitleMutation.isPending || !editingGoal?.title.trim()}
                        >
                            {updateTitleMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : null}
                            Salva Modifiche
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Report Dialog */}
            <AlertDialog open={!!importReport} onOpenChange={(open) => !open && setImportReport(null)}>
                <AlertDialogContent className="max-w-3xl max-h-[85vh] overflow-y-auto">
                    <AlertDialogHeader>
                        <AlertDialogTitle>Rapporto Importazione</AlertDialogTitle>
                        <AlertDialogDescription>
                            Ecco il dettaglio delle modifiche apportate ai tuoi dati.
                        </AlertDialogDescription>
                    </AlertDialogHeader>

                    <div className="space-y-6 py-4">
                        {/* Summary Stats Cards */}
                        <div className="grid grid-cols-3 gap-4">
                            <div className="p-4 bg-green-500/10 border border-green-500/20 rounded-xl flex flex-col items-center justify-center text-center">
                                <span className="text-3xl font-bold text-green-600 dark:text-green-400">{importReport?.restored.length || 0}</span>
                                <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mt-1">Nuovi</span>
                            </div>
                            <div className="p-4 bg-amber-500/10 border border-amber-500/20 rounded-xl flex flex-col items-center justify-center text-center">
                                <span className="text-3xl font-bold text-amber-600 dark:text-amber-400">{importReport?.updated.length || 0}</span>
                                <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mt-1">Modificati</span>
                            </div>
                            <div className="p-4 bg-slate-500/10 border border-slate-500/20 rounded-xl flex flex-col items-center justify-center text-center opacity-70">
                                <span className="text-3xl font-bold text-slate-600 dark:text-slate-400">{importReport?.unchanged || 0}</span>
                                <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mt-1">Invariati</span>
                            </div>
                        </div>

                        {importReport?.settingsUpdated && (
                            <div className="flex items-center gap-3 text-sm text-yellow-600 bg-yellow-50 dark:bg-yellow-900/20 dark:text-yellow-400 p-3 rounded-lg border border-yellow-200 dark:border-yellow-800">
                                <span className="flex h-2 w-2 rounded-full bg-yellow-500 animate-pulse" />
                                <span>Le impostazioni delle categorie sono state aggiornate con successo.</span>
                            </div>
                        )}

                        {/* Detailed Lists with Categories */}
                        <div className="space-y-6">
                            {/* Restored Section */}
                            {importReport?.restored && importReport.restored.length > 0 && (
                                <div className="space-y-3">
                                    <h4 className="font-semibold flex items-center gap-2 text-green-600 dark:text-green-400">
                                        <div className="w-2 h-2 rounded-full bg-current" />
                                        Elementi Aggiunti / Ripristinati
                                    </h4>
                                    <div className="space-y-4 pl-4 border-l-2 border-green-100 dark:border-green-900/30">
                                        {Object.entries(
                                            (importReport.restored as any[]).reduce((acc: any, goal: any) => {
                                                const label = getLabel(goal.color || 'default');
                                                if (!acc[label]) acc[label] = [];
                                                acc[label].push(goal);
                                                return acc;
                                            }, {})
                                        ).map(([category, goals]: [string, any[]]) => (
                                            <div key={category} className="space-y-2">
                                                <div className="text-xs font-bold uppercase text-muted-foreground tracking-widest">{category}</div>
                                                <div className="grid gap-2">
                                                    {goals.map(g => (
                                                        <div key={g.id} className="bg-secondary/40 p-3 rounded-md flex justify-between items-start gap-3 text-sm">
                                                            <span className="font-medium">{g.title}</span>
                                                            <span className="shrink-0 text-xs px-2 py-0.5 bg-background rounded border opacity-70">
                                                                {g.year} • {g.type}
                                                            </span>
                                                        </div>
                                                    ))}
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}

                            {/* Updated Section */}
                            {importReport?.updated && importReport.updated.length > 0 && (
                                <div className="space-y-3">
                                    <h4 className="font-semibold flex items-center gap-2 text-amber-600 dark:text-amber-400">
                                        <div className="w-2 h-2 rounded-full bg-current" />
                                        Elementi Aggiornati
                                    </h4>
                                    <div className="space-y-4 pl-4 border-l-2 border-amber-100 dark:border-amber-900/30">
                                        {Object.entries(
                                            (importReport.updated as any[]).reduce((acc: any, goal: any) => {
                                                const label = getLabel(goal.color || 'default');
                                                if (!acc[label]) acc[label] = [];
                                                acc[label].push(goal);
                                                return acc;
                                            }, {})
                                        ).map(([category, goals]: [string, any[]]) => (
                                            <div key={category} className="space-y-2">
                                                <div className="text-xs font-bold uppercase text-muted-foreground tracking-widest">{category}</div>
                                                <div className="grid gap-2">
                                                    {goals.map(g => (
                                                        <div key={g.id} className="bg-secondary/40 p-3 rounded-md flex justify-between items-start gap-3 text-sm">
                                                            <span className="font-medium">{g.title}</span>
                                                            <span className="shrink-0 text-xs px-2 py-0.5 bg-background rounded border opacity-70">
                                                                {g.year} • {g.type}
                                                            </span>
                                                        </div>
                                                    ))}
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>

                    <AlertDialogFooter>
                        <AlertDialogAction onClick={() => setImportReport(null)}>Chiudi Report</AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>

            {/* New UI Header */}
            <div className="space-y-6">
                {/* 1. View Mode Switcher */}
                <div className="flex justify-center w-full">
                    <Tabs value={view} onValueChange={(v) => setView(v as GoalType)} className="w-full max-w-2xl">
                        <TabsList className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 w-full h-auto p-1 bg-secondary/30 backdrop-blur-sm border border-white/5 gap-1">
                            <TabsTrigger value="lifetime" className="w-full col-span-2 sm:col-span-1">Lifetime</TabsTrigger>
                            <TabsTrigger value="annual" className="w-full">Annuale</TabsTrigger>
                            <TabsTrigger value="quarterly" className="w-full">Trimestrale</TabsTrigger>
                            <TabsTrigger value="monthly" className="w-full">Mensile</TabsTrigger>
                            <TabsTrigger value="weekly" className="w-full">Settimanale</TabsTrigger>
                            <TabsTrigger value="stats" className="w-full gap-2 col-span-2 sm:col-span-1"><PieChart className="w-4 h-4" /> Stats</TabsTrigger>
                        </TabsList>
                    </Tabs>
                </div>

                {/* 2. Contextual Toolbar */}
                <div className="flex flex-col md:flex-row justify-between items-center gap-4 p-4 rounded-2xl bg-card/40 border border-white/5 backdrop-blur-xl transition-all duration-300">

                    {/* Left: Filters - Only show what's needed */}
                    <div className="flex flex-wrap justify-center md:justify-start items-center gap-2 w-full md:w-auto">
                        <Select value={selectedYear} onValueChange={(val) => setSelectedYear(val)}>
                            <SelectTrigger className="w-[120px] bg-background/40 border-white/5">
                                <SelectValue placeholder="Anno" />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="all" className="font-bold text-primary">Dal {startYear}</SelectItem>
                                {years.map(year => (
                                    <SelectItem key={year} value={year.toString()} className={cn(year < currentYear && "text-muted-foreground italic")}>
                                        {year}
                                    </SelectItem>
                                ))}
                            </SelectContent>
                        </Select>

                        {view === 'quarterly' && (
                            <Select value={selectedQuarter.toString()} onValueChange={(val) => setSelectedQuarter(parseInt(val))}>
                                <SelectTrigger className="w-[160px] bg-background/40 border-white/5">
                                    <SelectValue placeholder="Trimestre" />
                                </SelectTrigger>
                                <SelectContent>
                                    {quarters.map(q => (
                                        <SelectItem key={q.value} value={q.value.toString()}>{q.label}</SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                        )}

                        {(view === 'monthly' || view === 'weekly') && (
                            <Select value={selectedMonth.toString()} onValueChange={(val) => {
                                setSelectedMonth(parseInt(val));
                                setSelectedWeek(1);
                            }}>
                                <SelectTrigger className="w-[140px] bg-background/40 border-white/5">
                                    <SelectValue placeholder="Mese" />
                                </SelectTrigger>
                                <SelectContent>
                                    {months.map(m => (
                                        <SelectItem key={m.value} value={m.value.toString()} className={cn(
                                            (
                                                (selectedYear !== 'all' && parseInt(selectedYear) < currentYear) ||
                                                (selectedYear === currentYear.toString() && m.value < currentMonth)
                                            ) && "text-muted-foreground italic"
                                        )}>
                                            {m.label}
                                        </SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                        )}

                        {view === 'weekly' && (
                            <Select value={selectedWeek.toString()} onValueChange={(val) => setSelectedWeek(parseInt(val))}>
                                <SelectTrigger className="w-[140px] bg-background/40 border-white/5">
                                    <SelectValue placeholder="Settimana" />
                                </SelectTrigger>
                                <SelectContent>
                                    {Array.from({ length: getLogicalWeeksInMonth(new Date(selectedYear === 'all' ? currentYear : parseInt(selectedYear), selectedMonth - 1, 1)) }, (_, i) => i + 1).map(w => (
                                        <SelectItem key={w} value={w.toString()} className={cn(
                                            (
                                                (selectedYear !== 'all' && parseInt(selectedYear) < currentYear) ||
                                                (selectedYear === currentYear.toString() && selectedMonth < currentMonth) ||
                                                (selectedYear === currentYear.toString() && selectedMonth === currentMonth && w < currentWeek)
                                            ) && "text-muted-foreground italic"
                                        )}>
                                            Settimana {w}
                                        </SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                        )}
                    </div>

                    {/* Right: Actions */}
                    <div className="flex items-center gap-2">
                        {/* Export Button */}
                        <AlertDialog>
                            <AlertDialogTrigger asChild>
                                <Button variant="ghost" size="icon" className="hover:bg-white/5" title="Esporta Backup (JSON)">
                                    <Download className="w-4 h-4 text-muted-foreground" />
                                </Button>
                            </AlertDialogTrigger>
                            <AlertDialogContent className="sm:max-w-md">
                                <AlertDialogHeader>
                                    <AlertDialogTitle>Backup Obiettivi</AlertDialogTitle>
                                    <AlertDialogDescription>
                                        Crea un backup dei tuoi obiettivi e impostazioni. I file sono in formato JSON.
                                    </AlertDialogDescription>
                                </AlertDialogHeader>

                                <div className="py-4">
                                    <RadioGroup value={exportScope} onValueChange={(v: 'all' | 'year') => setExportScope(v)}>
                                        <div className="flex items-center space-x-2 border p-3 rounded-lg hover:bg-accent cursor-pointer" onClick={() => setExportScope('all')}>
                                            <RadioGroupItem value="all" id="r1" />
                                            <Label htmlFor="r1" className="cursor-pointer flex-1">
                                                <div className="font-medium">Esporta Tutto</div>
                                                <div className="text-xs text-muted-foreground">Tutti gli anni, mesi e impostazioni</div>
                                            </Label>
                                        </div>
                                        <div className="flex items-center space-x-2 border p-3 rounded-lg hover:bg-accent cursor-pointer" onClick={() => setExportScope('year')}>
                                            <RadioGroupItem value="year" id="r2" />
                                            <Label htmlFor="r2" className="cursor-pointer flex-1">
                                                <div className="font-medium">Solo {selectedYear === 'all' ? currentYear : selectedYear}</div>
                                                <div className="text-xs text-muted-foreground">Solo obiettivi di questo anno e impostazioni</div>
                                            </Label>
                                        </div>
                                    </RadioGroup>
                                </div>

                                <AlertDialogFooter>
                                    <AlertDialogCancel>Annulla</AlertDialogCancel>
                                    <AlertDialogAction onClick={() => exportBackup({ scope: exportScope, year: selectedYear === 'all' ? currentYear : parseInt(selectedYear) })} disabled={isExporting}>
                                        {isExporting ? <Loader2 className="w-4 h-4 animate-spin mr-2" /> : null}
                                        Scarica Backup
                                    </AlertDialogAction>
                                </AlertDialogFooter>
                            </AlertDialogContent>
                        </AlertDialog>

                        {/* Import Button */}
                        <Button variant="ghost" size="icon" className="hover:bg-white/5" title="Ripristina da Backup (JSON)" onClick={handleImportClick} disabled={isImporting}>
                            {isImporting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Upload className="w-4 h-4 text-muted-foreground" />}
                        </Button>
                        <input
                            type="file"
                            ref={fileInputRef}
                            onChange={handleFileUpload}
                            accept=".json"
                            className="hidden"
                        />

                        {/* Settings Button */}
                        <div className="ml-1">
                            <GoalCategorySettingsDialog />
                        </div>
                    </div>
                </div>

                {/* Dynamic Title Context */}
                {view !== 'stats' && (
                    <div className={cn("text-2xl font-bold tracking-tight text-white flex items-center gap-3 transition-all duration-300 pl-2", isPrivacyMode && "blur-sm")}>
                        {view === 'lifetime' && <span className="text-emerald-400">Lifetime</span>}
                        {view === 'annual' && <span className="text-primary">{selectedYear === 'all' ? 'Tutti gli anni' : selectedYear}</span>}
                        {view === 'quarterly' && <span className="text-amber-500">Q{selectedQuarter} {selectedYear !== 'all' && selectedYear}</span>}
                        {view === 'monthly' && <span className="text-blue-400">{months.find(m => m.value === selectedMonth)?.label}</span>}
                        {view === 'weekly' && <span className="text-purple-400">Settimana {selectedWeek}</span>}
                        <span className="text-muted-foreground text-lg font-normal">
                            {view === 'lifetime' ? 'Obiettivi a Lungo Termine' : view === 'annual' ? 'Obiettivi Annuali' : view === 'quarterly' ? 'Obiettivi Trimestrali' : view === 'monthly' ? 'Obiettivi Mensili' : 'Obiettivi Settimanali'}
                        </span>
                    </div>
                )}
            </div>


            {view === 'stats' ? (
                <MacroGoalsStats year={selectedYear} />
            ) : (
                <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                    {/* Input */}
                    <form onSubmit={handleCreate} className="flex gap-2">
                        <Input
                            className="flex-1 bg-background/50"
                            placeholder={`Aggiungi obiettivo ${view === 'lifetime' ? 'lifetime' : view === 'annual' ? 'annuale' : view === 'quarterly' ? 'trimestrale' : view === 'monthly' ? 'mensile' : 'settimanale'}...`}
                            value={newGoalTitle}
                            onChange={(e) => setNewGoalTitle(e.target.value)}
                        />
                        <Select
                            value={newGoalColor || "null"}
                            onValueChange={(val) => setNewGoalColor(val === "null" ? null : val)}
                        >
                            <SelectTrigger className="w-[50px] px-2 bg-background/50 border-input">
                                <div className="flex items-center justify-center w-full">
                                    <div
                                        className="w-4 h-4 rounded-full border border-white/10"
                                        style={{ backgroundColor: newGoalColor ? getGoalColor(newGoalColor) : 'transparent' }}
                                    />
                                </div>
                            </SelectTrigger>
                            <SelectContent align="end">
                                <SelectItem value="null">Nessun Colore</SelectItem>
                                {categoryKeys.map(key => (
                                    <SelectItem key={key} value={key}>
                                        <div className="flex items-center gap-2">
                                            <div
                                                className="w-3 h-3 rounded-full border border-white/10"
                                                style={{ backgroundColor: getGoalColor(key) }}
                                            />
                                            {getLabel(key)}
                                        </div>
                                    </SelectItem>
                                ))}
                            </SelectContent>
                        </Select>
                        <Button type="submit" disabled={createGoalMutation.isPending}>
                            {createGoalMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
                        </Button>
                    </form>

                    {/* List */}
                    <div className="space-y-2 mt-2">
                        {isLoading ? (
                            <div className="flex justify-center p-8 text-muted-foreground"><Loader2 className="w-6 h-6 animate-spin" /></div>
                        ) : goals?.length === 0 ? (
                            <div className="text-center p-8 border border-dashed border-white/10 rounded-xl text-muted-foreground">
                                Nessun obiettivo impostato per questo periodo.
                            </div>
                        ) : (
                            goals?.map((goal, index) => {
                                const effectiveStatus = pendingUpdates[goal.id] || goal.status;
                                const prevGoal = goals[index - 1];
                                const showCompletedHeader = goal.status === 'completed' && (!prevGoal || prevGoal.status !== 'completed');
                                const showFailedHeader = goal.status === 'failed' && (!prevGoal || prevGoal.status !== 'failed');

                                const handleStatusToggle = () => {
                                    if (updateTimeouts.current[goal.id]) {
                                        clearTimeout(updateTimeouts.current[goal.id]);
                                    }

                                    const current = pendingUpdates[goal.id] || goal.status;
                                    const next = current === 'active' ? 'completed' :
                                        current === 'completed' ? 'failed' :
                                            'active';

                                    setPendingUpdates(prev => ({ ...prev, [goal.id]: next }));

                                    updateTimeouts.current[goal.id] = setTimeout(() => {
                                        updateStatusMutation.mutate({ id: goal.id, status: next }, {
                                            onSuccess: () => {
                                                setPendingUpdates(prev => {
                                                    const newState = { ...prev };
                                                    delete newState[goal.id];
                                                    return newState;
                                                });
                                                delete updateTimeouts.current[goal.id];
                                            }
                                        });
                                    }, 2000);
                                };

                                return (
                                    <div key={goal.id}>
                                        {showCompletedHeader && (
                                            <div className="flex items-center gap-4 py-6">
                                                <div className="h-px bg-white/10 flex-1" />
                                                <span className="text-xs font-medium text-emerald-500/70 uppercase tracking-widest">Completati</span>
                                                <div className="h-px bg-white/10 flex-1" />
                                            </div>
                                        )}
                                        {showFailedHeader && (
                                            <div className="flex items-center gap-4 py-6">
                                                <div className="h-px bg-white/10 flex-1" />
                                                <span className="text-xs font-medium text-destructive/70 uppercase tracking-widest">Falliti</span>
                                                <div className="h-px bg-white/10 flex-1" />
                                            </div>
                                        )}
                                        <div
                                            className={cn(
                                                "group flex items-center gap-3 p-4 rounded-xl border transition-all duration-300",
                                                effectiveStatus === 'completed'
                                                    ? "opacity-60 bg-emerald-500/5 border-emerald-500/10"
                                                    : effectiveStatus === 'failed'
                                                        ? "opacity-60 bg-destructive/5 border-destructive/10"
                                                        : (getGoalColorClass(goal.color))
                                            )}
                                            style={effectiveStatus === 'active' ? getGoalStyle(goal.color) : {}}
                                        >
                                            <div
                                                onClick={handleStatusToggle}
                                                className={cn(
                                                    "w-5 h-5 rounded flex items-center justify-center border cursor-pointer transition-all duration-300 hover:scale-110",
                                                    effectiveStatus === 'active' && "border-white/20 hover:border-white/40",
                                                    effectiveStatus === 'completed' && "bg-emerald-500 border-emerald-500 text-white",
                                                    effectiveStatus === 'failed' && "bg-destructive border-destructive text-white"
                                                )}
                                            >
                                                {effectiveStatus === 'active' && <div className="w-full h-full" />}

                                                {effectiveStatus === 'completed' && (
                                                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" className="animate-in zoom-in duration-200">
                                                        <polyline points="20 6 9 17 4 12" />
                                                    </svg>
                                                )}

                                                {effectiveStatus === 'failed' && (
                                                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" className="animate-in zoom-in duration-200">
                                                        <line x1="18" y1="6" x2="6" y2="18" />
                                                        <line x1="6" y1="6" x2="18" y2="18" />
                                                    </svg>
                                                )}
                                            </div>

                                            <span className={cn(
                                                "flex-1 font-medium transition-all cursor-pointer duration-300 min-w-0 break-words",
                                                effectiveStatus === 'completed' && "text-emerald-500/80 line-through",
                                                effectiveStatus === 'failed' && "text-destructive/80 line-through",
                                                effectiveStatus === 'active' && "text-foreground"
                                            )} onClick={handleStatusToggle}>
                                                {goal.title}
                                            </span>

                                            <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                                                <Select
                                                    value={goal.color || "null"}
                                                    onValueChange={(val) => updateColorMutation.mutate({ id: goal.id, color: val === "null" ? null : val })}
                                                >
                                                    <SelectTrigger className="w-[30px] h-[30px] p-0 border-0 bg-transparent focus:ring-0">
                                                        <div
                                                            className="w-4 h-4 rounded-full border border-white/10"
                                                            style={{ backgroundColor: goal.color ? getGoalColor(goal.color) : 'rgba(255,255,255,0.2)' }}
                                                        />
                                                    </SelectTrigger>
                                                    <SelectContent align="end">
                                                        <SelectItem value="null">Nessun Colore</SelectItem>
                                                        {categoryKeys.map(key => (
                                                            <SelectItem key={key} value={key}>
                                                                <div className="flex items-center gap-2">
                                                                    <div
                                                                        className="w-3 h-3 rounded-full border border-white/10"
                                                                        style={{ backgroundColor: getGoalColor(key) }}
                                                                    />
                                                                    {getLabel(key)}
                                                                </div>
                                                            </SelectItem>
                                                        ))}
                                                    </SelectContent>
                                                </Select>

                                                {/* Fail & Copy to Next Week — solo vista settimanale */}
                                                {view === 'weekly' && effectiveStatus === 'active' && (
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        className="text-amber-500 hover:bg-amber-500/15 hover:text-amber-400 h-8 w-8"
                                                        title="Segna come fallito e copia nella settimana successiva"
                                                        disabled={failAndCopyToNextWeekMutation.isPending}
                                                        onClick={() => failAndCopyToNextWeekMutation.mutate(goal)}
                                                    >
                                                        {failAndCopyToNextWeekMutation.isPending
                                                            ? <Loader2 className="w-4 h-4 animate-spin" />
                                                            : <ArrowRightToLine className="w-4 h-4" />}
                                                    </Button>
                                                )}

                                                <Button
                                                    variant="ghost"
                                                    size="icon"
                                                    className="text-muted-foreground hover:bg-white/10 hover:text-white h-8 w-8"
                                                    onClick={() => setEditingGoal({ id: goal.id, title: goal.title })}
                                                >
                                                    <Pencil className="w-4 h-4" />
                                                </Button>

                                                <AlertDialog>
                                                    <AlertDialogTrigger asChild>
                                                        <Button
                                                            variant="ghost"
                                                            size="icon"
                                                            className="text-destructive hover:bg-destructive/10 hover:text-destructive h-8 w-8"
                                                        >
                                                            <Trash2 className="w-4 h-4" />
                                                        </Button>
                                                    </AlertDialogTrigger>
                                                    <AlertDialogContent>
                                                        <AlertDialogHeader>
                                                            <AlertDialogTitle>Eliminare questo obiettivo?</AlertDialogTitle>
                                                            <AlertDialogDescription>
                                                                Questa azione non può essere annullata. L'obiettivo verrà rimosso permanentemente.
                                                            </AlertDialogDescription>
                                                        </AlertDialogHeader>
                                                        <AlertDialogFooter>
                                                            <AlertDialogCancel>Annulla</AlertDialogCancel>
                                                            <AlertDialogAction onClick={() => deleteGoalMutation.mutate(goal.id)}>
                                                                Elimina
                                                            </AlertDialogAction>
                                                        </AlertDialogFooter>
                                                    </AlertDialogContent>
                                                </AlertDialog>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })
                        )}
                    </div>
                </div>
            )
            }

        </div >
    );
}
