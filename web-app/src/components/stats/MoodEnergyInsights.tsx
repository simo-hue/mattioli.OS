import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { MoodEnergyInsights as MoodEnergyInsightsType } from "@/hooks/useHabitMoodCorrelation";
import { Sparkles, Shield, TrendingUp, TrendingDown, Zap, Frown, Smile, Battery, BatteryLow } from "lucide-react";

interface MoodEnergyInsightsProps {
    insights: MoodEnergyInsightsType;
}

export const MoodEnergyInsights = ({ insights }: MoodEnergyInsightsProps) => {
    const hasAnyInsights =
        insights.moodSensitiveHabits.length > 0 ||
        insights.energySensitiveHabits.length > 0 ||
        insights.resilientHabits.length > 0;

    if (!hasAnyInsights) {
        return (
            <Card className="glass-panel">
                <CardContent className="p-8 text-center">
                    <p className="text-muted-foreground">
                        Non ci sono abbastanza dati per generare insights. Continua a tracciare le tue abitudini e il tuo mood!
                    </p>
                </CardContent>
            </Card>
        );
    }

    return (
        <div className="space-y-4">
            {/* Mood-Sensitive Habits */}
            {insights.moodSensitiveHabits.length > 0 && (
                <Card className="glass-panel border border-orange-500/30 shadow-lg hover:shadow-xl transition-shadow duration-300">
                    <CardHeader>
                        <CardTitle className="text-base sm:text-lg flex items-center gap-2">
                            <Sparkles className="w-5 h-5 text-orange-500" />
                            Mood
                        </CardTitle>
                        <p className="text-sm text-muted-foreground">
                            Queste abitudini hanno bisogno di un buon mood per essere completate
                        </p>
                    </CardHeader>
                    <CardContent className="space-y-3">
                        {insights.moodSensitiveHabits.map((habit, index) => (
                            <div
                                key={habit.habitId}
                                className="glass-card rounded-xl p-3 flex items-center justify-between hover:bg-white/5 transition-colors"
                            >
                                <div className="flex items-center gap-3">
                                    <div
                                        className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0"
                                        style={{
                                            backgroundColor: `${habit.habitColor}20`,
                                            borderColor: `${habit.habitColor}40`,
                                            borderWidth: "2px",
                                        }}
                                    >
                                        <div
                                            className="w-3 h-3 rounded-sm"
                                            style={{ backgroundColor: habit.habitColor }}
                                        />
                                    </div>
                                    <div>
                                        <p className="font-semibold text-sm">{habit.habitTitle}</p>
                                        <div className="flex items-center gap-2 text-xs text-muted-foreground">
                                            <Frown className="w-3 h-3" />
                                            <span>{Math.round(habit.completionRateByMood.low)}% con mood basso</span>
                                            <Smile className="w-3 h-3 ml-2" />
                                            <span>{Math.round(habit.completionRateByMood.high)}% con mood alto</span>
                                        </div>
                                    </div>
                                </div>
                                <div className="text-right">
                                    <p className="text-xs text-muted-foreground">Drop</p>
                                    <p className="text-lg font-bold text-orange-500">
                                        {Math.round(habit.completionRateByMood.high - habit.completionRateByMood.low)}%
                                    </p>
                                </div>
                            </div>
                        ))}
                    </CardContent>
                </Card>
            )}

            {/* Energy-Sensitive Habits */}
            {insights.energySensitiveHabits.length > 0 && (
                <Card className="glass-panel border border-yellow-500/30 shadow-lg hover:shadow-xl transition-shadow duration-300">
                    <CardHeader>
                        <CardTitle className="text-base sm:text-lg flex items-center gap-2">
                            <Zap className="w-5 h-5 text-yellow-500" />
                            Energia
                        </CardTitle>
                        <p className="text-sm text-muted-foreground">
                            Queste abitudini richiedono alta energia per essere completate
                        </p>
                    </CardHeader>
                    <CardContent className="space-y-3">
                        {insights.energySensitiveHabits.map((habit, index) => (
                            <div
                                key={habit.habitId}
                                className="glass-card rounded-xl p-3 flex items-center justify-between hover:bg-white/5 transition-colors"
                            >
                                <div className="flex items-center gap-3">
                                    <div
                                        className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0"
                                        style={{
                                            backgroundColor: `${habit.habitColor}20`,
                                            borderColor: `${habit.habitColor}40`,
                                            borderWidth: "2px",
                                        }}
                                    >
                                        <div
                                            className="w-3 h-3 rounded-sm"
                                            style={{ backgroundColor: habit.habitColor }}
                                        />
                                    </div>
                                    <div>
                                        <p className="font-semibold text-sm">{habit.habitTitle}</p>
                                        <div className="flex items-center gap-2 text-xs text-muted-foreground">
                                            <BatteryLow className="w-3 h-3" />
                                            <span>{Math.round(habit.completionRateByEnergy.low)}% con energia bassa</span>
                                            <Battery className="w-3 h-3 ml-2" />
                                            <span>{Math.round(habit.completionRateByEnergy.high)}% con energia alta</span>
                                        </div>
                                    </div>
                                </div>
                                <div className="text-right">
                                    <p className="text-xs text-muted-foreground">Drop</p>
                                    <p className="text-lg font-bold text-yellow-500">
                                        {Math.round(habit.completionRateByEnergy.high - habit.completionRateByEnergy.low)}%
                                    </p>
                                </div>
                            </div>
                        ))}
                    </CardContent>
                </Card>
            )}

            {/* Resilient Habits */}
            {insights.resilientHabits.length > 0 && (
                <Card className="glass-panel border border-green-500/30 shadow-lg hover:shadow-xl transition-shadow duration-300">
                    <CardHeader>
                        <CardTitle className="text-base sm:text-lg flex items-center gap-2">
                            <Shield className="w-5 h-5 text-green-500" />
                            Resilienti
                        </CardTitle>
                        <p className="text-sm text-muted-foreground">
                            Queste abitudini vengono mantenute anche quando mood ed energia sono bassi
                        </p>
                    </CardHeader>
                    <CardContent className="space-y-3">
                        {insights.resilientHabits.map((habit, index) => (
                            <div
                                key={habit.habitId}
                                className="glass-card rounded-xl p-3 flex items-center justify-between hover:bg-white/5 transition-colors"
                            >
                                <div className="flex items-center gap-3">
                                    <div
                                        className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0"
                                        style={{
                                            backgroundColor: `${habit.habitColor}20`,
                                            borderColor: `${habit.habitColor}40`,
                                            borderWidth: "2px",
                                        }}
                                    >
                                        <div
                                            className="w-3 h-3 rounded-sm"
                                            style={{ backgroundColor: habit.habitColor }}
                                        />
                                    </div>
                                    <div>
                                        <p className="font-semibold text-sm">{habit.habitTitle}</p>
                                        <div className="flex items-center gap-3 text-xs text-muted-foreground">
                                            <div className="flex items-center gap-1">
                                                <Frown className="w-3 h-3" />
                                                <span>Mood: {Math.round(habit.completionRateByMood.low)}%</span>
                                            </div>
                                            <div className="flex items-center gap-1">
                                                <BatteryLow className="w-3 h-3" />
                                                <span>Energia: {Math.round(habit.completionRateByEnergy.low)}%</span>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <div className="flex items-center gap-1 text-green-500">
                                    <TrendingUp className="w-5 h-5" />
                                    <span className="text-xs font-bold">Stabile</span>
                                </div>
                            </div>
                        ))}
                    </CardContent>
                </Card>
            )}

            {/* Quick Tips */}
            <Card className="glass-panel border border-primary/30">
                <CardHeader>
                    <CardTitle className="text-base sm:text-lg">💡 Suggerimenti</CardTitle>
                </CardHeader>
                <CardContent>
                    <ul className="space-y-2 text-sm text-muted-foreground">
                        {insights.moodSensitiveHabits.length > 0 && (
                            <li className="flex items-start gap-2">
                                <span className="text-orange-500 shrink-0">•</span>
                                <span>
                                    Pianifica le abitudini sensibili al mood nei momenti della giornata in cui ti senti meglio
                                </span>
                            </li>
                        )}
                        {insights.energySensitiveHabits.length > 0 && (
                            <li className="flex items-start gap-2">
                                <span className="text-yellow-500 shrink-0">•</span>
                                <span>
                                    Esegui le abitudini che richiedono energia al mattino o dopo una pausa rigenerante
                                </span>
                            </li>
                        )}
                        {insights.resilientHabits.length > 0 && (
                            <li className="flex items-start gap-2">
                                <span className="text-green-500 shrink-0">•</span>
                                <span>
                                    Le abitudini resilienti sono ottime da mantenere anche nei giorni difficili
                                </span>
                            </li>
                        )}
                        <li className="flex items-start gap-2">
                            <span className="text-primary shrink-0">•</span>
                            <span>
                                Monitora il tuo mood ed energia quotidianamente per ottenere insights più accurati
                            </span>
                        </li>
                    </ul>
                </CardContent>
            </Card>
        </div>
    );
};
