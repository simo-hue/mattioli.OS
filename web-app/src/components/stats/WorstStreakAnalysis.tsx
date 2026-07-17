import { HabitStat } from '@/hooks/useHabitStats';
import { TrendingDown, Target, HelpCircle, BarChart3, TrendingUp, Lightbulb, Calendar } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useMemo } from 'react';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';

interface WorstStreakAnalysisProps {
    habitStats: HabitStat[];
}

export function WorstStreakAnalysis({ habitStats }: WorstStreakAnalysisProps) {
    const analysis = useMemo(() => {
        if (habitStats.length === 0) return null;

        // Top 3 Worst Streaks (INVARIATO)
        const top3Worst = [...habitStats]
            .filter(h => h.worstStreak > 0)
            .sort((a, b) => b.worstStreak - a.worstStreak)
            .slice(0, 3);

        if (top3Worst.length === 0) return null;

        // Analisi Fallimenti (per top 3)
        const failureAnalysis = top3Worst.map(habit => {
            // Stima frequenza fallimenti mensile basata su worst streak e completion rate
            const estimatedMissesPerMonth = Math.round(
                (30 * (100 - habit.completionRate)) / 100
            );

            return {
                habitId: habit.id,
                title: habit.title,
                color: habit.color,
                worstStreak: habit.worstStreak,
                failureFrequency: estimatedMissesPerMonth,
                completionRate: habit.completionRate
            };
        });

        // Pattern di Recupero
        const recoveryPatterns = habitStats
            .filter(h => h.worstStreak > 0 && h.longestStreak > 0)
            .map(habit => {
                // Stima tempo recupero: inversamente proporzionale al completion rate
                const estimatedRecoveryTime = habit.worstStreak > 0
                    ? Math.round(habit.worstStreak * (100 - habit.completionRate) / 100)
                    : 0;

                return {
                    habitId: habit.id,
                    title: habit.title,
                    color: habit.color,
                    recoveryTime: Math.max(estimatedRecoveryTime, 1),
                    worstStreak: habit.worstStreak
                };
            })
            .sort((a, b) => a.recoveryTime - b.recoveryTime);

        const avgRecoveryTime = recoveryPatterns.length > 0
            ? Math.round(recoveryPatterns.reduce((sum, p) => sum + p.recoveryTime, 0) / recoveryPatterns.length)
            : 0;

        const fastestRecoverers = recoveryPatterns.slice(0, 3);

        // Confronto Best vs Worst - Top 3 peggiori
        const comparisons = habitStats
            .filter(h => h.worstStreak > 0)
            .map(habit => {
                const gap = habit.worstStreak > 0
                    ? Math.round((habit.longestStreak / habit.worstStreak) * 100)
                    : 999;

                let status: 'excellent' | 'good' | 'attention';
                if (gap >= 300) status = 'excellent';
                else if (gap >= 150) status = 'good';
                else status = 'attention';

                return {
                    habitId: habit.id,
                    title: habit.title,
                    color: habit.color,
                    best: habit.longestStreak,
                    worst: habit.worstStreak,
                    gap,
                    status
                };
            })
            .sort((a, b) => a.gap - b.gap)
            .slice(0, 3);

        // Suggerimenti Pratici
        const suggestions: Array<{ icon: string; title: string; description: string; action: string }> = [];

        // Suggerimento basato su worst streak alta
        const highestWorst = top3Worst[0];
        if (highestWorst && highestWorst.worstStreak >= 7) {
            suggestions.push({
                icon: '🎯',
                title: `Focus su "${highestWorst.title}"`,
                description: `Hai passato ${highestWorst.worstStreak} giorni consecutivi senza completare questa abitudine`,
                action: 'Considera di ridurre la difficoltà o impostare promemoria extra'
            });
        }

        // Suggerimento basato su basso completion rate
        const lowCompletion = failureAnalysis.find(f => f.completionRate < 50);
        if (lowCompletion) {
            suggestions.push({
                icon: '📊',
                title: 'Tasso di Completamento Basso',
                description: `"${lowCompletion.title}" ha solo ${lowCompletion.completionRate}% di successo`,
                action: 'Prova a semplificare l\'abitudine o renderla più piccola'
            });
        }

        // Suggerimento positivo se recovery veloce
        if (fastestRecoverers.length > 0 && fastestRecoverers[0].recoveryTime <= 3) {
            suggestions.push({
                icon: '💪',
                title: 'Ottima Capacità di Recupero',
                description: `Recuperi velocemente dopo i fallimenti (media ${avgRecoveryTime} giorni)`,
                action: 'Continua così - usa la stessa strategia per altre abitudini!'
            });
        }

        // Suggerimento su pattern generale
        if (failureAnalysis.length >= 2) {
            const totalFailures = failureAnalysis.reduce((sum, f) => sum + f.failureFrequency, 0);
            suggestions.push({
                icon: '📅',
                title: 'Pattern Generale',
                description: `In media fallisci ~${Math.round(totalFailures / failureAnalysis.length)} volte al mese`,
                action: 'Identifica i trigger comuni e crea strategie preventive'
            });
        }

        return {
            top3Worst,
            failureAnalysis,
            avgRecoveryTime,
            fastestRecoverers,
            comparisons,
            suggestions
        };
    }, [habitStats]);

    if (!analysis) {
        return (
            <div className="glass-panel rounded-3xl p-6 text-center">
                <TrendingUp className="w-12 h-12 mx-auto mb-3 text-green-500 opacity-50" />
                <p className="text-muted-foreground">
                    Ottimo lavoro! Non sono stati rilevati worst streak significativi.
                </p>
            </div>
        );
    }

    return (
        <div className="space-y-6 animate-fade-in">
            {/* Header */}
            <div className="glass-panel rounded-3xl p-4 sm:p-6">
                <div className="flex items-start gap-3">
                    <div className="w-10 h-10 rounded-xl bg-destructive/10 flex items-center justify-center shrink-0">
                        <TrendingDown className="w-5 h-5 text-destructive" />
                    </div>
                    <div>
                        <h3 className="text-lg font-display font-semibold text-foreground">
                            Analisi Worst Streaks
                        </h3>
                        <p className="text-sm text-muted-foreground mt-1">
                            Analisi dettagliata delle serie negative per identificare pattern e migliorare.
                        </p>
                    </div>
                </div>
            </div>

            {/* 1. Abitudini Critiche (INVARIATO) */}
            <div className="glass-panel rounded-3xl p-4 sm:p-6">
                <div className="flex items-center gap-2 mb-4">
                    <Target className="w-5 h-5 text-destructive" />
                    <h4 className="font-display font-semibold text-foreground">Abitudini Critiche</h4>
                    <TooltipProvider>
                        <Tooltip>
                            <TooltipTrigger asChild>
                                <button className="ml-1">
                                    <HelpCircle className="w-4 h-4 text-muted-foreground hover:text-foreground transition-colors" />
                                </button>
                            </TooltipTrigger>
                            <TooltipContent className="max-w-xs">
                                <p className="text-sm">
                                    Le 3 abitudini con le serie di non completamento più lunghe.
                                    Queste richiedono più attenzione per evitare l'abbandono.
                                </p>
                            </TooltipContent>
                        </Tooltip>
                    </TooltipProvider>
                    <span className="text-xs text-muted-foreground ml-auto">Top 3 Worst Streaks</span>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    {analysis.top3Worst.map((metric, index) => (
                        <div key={metric.id} className="bg-card/50 border border-destructive/20 rounded-xl p-4 relative overflow-hidden group hover:border-destructive/40 transition-all">
                            <div className="absolute top-2 right-2 w-6 h-6 rounded-full bg-destructive/20 flex items-center justify-center">
                                <span className="text-xs font-bold text-destructive">{index + 1}</span>
                            </div>

                            <div className="flex items-center gap-2 mb-3">
                                <div className="w-3 h-3 rounded-full" style={{ backgroundColor: metric.color }} />
                                <span className="font-semibold text-foreground text-sm truncate">{metric.title}</span>
                            </div>

                            <div className="bg-background/50 rounded-lg p-3 text-center">
                                <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Worst Streak</p>
                                <p className="text-3xl font-bold font-mono text-destructive">{metric.worstStreak}</p>
                                <p className="text-xs text-muted-foreground mt-1">giorni consecutivi</p>
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            {/* 2. Analisi Fallimenti + 3. Pattern di Recupero */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Analisi Fallimenti */}
                <div className="glass-panel rounded-3xl p-4 sm:p-6">
                    <div className="flex items-center gap-2 mb-4">
                        <BarChart3 className="w-5 h-5 text-orange-500" />
                        <h4 className="font-display font-semibold text-foreground">Analisi Fallimenti</h4>
                        <TooltipProvider>
                            <Tooltip>
                                <TooltipTrigger asChild>
                                    <button className="ml-1">
                                        <HelpCircle className="w-4 h-4 text-muted-foreground hover:text-foreground transition-colors" />
                                    </button>
                                </TooltipTrigger>
                                <TooltipContent className="max-w-xs">
                                    <p className="text-sm">
                                        Mostra pattern e frequenza dei tuoi fallimenti per capire
                                        quando e quanto spesso abbandoni le abitudini.
                                    </p>
                                </TooltipContent>
                            </Tooltip>
                        </TooltipProvider>
                    </div>

                    <div className="space-y-3">
                        {analysis.failureAnalysis.map(failure => (
                            <div key={failure.habitId} className="bg-background/50 rounded-lg p-3">
                                <div className="flex items-center gap-2 mb-2">
                                    <div className="w-2 h-2 rounded-full" style={{ backgroundColor: failure.color }} />
                                    <span className="text-sm font-medium truncate">{failure.title}</span>
                                </div>
                                <div className="grid grid-cols-2 gap-3 text-xs">
                                    <div>
                                        <p className="text-muted-foreground mb-1">Worst Streak</p>
                                        <p className="font-bold text-destructive">{failure.worstStreak} giorni</p>
                                    </div>
                                    <div>
                                        <p className="text-muted-foreground mb-1">Freq. Fallimenti</p>
                                        <p className="font-bold text-orange-500">~{failure.failureFrequency}/mese</p>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Pattern di Recupero */}
                <div className="glass-panel rounded-3xl p-4 sm:p-6">
                    <div className="flex items-center gap-2 mb-4">
                        <Calendar className="w-5 h-5 text-primary" />
                        <h4 className="font-display font-semibold text-foreground">Pattern di Recupero</h4>
                        <TooltipProvider>
                            <Tooltip>
                                <TooltipTrigger asChild>
                                    <button className="ml-1">
                                        <HelpCircle className="w-4 h-4 text-muted-foreground hover:text-foreground transition-colors" />
                                    </button>
                                </TooltipTrigger>
                                <TooltipContent className="max-w-xs">
                                    <p className="text-sm">
                                        Mostra quanto velocemente riesci a recuperare dopo un periodo
                                        di fallimenti e quali abitudini ripristini più facilmente.
                                    </p>
                                </TooltipContent>
                            </Tooltip>
                        </TooltipProvider>
                    </div>

                    {/* Tempo Medio */}
                    <div className="bg-card/50 rounded-xl p-4 mb-4">
                        <div className="flex items-center justify-between mb-2">
                            <span className="text-sm text-muted-foreground">Tempo Medio Recupero</span>
                            <span className="text-sm font-bold text-foreground">{analysis.avgRecoveryTime} giorni</span>
                        </div>
                        <div className="h-2 bg-secondary rounded-full overflow-hidden">
                            <div
                                className="h-full bg-gradient-to-r from-primary to-green-500 transition-all duration-500"
                                style={{ width: `${Math.min((analysis.avgRecoveryTime / 14) * 100, 100)}%` }}
                            />
                        </div>
                        <p className="text-xs text-muted-foreground mt-2">
                            {analysis.avgRecoveryTime <= 5 ? '✅ Eccellente!' : analysis.avgRecoveryTime <= 10 ? '👍 Buono' : '⚠️ Da migliorare'}
                        </p>
                    </div>

                    {/* Migliori Recuperatori */}
                    {analysis.fastestRecoverers.length > 0 && (
                        <div className="space-y-2">
                            <p className="text-xs text-muted-foreground uppercase tracking-wider mb-3">🔥 Recuperatori Veloci</p>
                            {analysis.fastestRecoverers.map(recoverer => (
                                <div key={recoverer.habitId} className="bg-background/50 rounded-lg p-2 flex items-center justify-between">
                                    <div className="flex items-center gap-2 min-w-0">
                                        <div className="w-2 h-2 rounded-full shrink-0" style={{ backgroundColor: recoverer.color }} />
                                        <span className="text-sm truncate">{recoverer.title}</span>
                                    </div>
                                    <span className="text-xs font-bold text-green-500 shrink-0 ml-2">{recoverer.recoveryTime} gg</span>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>

            {/* 4. Confronto Best vs Worst */}
            <div className="glass-panel rounded-3xl p-4 sm:p-6">
                <div className="flex items-center gap-2 mb-4">
                    <TrendingUp className="w-5 h-5 text-primary" />
                    <h4 className="font-display font-semibold text-foreground">Confronto Performance</h4>
                    <TooltipProvider>
                        <Tooltip>
                            <TooltipTrigger asChild>
                                <button className="ml-1">
                                    <HelpCircle className="w-4 h-4 text-muted-foreground hover:text-foreground transition-colors" />
                                </button>
                            </TooltipTrigger>
                            <TooltipContent className="max-w-xs">
                                <p className="text-sm">
                                    Mostra le 3 abitudini con il peggior rapporto Best/Worst.
                                    Queste sono le abitudini che hanno più margine di miglioramento e richiedono maggior attenzione.
                                </p>
                            </TooltipContent>
                        </Tooltip>
                    </TooltipProvider>
                </div>

                <div className="space-y-4">
                    {analysis.comparisons.map(comp => (
                        <div key={comp.habitId} className="bg-background/50 rounded-lg p-4">
                            <div className="flex items-center gap-2 mb-3">
                                <div className="w-2 h-2 rounded-full" style={{ backgroundColor: comp.color }} />
                                <span className="text-sm font-medium">{comp.title}</span>
                                <span className={cn(
                                    "text-xs font-bold px-2 py-0.5 rounded-full ml-auto",
                                    comp.status === 'excellent' && "bg-green-500/10 text-green-500",
                                    comp.status === 'good' && "bg-yellow-500/10 text-yellow-500",
                                    comp.status === 'attention' && "bg-orange-500/10 text-orange-500"
                                )}>
                                    {comp.status === 'excellent' ? 'Eccellente' :
                                        comp.status === 'good' ? 'Buono' : 'Attenzione'}
                                </span>
                            </div>

                            <div className="space-y-2">
                                {/* Best Bar */}
                                <div>
                                    <div className="flex items-center justify-between mb-1">
                                        <span className="text-xs text-muted-foreground">Best</span>
                                        <span className="text-xs font-bold text-green-500">{comp.best} gg</span>
                                    </div>
                                    <div className="h-2 bg-secondary rounded-full overflow-hidden">
                                        <div
                                            className="h-full bg-green-500 transition-all duration-500"
                                            style={{ width: `${Math.min((comp.best / Math.max(comp.best, comp.worst)) * 100, 100)}%` }}
                                        />
                                    </div>
                                </div>

                                {/* Worst Bar */}
                                <div>
                                    <div className="flex items-center justify-between mb-1">
                                        <span className="text-xs text-muted-foreground">Worst</span>
                                        <span className="text-xs font-bold text-destructive">{comp.worst} gg</span>
                                    </div>
                                    <div className="h-2 bg-secondary rounded-full overflow-hidden">
                                        <div
                                            className="h-full bg-destructive transition-all duration-500"
                                            style={{ width: `${Math.min((comp.worst / Math.max(comp.best, comp.worst)) * 100, 100)}%` }}
                                        />
                                    </div>
                                </div>
                            </div>

                            <p className="text-xs text-muted-foreground mt-2">
                                Gap: <span className="font-bold text-foreground">{comp.gap}%</span>
                            </p>
                        </div>
                    ))}
                </div>
            </div>

            {/* 5. Suggerimenti Pratici */}
            <div className="glass-panel rounded-3xl p-4 sm:p-6">
                <div className="flex items-center gap-2 mb-4">
                    <Lightbulb className="w-5 h-5 text-yellow-500" />
                    <h4 className="font-display font-semibold text-foreground">Suggerimenti Pratici</h4>
                    <TooltipProvider>
                        <Tooltip>
                            <TooltipTrigger asChild>
                                <button className="ml-1">
                                    <HelpCircle className="w-4 h-4 text-muted-foreground hover:text-foreground transition-colors" />
                                </button>
                            </TooltipTrigger>
                            <TooltipContent className="max-w-xs">
                                <p className="text-sm">
                                    Suggerimenti personalizzati basati sui tuoi dati con azioni
                                    concrete che puoi implementare subito per migliorare.
                                </p>
                            </TooltipContent>
                        </Tooltip>
                    </TooltipProvider>
                </div>

                <div className="space-y-3">
                    {analysis.suggestions.map((suggestion, index) => (
                        <div key={index} className="bg-gradient-to-r from-primary/5 to-transparent border border-primary/20 rounded-xl p-4">
                            <div className="flex items-start gap-3">
                                <span className="text-2xl shrink-0">{suggestion.icon}</span>
                                <div className="flex-1">
                                    <p className="font-semibold text-sm text-foreground mb-1">{suggestion.title}</p>
                                    <p className="text-xs text-muted-foreground mb-2">{suggestion.description}</p>
                                    <div className="flex items-start gap-2 text-xs text-primary">
                                        <span className="shrink-0">→</span>
                                        <span className="font-medium">{suggestion.action}</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
}
