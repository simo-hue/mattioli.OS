import { Trophy, Flame, Target } from 'lucide-react';
import { cn } from '@/lib/utils';
import { HabitStat } from '@/hooks/useHabitStats';

interface StatsOverviewProps {
    globalStats: {
        totalActiveDays: number;
        globalSuccessRate: number;
        bestStreak: number;
        worstDay?: string;
    };
    bestHabit?: HabitStat;
}

export function StatsOverview({ globalStats, bestHabit }: StatsOverviewProps) {
    return (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {/* Success Rate */}
            <div className="bg-card/50 backdrop-blur-sm rounded-3xl p-6 border border-white/5 shadow-sm relative overflow-hidden group">
                <div className="absolute right-0 top-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
                    <Target className="w-24 h-24" />
                </div>
                <div>
                    <div className="flex items-center gap-2 mb-2 text-muted-foreground">
                        <Target className="w-4 h-4" />
                        <span className="text-sm font-medium">Completamento</span>
                    </div>
                    <div className="flex items-baseline gap-2">
                        <span className="text-4xl font-display font-bold text-foreground">
                            {globalStats.globalSuccessRate}%
                        </span>
                        <span className="text-sm text-muted-foreground">globale</span>
                    </div>
                </div>
            </div>

            {/* Best Streak */}
            <div className="bg-card/50 backdrop-blur-sm rounded-3xl p-6 border border-white/5 shadow-sm relative overflow-hidden group">
                <div className="absolute right-0 top-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
                    <Flame className="w-24 h-24 text-orange-500" />
                </div>
                <div>
                    <div className="flex items-center gap-2 mb-2 text-muted-foreground">
                        <Flame className="w-4 h-4 text-orange-500" />
                        <span className="text-sm font-medium">Miglior Serie</span>
                    </div>
                    <div className="flex items-baseline gap-2">
                        <span className="text-4xl font-display font-bold text-foreground">
                            {globalStats.bestStreak}
                        </span>
                        <span className="text-sm text-muted-foreground">giorni</span>
                    </div>
                </div>
            </div>

            {/* Best Habit */}
            <div className="bg-card/50 backdrop-blur-sm rounded-3xl p-6 border border-white/5 shadow-sm relative overflow-hidden group">
                <div className="absolute right-0 top-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
                    <Trophy className="w-24 h-24 text-yellow-500" />
                </div>
                <div>
                    <div className="flex items-center gap-2 mb-2 text-muted-foreground">
                        <Trophy className="w-4 h-4 text-yellow-500" />
                        <span className="text-sm font-medium">Top Performer</span>
                    </div>
                    {bestHabit ? (
                        <div>
                            <span className="text-2xl font-display font-bold text-foreground block truncate">
                                {bestHabit.title}
                            </span>
                            <span className="text-sm text-muted-foreground">{bestHabit.completionRate}% completamento</span>
                        </div>
                    ) : (
                        <span className="text-muted-foreground text-sm">Nessun dato</span>
                    )}
                </div>
            </div>
            {/* Worst Day */}
            <div className="bg-card/50 backdrop-blur-sm rounded-3xl p-6 border border-white/5 shadow-sm relative overflow-hidden group">
                <div className="absolute right-0 top-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
                    <div className="text-4xl">⚠️</div>
                </div>
                <div>
                    <div className="flex items-center gap-2 mb-2 text-muted-foreground">
                        <span className="text-sm font-medium">Giorno Peggiore</span>
                    </div>
                    {globalStats.worstDay ? (
                        <div>
                            <span className="text-2xl font-display font-bold text-foreground block truncate">
                                {globalStats.worstDay}
                            </span>
                            <span className="text-sm text-muted-foreground">Focus richiesto</span>
                        </div>
                    ) : (
                        <span className="text-muted-foreground text-sm">Nessun dato</span>
                    )}
                </div>
            </div>
        </div>
    );
}
