import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import {
    BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
    PieChart, Pie, Cell, Legend,
    AreaChart, Area,
    RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar,
    ComposedChart, Line, LineChart
} from 'recharts';
import { Loader2, Trophy, Target, TrendingUp, CheckCircle2, Zap, Brain, Rocket, Calendar, Activity } from 'lucide-react';
import { useGoalCategories, DEFAULT_CATEGORY_LABELS } from '@/hooks/useGoalCategories';

interface MacroGoalsStatsProps {
    year: number | string;
}

type GoalType = 'annual' | 'quarterly' | 'monthly' | 'weekly' | 'lifetime' | 'stats';

interface LongTermGoal {
    id: string;
    title: string;
    is_completed: boolean;
    type: GoalType;
    year: number | null;
    quarter: number | null;
    month: number | null;
    week_number: number | null;
    created_at: string;
    color: string | null;
}

export function MacroGoalsStats({ year }: MacroGoalsStatsProps) {
    const { getLabel, settings } = useGoalCategories();
    const { data: allGoals, isLoading } = useQuery({
        queryKey: ['longTermGoals', 'stats', year],
        queryFn: async () => {
            let allRows: LongTermGoal[] = [];
            let from = 0;
            const step = 1000;
            let keepFetching = true;

            while (keepFetching) {
                let query = supabase
                    .from('long_term_goals')
                    .select('*');

                if (year !== 'all') {
                    query = query.eq('year', typeof year === 'string' ? parseInt(year) : year);
                }

                // Range is inclusive
                const { data, error } = await query
                    .range(from, from + step - 1);

                if (error) throw error;

                if (data && data.length > 0) {
                    allRows = [...allRows, ...(data as LongTermGoal[])];
                    if (data.length < step) {
                        keepFetching = false;
                    } else {
                        from += step;
                    }
                } else {
                    keepFetching = false; // No more data
                }
            }

            return allRows;
        },
    });

    if (isLoading) {
        return <div className="flex justify-center p-8"><Loader2 className="w-8 h-8 animate-spin text-muted-foreground" /></div>;
    }

    if (!allGoals || allGoals.length === 0) {
        return (
            <div className="text-center p-12 border border-dashed border-white/10 rounded-xl text-muted-foreground">
                Nessun dato disponibile per {year === 'all' ? 'il periodo selezionato' : `il ${year}`}. Aggiungi qualche obiettivo!
            </div>
        );
    }

    // --- KPIs ---
    const totalGoals = allGoals.length;
    const completedGoals = allGoals.filter(g => g.is_completed).length;
    const completionRate = Math.round((completedGoals / totalGoals) * 100) || 0;

    // Calculate dynamic start year for "All Time" label
    const lifetimeGoals = allGoals.filter(g => g.type === 'lifetime');
    const timeBasedGoals = allGoals.filter(g => g.type !== 'lifetime');

    // Calculate dynamic start year for "All Time" label (ignoring lifetime goals for start year)
    const validYears = timeBasedGoals.map(g => g.year).filter((y): y is number => y !== null);
    const minYear = validYears.length > 0 ? Math.min(...validYears) : new Date().getFullYear();

    const byType = {
        annual: allGoals.filter(g => g.type === 'annual').length,
        quarterly: allGoals.filter(g => g.type === 'quarterly').length,
        monthly: allGoals.filter(g => g.type === 'monthly').length,
        weekly: allGoals.filter(g => g.type === 'weekly').length,
        lifetime: lifetimeGoals.length,
    };

    // Calculate best type for generic use
    const typeStats = [
        { type: 'Lifetime', total: byType.lifetime, completed: lifetimeGoals.filter(g => g.is_completed).length },
        { type: 'Annuale', total: byType.annual, completed: allGoals.filter(g => g.type === 'annual' && g.is_completed).length },
        { type: 'Trimestrale', total: byType.quarterly, completed: allGoals.filter(g => g.type === 'quarterly' && g.is_completed).length },
        { type: 'Mensile', total: byType.monthly, completed: allGoals.filter(g => g.type === 'monthly' && g.is_completed).length },
        { type: 'Settimanale', total: byType.weekly, completed: allGoals.filter(g => g.type === 'weekly' && g.is_completed).length },
    ].map(t => ({
        ...t,
        rate: t.total > 0 ? Math.round((t.completed / t.total) * 100) : 0
    })).sort((a, b) => b.rate - a.rate || b.completed - a.completed);

    const bestType = typeStats[0];


    // --- Category Data (Common) ---
    const categoryStats: Record<string, { total: number; completed: number }> = {};
    allGoals.forEach(g => {
        const c = g.color || 'null';
        // Filter: Active if 'null' (Generale) OR if the resolved label is DIFFERENT from the default color name
        const label = getLabel(c === 'null' ? null : c);
        // Fallback to 'c' if default label is missing (e.g. for new colors) to prevent them showing as "custom"
        const defaultLabel = c === 'null' ? 'Generale' : (DEFAULT_CATEGORY_LABELS[c] || c);
        // If label != defaultLabel, it means the user heavily customized it (or it's 'Generale' which we always show?)
        // Actually 'Generale' label is 'Generale'. default is 'Generale'. 
        // Logic: Show if 'null' OR label != defaultLabel

        const isDefault = c !== 'null' && label === defaultLabel;
        const isActive = c === 'null' || !isDefault;

        if (isActive) {
            if (!categoryStats[c]) categoryStats[c] = { total: 0, completed: 0 };
            categoryStats[c].total++;
            if (g.is_completed) categoryStats[c].completed++;
        }
    });

    const radarData = Object.entries(categoryStats).map(([key, stats]) => ({
        subject: getLabel(key === 'null' ? null : key),
        A: Math.round((stats.completed / stats.total) * 100),
        fullMark: 100,
        total: stats.total // Keep for reference
    })).sort((a, b) => b.A - a.A);

    const bestCategory = radarData.length > 0 ? radarData[0] : null;

    const chartColors: Record<string, string> = {
        'red': '#f43f5e', 'orange': '#f97316', 'yellow': '#fbbf24', 'green': '#10b981',
        'blue': '#2563eb', 'purple': '#7c3aed', 'pink': '#d946ef', 'cyan': '#06b6d4', 'null': '#525252'
    };
    const pieData = Object.entries(categoryStats).map(([key, stats]) => ({
        name: getLabel(key === 'null' ? null : key),
        value: stats.total,
        fill: chartColors[key] || '#888888'
    })).sort((a, b) => b.value - a.value);

    // --- MODE SWITCHING: All Time vs Single Year ---
    const isAllTime = year === 'all';

    if (isAllTime) {
        // --- ALL TIME CALCULATIONS ---

        // Group by Year
        const yearlyStatsMap: Record<number, { total: number; completed: number; rate: number }> = {};
        timeBasedGoals.forEach(g => {
            if (g.year === null) return;
            if (!yearlyStatsMap[g.year]) yearlyStatsMap[g.year] = { total: 0, completed: 0, rate: 0 };
            yearlyStatsMap[g.year].total++;
            if (g.is_completed) yearlyStatsMap[g.year].completed++;
        });

        const yearlyData = Object.entries(yearlyStatsMap).map(([y, s]) => ({
            year: y,
            total: s.total,
            completed: s.completed,
            rate: Math.round((s.completed / s.total) * 100) || 0
        })).sort((a, b) => parseInt(a.year) - parseInt(b.year));

        // Insights for All Time
        const bestYear = [...yearlyData].sort((a, b) => b.rate - a.rate || b.completed - a.completed)[0];
        const mostProductiveYear = [...yearlyData].sort((a, b) => b.completed - a.completed)[0];

        // --- SEASONAL DATA (Q1-Q4 Aggregated) ---
        const seasonalData = [1, 2, 3, 4].map(q => ({
            name: `Q${q}`,
            total: 0,
            completed: 0,
            rate: 0
        }));

        timeBasedGoals.forEach(g => {
            const q = g.quarter;

            if (q && q >= 1 && q <= 4) {
                const idx = q - 1;
                seasonalData[idx].total++;
                if (g.is_completed) seasonalData[idx].completed++;
            }
        });

        seasonalData.forEach(d => {
            d.rate = d.total > 0 ? Math.round((d.completed / d.total) * 100) : 0;
        });

        // --- MONTHLY HISTORICAL DATA (Jan-Dec Aggregated) ---
        const monthlyHistoricalData = Array.from({ length: 12 }, (_, i) => ({
            name: new Date(2024, i).toLocaleString('it-IT', { month: 'short' }), // Year doesn't matter for month name
            monthIndex: i + 1,
            total: 0,
            completed: 0,
            rate: 0
        }));

        timeBasedGoals.forEach(g => {
            if (g.month && g.month >= 1 && g.month <= 12) {
                const idx = g.month - 1;
                monthlyHistoricalData[idx].total++;
                if (g.is_completed) monthlyHistoricalData[idx].completed++;
            }
        });

        monthlyHistoricalData.forEach(d => {
            d.rate = d.total > 0 ? Math.round((d.completed / d.total) * 100) : 0;
        });

        // --- CATEGORY EVOLUTION DATA (Stacked Bar by Year) ---
        const categoryEvolutionData: any[] = [];
        // Get all unique years sorted
        const uniqueYears = Array.from(new Set(timeBasedGoals.map(g => g.year).filter((y): y is number => y !== null))).sort((a, b) => a - b);

        uniqueYears.forEach(y => {
            const yearGoals = timeBasedGoals.filter(g => g.year === y);
            const row: any = { year: y.toString(), total: yearGoals.length };

            // Initialize all colors to 0, but ONLY active ones
            Object.keys(chartColors).forEach(color => {
                const label = getLabel(color === 'null' ? null : color);
                const defaultLabel = color === 'null' ? 'Generale' : (DEFAULT_CATEGORY_LABELS[color] || color);
                const isDefault = color !== 'null' && label === defaultLabel;
                const isActive = color === 'null' || !isDefault;

                if (isActive) {
                    row[color] = 0;
                }
            });

            yearGoals.forEach(g => {
                const c = g.color || 'null';
                const label = getLabel(c === 'null' ? null : c);
                const defaultLabel = c === 'null' ? 'Generale' : (DEFAULT_CATEGORY_LABELS[c] || c);
                const isDefault = c !== 'null' && label === defaultLabel;
                const isActive = c === 'null' || !isDefault;
                if (isActive) {
                    if (row[c] !== undefined) row[c]++;
                }
            });

            categoryEvolutionData.push(row);
        });

        return (
            <div className="space-y-8 animate-fade-in pb-10">
                {/* HEADLINE METRICS - Premium Style */}
                <div className="grid gap-6 md:grid-cols-4">
                    <Card className="bg-gradient-to-br from-indigo-500/10 to-blue-600/10 border-indigo-500/20 shadow-lg shadow-indigo-500/5">
                        <CardHeader className="flex flex-row items-center justify-between pb-2">
                            <CardTitle className="text-sm font-medium text-indigo-400">Totale Storico</CardTitle>
                            <Target className="h-4 w-4 text-indigo-500" />
                        </CardHeader>
                        <CardContent>
                            <div className="text-3xl font-bold text-white">{totalGoals}</div>
                            <p className="text-xs text-muted-foreground mt-1">Obiettivi tracciati dal {minYear}</p>
                        </CardContent>
                    </Card>

                    <Card className="bg-gradient-to-br from-emerald-500/10 to-teal-500/10 border-emerald-500/20 shadow-lg shadow-emerald-500/5">
                        <CardHeader className="flex flex-row items-center justify-between pb-2">
                            <CardTitle className="text-sm font-medium text-emerald-400">Successo Globale</CardTitle>
                            <Trophy className="h-4 w-4 text-emerald-500" />
                        </CardHeader>
                        <CardContent>
                            <div className="text-3xl font-bold text-white">{completionRate}%</div>
                            <p className="text-xs text-muted-foreground mt-1">{completedGoals} obiettivi completati</p>
                        </CardContent>
                    </Card>

                    <Card className="bg-gradient-to-br from-amber-500/10 to-orange-500/10 border-amber-500/20 shadow-lg shadow-amber-500/5">
                        <CardHeader className="flex flex-row items-center justify-between pb-2">
                            <CardTitle className="text-sm font-medium text-amber-400">Anno Migliore</CardTitle>
                            <Calendar className="h-4 w-4 text-amber-500" />
                        </CardHeader>
                        <CardContent>
                            <div className="text-3xl font-bold text-white">{bestYear?.year || 'N/A'}</div>
                            <p className="text-xs text-muted-foreground mt-1">{bestYear?.rate}% completamento</p>
                        </CardContent>
                    </Card>

                    <Card className="bg-gradient-to-br from-cyan-500/10 to-sky-500/10 border-cyan-500/20 shadow-lg shadow-cyan-500/5">
                        <CardHeader className="flex flex-row items-center justify-between pb-2">
                            <CardTitle className="text-sm font-medium text-cyan-400">Anno Più Produttivo</CardTitle>
                            <Activity className="h-4 w-4 text-cyan-500" />
                        </CardHeader>
                        <CardContent>
                            <div className="text-3xl font-bold text-white">{mostProductiveYear?.year || 'N/A'}</div>
                            <p className="text-xs text-muted-foreground mt-1">{mostProductiveYear?.total} obiettivi totali</p>
                        </CardContent>
                    </Card>
                </div>

                {/* MAIN CHARTS - Separated logic from Single Year */}
                <div className="grid gap-6 md:grid-cols-2">
                    {/* 1. Yearly Progression Bar Chart */}
                    <Card className="md:col-span-2 bg-card/40 border-white/5 backdrop-blur-sm p-2">
                        <CardHeader>
                            <div className="flex items-center gap-2">
                                <TrendingUp className="w-5 h-5 text-blue-500" />
                                <CardTitle>Progressione Annuale</CardTitle>
                            </div>
                            <CardDescription>Confronto anno per anno del volume di obiettivi e completamenti</CardDescription>
                        </CardHeader>
                        <CardContent className="h-[300px] sm:h-[400px]">
                            <ResponsiveContainer width="100%" height="100%">
                                <ComposedChart data={yearlyData} margin={{ top: 20, right: 20, bottom: 20, left: 20 }}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#ffffff10" vertical={false} />
                                    <XAxis dataKey="year" stroke="#888888" fontSize={14} tickLine={false} axisLine={false} />
                                    <YAxis yAxisId="left" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                    <YAxis yAxisId="right" orientation="right" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} unit="%" domain={[0, 100]} />
                                    <Tooltip
                                        contentStyle={{ backgroundColor: '#09090b', border: '1px solid #27272a', borderRadius: '12px', boxShadow: '0 4px 20px rgba(0,0,0,0.5)' }}
                                        cursor={{ fill: '#ffffff05' }}
                                    />
                                    <Legend wrapperStyle={{ paddingTop: '20px' }} />
                                    <Bar yAxisId="left" dataKey="total" name="Totale Obiettivi" fill="#3b82f6" radius={[4, 4, 0, 0]} barSize={40} fillOpacity={0.8} />
                                    <Bar yAxisId="left" dataKey="completed" name="Completati" fill="#10b981" radius={[4, 4, 0, 0]} barSize={40} fillOpacity={0.8} />
                                    <Line yAxisId="right" type="monotone" dataKey="rate" name="Tasso Successo %" stroke="#f59e0b" strokeWidth={3} dot={{ r: 4, strokeWidth: 2 }} activeDot={{ r: 6 }} />
                                </ComposedChart>
                            </ResponsiveContainer>
                        </CardContent>
                    </Card>

                    {/* 2. Category Radar (Same as before, good for aggregation) */}
                    <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                        <CardHeader>
                            <div className="flex items-center gap-2">
                                <Target className="w-5 h-5 text-cyan-500" />
                                <CardTitle>Performance per Categoria (Storico)</CardTitle>
                            </div>
                        </CardHeader>
                        <CardContent className="h-[300px] sm:h-[350px]">
                            <ResponsiveContainer width="100%" height="100%">
                                <RadarChart cx="50%" cy="50%" outerRadius="65%" data={radarData}>
                                    <PolarGrid stroke="#ffffff20" />
                                    <PolarAngleAxis
                                        dataKey="subject"
                                        tick={{ fill: '#a1a1aa', fontSize: 13, fontWeight: 500 }}
                                    />
                                    <PolarRadiusAxis angle={30} domain={[0, 100]} tick={false} axisLine={false} />
                                    <Radar
                                        name="Success Rate"
                                        dataKey="A"
                                        stroke="#06b6d4"
                                        fill="#06b6d4"
                                        fillOpacity={0.5}
                                    />
                                    <Tooltip
                                        contentStyle={{ backgroundColor: '#1f1f1f', border: '1px solid #333', color: '#fff', borderRadius: '8px' }}
                                        itemStyle={{ color: '#fff' }}
                                        formatter={(value: number) => [`${value}%`, 'Successo']}
                                    />
                                </RadarChart>
                            </ResponsiveContainer>
                        </CardContent>
                    </Card>

                    {/* 3. Type Distribution */}
                    <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                        <CardHeader>
                            <div className="flex items-center gap-2">
                                <Brain className="w-5 h-5 text-purple-500" />
                                <CardTitle>Distribuzione Tipologie</CardTitle>
                            </div>
                        </CardHeader>
                        <CardContent className="h-[300px] sm:h-[350px]">
                            <ResponsiveContainer width="100%" height="100%">
                                <BarChart data={typeStats} layout="vertical" margin={{ left: 20 }}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#ffffff10" horizontal={true} vertical={false} />
                                    <XAxis type="number" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                    <YAxis dataKey="type" type="category" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} width={80} />
                                    <Tooltip
                                        contentStyle={{ backgroundColor: '#1f1f1f', border: '1px solid #333', color: '#fff', borderRadius: '8px' }}
                                        cursor={{ fill: '#ffffff05' }}
                                    />
                                    <Bar dataKey="rate" name="Successo %" fill="#8b5cf6" radius={[0, 4, 4, 0]} barSize={30}>
                                        {/* Label list could be cool */}
                                    </Bar>
                                </BarChart>
                            </ResponsiveContainer>
                        </CardContent>
                    </Card>

                    {/* 4. Seasonal/Quarterly Performance (New) */}
                    <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                        <CardHeader>
                            <div className="flex items-center gap-2">
                                <Calendar className="w-5 h-5 text-amber-500" />
                                <CardTitle>Stagionalità (Performance Trimestrale)</CardTitle>
                            </div>
                            <CardDescription>Aggregato di tutti gli anni: in quale trimestre rendi meglio?</CardDescription>
                        </CardHeader>
                        <CardContent className="h-[300px] sm:h-[350px]">
                            <ResponsiveContainer width="100%" height="100%">
                                <BarChart data={seasonalData}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#ffffff10" vertical={false} />
                                    <XAxis dataKey="name" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                    <YAxis stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                    <Tooltip
                                        contentStyle={{ backgroundColor: '#1f1f1f', border: '1px solid #333', color: '#fff', borderRadius: '8px' }}
                                        cursor={{ fill: '#ffffff05' }}
                                    />
                                    <Bar dataKey="total" name="Totale" fill="#f59e0b" radius={[4, 4, 0, 0]} barSize={30} fillOpacity={0.6} />
                                    <Bar dataKey="completed" name="Completati" fill="#10b981" radius={[4, 4, 0, 0]} barSize={30} />
                                </BarChart>
                            </ResponsiveContainer>
                        </CardContent>
                    </Card>

                    {/* 5. Historical Monthly Performance (New) */}
                    <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                        <CardHeader>
                            <div className="flex items-center gap-2">
                                <Activity className="w-5 h-5 text-pink-500" />
                                <CardTitle>Performance Mensile (Storico)</CardTitle>
                            </div>
                            <CardDescription>Successo medio per mese: scopri il tuo ritmo ideale</CardDescription>
                        </CardHeader>
                        <CardContent className="h-[300px] sm:h-[350px]">
                            <ResponsiveContainer width="100%" height="100%">
                                <LineChart data={monthlyHistoricalData}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#ffffff10" vertical={false} />
                                    <XAxis dataKey="name" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                    <YAxis stroke="#888888" fontSize={12} tickLine={false} axisLine={false} unit="%" domain={[0, 100]} />
                                    <Tooltip
                                        contentStyle={{ backgroundColor: '#1f1f1f', border: '1px solid #333', color: '#fff', borderRadius: '8px' }}
                                        cursor={{ stroke: '#ffffff20' }}
                                    />
                                    <Line
                                        type="monotone"
                                        dataKey="rate"
                                        name="Tasso di Successo"
                                        stroke="#ec4899"
                                        strokeWidth={3}
                                        dot={{ r: 4, strokeWidth: 2, fill: '#1f1f1f' }}
                                        activeDot={{ r: 6, fill: '#ec4899' }}
                                    />
                                </LineChart>
                            </ResponsiveContainer>
                        </CardContent>
                    </Card>

                    {/* 5. Category Evolution (Stacked Bar) */}
                    <Card className="md:col-span-2 bg-card/40 border-white/5 backdrop-blur-sm">
                        <CardHeader>
                            <div className="flex items-center gap-2">
                                <TrendingUp className="w-5 h-5 text-indigo-500" />
                                <CardTitle>Evoluzione Interessi (Categorie)</CardTitle>
                            </div>
                            <CardDescription>Come sono cambiati i tuoi focus nel corso degli anni</CardDescription>
                        </CardHeader>
                        <CardContent className="h-[300px] sm:h-[400px]">
                            <ResponsiveContainer width="100%" height="100%">
                                <BarChart data={categoryEvolutionData}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#ffffff10" vertical={false} />
                                    <XAxis dataKey="year" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                    <YAxis stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                    <Tooltip
                                        contentStyle={{ backgroundColor: '#1f1f1f', border: '1px solid #333', color: '#fff', borderRadius: '8px' }}
                                        cursor={{ fill: '#ffffff05' }}
                                    />
                                    <Legend />
                                    {Object.entries(chartColors).map(([color, hex]) => {
                                        const label = getLabel(color === 'null' ? null : color);
                                        const defaultLabel = color === 'null' ? 'Generale' : (DEFAULT_CATEGORY_LABELS[color] || color);
                                        const isDefault = color !== 'null' && label === defaultLabel;
                                        const isActive = color === 'null' || !isDefault;

                                        if (!isActive) return null;

                                        return (
                                            <Bar
                                                key={color}
                                                dataKey={color}
                                                name={label}
                                                stackId="a"
                                                fill={hex}
                                            />
                                        );
                                    })}
                                </BarChart>
                            </ResponsiveContainer>
                        </CardContent>
                    </Card>
                </div>
            </div>
        );
    }

    // --- SINGLE YEAR LOGIC (Old logic mostly preserved but cleaner) ---
    // (Existing Monthly/Timeline logic remains here for else branch)

    // ... [Previous implementation for single year]
    // --- SINGLE YEAR LOGIC ---

    // 1. Monthly Data Preparation (Specific for Single Year)
    const y = typeof year === 'string' ? parseInt(year) : year;
    const monthlyData = Array.from({ length: 12 }, (_, i) => ({
        name: new Date(y, i).toLocaleString('it-IT', { month: 'short' }),
        monthIndex: i + 1,
        total: 0,
        completed: 0,
        rate: 0,
        cumulativeTotal: 0,
        cumulativeCompleted: 0,
    }));

    let runningTotal = 0;
    let runningCompleted = 0;

    timeBasedGoals.forEach(g => {
        let mIdx = 0;
        if (g.month) mIdx = g.month - 1;
        if (mIdx < 0) mIdx = 0;
        if (mIdx > 11) mIdx = 11;

        monthlyData[mIdx].total++;
        if (g.is_completed) monthlyData[mIdx].completed++;
    });

    monthlyData.forEach(d => {
        d.rate = d.total > 0 ? Math.round((d.completed / d.total) * 100) : 0;
        runningTotal += d.total;
        runningCompleted += d.completed;
        d.cumulativeTotal = runningTotal;
        d.cumulativeCompleted = runningCompleted;
    });

    // 2. Quarterly Data Preparation
    const quarterlyData = [1, 2, 3, 4].map(q => ({
        name: `Q${q}`,
        quarterIndex: q,
        total: 0,
        completed: 0,
        rate: 0
    }));

    allGoals.filter(g => g.quarter).forEach(g => {
        if (g.quarter && g.quarter >= 1 && g.quarter <= 4) {
            const idx = g.quarter - 1;
            quarterlyData[idx].total++;
            if (g.is_completed) quarterlyData[idx].completed++;
        }
    });

    quarterlyData.forEach(d => {
        d.rate = d.total > 0 ? Math.round((d.completed / d.total) * 100) : 0;
    });

    // 3. Insights
    const bestMonth = [...monthlyData]
        .filter(m => m.total > 0)
        .sort((a, b) => b.rate - a.rate || b.completed - a.completed)[0];

    return (
        <div className="space-y-6 animate-fade-in pb-10">
            {/* Top Insights Section */}
            <div className="grid gap-4 md:grid-cols-3">
                <Card className="bg-gradient-to-br from-purple-500/10 to-blue-500/10 border-purple-500/20">
                    <CardHeader className="flex flex-row items-center justify-between pb-2">
                        <CardTitle className="text-sm font-medium text-purple-400">Punto di Forza</CardTitle>
                        <Zap className="h-4 w-4 text-purple-500" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-white">{bestCategory?.subject || 'N/A'}</div>
                        <p className="text-xs text-muted-foreground">
                            {bestCategory ? `${bestCategory.A}% di completamento` : 'Nessun dato'}
                        </p>
                    </CardContent>
                </Card>
                <Card className="bg-gradient-to-br from-amber-500/10 to-orange-500/10 border-amber-500/20">
                    <CardHeader className="flex flex-row items-center justify-between pb-2">
                        <CardTitle className="text-sm font-medium text-amber-400">Mese Migliore</CardTitle>
                        <Trophy className="h-4 w-4 text-amber-500" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-white">{bestMonth?.name || 'N/A'}</div>
                        <p className="text-xs text-muted-foreground">
                            {bestMonth ? `${bestMonth.rate}% di successo (${bestMonth.completed}/${bestMonth.total})` : 'Nessuna attività'}
                        </p>
                    </CardContent>
                </Card>
                <Card className="bg-gradient-to-br from-emerald-500/10 to-cyan-500/10 border-emerald-500/20">
                    <CardHeader className="flex flex-row items-center justify-between pb-2">
                        <CardTitle className="text-sm font-medium text-emerald-400">Tipologia Efficace</CardTitle>
                        <Brain className="h-4 w-4 text-emerald-500" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-white capitalize">
                            {bestType.total > 0 ? bestType.type : 'N/A'}
                        </div>
                        <p className="text-xs text-muted-foreground">
                            {bestType.total > 0 ? `${bestType.rate}% di successo` : 'Dati insufficienti'}
                        </p>
                    </CardContent>
                </Card>
            </div>

            {/* Standard KPIs */}
            <div className="grid gap-4 md:grid-cols-4">
                <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                    <CardHeader className="flex flex-row items-center justify-between pb-2">
                        <CardTitle className="text-sm font-medium text-muted-foreground">Totale</CardTitle>
                        <Target className="h-4 w-4 text-primary" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-white">{totalGoals}</div>
                    </CardContent>
                </Card>
                <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                    <CardHeader className="flex flex-row items-center justify-between pb-2">
                        <CardTitle className="text-sm font-medium text-muted-foreground">Completati</CardTitle>
                        <CheckCircle2 className="h-4 w-4 text-green-500" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-white">{completedGoals}</div>
                    </CardContent>
                </Card>
                <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                    <CardHeader className="flex flex-row items-center justify-between pb-2">
                        <CardTitle className="text-sm font-medium text-muted-foreground">Successo</CardTitle>
                        <Trophy className="h-4 w-4 text-yellow-500" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-white">{completionRate}%</div>
                    </CardContent>
                </Card>
                <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                    <CardHeader className="flex flex-row items-center justify-between pb-2">
                        <CardTitle className="text-sm font-medium text-muted-foreground">Trend</CardTitle>
                        <TrendingUp className="h-4 w-4 text-blue-500" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold text-white">
                            {runningCompleted > 0 ? 'In Crescita' : 'Stabile'}
                        </div>
                    </CardContent>
                </Card>
            </div>

            {/* Advanced Charts Row 1: Velocity & Radar */}
            <div className="grid gap-4 md:grid-cols-3">
                {/* Goal Velocity */}
                <Card className="md:col-span-2 bg-card/40 border-white/5 backdrop-blur-sm">
                    <CardHeader>
                        <div className="flex items-center gap-2">
                            <Rocket className="w-5 h-5 text-orange-500" />
                            <CardTitle>Velocità di Esecuzione (Cumulativa)</CardTitle>
                        </div>
                        <CardDescription>Confronto tra obiettivi pianificati e completati nel tempo</CardDescription>
                    </CardHeader>
                    <CardContent className="h-[300px] sm:h-[350px]">
                        <ResponsiveContainer width="100%" height="100%">
                            <AreaChart data={monthlyData}>
                                <defs>
                                    <linearGradient id="colorTotal" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="5%" stopColor="#8884d8" stopOpacity={0.3} />
                                        <stop offset="95%" stopColor="#8884d8" stopOpacity={0} />
                                    </linearGradient>
                                    <linearGradient id="colorCompleted" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="5%" stopColor="#82ca9d" stopOpacity={0.3} />
                                        <stop offset="95%" stopColor="#82ca9d" stopOpacity={0} />
                                    </linearGradient>
                                </defs>
                                <XAxis dataKey="name" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                <YAxis stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                <CartesianGrid strokeDasharray="3 3" stroke="#ffffff10" />
                                <Tooltip
                                    contentStyle={{ backgroundColor: '#1f1f1f', border: '1px solid #333', color: '#fff', borderRadius: '8px' }}
                                    itemStyle={{ color: '#fff' }}
                                />
                                <Area type="monotone" dataKey="cumulativeTotal" stroke="#8884d8" fillOpacity={1} fill="url(#colorTotal)" name="Obiettivi Totali" />
                                <Area type="monotone" dataKey="cumulativeCompleted" stroke="#82ca9d" fillOpacity={1} fill="url(#colorCompleted)" name="Obiettivi Completati" />
                            </AreaChart>
                        </ResponsiveContainer>
                    </CardContent>
                </Card>

                {/* Category Radar */}
                <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                    <CardHeader>
                        <div className="flex items-center gap-2">
                            <Target className="w-5 h-5 text-cyan-500" />
                            <CardTitle>Performance Categorie</CardTitle>
                        </div>
                        <CardDescription>Tasso di successo per categoria</CardDescription>
                    </CardHeader>
                    <CardContent className="h-[300px] sm:h-[350px]">
                        <ResponsiveContainer width="100%" height="100%">
                            <RadarChart cx="50%" cy="50%" outerRadius="65%" data={radarData}>
                                <PolarGrid stroke="#ffffff20" />
                                <PolarAngleAxis
                                    dataKey="subject"
                                    tick={{ fill: '#a1a1aa', fontSize: 13, fontWeight: 500 }}
                                />
                                <PolarRadiusAxis angle={30} domain={[0, 100]} tick={false} axisLine={false} />
                                <Radar
                                    name="Success Rate"
                                    dataKey="A"
                                    stroke="#06b6d4"
                                    fill="#06b6d4"
                                    fillOpacity={0.5}
                                />
                                <Tooltip
                                    contentStyle={{ backgroundColor: '#1f1f1f', border: '1px solid #333', color: '#fff', borderRadius: '8px' }}
                                    itemStyle={{ color: '#fff' }}
                                    formatter={(value: number) => [`${value}%`, 'Successo']}
                                />
                            </RadarChart>
                        </ResponsiveContainer>
                    </CardContent>
                </Card>
            </div>

            {/* Charts Row 2: Monthly & Quarterly Activity */}
            <div className="grid gap-4 md:grid-cols-2">
                {/* Quarterly Activity Breakdown */}
                <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                    <CardHeader>
                        <CardTitle>Attività Trimestrale</CardTitle>
                        <CardDescription>Progressione Q1 - Q4</CardDescription>
                    </CardHeader>
                    <CardContent className="h-[300px]">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={quarterlyData}>
                                <XAxis dataKey="name" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                <YAxis stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                <Tooltip
                                    contentStyle={{ backgroundColor: '#1f1f1f', border: '1px solid #333', color: '#fff', borderRadius: '8px' }}
                                    itemStyle={{ color: '#fff' }}
                                    cursor={{ fill: '#ffffff05' }}
                                />
                                <CartesianGrid stroke="#ffffff10" vertical={false} />
                                <Bar dataKey="total" name="Pianificati" fill="#f59e0b" radius={[4, 4, 0, 0]} barSize={30} fillOpacity={0.7} />
                                <Bar dataKey="completed" name="Completati" fill="#10b981" radius={[4, 4, 0, 0]} barSize={30} />
                            </BarChart>
                        </ResponsiveContainer>
                    </CardContent>
                </Card>

                {/* Monthly Activity Breakdown */}
                <Card className="bg-card/40 border-white/5 backdrop-blur-sm">
                    <CardHeader>
                        <CardTitle>Attività Mensile</CardTitle>
                    </CardHeader>
                    <CardContent className="h-[300px]">
                        <ResponsiveContainer width="100%" height="100%">
                            <ComposedChart data={monthlyData}>
                                <XAxis dataKey="name" stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                <YAxis stroke="#888888" fontSize={12} tickLine={false} axisLine={false} />
                                <Tooltip
                                    contentStyle={{ backgroundColor: '#1f1f1f', border: '1px solid #333', color: '#fff', borderRadius: '8px' }}
                                    itemStyle={{ color: '#fff' }}
                                />
                                <CartesianGrid stroke="#ffffff10" />
                                <Bar dataKey="total" barSize={20} fill="#413ea0" radius={[4, 4, 0, 0]} name="Creati" />
                                <Line type="monotone" dataKey="completed" stroke="#ff7300" strokeWidth={2} name="Completati" />
                            </ComposedChart>
                        </ResponsiveContainer>
                    </CardContent>
                </Card>

                {/* Color Distribution Pie */}
                <Card className="md:col-span-2 bg-card/40 border-white/5 backdrop-blur-sm">
                    <CardHeader>
                        <CardTitle>Distribuzione Categorie</CardTitle>
                    </CardHeader>
                    <CardContent className="h-[300px]">
                        <ResponsiveContainer width="100%" height="100%">
                            <PieChart>
                                <Pie
                                    data={pieData}
                                    cx="50%"
                                    cy="50%"
                                    innerRadius={60}
                                    outerRadius={80}
                                    paddingAngle={5}
                                    dataKey="value"
                                >
                                    {pieData.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={entry.fill} />
                                    ))}
                                </Pie>
                                <Tooltip
                                    contentStyle={{ backgroundColor: '#1f1f1f', border: '1px solid #333', color: '#fff', borderRadius: '8px' }}
                                    itemStyle={{ color: '#fff' }}
                                />
                                <Legend formatter={(value, entry: any) => <span style={{ color: '#ccc' }}>{value}</span>} />
                            </PieChart>
                        </ResponsiveContainer>
                    </CardContent>
                </Card>
            </div>
        </div>
    );
}
