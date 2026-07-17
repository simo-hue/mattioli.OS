import {
    ComposedChart,
    Line,
    Bar,
    XAxis,
    YAxis,
    CartesianGrid,
    Tooltip,
    Legend,
    ResponsiveContainer,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { HabitMoodCorrelation } from "@/hooks/useHabitMoodCorrelation";
import { useTheme } from "next-themes";
import { Sparkles, TrendingUp, TrendingDown, Minus } from "lucide-react";

interface HabitMoodCorrelationChartProps {
    correlation: HabitMoodCorrelation;
}

export const HabitMoodCorrelationChart = ({ correlation }: HabitMoodCorrelationChartProps) => {
    const { theme } = useTheme();
    const isDark = theme === "dark";

    // Prepare data for the chart
    const averagesData = [
        {
            category: "Completato",
            mood: Math.round(correlation.avgMoodWhenCompleted * 10) / 10,
            energy: Math.round(correlation.avgEnergyWhenCompleted * 10) / 10,
        },
        {
            category: "Mancato",
            mood: Math.round(correlation.avgMoodWhenMissed * 10) / 10,
            energy: Math.round(correlation.avgEnergyWhenMissed * 10) / 10,
        },
    ];

    const rangeData = [
        {
            range: "Basso",
            rangeFull: "Basso (1-4)",
            mood: Math.round(correlation.completionRateByMood.low),
            energy: Math.round(correlation.completionRateByEnergy.low),
        },
        {
            range: "Medio",
            rangeFull: "Medio (5-7)",
            mood: Math.round(correlation.completionRateByMood.medium),
            energy: Math.round(correlation.completionRateByEnergy.medium),
        },
        {
            range: "Alto",
            rangeFull: "Alto (8-10)",
            mood: Math.round(correlation.completionRateByMood.high),
            energy: Math.round(correlation.completionRateByEnergy.high),
        },
    ];

    // Determine correlation strength icons
    const getMoodCorrelationIcon = () => {
        if (correlation.moodCorrelation > 0.3) return <TrendingUp className="w-4 h-4 text-green-500" />;
        if (correlation.moodCorrelation < -0.3) return <TrendingDown className="w-4 h-4 text-red-500" />;
        return <Minus className="w-4 h-4 text-gray-500" />;
    };

    const getEnergyCorrelationIcon = () => {
        if (correlation.energyCorrelation > 0.3) return <TrendingUp className="w-4 h-4 text-green-500" />;
        if (correlation.energyCorrelation < -0.3) return <TrendingDown className="w-4 h-4 text-red-500" />;
        return <Minus className="w-4 h-4 text-gray-500" />;
    };

    const getCorrelationStrength = (value: number) => {
        const abs = Math.abs(value);
        if (abs >= 0.7) return "Forte";
        if (abs >= 0.4) return "Moderata";
        if (abs >= 0.2) return "Debole";
        return "Nessuna";
    };

    return (
        <div className="space-y-4">
            {/* Overview Cards */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                <Card className="glass-panel">
                    <CardContent className="p-4 text-center">
                        <p className="text-xs text-muted-foreground mb-1">Correlazione Mood</p>
                        <div className="flex items-center justify-center gap-2 mb-1">
                            {getMoodCorrelationIcon()}
                            <p className="text-2xl font-bold font-mono">
                                {(correlation.moodCorrelation * 100).toFixed(0)}%
                            </p>
                        </div>
                        <p className="text-xs text-muted-foreground">{getCorrelationStrength(correlation.moodCorrelation)}</p>
                    </CardContent>
                </Card>

                <Card className="glass-panel">
                    <CardContent className="p-4 text-center">
                        <p className="text-xs text-muted-foreground mb-1">Correlazione Energia</p>
                        <div className="flex items-center justify-center gap-2 mb-1">
                            {getEnergyCorrelationIcon()}
                            <p className="text-2xl font-bold font-mono">
                                {(correlation.energyCorrelation * 100).toFixed(0)}%
                            </p>
                        </div>
                        <p className="text-xs text-muted-foreground">{getCorrelationStrength(correlation.energyCorrelation)}</p>
                    </CardContent>
                </Card>

                <Card className="glass-panel">
                    <CardContent className="p-4 text-center">
                        <p className="text-xs text-muted-foreground mb-1">Mood Medio (✓)</p>
                        <p className="text-2xl font-bold" style={{ color: correlation.habitColor }}>
                            {correlation.avgMoodWhenCompleted.toFixed(1)}
                        </p>
                        <p className="text-xs text-muted-foreground">su 10</p>
                    </CardContent>
                </Card>

                <Card className="glass-panel">
                    <CardContent className="p-4 text-center">
                        <p className="text-xs text-muted-foreground mb-1">Energia Media (✓)</p>
                        <p className="text-2xl font-bold" style={{ color: correlation.habitColor }}>
                            {correlation.avgEnergyWhenCompleted.toFixed(1)}
                        </p>
                        <p className="text-xs text-muted-foreground">su 10</p>
                    </CardContent>
                </Card>
            </div>

            {/* Classification Badges */}
            <div className="flex flex-wrap gap-2">
                {correlation.isMoodSensitive && (
                    <div className="glass-panel px-3 py-1.5 rounded-full flex items-center gap-2 border border-orange-500/30">
                        <Sparkles className="w-3 h-3 text-orange-500" />
                        <span className="text-xs font-medium text-orange-500">Sensibile al Mood</span>
                    </div>
                )}
                {correlation.isEnergySensitive && (
                    <div className="glass-panel px-3 py-1.5 rounded-full flex items-center gap-2 border border-yellow-500/30">
                        <Sparkles className="w-3 h-3 text-yellow-500" />
                        <span className="text-xs font-medium text-yellow-500">Sensibile all'Energia</span>
                    </div>
                )}
                {correlation.isResilient && (
                    <div className="glass-panel px-3 py-1.5 rounded-full flex items-center gap-2 border border-green-500/30">
                        <TrendingUp className="w-3 h-3 text-green-500" />
                        <span className="text-xs font-medium text-green-500">Resiliente</span>
                    </div>
                )}
                {!correlation.isMoodSensitive && !correlation.isEnergySensitive && !correlation.isResilient && (
                    <div className="glass-panel px-3 py-1.5 rounded-full flex items-center gap-2 border border-gray-500/30">
                        <Minus className="w-3 h-3 text-gray-500" />
                        <span className="text-xs font-medium text-gray-500">Neutrale</span>
                    </div>
                )}
            </div>

            {/* Chart 1: Average Mood/Energy when Completed vs Missed */}
            <Card className="glass-panel shadow-lg hover:shadow-xl transition-shadow duration-300">
                <CardHeader>
                    <CardTitle className="text-base sm:text-lg">Completato vs Mancato</CardTitle>
                </CardHeader>
                <CardContent className="h-[300px]">
                    <ResponsiveContainer width="100%" height="100%">
                        <ComposedChart data={averagesData}>
                            <CartesianGrid strokeDasharray="3 3" opacity={0.2} vertical={false} />
                            <XAxis
                                dataKey="category"
                                tick={{ fontSize: 12, fill: isDark ? "#A0A0A0" : "#666" }}
                                axisLine={false}
                                tickLine={false}
                            />
                            <YAxis
                                domain={[0, 10]}
                                tick={{ fontSize: 12, fill: isDark ? "#A0A0A0" : "#666" }}
                                axisLine={false}
                                tickLine={false}
                                label={{
                                    value: "Score (1-10)",
                                    angle: -90,
                                    position: "insideLeft",
                                    style: { fill: isDark ? "#A0A0A0" : "#666" },
                                }}
                            />
                            <Tooltip
                                contentStyle={{
                                    backgroundColor: isDark ? "#1f2937" : "#fff",
                                    borderRadius: "12px",
                                    border: "none",
                                    boxShadow: "0 10px 15px -3px rgba(0, 0, 0, 0.1)",
                                }}
                            />
                            <Legend wrapperStyle={{ paddingTop: "10px" }} />
                            <Bar dataKey="mood" fill="#10b981" name="Mood" radius={[8, 8, 0, 0]} />
                            <Bar dataKey="energy" fill="#f59e0b" name="Energia" radius={[8, 8, 0, 0]} />
                        </ComposedChart>
                    </ResponsiveContainer>
                </CardContent>
            </Card>

            {/* Chart 2: Completion Rate by Mood/Energy Range */}
            <Card className="glass-panel shadow-lg hover:shadow-xl transition-shadow duration-300">
                <CardHeader>
                    <CardTitle className="text-base sm:text-lg">Performance per Livello</CardTitle>
                    <p className="text-xs text-muted-foreground mt-1">
                        Basso (1-4) • Medio (5-7) • Alto (8-10)
                    </p>
                </CardHeader>
                <CardContent className="h-[320px]">
                    <ResponsiveContainer width="100%" height="100%">
                        <ComposedChart data={rangeData} margin={{ top: 10, right: 20, bottom: 20, left: 0 }}>
                            <CartesianGrid strokeDasharray="3 3" opacity={0.2} vertical={false} />
                            <XAxis
                                dataKey="range"
                                tick={{ fontSize: 12, fill: isDark ? "#A0A0A0" : "#666" }}
                                axisLine={false}
                                tickLine={false}
                            />
                            <YAxis
                                domain={[0, 100]}
                                tick={{ fontSize: 12, fill: isDark ? "#A0A0A0" : "#666" }}
                                axisLine={false}
                                tickLine={false}
                                unit="%"
                            />
                            <Tooltip
                                contentStyle={{
                                    backgroundColor: isDark ? "#1f2937" : "#fff",
                                    borderRadius: "12px",
                                    border: "none",
                                    boxShadow: "0 10px 15px -3px rgba(0, 0, 0, 0.1)",
                                }}
                                formatter={(value: number, name: string, props: any) => {
                                    return [`${value}%`, name === "mood" ? "Con Mood" : "Con Energia"];
                                }}
                                labelFormatter={(label: string) => {
                                    const item = rangeData.find(d => d.range === label);
                                    return item ? item.rangeFull : label;
                                }}
                            />
                            <Legend wrapperStyle={{ paddingTop: "10px" }} />
                            <Line
                                type="monotone"
                                dataKey="mood"
                                stroke="#10b981"
                                strokeWidth={3}
                                dot={{ r: 5, strokeWidth: 2 }}
                                activeDot={{ r: 7 }}
                                name="Con Mood"
                            />
                            <Line
                                type="monotone"
                                dataKey="energy"
                                stroke="#f59e0b"
                                strokeWidth={3}
                                strokeDasharray="5 5"
                                dot={{ r: 5, strokeWidth: 2 }}
                                activeDot={{ r: 7 }}
                                name="Con Energia"
                            />
                        </ComposedChart>
                    </ResponsiveContainer>
                </CardContent>
            </Card>

            {/* Data Info */}
            <Card className="glass-panel">
                <CardContent className="p-4">
                    <p className="text-xs text-muted-foreground text-center">
                        Analisi basata su <strong>{correlation.totalDaysWithMoodData}</strong> giorni con dati mood/energia
                        ({correlation.daysCompleted} completati, {correlation.daysMissed} mancati)
                    </p>
                </CardContent>
            </Card>
        </div>
    );
};
