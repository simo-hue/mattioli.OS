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

    // Helper to get semantic background color based on performance
    const getSemanticBackground = (rate: number) => {
        if (rate >= 80) return 'bg-green-500/90';
        if (rate >= 70) return 'bg-lime-500/90';
        if (rate >= 50) return 'bg-yellow-500/90';
        if (rate >= 30) return 'bg-orange-500/90';
        if (rate > 0) return 'bg-red-500/90';
        return 'bg-gray-700/90';
    };

    const getTextColor = (rate: number) => {
        if (rate >= 50) return "text-white font-bold";
        return "text-foreground font-bold";
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
                {/* Desktop View - Matrix */}
                <div className="hidden md:block min-w-[700px]">
                    {/* Header Row */}
                    <div className="grid grid-cols-[minmax(120px,1fr)_3fr_1px_3fr] gap-3 mb-4 pb-3 border-b border-white/10">
                        <div></div>
                        <div className="text-center">
                            <p className="text-sm font-bold text-green-500 mb-2">MOOD</p>
                            <div className="grid grid-cols-3 gap-3">
                                <div className="text-sm text-muted-foreground font-medium">Basso</div>
                                <div className="text-sm text-muted-foreground font-medium">Medio</div>
                                <div className="text-sm text-muted-foreground font-medium">Alto</div>
                            </div>
                        </div>
                        <div className="w-px bg-gradient-to-b from-transparent via-white/20 to-transparent"></div>
                        <div className="text-center">
                            <p className="text-sm font-bold text-amber-500 mb-2">ENERGIA</p>
                            <div className="grid grid-cols-3 gap-3">
                                <div className="text-sm text-muted-foreground font-medium">Bassa</div>
                                <div className="text-sm text-muted-foreground font-medium">Media</div>
                                <div className="text-sm text-muted-foreground font-medium">Alta</div>
                            </div>
                        </div>
                    </div>

                    {/* Data Rows */}
                    <div className="space-y-3">
                        {validCorrelations.map((correlation) => (
                            <div key={correlation.habitId} className="grid grid-cols-[minmax(120px,1fr)_3fr_1px_3fr] gap-3 items-center">
                                <div className="flex items-center gap-2 min-w-0 pr-2">
                                    <div className="w-4 h-4 rounded-md shrink-0" style={{ backgroundColor: correlation.habitColor }} />
                                    <span className="text-sm font-semibold truncate" title={correlation.habitTitle}>{correlation.habitTitle}</span>
                                </div>
                                <div className="grid grid-cols-3 gap-3">
                                    {(['low', 'medium', 'high'] as const).map((range) => {
                                        const rate = Math.round(correlation.completionRateByMood[range]);
                                        return (
                                            <div key={`mood-${range}`} className={cn("rounded-xl p-3 text-center transition-all duration-200 cursor-pointer border-2 border-transparent hover:scale-110 hover:shadow-2xl hover:border-white/30 hover:brightness-110", getSemanticBackground(rate), getTextColor(rate))} title={`${correlation.habitTitle}: ${rate}% con mood ${range === 'low' ? 'basso' : range === 'medium' ? 'medio' : 'alto'}`}>
                                                <span className="text-sm font-bold">{rate}%</span>
                                            </div>
                                        );
                                    })}
                                </div>
                                <div className="w-px bg-gradient-to-b from-transparent via-white/10 to-transparent h-full"></div>
                                <div className="grid grid-cols-3 gap-3">
                                    {(['low', 'medium', 'high'] as const).map((range) => {
                                        const rate = Math.round(correlation.completionRateByEnergy[range]);
                                        return (
                                            <div key={`energy-${range}`} className={cn("rounded-xl p-3 text-center transition-all duration-200 cursor-pointer border-2 border-transparent hover:scale-110 hover:shadow-2xl hover:border-white/30 hover:brightness-110", getSemanticBackground(rate), getTextColor(rate))} title={`${correlation.habitTitle}: ${rate}% con energia ${range === 'low' ? 'bassa' : range === 'medium' ? 'media' : 'alta'}`}>
                                                <span className="text-sm font-bold">{rate}%</span>
                                            </div>
                                        );
                                    })}
                                </div>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Mobile View - Vertical Cards */}
                <div className="md:hidden space-y-4">
                    {validCorrelations.map((correlation) => (
                        <div key={correlation.habitId} className="glass-panel rounded-2xl p-4 border border-white/10">
                            <div className="flex items-center gap-2 mb-4">
                                <div className="w-5 h-5 rounded-md shrink-0" style={{ backgroundColor: correlation.habitColor }} />
                                <h4 className="text-base font-bold">{correlation.habitTitle}</h4>
                            </div>
                            <div className="mb-4">
                                <p className="text-xs font-bold text-green-500 mb-2">MOOD</p>
                                <div className="grid grid-cols-3 gap-2">
                                    {(['low', 'medium', 'high'] as const).map((range) => {
                                        const rate = Math.round(correlation.completionRateByMood[range]);
                                        const label = range === 'low' ? 'Basso' : range === 'medium' ? 'Medio' : 'Alto';
                                        return (
                                            <div key={`mood-${range}`} className="text-center">
                                                <div className={cn("rounded-lg p-3 mb-1", getSemanticBackground(rate), getTextColor(rate))}>
                                                    <span className="text-base font-bold">{rate}%</span>
                                                </div>
                                                <span className="text-xs text-muted-foreground">{label}</span>
                                            </div>
                                        );
                                    })}
                                </div>
                            </div>
                            <div className="h-px bg-gradient-to-r from-transparent via-white/10 to-transparent mb-4"></div>
                            <div>
                                <p className="text-xs font-bold text-amber-500 mb-2">ENERGIA</p>
                                <div className="grid grid-cols-3 gap-2">
                                    {(['low', 'medium', 'high'] as const).map((range) => {
                                        const rate = Math.round(correlation.completionRateByEnergy[range]);
                                        const label = range === 'low' ? 'Bassa' : range === 'medium' ? 'Media' : 'Alta';
                                        return (
                                            <div key={`energy-${range}`} className="text-center">
                                                <div className={cn("rounded-lg p-3 mb-1", getSemanticBackground(rate), getTextColor(rate))}>
                                                    <span className="text-base font-bold">{rate}%</span>
                                                </div>
                                                <span className="text-xs text-muted-foreground">{label}</span>
                                            </div>
                                        );
                                    })}
                                </div>
                            </div>
                        </div>
                    ))}
                </div>

                {/* Legend */}
                <div className="mt-6 pt-4 border-t border-white/10">
                    <div className="flex flex-wrap items-center justify-center gap-4 mb-2">
                        <div className="flex items-center gap-2">
                            <div className="w-6 h-6 rounded bg-green-500/90"></div>
                            <span className="text-xs text-muted-foreground">Ottimo (≥80%)</span>
                        </div>
                        <div className="flex items-center gap-2">
                            <div className="w-6 h-6 rounded bg-lime-500/90"></div>
                            <span className="text-xs text-muted-foreground">Buono (70-79%)</span>
                        </div>
                        <div className="flex items-center gap-2">
                            <div className="w-6 h-6 rounded bg-yellow-500/90"></div>
                            <span className="text-xs text-muted-foreground">Medio (50-69%)</span>
                        </div>
                        <div className="flex items-center gap-2">
                            <div className="w-6 h-6 rounded bg-orange-500/90"></div>
                            <span className="text-xs text-muted-foreground">Basso (30-49%)</span>
                        </div>
                        <div className="flex items-center gap-2">
                            <div className="w-6 h-6 rounded bg-red-500/90"></div>
                            <span className="text-xs text-muted-foreground">Critico (&lt;30%)</span>
                        </div>
                    </div>
                    <p className="text-xs text-muted-foreground text-center">
                        I colori indicano la performance • Passa il mouse per i dettagli
                    </p>
                </div>
            </CardContent>
        </Card>
    );
};
