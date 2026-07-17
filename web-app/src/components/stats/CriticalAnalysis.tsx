import { CriticalHabitStat } from '@/hooks/useHabitStats';
import { AlertCircle, Target, XCircle } from 'lucide-react';
import { cn } from '@/lib/utils';

interface CriticalAnalysisProps {
    criticalHabits: CriticalHabitStat[];
}

export function CriticalAnalysis({ criticalHabits }: CriticalAnalysisProps) {
    // Filter only habits that have some data and aren't perfect
    // Sort primarily by completion rate, then by worst day rate
    const areaOfImprovement = criticalHabits
        .filter(h => h.completionRate < 85 && h.completionRate > 0) // < 85% is where improvement is usually needed
        .sort((a, b) => a.completionRate - b.completionRate)
        .slice(0, 3); // Top 3

    if (areaOfImprovement.length === 0) return null;

    return (
        <div className="glass-panel rounded-3xl p-6 animate-fade-in space-y-4">
            <div>
                <h3 className="text-lg font-display font-semibold flex items-center gap-2">
                    <Target className="w-5 h-5 text-primary" />
                    Aree di Miglioramento
                </h3>
                <p className="text-sm text-muted-foreground">
                    Abitudini che richiedono più attenzione e i loro giorni critici.
                </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {areaOfImprovement.map((habit) => (
                    <div key={habit.habitId} className="bg-card/50 border border-destructive/10 rounded-xl p-4 flex flex-col gap-3 group hover:border-destructive/30 transition-all">
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2">
                                <div className="w-2 h-2 rounded-full" style={{ backgroundColor: habit.color }} />
                                <span className="font-semibold text-foreground">{habit.title}</span>
                            </div>
                            <span className={cn(
                                "text-xs font-bold px-2 py-0.5 rounded-full",
                                habit.completionRate < 50 ? "bg-destructive/10 text-destructive" : "bg-warning/10 text-warning"
                            )}>
                                {habit.completionRate}% succ.
                            </span>
                        </div>

                        <div className="flex items-start gap-3 bg-background/50 rounded-lg p-3">
                            <AlertCircle className="w-4 h-4 text-destructive mt-0.5 shrink-0" />
                            <div className="space-y-1">
                                <p className="text-xs text-muted-foreground uppercase tracking-wider font-bold">Giorno Nero</p>
                                <p className="font-display font-semibold text-lg text-foreground">
                                    {habit.worstDay}
                                </p>
                                <p className="text-xs text-muted-foreground">
                                    Solo il <span className="text-destructive font-bold">{habit.worstDayRate}%</span> di completamento
                                </p>
                            </div>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}
