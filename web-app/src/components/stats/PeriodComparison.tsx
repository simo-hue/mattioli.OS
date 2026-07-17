import { useState } from 'react';
import { HabitComparison } from '@/hooks/useHabitStats';
import { Goal } from '@/types/goals';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { cn } from '@/lib/utils';
import { ArrowUpRight, ArrowDownRight, Minus, TrendingUp } from 'lucide-react';

interface PeriodComparisonProps {
    comparisons: HabitComparison[];
    goals: Goal[];
}

type Period = 'week' | 'month' | 'year';

export function PeriodComparison({ comparisons, goals }: PeriodComparisonProps) {
    const [period, setPeriod] = useState<Period>('month');

    return (
        <div className="glass-panel rounded-3xl p-6 animate-fade-in">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
                <div>
                    <h3 className="text-lg font-display font-semibold flex items-center gap-2">
                        <TrendingUp className="w-5 h-5 text-primary" />
                        Confronto Temporale
                    </h3>
                    <p className="text-sm text-muted-foreground">
                        Analizza come stai andando rispetto al passato.
                    </p>
                </div>

                <Tabs value={period} onValueChange={(v) => setPeriod(v as Period)} className="w-full sm:w-auto">
                    <TabsList className="grid w-full grid-cols-3 sm:w-[300px]">
                        <TabsTrigger value="week">Settimana</TabsTrigger>
                        <TabsTrigger value="month">Mese</TabsTrigger>
                        <TabsTrigger value="year">Anno</TabsTrigger>
                    </TabsList>
                </Tabs>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {goals.map(goal => {
                    const comp = comparisons.find(c => c.habitId === goal.id);
                    if (!comp) return null;

                    const stat = comp[period];
                    const isNeutral = stat.trend === 'neutral' || stat.change === 0;
                    const isPositive = stat.trend === 'up';

                    return (
                        <div key={goal.id} className="bg-card/50 border border-border/50 rounded-xl p-4 flex items-center justify-between group hover:bg-card/80 transition-colors">
                            <div className="flex items-center gap-3">
                                <div
                                    className="w-10 h-10 rounded-lg flex items-center justify-center opacity-80"
                                    style={{ backgroundColor: `${goal.color}20`, color: goal.color }}
                                >
                                    <div className="w-3 h-3 rounded-sm" style={{ backgroundColor: goal.color }} />
                                </div>
                                <div>
                                    <h4 className="font-semibold text-foreground">{goal.title}</h4>
                                    <div className="flex items-center gap-2 text-xs text-muted-foreground">
                                        <span>Precedente: {stat.previous}%</span>
                                    </div>
                                </div>
                            </div>

                            <div className="text-right">
                                <div className="text-xl font-display font-bold text-foreground">
                                    {stat.current}%
                                </div>
                                <div className={cn(
                                    "flex items-center justify-end gap-1 text-xs font-medium",
                                    isNeutral ? "text-muted-foreground" : isPositive ? "text-emerald-500" : "text-rose-500"
                                )}>
                                    {isNeutral ? (
                                        <Minus className="w-3 h-3" />
                                    ) : isPositive ? (
                                        <ArrowUpRight className="w-3 h-3" />
                                    ) : (
                                        <ArrowDownRight className="w-3 h-3" />
                                    )}
                                    <span>
                                        {stat.change > 0 ? '+' : ''}{stat.change}%
                                    </span>
                                </div>
                            </div>
                        </div>
                    );
                })}
            </div>
        </div>
    );
}
