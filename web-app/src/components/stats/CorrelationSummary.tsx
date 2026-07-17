import { CorrelationInsights } from '@/hooks/useHabitCorrelation';
import { Network, TrendingUp, TrendingDown, Info } from 'lucide-react';
import { cn } from '@/lib/utils';

interface CorrelationSummaryProps {
    insights: CorrelationInsights;
}

export const CorrelationSummary = ({ insights }: CorrelationSummaryProps) => {
    const { totalPairs, avgCorrelation, strongestPositive, strongestNegative, isolatedHabits } = insights;

    if (totalPairs === 0) {
        return (
            <div className="glass-panel rounded-3xl p-6 text-center">
                <Network className="w-12 h-12 mx-auto mb-3 text-muted-foreground opacity-50" />
                <h3 className="text-base font-semibold mb-2">Nessuna Correlazione Rilevata</h3>
                <p className="text-sm text-muted-foreground">
                    Traccia almeno 2 abitudini per 10+ giorni per vedere le correlazioni.
                </p>
            </div>
        );
    }

    return (
        <div className="glass-panel rounded-3xl p-4 sm:p-6">
            <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500/20 to-purple-500/20 flex items-center justify-center">
                    <Network className="w-5 h-5 text-blue-500" />
                </div>
                <div>
                    <h3 className="text-base sm:text-lg font-display font-semibold">Analisi Correlazioni</h3>
                    <p className="text-xs sm:text-sm text-muted-foreground">
                        Pattern tra le tue abitudini
                    </p>
                </div>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-4">
                <div className="bg-white/5 rounded-xl p-3 text-center">
                    <p className="text-xs text-muted-foreground mb-1">Coppie Analizzate</p>
                    <p className="text-2xl font-bold text-foreground font-mono">{totalPairs}</p>
                </div>

                <div className="bg-white/5 rounded-xl p-3 text-center">
                    <p className="text-xs text-muted-foreground mb-1">Correlazione Media</p>
                    <p className="text-2xl font-bold text-primary font-mono">
                        {avgCorrelation >= 0 ? '+' : ''}{avgCorrelation.toFixed(2)}
                    </p>
                </div>

                <div className="bg-white/5 rounded-xl p-3 text-center">
                    <div className="flex items-center justify-center gap-1 mb-1">
                        <TrendingUp className="w-3 h-3 text-green-500" />
                        <p className="text-xs text-muted-foreground">Positive</p>
                    </div>
                    <p className="text-2xl font-bold text-green-500 font-mono">{strongestPositive.length}</p>
                </div>

                <div className="bg-white/5 rounded-xl p-3 text-center">
                    <div className="flex items-center justify-center gap-1 mb-1">
                        <TrendingDown className="w-3 h-3 text-red-500" />
                        <p className="text-xs text-muted-foreground">Negative</p>
                    </div>
                    <p className="text-2xl font-bold text-red-500 font-mono">{strongestNegative.length}</p>
                </div>
            </div>

            {/* Info Alert */}
            {isolatedHabits.length > 0 && (
                <div className="bg-yellow-500/5 border border-yellow-500/20 rounded-xl p-3">
                    <div className="flex items-start gap-2">
                        <Info className="w-4 h-4 text-yellow-500 shrink-0 mt-0.5" />
                        <div>
                            <p className="text-xs font-semibold text-yellow-500 mb-1">Abitudini Isolate</p>
                            <p className="text-xs text-muted-foreground">
                                {isolatedHabits.length} {isolatedHabits.length === 1 ? 'abitudine non ha' : 'abitudini non hanno'}
                                {' '}correlazioni significative con le altre. Potrebbero essere indipendenti o necessitare più dati.
                            </p>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
