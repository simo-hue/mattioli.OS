import { useGoals } from '@/hooks/useGoals';
import { useHabitStats, Timeframe } from '@/hooks/useHabitStats';
import { useHabitMoodCorrelation } from '@/hooks/useHabitMoodCorrelation';
import { useHabitCorrelation } from '@/hooks/useHabitCorrelation';
import { StatsOverview } from '@/components/stats/StatsOverview';
import { ActivityHeatmap } from '@/components/stats/ActivityHeatmap';
import { TrendChart } from '@/components/stats/TrendChart';
import { HabitRadar } from '@/components/stats/HabitRadar';
import { DayOfWeekChart } from '@/components/stats/DayOfWeekChart';
import { PeriodComparison } from '@/components/stats/PeriodComparison';
import { CriticalAnalysis } from '@/components/stats/CriticalAnalysis';
import { MoodCorrelationChart } from '@/components/stats/MoodCorrelationChart';
import { HabitMoodCorrelationChart } from '@/components/stats/HabitMoodCorrelationChart';
import { MoodEnergyHabitMatrix } from '@/components/stats/MoodEnergyHabitMatrix';
import { MoodEnergyInsights } from '@/components/stats/MoodEnergyInsights';
import { WorstStreakAnalysis } from '@/components/stats/WorstStreakAnalysis';
import { KeystoneHabitsPanel } from '@/components/stats/KeystoneHabitsPanel';
import { CorrelationSummary } from '@/components/stats/CorrelationSummary';
import { CorrelationPairCard } from '@/components/stats/CorrelationPairCard';
import { SingleHabitCorrelations } from '@/components/stats/SingleHabitCorrelations';
import { Trophy, TrendingDown, AlertTriangle, Calendar, Target, MoveLeft, AlignLeft, Sparkles, Flame, TrendingUp } from 'lucide-react';
import { usePrivacy } from '@/context/PrivacyContext';
import { useAI } from '@/context/AIContext';
import { cn } from '@/lib/utils';
import { useMemo, useState } from 'react';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { format, eachDayOfInterval, startOfYear, endOfYear, differenceInDays, isSameDay } from 'date-fns';
import { it } from 'date-fns/locale';

