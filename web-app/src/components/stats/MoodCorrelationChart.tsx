import { useState, useMemo } from "react";
import {
    ComposedChart,
    Line,
    XAxis,
    YAxis,
    CartesianGrid,
    Tooltip,
    Legend,
    ResponsiveContainer,
    Area,
    ReferenceLine
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useMoods } from "@/hooks/useMoods";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { format, subDays, parseISO } from "date-fns";
import { useTheme } from "next-themes";
import { TrendingUp, Zap, Activity } from "lucide-react";

type MoodTimeframe = 'weekly' | 'biweekly' | 'monthly' | 'all';

// Custom Tooltip Component
const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
        const mood = payload.find((p: any) => p.dataKey === 'mood');
        const energy = payload.find((p: any) => p.dataKey === 'energy');
        const productivity = payload.find((p: any) => p.dataKey === 'productivity');

        return (
            <div className="glass-panel rounded-xl p-4 border border-white/10 shadow-2xl backdrop-blur-xl min-w-[180px]">
                <p className="text-sm font-semibold text-foreground mb-3 border-b border-white/10 pb-2">{label}</p>
                <div className="space-y-2.5">
                    {mood && (
                        <div className="flex items-center justify-between gap-4">
                            <div className="flex items-center gap-2">
                                <div className="w-2.5 h-2.5 rounded-full bg-emerald-500 shadow-lg shadow-emerald-500/50" />
                                <span className="text-xs text-muted-foreground">Mood</span>
                            </div>
                            <span className="text-sm font-bold text-emerald-400">{mood.value}/10</span>
                        </div>
                    )}
                    {energy && (
                        <div className="flex items-center justify-between gap-4">
                            <div className="flex items-center gap-2">
                                <div className="w-2.5 h-2.5 rounded-full bg-amber-500 shadow-lg shadow-amber-500/50" />
                                <span className="text-xs text-muted-foreground">Energy</span>
                            </div>
                            <span className="text-sm font-bold text-amber-400">{energy.value}/10</span>
                        </div>
                    )}
                    {productivity && (
                        <div className="flex items-center justify-between gap-4">
                            <div className="flex items-center gap-2">
                                <div className="w-2.5 h-2.5 rounded-full bg-violet-500 shadow-lg shadow-violet-500/50" />
                                <span className="text-xs text-muted-foreground">Produttività</span>
                            </div>
                            <span className="text-sm font-bold text-violet-400">{productivity.value}%</span>
                        </div>
                    )}
                </div>
            </div>
        );
    }
    return null;
};

// Custom Legend Component
const CustomLegend = () => (
    <div className="flex flex-wrap items-center justify-center gap-4 sm:gap-6 pt-4">
        <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-gradient-to-r from-violet-500 to-purple-600 shadow-lg shadow-violet-500/30" />
            <span className="text-xs sm:text-sm text-muted-foreground font-medium">Habit Completion %</span>
        </div>
        <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-gradient-to-r from-emerald-400 to-green-500 shadow-lg shadow-emerald-500/30" />
            <span className="text-xs sm:text-sm text-muted-foreground font-medium">Mood</span>
        </div>
        <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-gradient-to-r from-amber-400 to-orange-500 shadow-lg shadow-amber-500/30" />
            <span className="text-xs sm:text-sm text-muted-foreground font-medium">Energy</span>
        </div>
    </div>
);

const useHabitCompletionHistory = (daysBack: number | null) => {
    return useQuery({
        queryKey: ["habit-completion-history", daysBack],
        queryFn: async () => {
            const startDate = daysBack
                ? format(subDays(new Date(), daysBack), "yyyy-MM-dd")
                : null;

            let query = supabase
                .from("goal_logs")
                .select("date, status");

            if (startDate) {
                query = query.gte("date", startDate);
            }

            const { data, error } = await query;

            if (error) throw error;

            const logs = data as { date: string; status: 'done' | 'missed' | 'skipped' }[] | null;

            const grouped: Record<string, { total: number; done: number }> = {};

            logs?.forEach(log => {
                const date = log.date;
                if (!grouped[date]) grouped[date] = { total: 0, done: 0 };
                grouped[date].total += 1;
                if (log.status === 'done') grouped[date].done += 1;
            });

            return grouped;
        }
    });
};

