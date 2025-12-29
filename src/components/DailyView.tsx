import { format } from 'date-fns';
import { it } from 'date-fns/locale';
import { cn } from '@/lib/utils';
import { Goal, GoalLogsMap } from '@/types/goals';
import { Check, X } from 'lucide-react';

interface DailyViewProps {
    habits: Goal[];
    records: GoalLogsMap;
    onToggleHabit: (date: Date, habitId: string) => void;
    isPrivacyMode?: boolean;
}

export function DailyView({ habits, records, onToggleHabit, isPrivacyMode = false }: DailyViewProps) {
    const today = new Date();
    const dateKey = format(today, 'yyyy-MM-dd');
    const dayRecord = records[dateKey] || {};

    // Filter habits valid for today
    const validHabits = habits.filter(h => {
        const isStarted = h.start_date <= dateKey;
        const isNotEnded = !h.end_date || h.end_date >= dateKey;
        return isStarted && isNotEnded;
    });

    return (
        <div className="glass-panel rounded-3xl p-6 animate-scale-in max-w-lg mx-auto w-full">
            <div className="text-center mb-8">
                <h2 className="text-2xl font-display font-bold">Focus Giornaliero</h2>
                <p className="text-muted-foreground capitalize">{format(today, 'EEEE d MMMM', { locale: it })}</p>
            </div>

            <div className="space-y-3">
                {validHabits.length === 0 && (
                    <div className="text-center py-12 border border-dashed border-white/10 rounded-xl">
                        <p className="text-muted-foreground">Nessun obiettivo per oggi.</p>
                        <p className="text-xs text-muted-foreground/60 mt-1">Aggiungine alcuni dalle impostazioni.</p>
                    </div>
                )}
                {validHabits.map(habit => {
                    const status = dayRecord[habit.id];
                    return (
                        <div
                            key={habit.id}
                            onClick={() => onToggleHabit(today, habit.id)}
                            className={cn(
                                "group relative overflow-hidden p-4 rounded-xl border border-white/10 bg-white/5 hover:bg-white/10 transition-all cursor-pointer flex items-center justify-between",
                                status === 'done' && "border-primary/20 bg-primary/5"
                            )}
                        >
                            {/* Progress Fill Background */}
                            <div
                                className={cn(
                                    "absolute inset-0 opacity-0 transition-opacity duration-500",
                                    status === 'done' && "opacity-10"
                                )}
                                style={{ backgroundColor: habit.color }}
                            />

                            <div className="flex items-center gap-4 relative z-10">
                                <div
                                    className={cn(
                                        "w-8 h-8 rounded-lg border-2 flex items-center justify-center transition-all",
                                        status === 'done' ? "border-transparent text-black" : "border-white/20 text-transparent"
                                    )}
                                    style={{
                                        backgroundColor: status === 'done' ? habit.color : 'transparent',
                                        borderColor: status === 'done' ? undefined : habit.color
                                    }}
                                >
                                    <Check className="w-5 h-5" />
                                </div>
                                <span className={cn(
                                    "text-lg font-medium transition-colors transition-all duration-300",
                                    status === 'done' ? "text-foreground" : "text-muted-foreground group-hover:text-foreground",
                                    isPrivacyMode && "blur-sm"
                                )}>
                                    {habit.title}
                                </span>
                            </div>

                            {status === 'missed' && (
                                <span className="text-xs uppercase font-bold text-destructive tracking-widest px-2 py-1 rounded bg-destructive/10">Saltato</span>
                            )}
                        </div>
                    );
                })}
            </div>
        </div>
    );
}
