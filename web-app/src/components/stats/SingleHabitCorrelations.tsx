import { HabitPairCorrelation } from '@/hooks/useHabitCorrelation';
import { TrendingUp, TrendingDown, Link2, AlertCircle } from 'lucide-react';
import { cn } from '@/lib/utils';

interface SingleHabitCorrelationsProps {
    habitId: string;
    habitTitle: string;
    habitColor: string;
    allCorrelations: HabitPairCorrelation[];
}

export const SingleHabitCorrelations = ({
    habitId,
    habitTitle,
    habitColor,
    allCorrelations
}: SingleHabitCorrelationsProps) => {
    // Filter correlations relevant to this habit
    const relevantCorrelations = allCorrelations.filter(
        corr => corr.habitA.id === habitId || corr.habitB.id === habitId
    );

    if (relevantCorrelations.length === 0) {
        return (
            <div className="glass-panel rounded-3xl p-6 text-center">
                <Link2 className="w-12 h-12 mx-auto mb-3 text-muted-foreground opacity-50" />
                <h3 className="text-base font-semibold mb-2">Nessuna Correlazione</h3>
                <p className="text-sm text-muted-foreground">
                    Questa abitudine non ha correlazioni significative con le altre.
                    Traccia più abitudini insieme per vedere i pattern.
                </p>
            </div>
        );
    }

    // Separate positive and negative
    const positive = relevantCorrelations
        .filter(c => c.type === 'positive')
        .sort((a, b) => Math.abs(b.correlationCoefficient) - Math.abs(a.correlationCoefficient))
        .slice(0, 3); // Top 3

    const negative = relevantCorrelations
        .filter(c => c.type === 'negative')
        .sort((a, b) => Math.abs(b.correlationCoefficient) - Math.abs(a.correlationCoefficient))
        .slice(0, 2); // Top 2

    // Helper to get the "other" habit in the correlation
    const getOtherHabit = (corr: HabitPairCorrelation) => {
        return corr.habitA.id === habitId ? corr.habitB : corr.habitA;
    };

    return (
        <div className="glass-panel rounded-3xl p-4 sm:p-6">
            <div className="mb-4">
                <h3 className="text-base sm:text-lg font-display font-semibold mb-1">
                    Correlazioni con "{habitTitle}"
                </h3>
                <p className="text-xs sm:text-sm text-muted-foreground">
                    Come questa abitudine si relaziona con le altre
                </p>
            </div>

            {/* Positive Correlations */}
            {positive.length > 0 && (
                <div className="mb-4">
                    <div className="flex items-center gap-2 mb-3">
                        <TrendingUp className="w-4 h-4 text-green-500" />
                        <h4 className="text-sm font-semibold text-green-500">
                            Correlazioni Positive
                        </h4>
                    </div>
                    <div className="space-y-2">
                        {positive.map((corr, i) => {
                            const otherHabit = getOtherHabit(corr);
                            const strength = corr.strength === 'strong' ? 'Forte' : 'Moderata';

                            return (
                                <div
                                    key={i}
                                    className="bg-gradient-to-br from-green-500/5 to-transparent border-2 border-green-500/20 rounded-xl p-3"
                                >
                                    <div className="flex items-center gap-3 mb-2">
                                        <div
                                            className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0"
                                            style={{ backgroundColor: `${otherHabit.color}20` }}
                                        >
                                            <div
                                                className="w-3 h-3 rounded-sm"
                                                style={{ backgroundColor: otherHabit.color }}
                                            />
                                        </div>
                                        <div className="flex-1 min-w-0">
                                            <p className="font-semibold text-sm truncate">{otherHabit.title}</p>
                                            <div className="flex items-center gap-2 text-xs text-muted-foreground">
                                                <span className="text-green-500 font-semibold">
                                                    {strength} ({corr.correlationCoefficient >= 0 ? '+' : ''}{corr.correlationCoefficient.toFixed(2)})
                                                </span>
                                                <span>•</span>
                                                <span>{Math.round(corr.coOccurrenceRate)}% insieme</span>
                                            </div>
                                        </div>
                                    </div>
                                    <p className="text-xs text-muted-foreground leading-relaxed">
                                        {corr.suggestion}
                                    </p>
                                </div>
                            );
                        })}
                    </div>
                </div>
            )}

            {/* Negative Correlations */}
            {negative.length > 0 && (
                <div>
                    <div className="flex items-center gap-2 mb-3">
                        <TrendingDown className="w-4 h-4 text-red-500" />
                        <h4 className="text-sm font-semibold text-red-500">
                            Correlazioni Negative
                        </h4>
                    </div>
                    <div className="space-y-2">
                        {negative.map((corr, i) => {
                            const otherHabit = getOtherHabit(corr);
                            const strength = corr.strength === 'strong' ? 'Forte' : 'Moderata';

                            return (
                                <div
                                    key={i}
                                    className="bg-gradient-to-br from-red-500/5 to-transparent border-2 border-red-500/20 rounded-xl p-3"
                                >
                                    <div className="flex items-center gap-3 mb-2">
                                        <div
                                            className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0"
                                            style={{ backgroundColor: `${otherHabit.color}20` }}
                                        >
                                            <div
                                                className="w-3 h-3 rounded-sm"
                                                style={{ backgroundColor: otherHabit.color }}
                                            />
                                        </div>
                                        <div className="flex-1 min-w-0">
                                            <p className="font-semibold text-sm truncate">{otherHabit.title}</p>
                                            <div className="flex items-center gap-2 text-xs text-muted-foreground">
                                                <span className="text-red-500 font-semibold">
                                                    {strength} ({corr.correlationCoefficient.toFixed(2)})
                                                </span>
                                                <span>•</span>
                                                <span>{corr.totalDaysTracked} giorni</span>
                                            </div>
                                        </div>
                                    </div>
                                    <p className="text-xs text-muted-foreground leading-relaxed">
                                        {corr.suggestion}
                                    </p>
                                </div>
                            );
                        })}
                    </div>
                </div>
            )}

            {/* Info Footer */}
            {(positive.length > 0 || negative.length > 0) && (
                <div className="mt-4 p-3 bg-blue-500/5 rounded-xl border border-blue-500/10">
                    <div className="flex items-start gap-2">
                        <AlertCircle className="w-4 h-4 text-blue-500 shrink-0 mt-0.5" />
                        <p className="text-xs text-muted-foreground">
                            Le correlazioni positive suggeriscono abitudini che funzionano bene insieme.
                            Le negative indicano possibili conflitti di tempo o energia.
                        </p>
                    </div>
                </div>
            )}
        </div>
    );
};
