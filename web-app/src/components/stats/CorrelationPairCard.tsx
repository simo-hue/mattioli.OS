import { HabitPairCorrelation } from '@/hooks/useHabitCorrelation';
import { TrendingUp, TrendingDown, Link2, ChevronRight } from 'lucide-react';
import { cn } from '@/lib/utils';

interface CorrelationPairCardProps {
    correlation: HabitPairCorrelation;
}

export const CorrelationPairCard = ({ correlation }: CorrelationPairCardProps) => {
    const { habitA, habitB, correlationCoefficient, coOccurrenceRate, totalDaysTracked, strength, type, suggestion } = correlation;

    // Determine colors and icons based on correlation type
    const isPositive = type === 'positive';
    const Icon = isPositive ? TrendingUp : TrendingDown;

    const borderColor = isPositive
        ? strength === 'strong' ? 'border-green-500/40' : 'border-green-500/20'
        : strength === 'strong' ? 'border-red-500/40' : 'border-red-500/20';

    const bgGradient = isPositive
        ? 'from-green-500/5 to-transparent'
        : 'from-red-500/5 to-transparent';

    const badgeColor = isPositive
        ? 'bg-green-500/20 text-green-400 border-green-500/30'
        : 'bg-red-500/20 text-red-400 border-red-500/30';

    const strengthLabel =
        strength === 'strong' ? 'Forte' :
            strength === 'moderate' ? 'Moderata' :
                'Debole';

    const typeLabel = isPositive ? 'Positiva' : 'Negativa';

    return (
        <div className={cn(
            "glass-card rounded-2xl p-4 border-2 transition-all duration-300 hover:scale-[1.01]",
            "bg-gradient-to-br",
            borderColor,
            bgGradient
        )}>
            {/* Header */}
            <div className="flex items-center justify-between mb-3">
                <div className={cn(
                    "flex items-center gap-2 px-3 py-1 rounded-full border text-xs font-semibold",
                    badgeColor
                )}>
                    <Icon className="w-3 h-3" />
                    <span>Correlazione {typeLabel} - {strengthLabel}</span>
                </div>
            </div>

            {/* Habit Pair */}
            <div className="flex items-center gap-3 mb-4">
                {/* Habit A */}
                <div className="flex items-center gap-2 flex-1">
                    <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
                        style={{ backgroundColor: `${habitA.color}20` }}
                    >
                        <div
                            className="w-4 h-4 rounded-sm"
                            style={{ backgroundColor: habitA.color }}
                        />
                    </div>
                    <span className="font-semibold text-foreground text-sm truncate">
                        {habitA.title}
                    </span>
                </div>

                {/* Connector */}
                <Link2 className={cn(
                    "w-5 h-5 shrink-0",
                    isPositive ? "text-green-500" : "text-red-500"
                )} />

                {/* Habit B */}
                <div className="flex items-center gap-2 flex-1">
                    <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
                        style={{ backgroundColor: `${habitB.color}20` }}
                    >
                        <div
                            className="w-4 h-4 rounded-sm"
                            style={{ backgroundColor: habitB.color }}
                        />
                    </div>
                    <span className="font-semibold text-foreground text-sm truncate">
                        {habitB.title}
                    </span>
                </div>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-3 gap-3 mb-4">
                <div className="bg-white/5 rounded-lg p-2 text-center">
                    <p className="text-xs text-muted-foreground mb-1">Coefficiente</p>
                    <p className={cn(
                        "text-base font-mono font-bold",
                        isPositive ? "text-green-500" : "text-red-500"
                    )}>
                        {correlationCoefficient >= 0 ? '+' : ''}{correlationCoefficient.toFixed(2)}
                    </p>
                </div>

                <div className="bg-white/5 rounded-lg p-2 text-center">
                    <p className="text-xs text-muted-foreground mb-1">Co-occorrenza</p>
                    <p className="text-base font-mono font-bold text-foreground">
                        {Math.round(coOccurrenceRate)}%
                    </p>
                </div>

                <div className="bg-white/5 rounded-lg p-2 text-center">
                    <p className="text-xs text-muted-foreground mb-1">Giorni</p>
                    <p className="text-base font-mono font-bold text-foreground">
                        {totalDaysTracked}
                    </p>
                </div>
            </div>

            {/* Suggestion */}
            {suggestion && (
                <div className="bg-primary/5 border border-primary/10 rounded-xl p-3">
                    <div className="flex items-start gap-2">
                        <ChevronRight className="w-4 h-4 text-primary shrink-0 mt-0.5" />
                        <p className="text-xs text-muted-foreground leading-relaxed">
                            {suggestion}
                        </p>
                    </div>
                </div>
            )}
        </div>
    );
};
