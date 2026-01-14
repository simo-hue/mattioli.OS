import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { HabitMoodCorrelation } from "@/hooks/useHabitMoodCorrelation";
import { cn } from "@/lib/utils";

interface MoodEnergyHabitMatrixProps {
    correlations: HabitMoodCorrelation[];
}

export const MoodEnergyHabitMatrix = ({ correlations }: MoodEnergyHabitMatrixProps) => {
    // Filter out habits with insufficient data
    const validCorrelations = correlations.filter(c => c.totalDaysWithMoodData >= 5);

    if (validCorrelations.length === 0) {
        return (
            <Card className="glass-panel">
                <CardContent className="p-8 text-center">
                    <p className="text-muted-foreground">
                        Non ci sono abbastanza dati per mostrare la matrice. Registra mood ed energie per almeno 5 giorni.
                    </p>
                </CardContent>
            </Card>
        );
    }

    // Helper to get color intensity based on completion rate
    const getColorIntensity = (rate: number, baseColor: string) => {
        if (rate >= 80) return `${baseColor}90`; // Strong
        if (rate >= 60) return `${baseColor}70`; // Medium-strong
        if (rate >= 40) return `${baseColor}50`; // Medium
        if (rate >= 20) return `${baseColor}30`; // Weak
        return `${baseColor}10`; // Very weak
    };

    const getTextColor = (rate: number) => {
        if (rate >= 60) return "text-white";
        return "text-foreground";
    };

    return (
        <Card className="glass-panel shadow-lg hover:shadow-xl transition-shadow duration-300">
            <CardHeader>
                <CardTitle className="text-base sm:text-lg">Performance per Livello</CardTitle>
                <p className="text-sm text-muted-foreground">
                    Completamento (%) per mood ed energia
                </p>
            </CardHeader>
            <CardContent className="overflow-x-auto">
                <div className="min-w-[600px]">
                    {/* Header Row */}
                    <div className="grid grid-cols-7 gap-2 mb-2">
                        <div className="col-span-1"></div>
                        <div className="col-span-3 text-center">
                            <p className="text-xs font-bold text-green-500 mb-1">MOOD</p>
                            <div className="grid grid-cols-3 gap-2">
                                <div className="text-xs text-muted-foreground">Basso</div>
                                <div className="text-xs text-muted-foreground">Medio</div>
                                <div className="text-xs text-muted-foreground">Alto</div>
                            </div>
                        </div>
                        <div className="col-span-3 text-center">
                            <p className="text-xs font-bold text-amber-500 mb-1">ENERGIA</p>
                            <div className="grid grid-cols-3 gap-2">
                                <div className="text-xs text-muted-foreground">Bassa</div>
                                <div className="text-xs text-muted-foreground">Media</div>
                                <div className="text-xs text-muted-foreground">Alta</div>
                            </div>
                        </div>
                    </div>

                    {/* Data Rows */}
                    <div className="space-y-2">
                        {validCorrelations.map((correlation) => (
                            <div key={correlation.habitId} className="grid grid-cols-7 gap-2 items-center">
                                {/* Habit Name */}
                                <div className="col-span-1 flex items-center gap-2 min-w-0">
                                    <div
                                        className="w-3 h-3 rounded-sm shrink-0"
                                        style={{ backgroundColor: correlation.habitColor }}
                                    />
                                    <span className="text-xs font-medium truncate" title={correlation.habitTitle}>
                                        {correlation.habitTitle}
                                    </span>
                                </div>

                                {/* Mood Cells */}
                                <div className="col-span-3 grid grid-cols-3 gap-2">
                                    {['low', 'medium', 'high'].map((range) => {
                                        const rate = Math.round(
                                            correlation.completionRateByMood[range as keyof typeof correlation.completionRateByMood]
                                        );
                                        return (
                                            <div
                                                key={`mood-${range}`}
                                                className={cn(
                                                    "rounded-lg p-2 text-center transition-all duration-200 hover:scale-105",
                                                    getTextColor(rate)
                                                )}
                                                style={{
                                                    backgroundColor: getColorIntensity(rate, correlation.habitColor),
                                                }}
                                                title={`${rate}% completamento con mood ${range}`}
                                            >
                                                <span className="text-xs font-bold">{rate}%</span>
                                            </div>
                                        );
                                    })}
                                </div>

                                {/* Energy Cells */}
                                <div className="col-span-3 grid grid-cols-3 gap-2">
                                    {['low', 'medium', 'high'].map((range) => {
                                        const rate = Math.round(
                                            correlation.completionRateByEnergy[range as keyof typeof correlation.completionRateByEnergy]
                                        );
                                        return (
                                            <div
                                                key={`energy-${range}`}
                                                className={cn(
                                                    "rounded-lg p-2 text-center transition-all duration-200 hover:scale-105",
                                                    getTextColor(rate)
                                                )}
                                                style={{
                                                    backgroundColor: getColorIntensity(rate, correlation.habitColor),
                                                }}
                                                title={`${rate}% completamento con energia ${range}`}
                                            >
                                                <span className="text-xs font-bold">{rate}%</span>
                                            </div>
                                        );
                                    })}
                                </div>
                            </div>
                        ))}
                    </div>

                    {/* Legend */}
                    <div className="mt-4 pt-4 border-t border-white/10">
                        <p className="text-xs text-muted-foreground text-center">
                            Intensità colore = tasso completamento più alto • Passa il mouse sulle celle per i dettagli
                        </p>
                    </div>
                </div>
            </CardContent>
        </Card>
    );
};