export const MoodCorrelationChart = () => {
    const [timeframe, setTimeframe] = useState<MoodTimeframe>('biweekly');
    const { data: moods } = useMoods();
    const { theme } = useTheme();

    const daysBack = useMemo(() => {
        switch (timeframe) {
            case 'weekly': return 7;
            case 'biweekly': return 14;
            case 'monthly': return 30;
            case 'all': return null;
        }
    }, [timeframe]);

    const { data: completionStats } = useHabitCompletionHistory(daysBack);

    const data = useMemo(() => {
        if (!moods || !completionStats) return [];

        const sliceCount = daysBack ?? moods.length;
        return moods.slice(0, sliceCount).reverse().map(mood => {
            const stats = completionStats[mood.date] || { total: 0, done: 0 };
            const percentage = stats.total > 0 ? Math.round((stats.done / stats.total) * 100) : 0;

            return {
                date: format(parseISO(mood.date), "dd/MM"),
                fullDate: mood.date,
                mood: mood.mood_score,
                energy: mood.energy_score,
                productivity: percentage
            };
        });
    }, [moods, completionStats, daysBack]);

    const isDark = theme === "dark";

    if (!moods || !completionStats) return (
        <Card className="col-span-1 lg:col-span-2 h-[450px] flex items-center justify-center glass-panel border-white/5">
            <div className="flex flex-col items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
                    <Activity className="w-5 h-5 text-primary animate-pulse" />
                </div>
                <p className="text-sm text-muted-foreground">Caricamento dati...</p>
            </div>
        </Card>
    );

    return (
        <Card className="col-span-1 lg:col-span-2 shadow-2xl hover:shadow-primary/5 transition-all duration-500 glass-panel border-white/5 overflow-hidden">
            {/* Ambient glow effect */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[600px] h-[300px] bg-gradient-to-b from-primary/10 via-violet-500/5 to-transparent blur-3xl pointer-events-none -z-10" />

            <CardHeader className="pb-2">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-violet-500/20 to-purple-600/20 flex items-center justify-center border border-violet-500/20">
                            <TrendingUp className="w-5 h-5 text-violet-400" />
                        </div>
                        <div>
                            <CardTitle className="text-lg sm:text-xl">Mood & Energy vs Productivity</CardTitle>
                            <p className="text-xs text-muted-foreground mt-0.5">Correlazione tra benessere e completamento abitudini</p>
                        </div>
                    </div>
                    <Tabs
                        value={timeframe}
                        onValueChange={(v) => setTimeframe(v as MoodTimeframe)}
                        className="w-full sm:w-auto"
                    >
                        <TabsList className="grid w-full grid-cols-4 sm:w-[260px] bg-white/5 border border-white/10">
                            <TabsTrigger value="weekly" className="text-xs data-[state=active]:bg-primary/20">7gg</TabsTrigger>
                            <TabsTrigger value="biweekly" className="text-xs data-[state=active]:bg-primary/20">14gg</TabsTrigger>
                            <TabsTrigger value="monthly" className="text-xs data-[state=active]:bg-primary/20">30gg</TabsTrigger>
                            <TabsTrigger value="all" className="text-xs data-[state=active]:bg-primary/20">Tutto</TabsTrigger>
                        </TabsList>
                    </Tabs>
                </div>
            </CardHeader>
            <CardContent className="h-[380px] pt-4">
                <ResponsiveContainer width="100%" height="100%">
                    <ComposedChart data={data} margin={{ top: 10, right: 10, left: -10, bottom: 0 }}>
                        <defs>
                            {/* Premium gradient for productivity area */}
                            <linearGradient id="productivityGradient" x1="0" y1="0" x2="0" y2="1">
                                <stop offset="0%" stopColor="#8b5cf6" stopOpacity={0.4} />
                                <stop offset="50%" stopColor="#7c3aed" stopOpacity={0.2} />
                                <stop offset="100%" stopColor="#6d28d9" stopOpacity={0} />
                            </linearGradient>

                            {/* Glow filters for lines */}
                            <filter id="moodGlow" x="-50%" y="-50%" width="200%" height="200%">
                                <feGaussianBlur stdDeviation="3" result="blur" />
                                <feFlood floodColor="#10b981" floodOpacity="0.5" />
                                <feComposite in2="blur" operator="in" />
                                <feMerge>
                                    <feMergeNode />
                                    <feMergeNode in="SourceGraphic" />
                                </feMerge>
                            </filter>

                            <filter id="energyGlow" x="-50%" y="-50%" width="200%" height="200%">
                                <feGaussianBlur stdDeviation="3" result="blur" />
                                <feFlood floodColor="#f59e0b" floodOpacity="0.5" />
                                <feComposite in2="blur" operator="in" />
                                <feMerge>
                                    <feMergeNode />
                                    <feMergeNode in="SourceGraphic" />
                                </feMerge>
                            </filter>

                            {/* Gradient for mood line */}
                            <linearGradient id="moodLineGradient" x1="0" y1="0" x2="1" y2="0">
                                <stop offset="0%" stopColor="#34d399" />
                                <stop offset="100%" stopColor="#10b981" />
                            </linearGradient>

                            {/* Gradient for energy line */}
                            <linearGradient id="energyLineGradient" x1="0" y1="0" x2="1" y2="0">
                                <stop offset="0%" stopColor="#fbbf24" />
                                <stop offset="100%" stopColor="#f59e0b" />
                            </linearGradient>
                        </defs>

                        <CartesianGrid
                            strokeDasharray="3 3"
                            opacity={0.08}
                            vertical={false}
                            stroke={isDark ? "#fff" : "#000"}
                        />

                        {/* Reference line at 50% productivity */}
                        <ReferenceLine
                            yAxisId="right"
                            y={50}
                            stroke="#8b5cf6"
                            strokeDasharray="5 5"
                            strokeOpacity={0.3}
                        />

                        <XAxis
                            dataKey="date"
                            tick={{ fontSize: 11, fill: isDark ? "#71717a" : "#a1a1aa" }}
                            axisLine={false}
                            tickLine={false}
                            dy={8}
                            interval="preserveStartEnd"
                        />

                        {/* Left Axis: Mood/Energy (1-10) */}
                        <YAxis
                            yAxisId="left"
                            domain={[0, 10]}
                            tickCount={6}
                            tick={{ fontSize: 11, fill: isDark ? "#71717a" : "#a1a1aa" }}
                            axisLine={false}
                            tickLine={false}
                            width={35}
                            label={{
                                value: 'Score',
                                angle: -90,
                                position: 'insideLeft',
                                offset: 10,
                                style: {
                                    fill: isDark ? "#52525b" : "#a1a1aa",
                                    fontSize: 11,
                                    fontWeight: 500
                                }
                            }}
                        />

                        {/* Right Axis: Productivity % */}
                        <YAxis
                            yAxisId="right"
                            orientation="right"
                            domain={[0, 100]}
                            tick={{ fontSize: 11, fill: "#8b5cf6" }}
                            axisLine={false}
                            tickLine={false}
                            width={40}
                            tickFormatter={(value) => `${value}%`}
                        />

                        <Tooltip content={<CustomTooltip />} />

                        {/* Productivity Area */}
                        <Area
                            yAxisId="right"
                            type="monotone"
                            dataKey="productivity"
                            fill="url(#productivityGradient)"
                            stroke="#8b5cf6"
                            strokeWidth={2.5}
                            name="Habit Completion %"
                            animationDuration={1500}
                            animationEasing="ease-out"
                        />

                        {/* Mood Line with glow */}
                        <Line
                            yAxisId="left"
                            type="monotone"
                            dataKey="mood"
                            stroke="url(#moodLineGradient)"
                            strokeWidth={3}
                            dot={{
                                r: 4,
                                strokeWidth: 2,
                                fill: isDark ? "#0a0a0a" : "#fff",
                                stroke: "#10b981"
                            }}
                            activeDot={{
                                r: 7,
                                strokeWidth: 3,
                                fill: "#10b981",
                                stroke: isDark ? "#0a0a0a" : "#fff",
                                className: "drop-shadow-lg"
                            }}
                            name="Mood"
                            filter="url(#moodGlow)"
                            animationDuration={1200}
                            animationEasing="ease-out"
                        />

                        {/* Energy Line with glow */}
                        <Line
                            yAxisId="left"
                            type="monotone"
                            dataKey="energy"
                            stroke="url(#energyLineGradient)"
                            strokeWidth={3}
                            strokeDasharray="6 4"
                            dot={{
                                r: 4,
                                strokeWidth: 2,
                                fill: isDark ? "#0a0a0a" : "#fff",
                                stroke: "#f59e0b"
                            }}
                            activeDot={{
                                r: 7,
                                strokeWidth: 3,
                                fill: "#f59e0b",
                                stroke: isDark ? "#0a0a0a" : "#fff",
                                className: "drop-shadow-lg"
                            }}
                            name="Energy"
                            filter="url(#energyGlow)"
                            animationDuration={1400}
                            animationEasing="ease-out"
                        />

                        <Legend content={<CustomLegend />} />
                    </ComposedChart>
                </ResponsiveContainer>
            </CardContent>
        </Card>
    );
};
