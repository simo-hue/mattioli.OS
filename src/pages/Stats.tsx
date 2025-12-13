import { useGoals } from '@/hooks/useGoals';
import { useHabitStats } from '@/hooks/useHabitStats';
import { StatsOverview } from '@/components/stats/StatsOverview';
import { ActivityHeatmap } from '@/components/stats/ActivityHeatmap';
import { TrendChart } from '@/components/stats/TrendChart';
import { HabitRadar } from '@/components/stats/HabitRadar';

const Stats = () => {
    const { goals, logs } = useGoals();
    const stats = useHabitStats(goals, logs);

    // Find best habit safely
    const bestHabit = stats.habitStats.length > 0
        ? stats.habitStats.reduce((prev, current) => (prev.completionRate > current.completionRate) ? prev : current, stats.habitStats[0])
        : null;

    return (
        <div className="container mx-auto px-4 py-8 max-w-5xl space-y-8 animate-fade-in pb-24">
            {/* Background Glow */}
            <div className="fixed top-20 left-1/2 -translate-x-1/2 w-[800px] h-[800px] bg-primary/5 blur-[120px] rounded-full pointer-events-none -z-10" />

            <div className="space-y-2">
                <h1 className="text-3xl sm:text-4xl font-display font-bold text-foreground">Le tue Statistiche</h1>
                <p className="text-muted-foreground font-light text-lg">Analisi dettagliata delle tue performance.</p>
            </div>

            {/* Overview Cards */}
            <StatsOverview globalStats={stats.globalStats} bestHabit={bestHabit || undefined} />

            {/* Heatmap - Full Width */}
            <div className="glass-panel rounded-3xl p-6">
                <h3 className="text-lg font-display font-semibold mb-6 flex items-center gap-2">
                    <span className="w-2 h-2 rounded-sm bg-primary animate-pulse" />
                    Attività Recente
                </h3>
                <ActivityHeatmap data={stats.heatmapData} />
            </div>

            {/* Charts Row */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="glass-panel rounded-3xl p-6 h-[400px] flex flex-col">
                    <h3 className="text-lg font-display font-semibold mb-4">Trend Settimanale</h3>
                    <div className="flex-1 w-full min-h-0">
                        <TrendChart data={stats.trendData} />
                    </div>
                </div>
                <div className="glass-panel rounded-3xl p-6 h-[400px] flex flex-col">
                    <h3 className="text-lg font-display font-semibold mb-4">Focus Abitudini</h3>
                    <div className="flex-1 w-full min-h-0">
                        <HabitRadar stats={stats.habitStats} />
                    </div>
                </div>
            </div>

            {/* Detailed Table */}
            <div className="glass-panel rounded-3xl p-6">
                <h3 className="text-lg font-display font-semibold mb-6">Dettagli Abitudini</h3>
                <div className="space-y-3">
                    {stats.habitStats.length === 0 ? (
                        <p className="text-muted-foreground text-center py-8">Nessuna abitudine tracciata ancora.</p>
                    ) : (
                        stats.habitStats.map(habit => (
                            <div key={habit.id} className="glass-card rounded-xl p-4 flex items-center justify-between group">
                                <div className="flex items-center gap-4">
                                    <div className="w-10 h-10 rounded-xl flex items-center justify-center bg-white/5 border border-white/10 text-xl group-hover:scale-110 transition-transform duration-300 shadow-lg" style={{ color: habit.color, borderColor: `${habit.color}40`, boxShadow: `0 0 20px ${habit.color}10` }}>
                                        {/* Simple initial or icon placeholder if available, else circle */}
                                        <div className="w-3 h-3 rounded-sm" style={{ backgroundColor: habit.color }} />
                                    </div>
                                    <div>
                                        <span className="font-semibold text-foreground text-lg">{habit.title}</span>
                                        <div className="h-1 w-20 bg-secondary rounded-full mt-1 overflow-hidden">
                                            <div className="h-full bg-primary transition-all duration-500" style={{ width: `${habit.completionRate}%`, backgroundColor: habit.color }} />
                                        </div>
                                    </div>
                                </div>
                                <div className="flex gap-8 text-sm text-muted-foreground text-right">
                                    <div className="flex flex-col items-end">
                                        <span className="text-[10px] uppercase tracking-widest font-bold opacity-60 mb-0.5">Serie</span>
                                        <span className="font-mono text-xl font-bold text-foreground">{habit.currentStreak} <span className="text-xs font-sans font-normal opacity-50">gg</span></span>
                                    </div>
                                    <div className="flex flex-col items-end">
                                        <span className="text-[10px] uppercase tracking-widest font-bold opacity-60 mb-0.5">Rate</span>
                                        <span className="font-mono text-xl font-bold text-foreground">{habit.completionRate}<span className="text-sm">%</span></span>
                                    </div>
                                </div>
                            </div>
                        ))
                    )}
                </div>
            </div>
        </div>
    );
}

export default Stats;
