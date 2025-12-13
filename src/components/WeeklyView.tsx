import { useMemo } from 'react';
import { format, startOfWeek, addDays, isSameDay } from 'date-fns';
import { it } from 'date-fns/locale';
import { cn } from '@/lib/utils';
import { Goal, GoalLogsMap } from '@/types/goals';

interface WeeklyViewProps {
    habits: Goal[];
    records: GoalLogsMap;
    onToggleHabit: (date: Date, habitId: string) => void;
}

export function WeeklyView({ habits, records, onToggleHabit }: WeeklyViewProps) {
    const today = new Date();
    const weekStart = startOfWeek(today, { weekStartsOn: 1 }); // Monday

    const weekDays = useMemo(() => {
        return Array.from({ length: 7 }).map((_, i) => addDays(weekStart, i));
    }, [weekStart]);

    return (
        <div className="w-full h-full p-6 animate-scale-in">
            <h2 className="text-xl font-display font-bold mb-6">Questa Settimana</h2>

            <div className="grid grid-cols-7 gap-2 sm:gap-4">
                {weekDays.map((date) => {
                    const dateKey = date.toISOString().split('T')[0];
                    const dayRecord = records[dateKey] || {};
                    const isToday = isSameDay(date, today);
                    const isFuture = date > today;

                    return (
                        <div key={dateKey} className="flex flex-col gap-2">
                            {/* Header */}
                            <div className={cn(
                                "text-center py-2 rounded-xl border border-transparent transition-all",
                                isToday && "bg-primary/10 border-primary/20 text-primary"
                            )}>
                                <div className="text-[10px] uppercase font-bold opacity-60">{format(date, 'EEE', { locale: it })}</div>
                                <div className="text-lg font-mono font-bold">{format(date, 'd')}</div>
                            </div>

                            {/* Habits Column caused by grid */}
                            <div className="flex flex-col gap-2">
                                {habits.map(habit => {
                                    const status = dayRecord[habit.id];
                                    return (
                                        <button
                                            key={habit.id}
                                            disabled={isFuture}
                                            onClick={() => onToggleHabit(date, habit.id)}
                                            className={cn(
                                                "aspect-square rounded-xl border border-white/5 flex items-center justify-center transition-all hover:border-white/20",
                                                isFuture && "opacity-30 cursor-not-allowed",
                                                status === 'done' && "opacity-100 shadow-[0_0_10px_currentColor]",
                                                status === 'missed' && "opacity-50 grayscale",
                                                !status && !isFuture && "bg-white/5"
                                            )}
                                            style={{
                                                backgroundColor: status === 'done' ? habit.color : undefined,
                                                color: habit.color
                                            }}
                                        >
                                            {/* Maybe an icon or just simple color block */}
                                        </button>
                                    )
                                })}
                            </div>
                        </div>
                    );
                })}
            </div>
            {/* Labels if needed, or maybe simple tooltip */}
        </div>
    );
}