const Stats = () => {
    const { goals, allGoals, logs } = useGoals();
    const [trendTimeframe, setTrendTimeframe] = useState<Timeframe>('weekly');
    const [selectedGoalId, setSelectedGoalId] = useState<string | null>(null);
    const [habitSortBy, setHabitSortBy] = useState<'rate' | 'best' | 'worst' | 'current' | 'name'>('rate');
    const stats = useHabitStats(goals, logs, trendTimeframe);
    const { isPrivacyMode } = usePrivacy();
    const { isAIEnabled } = useAI();
    const { correlations, insights } = useHabitMoodCorrelation(goals, logs);
    const { correlations: habitCorrelations, insights: habitCorrelationInsights } = useHabitCorrelation(goals, logs);

    // Find selected goal
    const selectedGoal = useMemo(() => {
        return allGoals.find(g => g.id === selectedGoalId) || null;
    }, [allGoals, selectedGoalId]);

    // Sort habits based on selected criteria
    const sortedHabits = useMemo(() => {
        const habitsCopy = [...stats.habitStats];
        switch (habitSortBy) {
            case 'rate':
                return habitsCopy.sort((a, b) => b.completionRate - a.completionRate);
            case 'best':
                return habitsCopy.sort((a, b) => b.longestStreak - a.longestStreak);
            case 'worst':
                return habitsCopy.sort((a, b) => b.worstStreak - a.worstStreak);
            case 'current':
                return habitsCopy.sort((a, b) => b.currentStreak - a.currentStreak);
            case 'name':
                return habitsCopy.sort((a, b) => a.title.localeCompare(b.title));
            default:
                return habitsCopy;
        }
    }, [stats.habitStats, habitSortBy]);

    // Calculate single goal stats
    const singleGoalStats = useMemo(() => {
        if (!selectedGoal) return null;

        const goalLogs: { date: string; status: 'done' | 'missed' | 'skipped' | null }[] = [];
        const today = new Date();
        const goalStartDate = new Date(selectedGoal.start_date);
        const goalEndDate = selectedGoal.end_date ? new Date(selectedGoal.end_date) : today;
        const endDate = goalEndDate > today ? today : goalEndDate;

        // Get all days in goal range
        const allDays = eachDayOfInterval({ start: goalStartDate, end: endDate });

        allDays.forEach(day => {
            const dateStr = format(day, 'yyyy-MM-dd');
            const status = logs[dateStr]?.[selectedGoal.id] || null;
            goalLogs.push({ date: dateStr, status });
        });

        // Calculate stats
        const totalDays = goalLogs.length;
        const doneDays = goalLogs.filter(l => l.status === 'done').length;
        const missedDays = goalLogs.filter(l => l.status === 'missed').length;
        const completionRate = totalDays > 0 ? Math.round((doneDays / totalDays) * 100) : 0;

        // Calculate streaks
        let currentStreak = 0;
        let bestStreak = 0;
        let tempStreak = 0;

        // Streaks interrotti (failure analysis)
        const brokenStreaks: { date: string; streakLength: number }[] = [];
        let lastStreakLength = 0;

        // Negative streaks (consecutive missed days)
        let currentNegativeStreak = 0;
        let worstNegativeStreak = 0;
        let worstNegativeStreakStart = '';
        let tempNegativeStart = '';

        for (let i = 0; i < goalLogs.length; i++) {
            const log = goalLogs[i];

            if (log.status === 'done') {
                tempStreak++;
                if (tempStreak > bestStreak) bestStreak = tempStreak;

                // End negative streak
                if (currentNegativeStreak > worstNegativeStreak) {
                    worstNegativeStreak = currentNegativeStreak;
                    worstNegativeStreakStart = tempNegativeStart;
                }
                currentNegativeStreak = 0;
            } else {
                // Streak broken
                if (tempStreak > 2) {
                    brokenStreaks.push({ date: log.date, streakLength: tempStreak });
                }
                tempStreak = 0;

                // Track negative streak
                if (log.status === 'missed' || log.status === null) {
                    if (currentNegativeStreak === 0) tempNegativeStart = log.date;
                    currentNegativeStreak++;
                }
            }
        }

        // Check final negative streak
        if (currentNegativeStreak > worstNegativeStreak) {
            worstNegativeStreak = currentNegativeStreak;
            worstNegativeStreakStart = tempNegativeStart;
        }

        // Current streak (from end, only 'done')
        for (let i = goalLogs.length - 1; i >= 0; i--) {
            if (goalLogs[i].status === 'done') currentStreak++;
            else break;
        }

        // Day of week analysis
        const dayOfWeekStats = [0, 0, 0, 0, 0, 0, 0]; // Mon-Sun
        const dayOfWeekTotal = [0, 0, 0, 0, 0, 0, 0];

        goalLogs.forEach(log => {
            const dayOfWeek = new Date(log.date).getDay();
            const adjustedDay = dayOfWeek === 0 ? 6 : dayOfWeek - 1; // Mon = 0
            dayOfWeekTotal[adjustedDay]++;
            if (log.status === 'done') dayOfWeekStats[adjustedDay]++;
        });

        const weekdayPerformance = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'].map((day, i) => ({
            day,
            rate: dayOfWeekTotal[i] > 0 ? Math.round((dayOfWeekStats[i] / dayOfWeekTotal[i]) * 100) : 0,
            total: dayOfWeekTotal[i],
            done: dayOfWeekStats[i]
        }));

        // Worst day
        const worstDay = weekdayPerformance.reduce((min, curr) =>
            curr.total > 2 && curr.rate < min.rate ? curr : min,
            { day: 'N/A', rate: 100, total: 0, done: 0 }
        );

        // Heatmap data for the year
        const yearStart = startOfYear(today);
        const yearEnd = endOfYear(today);
        const yearDays = eachDayOfInterval({ start: yearStart, end: yearEnd });

        const heatmapData = yearDays.map(day => {
            const dateStr = format(day, 'yyyy-MM-dd');
            const status = logs[dateStr]?.[selectedGoal.id];
            return {
                date: dateStr,
                count: status === 'done' ? 1 : status === 'missed' ? -1 : 0,
                intensity: status === 'done' ? 1 : status === 'missed' ? 0.5 : 0
            };
        });

        // Trend data (last 30 days)
        const last30Days = eachDayOfInterval({
            start: new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000),
            end: today
        });

        const trendData = last30Days.map(day => {
            const dateStr = format(day, 'yyyy-MM-dd');
            const status = logs[dateStr]?.[selectedGoal.id];
            return {
                date: format(day, 'dd/MM'),
                value: status === 'done' ? 100 : 0,
                status: status || null
            };
        });

        return {
            totalDays,
            doneDays,
            missedDays,
            completionRate,
            currentStreak,
            bestStreak,
            brokenStreaks: brokenStreaks.slice(-5).reverse(), // Last 5
            worstNegativeStreak,
            worstNegativeStreakStart,
            weekdayPerformance,
            worstDay,
            heatmapData,
            trendData
        };
    }, [selectedGoal, logs]);

    // Find best habit safely (for global view)
    const bestHabit = stats.habitStats.length > 0
        ? stats.habitStats.reduce((prev, current) => (prev.completionRate > current.completionRate) ? prev : current, stats.habitStats[0])
        : null;

    // Handle goal selection
    const handleGoalChange = (value: string) => {
        setSelectedGoalId(value === 'all' ? null : value);
    };

    return (
        <div className="container mx-auto px-4 py-6 max-w-5xl animate-fade-in pb-32 space-y-6">
            {/* Background Glow */}
            <div className="fixed top-20 left-1/2 -translate-x-1/2 w-[800px] h-[800px] bg-primary/5 blur-[120px] rounded-full pointer-events-none -z-10" />

            <div className={cn("space-y-3", isPrivacyMode && "blur-sm")}>
                <div className="space-y-1">
                    <h1 className="text-2xl sm:text-3xl font-display font-bold text-foreground">Le tue Statistiche</h1>
                    <p className="text-muted-foreground font-light text-sm sm:text-base">Analisi dettagliata delle tue performance.</p>
                </div>

                {/* Goal Selector */}
                <Select value={selectedGoalId || 'all'} onValueChange={handleGoalChange}>
                    <SelectTrigger className="w-full sm:w-[300px] glass-panel border-white/10">
                        <SelectValue placeholder="Seleziona goal" />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="all">
                            <span className="flex items-center gap-2">
                                <Target className="w-4 h-4" />
                                Tutti i Goals
                            </span>
                        </SelectItem>
                        {allGoals.map(goal => (
                            <SelectItem key={goal.id} value={goal.id}>
                                <span className="flex items-center gap-2">
                                    <div className="w-3 h-3 rounded-sm" style={{ backgroundColor: goal.color }} />
                                    {goal.title}
                                    {goal.end_date && <span className="text-xs text-muted-foreground">(archiviato)</span>}
                                </span>
                            </SelectItem>
                        ))}
                    </SelectContent>
                </Select>
            </div>

            {/* Conditional Rendering based on selection */}
            {selectedGoalId === null ? (
                // GLOBAL VIEW - All Goals
                <Tabs defaultValue="panoramica" className="w-full">
                    <TabsList className="grid w-full grid-cols-5 mb-4 shrink-0">
                        <TabsTrigger value="panoramica" className="text-xs sm:text-sm">Info</TabsTrigger>
                        <TabsTrigger value="trend" className="text-xs sm:text-sm">Trend</TabsTrigger>
                        <TabsTrigger value="analisi" className="text-xs sm:text-sm">Alert</TabsTrigger>
                        <TabsTrigger value="abitudini" className="text-xs sm:text-sm">Abitudini</TabsTrigger>
                        <TabsTrigger value="mood-energia" className="text-xs sm:text-sm flex items-center gap-1">
                            <span>Mood</span>
                        </TabsTrigger>
                    </TabsList>

                    <TabsContent value="panoramica" className="mt-0 space-y-6">
                        <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                            <StatsOverview
                                globalStats={{
                                    totalActiveDays: stats.totalActiveDays,
                                    globalSuccessRate: stats.globalSuccessRate,
                                    bestStreak: stats.bestStreak,
                                    worstDay: stats.worstDay,
                                }}
                                bestHabit={bestHabit || undefined}
                            />
                        </div>

                        {/* AI Coach Card - Desktop Only */}
                        {isAIEnabled && (
                            <div className="hidden lg:block">
                                <div
                                    onClick={() => window.location.hash = '/ai-coach'}
                                    className="glass-panel rounded-3xl p-6 cursor-pointer hover:scale-[1.02] transition-all duration-300 border-2 border-primary/20 hover:border-primary/40 group"
                                >
                                    <div className="flex items-start gap-4">
                                        <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-primary/20 to-purple-500/20 flex items-center justify-center shrink-0 group-hover:scale-110 transition-transform">
                                            <Sparkles className="w-7 h-7 text-primary animate-pulse" />
                                        </div>
                                        <div className="flex-1">
                                            <h3 className="text-lg sm:text-xl font-display font-semibold mb-2 flex items-center gap-2">
                                                AI Coach
                                                <span className="text-xs bg-primary/20 text-primary px-2 py-0.5 rounded-full font-normal">Nuovo</span>
                                            </h3>
                                            <p className="text-sm text-muted-foreground mb-3">
                                                Genera un report settimanale personalizzato con analisi AI dei tuoi progressi e suggerimenti concreti per migliorare.
                                            </p>
                                            <div className="flex items-center gap-2 text-xs text-primary">
                                                <span className="font-semibold">Clicca per iniziare</span>
                                                <span>→</span>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        )}

                        {/* Habit Correlation Insights */}
                        {habitCorrelationInsights.totalPairs > 0 && (
                            <>
                                {/* Keystone Habits */}
                                {habitCorrelationInsights.keystoneHabits.length > 0 && (
                                    <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                                        <KeystoneHabitsPanel keystoneHabits={habitCorrelationInsights.keystoneHabits} />
                                    </div>
                                )}

                                {/* Correlation Summary */}
                                <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                                    <CorrelationSummary insights={habitCorrelationInsights} />
                                </div>

                                {/* Top Positive Correlations */}
                                {habitCorrelationInsights.strongestPositive.length > 0 && (
                                    <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                                        <div className="space-y-3">
                                            <h3 className="text-base sm:text-lg font-display font-semibold flex items-center gap-2">
                                                <span className="text-green-500">💚</span>
                                                Correlazioni Positive
                                            </h3>
                                            {habitCorrelationInsights.strongestPositive.map((pair, i) => (
                                                <CorrelationPairCard key={i} correlation={pair} />
                                            ))}
                                        </div>
                                    </div>
                                )}

                                {/* Negative Correlations (if any) */}
                                {habitCorrelationInsights.strongestNegative.length > 0 && (
                                    <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                                        <div className="space-y-3">
                                            <h3 className="text-base sm:text-lg font-display font-semibold flex items-center gap-2">
                                                <span className="text-red-500">⚠️</span>
                                                Correlazioni Negative
                                            </h3>
                                            <p className="text-sm text-muted-foreground mb-3">
                                                Queste abitudini tendono a non essere completate insieme.
                                            </p>
                                            {habitCorrelationInsights.strongestNegative.map((pair, i) => (
                                                <CorrelationPairCard key={i} correlation={pair} />
                                            ))}
                                        </div>
                                    </div>
                                )}
                            </>
                        )}

                        <div className="glass-panel rounded-3xl p-4 sm:p-6">
                            <h3 className="text-base sm:text-lg font-display font-semibold mb-4 flex items-center gap-2">
                                <span className="w-2 h-2 rounded-sm bg-primary animate-pulse" />
                                Attività Recente
                            </h3>
                            <ActivityHeatmap data={stats.heatmapData} />
                        </div>
                    </TabsContent>

                    <TabsContent value="trend" className="mt-0 space-y-6">
                        <div className="glass-panel rounded-3xl p-4 sm:p-6 h-[350px] sm:h-[400px] flex flex-col">
                            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
                                <h3 className="text-base sm:text-lg font-display font-semibold">Trend</h3>
                                <Tabs value={trendTimeframe} onValueChange={(v) => setTrendTimeframe(v as Timeframe)} className="w-full sm:w-auto">
                                    <TabsList className="grid w-full grid-cols-4 sm:w-[300px]">
                                        <TabsTrigger value="weekly" className="text-xs">Sett</TabsTrigger>
                                        <TabsTrigger value="monthly" className="text-xs">Mese</TabsTrigger>
                                        <TabsTrigger value="annual" className="text-xs">Anno</TabsTrigger>
                                        <TabsTrigger value="all" className="text-xs">Tutto</TabsTrigger>
                                    </TabsList>
                                </Tabs>
                            </div>
                            <div className="flex-1 w-full min-h-0">
                                <TrendChart data={stats.trendData} />
                            </div>
                        </div>
                        <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                            <PeriodComparison comparisons={stats.comparisons} goals={goals} />
                        </div>
                    </TabsContent>

                    <TabsContent value="analisi" className="mt-0 space-y-6">
                        <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                            <CriticalAnalysis criticalHabits={stats.criticalHabits} />
                        </div>
                        <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                            <WorstStreakAnalysis habitStats={stats.habitStats} />
                        </div>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6">
                            <div className={cn("glass-panel rounded-3xl p-4 sm:p-6 h-[300px] sm:h-[350px] flex flex-col transition-all duration-300", isPrivacyMode && "blur-sm")}>
                                <h3 className="text-base sm:text-lg font-display font-semibold mb-3">Focus Abitudini</h3>
                                <div className="flex-1 w-full min-h-0">
                                    <HabitRadar stats={stats.habitStats} />
                                </div>
                            </div>
                            <div className="glass-panel rounded-3xl p-4 sm:p-6 h-[300px] sm:h-[350px] flex flex-col">
                                <div className="mb-3">
                                    <h3 className="text-base sm:text-lg font-display font-semibold flex items-center gap-2">
                                        <span className="w-2 h-2 rounded-sm bg-primary animate-pulse" />
                                        Costanza Settimanale
                                    </h3>
                                    <p className="text-xs sm:text-sm text-muted-foreground">Scopri in quali giorni sei più produttivo.</p>
                                </div>
                                <div className="flex-1 w-full min-h-0">
                                    <DayOfWeekChart data={stats.weekdayStats} />
                                </div>
                            </div>
                        </div>
                    </TabsContent>

                    <TabsContent value="abitudini" className="mt-0">
                        <div className={cn("glass-panel rounded-3xl p-4 sm:p-6 transition-all duration-300", isPrivacyMode && "blur-sm")}>
                            {/* Header with title and sort selector */}
                            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 mb-4 sm:mb-6">
                                <h3 className="text-base sm:text-lg font-display font-semibold">Dettagli Abitudini</h3>
                                <Select value={habitSortBy} onValueChange={(value: any) => setHabitSortBy(value)}>
                                    <SelectTrigger className="w-full sm:w-[200px] glass-card border-white/10">
                                        <SelectValue />
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="rate">
                                            <div className="flex items-center gap-2">
                                                <TrendingUp className="w-4 h-4 text-primary" />
                                                <span>Rate</span>
                                            </div>
                                        </SelectItem>
                                        <SelectItem value="best">
                                            <div className="flex items-center gap-2">
                                                <Trophy className="w-4 h-4 text-yellow-500" />
                                                <span>Best Streak</span>
                                            </div>
                                        </SelectItem>
                                        <SelectItem value="worst">
                                            <div className="flex items-center gap-2">
                                                <TrendingDown className="w-4 h-4 text-destructive" />
                                                <span>Worst Streak</span>
                                            </div>
                                        </SelectItem>
                                        <SelectItem value="current">
                                            <div className="flex items-center gap-2">
                                                <Flame className="w-4 h-4 text-orange-500" />
                                                <span>Serie Attuale</span>
                                            </div>
                                        </SelectItem>
                                        <SelectItem value="name">
                                            <div className="flex items-center gap-2">
                                                <AlignLeft className="w-4 h-4" />
                                                <span>Nome</span>
                                            </div>
                                        </SelectItem>
                                    </SelectContent>
                                </Select>
                            </div>

                            {/* Habits list */}
                            <div className="space-y-3">
                                {stats.habitStats.length === 0 ? (
                                    <p className="text-muted-foreground text-center py-8">Nessuna abitudine tracciata ancora.</p>
                                ) : (
                                    <>
                                        {/* Active Habits */}
                                        {(() => {
                                            const activeHabits = sortedHabits.filter(h => {
                                                const goal = allGoals.find(g => g.id === h.id);
                                                return goal && !goal.end_date;
                                            });
                                            const archivedHabits = sortedHabits.filter(h => {
                                                const goal = allGoals.find(g => g.id === h.id);
                                                return goal && goal.end_date;
                                            });

                                            return (
                                                <>
                                                    {/* Active Habits Section */}
                                                    {activeHabits.map(habit => (
                                                        <div key={habit.id} className="glass-card rounded-xl p-3 sm:p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 sm:gap-4 group cursor-pointer hover:bg-white/5 transition-colors" onClick={() => setSelectedGoalId(habit.id)}>
                                                            <div className="flex items-center gap-3 sm:gap-4 w-full sm:w-auto">
                                                                <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-xl flex items-center justify-center bg-white/5 border border-white/10 group-hover:scale-110 transition-transform duration-300 shadow-lg shrink-0" style={{ borderColor: `${habit.color}40`, boxShadow: `0 0 20px ${habit.color}10` }}>
                                                                    <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-sm" style={{ backgroundColor: habit.color }} />
                                                                </div>
                                                                <div className="min-w-0">
                                                                    <span className="font-semibold text-foreground text-base sm:text-lg truncate block">{habit.title}</span>
                                                                    <div className="h-1 w-16 sm:w-20 bg-secondary rounded-full mt-1 overflow-hidden">
                                                                        <div className="h-full bg-primary transition-all duration-500" style={{ width: `${habit.completionRate}%`, backgroundColor: habit.color }} />
                                                                    </div>
                                                                </div>
                                                            </div>
                                                            <div className="grid grid-cols-4 gap-3 sm:flex sm:gap-6 text-sm text-muted-foreground w-full sm:w-auto justify-between sm:justify-end">
                                                                <div className="flex flex-col items-center sm:items-end">
                                                                    <span className="text-[9px] sm:text-[10px] uppercase tracking-widest font-bold opacity-60 mb-0.5 flex items-center gap-1">
                                                                        <Trophy className="w-2.5 h-2.5 sm:w-3 sm:h-3 text-yellow-500" /> Best
                                                                    </span>
                                                                    <span className="font-mono text-base sm:text-lg font-bold text-foreground">{habit.longestStreak}<span className="text-[10px] sm:text-xs font-sans font-normal opacity-50">gg</span></span>
                                                                </div>
                                                                <div className="flex flex-col items-center sm:items-end">
                                                                    <span className="text-[9px] sm:text-[10px] uppercase tracking-widest font-bold opacity-60 mb-0.5 flex items-center gap-1">
                                                                        <TrendingDown className="w-2.5 h-2.5 sm:w-3 sm:h-3 text-destructive" /> Worst
                                                                    </span>
                                                                    <span className="font-mono text-base sm:text-lg font-bold text-destructive">{habit.worstStreak}<span className="text-[10px] sm:text-xs font-sans font-normal opacity-50">gg</span></span>
                                                                </div>
                                                                <div className="flex flex-col items-center sm:items-end">
                                                                    <span className="text-[9px] sm:text-[10px] uppercase tracking-widest font-bold opacity-60 mb-0.5">Serie</span>
                                                                    <span className="font-mono text-base sm:text-lg font-bold text-foreground">{habit.currentStreak}<span className="text-[10px] sm:text-xs font-sans font-normal opacity-50">gg</span></span>
                                                                </div>
                                                                <div className="flex flex-col items-center sm:items-end">
                                                                    <span className="text-[9px] sm:text-[10px] uppercase tracking-widest font-bold opacity-60 mb-0.5">Rate</span>
                                                                    <span className="font-mono text-base sm:text-lg font-bold text-foreground">{habit.completionRate}<span className="text-[10px] sm:text-sm">%</span></span>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    ))}

                                                    {/* Separator for Archived Habits */}
                                                    {archivedHabits.length > 0 && (
                                                        <div className="relative py-4">
                                                            <div className="absolute inset-0 flex items-center">
                                                                <div className="w-full border-t border-white/10"></div>
                                                            </div>
                                                            <div className="relative flex justify-center">
                                                                <span className="bg-[#0a0a0a] px-3 text-xs uppercase tracking-widest text-muted-foreground font-semibold">
                                                                    Archiviate ({archivedHabits.length})
                                                                </span>
                                                            </div>
                                                        </div>
                                                    )}

                                                    {/* Archived Habits Section */}
                                                    {archivedHabits.map(habit => (
                                                        <div key={habit.id} className="glass-card rounded-xl p-3 sm:p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 sm:gap-4 group cursor-pointer hover:bg-white/5 transition-colors opacity-60" onClick={() => setSelectedGoalId(habit.id)}>
                                                            <div className="flex items-center gap-3 sm:gap-4 w-full sm:w-auto">
                                                                <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-xl flex items-center justify-center bg-white/5 border border-white/10 group-hover:scale-110 transition-transform duration-300 shadow-lg shrink-0" style={{ borderColor: `${habit.color}40`, boxShadow: `0 0 20px ${habit.color}10` }}>
                                                                    <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-sm" style={{ backgroundColor: habit.color }} />
                                                                </div>
                                                                <div className="min-w-0">
                                                                    <div className="flex items-center gap-2">
                                                                        <span className="font-semibold text-foreground text-base sm:text-lg truncate">{habit.title}</span>
                                                                        <span className="text-xs text-muted-foreground shrink-0">(archiviato)</span>
                                                                    </div>
                                                                    <div className="h-1 w-16 sm:w-20 bg-secondary rounded-full mt-1 overflow-hidden">
                                                                        <div className="h-full bg-primary transition-all duration-500" style={{ width: `${habit.completionRate}%`, backgroundColor: habit.color }} />
                                                                    </div>
                                                                </div>
                                                            </div>
                                                            <div className="grid grid-cols-4 gap-3 sm:flex sm:gap-6 text-sm text-muted-foreground w-full sm:w-auto justify-between sm:justify-end">
                                                                <div className="flex flex-col items-center sm:items-end">
                                                                    <span className="text-[9px] sm:text-[10px] uppercase tracking-widest font-bold opacity-60 mb-0.5 flex items-center gap-1">
                                                                        <Trophy className="w-2.5 h-2.5 sm:w-3 sm:h-3 text-yellow-500" /> Best
                                                                    </span>
                                                                    <span className="font-mono text-base sm:text-lg font-bold text-foreground">{habit.longestStreak}<span className="text-[10px] sm:text-xs font-sans font-normal opacity-50">gg</span></span>
                                                                </div>
                                                                <div className="flex flex-col items-center sm:items-end">
                                                                    <span className="text-[9px] sm:text-[10px] uppercase tracking-widest font-bold opacity-60 mb-0.5 flex items-center gap-1">
                                                                        <TrendingDown className="w-2.5 h-2.5 sm:w-3 sm:h-3 text-destructive" /> Worst
                                                                    </span>
                                                                    <span className="font-mono text-base sm:text-lg font-bold text-destructive">{habit.worstStreak}<span className="text-[10px] sm:text-xs font-sans font-normal opacity-50">gg</span></span>
                                                                </div>
                                                                <div className="flex flex-col items-center sm:items-end">
                                                                    <span className="text-[9px] sm:text-[10px] uppercase tracking-widest font-bold opacity-60 mb-0.5">Serie</span>
                                                                    <span className="font-mono text-base sm:text-lg font-bold text-foreground">{habit.currentStreak}<span className="text-[10px] sm:text-xs font-sans font-normal opacity-50">gg</span></span>
                                                                </div>
                                                                <div className="flex flex-col items-center sm:items-end">
                                                                    <span className="text-[9px] sm:text-[10px] uppercase tracking-widest font-bold opacity-60 mb-0.5">Rate</span>
                                                                    <span className="font-mono text-base sm:text-lg font-bold text-foreground">{habit.completionRate}<span className="text-[10px] sm:text-sm">%</span></span>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    ))}
                                                </>
                                            );
                                        })()}
                                    </>
                                )}
                            </div>
                        </div>
                    </TabsContent>

                    <TabsContent value="mood-energia" className="mt-0 space-y-6">
                        <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                            <MoodCorrelationChart />
                        </div>
                        <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                            <MoodEnergyInsights insights={insights} />
                        </div>
                        <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                            <MoodEnergyHabitMatrix correlations={correlations} />
                        </div>
                    </TabsContent>
                </Tabs>
            ) : (
                // SINGLE GOAL VIEW
                selectedGoal && singleGoalStats && (
                    <Tabs defaultValue="overview" key={selectedGoalId} className="w-full">
                        <TabsList className="grid w-full grid-cols-5 mb-4 shrink-0">
                            <TabsTrigger value="overview" className="text-xs sm:text-sm">
                                <span className="hidden sm:inline">Overview</span>
                                <span className="sm:hidden">Info</span>
                            </TabsTrigger>
                            <TabsTrigger value="calendario" className="text-xs sm:text-sm">
                                <span className="hidden sm:inline">Calendario</span>
                                <span className="sm:hidden">Cal</span>
                            </TabsTrigger>
                            <TabsTrigger value="performance" className="text-xs sm:text-sm">
                                <span className="hidden sm:inline">Performance</span>
                                <span className="sm:hidden">Perf</span>
                            </TabsTrigger>
                            <TabsTrigger value="miglioramento" className="text-xs sm:text-sm">
                                <span className="hidden sm:inline">Miglioramento</span>
                                <span className="sm:hidden">Tips</span>
                            </TabsTrigger>
                            <TabsTrigger value="mood-energia" className="text-xs sm:text-sm flex items-center gap-1">
                                <Sparkles className="w-3 h-3" />
                                <span>Mood</span>
                            </TabsTrigger>
                        </TabsList>

                        {/* Tab 1: Overview */}
                        <TabsContent value="overview" className="mt-0 space-y-6">
                            {/* KPI Cards */}
                            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4">
                                <div className="glass-panel rounded-2xl p-4 text-center">
                                    <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Serie Attuale</p>
                                    <p className="text-3xl font-bold font-mono" style={{ color: selectedGoal.color }}>{singleGoalStats.currentStreak}</p>
                                    <p className="text-xs text-muted-foreground">giorni</p>
                                </div>
                                <div className="glass-panel rounded-2xl p-4 text-center">
                                    <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Record</p>
                                    <p className="text-3xl font-bold font-mono text-yellow-500">{singleGoalStats.bestStreak}</p>
                                    <p className="text-xs text-muted-foreground">giorni</p>
                                </div>
                                <div className="glass-panel rounded-2xl p-4 text-center">
                                    <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Completamento</p>
                                    <p className="text-3xl font-bold font-mono text-primary">{singleGoalStats.completionRate}%</p>
                                    <p className="text-xs text-muted-foreground">{singleGoalStats.doneDays}/{singleGoalStats.totalDays} gg</p>
                                </div>
                                <div className="glass-panel rounded-2xl p-4 text-center">
                                    <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Mancati</p>
                                    <p className="text-3xl font-bold font-mono text-destructive">{singleGoalStats.missedDays}</p>
                                    <p className="text-xs text-muted-foreground">giorni</p>
                                </div>
                            </div>

                            {/* Trend Chart */}
                            <div className="glass-panel rounded-3xl p-4 sm:p-6">
                                <h3 className="text-base sm:text-lg font-display font-semibold mb-4">Trend Ultimi 30 Giorni</h3>
                                <div className="grid grid-cols-10 gap-1 sm:gap-2">
                                    {singleGoalStats.trendData.slice(-30).map((d, i) => (
                                        <div
                                            key={i}
                                            className="aspect-square rounded-md sm:rounded-lg transition-all duration-300 hover:scale-110"
                                            style={{
                                                backgroundColor: d.status === 'done' ? '#11FF00' : d.status === 'missed' ? '#FF0000' : 'rgba(255,255,255,0.1)',
                                                opacity: d.status ? 1 : 0.4
                                            }}
                                            title={d.date}
                                        />
                                    ))}
                                </div>
                                <div className="flex items-center gap-4 mt-3 text-xs text-muted-foreground">
                                    <div className="flex items-center gap-1">
                                        <div className="w-3 h-3 rounded-sm" style={{ backgroundColor: '#11FF00' }} />
                                        <span>Completato</span>
                                    </div>
                                    <div className="flex items-center gap-1">
                                        <div className="w-3 h-3 rounded-sm bg-white/10" />
                                        <span>Non completato</span>
                                    </div>
                                </div>
                            </div>

                            {/* Single Habit Correlations */}
                            <div className={cn("transition-all duration-300", isPrivacyMode && "blur-sm")}>
                                <SingleHabitCorrelations
                                    habitId={selectedGoal.id}
                                    habitTitle={selectedGoal.title}
                                    habitColor={selectedGoal.color}
                                    allCorrelations={habitCorrelations}
                                />
                            </div>
                        </TabsContent>

                        {/* Tab 2: Calendario */}
                        <TabsContent value="calendario" className="mt-0 space-y-6">
                            <div className="glass-panel rounded-3xl p-4 sm:p-6">
                                <h3 className="text-base sm:text-lg font-display font-semibold mb-4 flex items-center gap-2">
                                    <Calendar className="w-5 h-5" />
                                    Calendario Annuale
                                </h3>
                                <div className="flex gap-1 flex-wrap">
                                    {singleGoalStats.heatmapData.map((d, i) => (
                                        <div
                                            key={i}
                                            className="w-3 h-3 rounded-sm transition-all"
                                            style={{
                                                backgroundColor: d.count === 1 ? '#11FF00' : d.count === -1 ? '#FF0000' : 'rgba(255,255,255,0.05)'
                                            }}
                                            title={`${d.date}: ${d.count === 1 ? 'Completato' : d.count === -1 ? 'Mancato' : 'Non tracciato'}`}
                                        />
                                    ))}
                                </div>
                                <div className="flex items-center gap-4 mt-4 text-xs text-muted-foreground">
                                    <div className="flex items-center gap-1">
                                        <div className="w-3 h-3 rounded-sm" style={{ backgroundColor: '#11FF00' }} />
                                        <span>Completato</span>
                                    </div>
                                    <div className="flex items-center gap-1">
                                        <div className="w-3 h-3 rounded-sm bg-destructive" />
                                        <span>Mancato</span>
                                    </div>
                                    <div className="flex items-center gap-1">
                                        <div className="w-3 h-3 rounded-sm bg-white/5" />
                                        <span>Non tracciato</span>
                                    </div>
                                </div>
                            </div>
                        </TabsContent>

                        {/* Tab 3: Performance */}
                        <TabsContent value="performance" className="mt-0 space-y-6">
                            <div className="glass-panel rounded-3xl p-4 sm:p-6">
                                <h3 className="text-base sm:text-lg font-display font-semibold mb-4">Performance per Giorno</h3>
                                <div className="grid grid-cols-7 gap-2">
                                    {singleGoalStats.weekdayPerformance.map((d, i) => (
                                        <div key={i} className="text-center">
                                            <p className="text-xs text-muted-foreground mb-2">{d.day}</p>
                                            <div className="h-24 bg-white/5 rounded-lg relative overflow-hidden">
                                                <div
                                                    className="absolute bottom-0 left-0 right-0 transition-all duration-500 rounded-t"
                                                    style={{
                                                        height: `${d.rate}%`,
                                                        backgroundColor: d.rate >= 70 ? '#11FF00' : d.rate >= 40 ? '#f59e0b' : '#FF0000'
                                                    }}
                                                />
                                            </div>
                                            <p className="text-sm font-bold mt-2">{d.rate}%</p>
                                        </div>
                                    ))}
                                </div>
                            </div>

                            {/* Worst Day Highlight */}
                            {singleGoalStats.worstDay.day !== 'N/A' && (
                                <div className="glass-panel rounded-2xl p-4 border border-destructive/30">
                                    <div className="flex items-center gap-3">
                                        <AlertTriangle className="w-5 h-5 text-destructive" />
                                        <div>
                                            <p className="font-semibold">Giorno più debole: {singleGoalStats.worstDay.day}</p>
                                            <p className="text-sm text-muted-foreground">Solo {singleGoalStats.worstDay.rate}% di completamento ({singleGoalStats.worstDay.done}/{singleGoalStats.worstDay.total})</p>
                                        </div>
                                    </div>
                                </div>
                            )}
                        </TabsContent>

                        {/* Tab 4: Miglioramento */}
                        <TabsContent value="miglioramento" className="mt-0 space-y-6">
                            {/* Worst Negative Streak */}
                            <div className="glass-panel rounded-3xl p-4 sm:p-6">
                                <h3 className="text-base sm:text-lg font-display font-semibold mb-4 flex items-center gap-2">
                                    <TrendingDown className="w-5 h-5 text-destructive" />
                                    Serie Negativa Peggiore
                                </h3>
                                {singleGoalStats.worstNegativeStreak > 0 ? (
                                    <div className="flex items-center gap-4">
                                        <div className="text-4xl font-bold font-mono text-destructive">{singleGoalStats.worstNegativeStreak}</div>
                                        <div>
                                            <p className="text-muted-foreground">giorni consecutivi mancati</p>
                                            <p className="text-sm text-muted-foreground">Iniziata il {format(new Date(singleGoalStats.worstNegativeStreakStart), 'd MMMM yyyy', { locale: it })}</p>
                                        </div>
                                    </div>
                                ) : (
                                    <p className="text-muted-foreground">Nessuna serie negativa significativa. Ottimo lavoro! 🎉</p>
                                )}
                            </div>

                            {/* Broken Streaks */}
                            <div className="glass-panel rounded-3xl p-4 sm:p-6">
                                <h3 className="text-base sm:text-lg font-display font-semibold mb-4">Streak Interrotti</h3>
                                {singleGoalStats.brokenStreaks.length > 0 ? (
                                    <div className="space-y-3">
                                        {singleGoalStats.brokenStreaks.map((streak, i) => (
                                            <div key={i} className="flex items-center justify-between p-3 bg-white/5 rounded-xl">
                                                <div className="flex items-center gap-3">
                                                    <div className="w-10 h-10 rounded-full bg-destructive/20 flex items-center justify-center">
                                                        <span className="text-destructive font-bold">{streak.streakLength}</span>
                                                    </div>
                                                    <div>
                                                        <p className="font-semibold">Streak di {streak.streakLength} giorni interrotto</p>
                                                        <p className="text-sm text-muted-foreground">{format(new Date(streak.date), 'd MMMM yyyy', { locale: it })}</p>
                                                    </div>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                ) : (
                                    <p className="text-muted-foreground">Nessuno streak significativo interrotto.</p>
                                )}
                            </div>

                            {/* Improvement Tips */}
                            <div className="glass-panel rounded-3xl p-4 sm:p-6 border border-primary/30">
                                <h3 className="text-base sm:text-lg font-display font-semibold mb-4">💡 Suggerimenti</h3>
                                <ul className="space-y-2 text-sm text-muted-foreground">
                                    {singleGoalStats.worstDay.day !== 'N/A' && singleGoalStats.worstDay.rate < 50 && (
                                        <li>• Concentrati sul <strong className="text-foreground">{singleGoalStats.worstDay.day}</strong> - è il tuo giorno più debole</li>
                                    )}
                                    {singleGoalStats.worstNegativeStreak >= 3 && (
                                        <li>• Evita pause prolungate - la tua serie negativa più lunga è stata di {singleGoalStats.worstNegativeStreak} giorni</li>
                                    )}
                                    {singleGoalStats.completionRate < 70 && (
                                        <li>• Obiettivo: raggiungi almeno il 70% di completamento per consolidare l'abitudine</li>
                                    )}
                                    {singleGoalStats.completionRate >= 80 && (
                                        <li>• 🎉 Ottimo lavoro! Mantieni questa costanza</li>
                                    )}
                                </ul>
                            </div>
                        </TabsContent>

                        {/* Tab 5: Mood & Energia */}
                        <TabsContent value="mood-energia" className="mt-0 space-y-6">
                            {(() => {
                                const habitCorrelation = correlations.find(c => c.habitId === selectedGoalId);
                                if (!habitCorrelation) {
                                    return (
                                        <div className="glass-panel rounded-3xl p-8 text-center">
                                            <Sparkles className="w-12 h-12 mx-auto mb-4 text-muted-foreground opacity-50" />
                                            <p className="text-muted-foreground">
                                                Non ci sono abbastanza dati per analizzare la correlazione mood/energia.
                                            </p>
                                            <p className="text-sm text-muted-foreground mt-2">
                                                Registra il tuo mood ed energia quotidianamente per vedere le correlazioni.
                                            </p>
                                        </div>
                                    );
                                }
                                return <HabitMoodCorrelationChart correlation={habitCorrelation} />;
                            })()}
                        </TabsContent>
                    </Tabs>
                )
            )}
        </div>
    );
}

export default Stats;
