import { KeystoneHabit } from '@/hooks/useHabitCorrelation';
import { Crown, TrendingUp, Zap } from 'lucide-react';
import { cn } from '@/lib/utils';

interface KeystoneHabitsPanelProps {
    keystoneHabits: KeystoneHabit[];
}

export const KeystoneHabitsPanel = ({ keystoneHabits }: KeystoneHabitsPanelProps) => {
    if (keystoneHabits.length === 0) return null;

    return (
        <div className="glass-panel rounded-3xl p-4 sm:p-6">
            <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-yellow-500/20 to-orange-500/20 flex items-center justify-center">
                    <Crown className="w-5 h-5 text-yellow-500" />
                </div>
                <div>
                    <h3 className="text-base sm:text-lg font-display font-semibold">Abitudini Chiave</h3>
                    <p className="text-xs sm:text-sm text-muted-foreground">
                        Abitudini che influenzano positivamente molte altre
                    </p>
                </div>
            </div>

            <div className={cn(
                "grid gap-3 sm:gap-4",
                keystoneHabits.length === 1 ? "grid-cols-1" : "grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
            )}>
                {keystoneHabits.map((keystone) => {
                    const impactColor =
                        keystone.impact === 'high' ? 'text-green-500' :
                            keystone.impact === 'medium' ? 'text-yellow-500' :
                                'text-blue-500';

                    const impactBg =
                        keystone.impact === 'high' ? 'bg-green-500/10 border-green-500/20' :
                            keystone.impact === 'medium' ? 'bg-yellow-500/10 border-yellow-500/20' :
                                'bg-blue-500/10 border-blue-500/20';

                    const impactLabel =
                        keystone.impact === 'high' ? 'Alto Impatto' :
                            keystone.impact === 'medium' ? 'Medio Impatto' :
                                'Impatto Basso';

                    return (
                        <div
                            key={keystone.habitId}
                            className={cn(
                                "glass-card rounded-2xl p-4 border-2 transition-all duration-300 hover:scale-[1.02]",
                                impactBg
                            )}
                        >
                            {/* Header */}
                            <div className="flex items-start justify-between gap-3 mb-3">
                                <div className="flex items-center gap-2 min-w-0 flex-1">
                                    <div
                                        className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0"
                                        style={{ backgroundColor: `${keystone.color}20` }}
                                    >
                                        <div
                                            className="w-3 h-3 rounded-sm"
                                            style={{ backgroundColor: keystone.color }}
                                        />
                                    </div>
                                    <h4 className="font-semibold text-foreground truncate text-sm sm:text-base">
                                        {keystone.title}
                                    </h4>
                                </div>
                                <Crown className={cn("w-5 h-5 shrink-0", impactColor)} />
                            </div>

                            {/* Impact Badge */}
                            <div className="flex items-center gap-2 mb-3">
                                <div className={cn("px-2 py-1 rounded-full text-xs font-semibold", impactColor, impactBg)}>
                                    {impactLabel}
                                </div>
                                <div className="text-xs text-muted-foreground">
                                    {keystone.connectedHabits} {keystone.connectedHabits === 1 ? 'connessione' : 'connessioni'}
                                </div>
                            </div>

                            {/* Connections List */}
                            <div className="space-y-1.5">
                                {keystone.connections.slice(0, 4).map((conn) => {
                                    const corrSign = conn.correlation >= 0 ? '+' : '';
                                    const corrColor = conn.correlation >= 0.6 ? 'text-green-500' :
                                        conn.correlation >= 0.3 ? 'text-yellow-500' :
                                            'text-muted-foreground';

                                    return (
                                        <div
                                            key={conn.habitId}
                                            className="flex items-center justify-between text-xs bg-white/5 rounded-lg px-2 py-1.5"
                                        >
                                            <span className="text-muted-foreground truncate flex-1">
                                                {conn.title}
                                            </span>
                                            <span className={cn("font-mono font-semibold ml-2", corrColor)}>
                                                {corrSign}{conn.correlation.toFixed(2)}
                                            </span>
                                        </div>
                                    );
                                })}

                                {keystone.connections.length > 4 && (
                                    <div className="text-xs text-center text-muted-foreground pt-1">
                                        +{keystone.connections.length - 4} altre connessioni
                                    </div>
                                )}
                            </div>

                            {/* Footer Stats */}
                            <div className="mt-3 pt-3 border-t border-white/10 flex items-center justify-between text-xs">
                                <div className="flex items-center gap-1 text-muted-foreground">
                                    <TrendingUp className="w-3 h-3" />
                                    <span>Media</span>
                                </div>
                                <span className="font-mono font-semibold text-foreground">
                                    {keystone.avgCorrelation >= 0 ? '+' : ''}{keystone.avgCorrelation.toFixed(2)}
                                </span>
                            </div>
                        </div>
                    );
                })}
            </div>

            {/* Info Footer */}
            <div className="mt-4 p-3 bg-primary/5 rounded-xl border border-primary/10">
                <div className="flex items-start gap-2">
                    <Zap className="w-4 h-4 text-primary shrink-0 mt-0.5" />
                    <p className="text-xs text-muted-foreground">
                        <span className="font-semibold text-foreground">Suggerimento:</span> Le abitudini chiave
                        hanno un effetto "domino" su altre. Concentrati a mantenerle costanti per migliorare
                        l'intero sistema delle tue abitudini.
                    </p>
                </div>
            </div>
        </div>
    );
};
