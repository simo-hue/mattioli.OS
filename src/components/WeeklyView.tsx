import { useState, useMemo } from 'react';
import { format, startOfWeek, addDays, isSameDay, subDays, endOfWeek } from 'date-fns';
import { it } from 'date-fns/locale';
import { cn } from '@/lib/utils';
import { Goal, GoalLogsMap } from '@/types/goals';
import { DayDetailsModal } from './DayDetailsModal';
import { ChevronLeft, ChevronRight } from 'lucide-react';

interface WeeklyViewProps {
    habits: Goal[];
    records: GoalLogsMap;
    onToggleHabit: (date: Date, habitId: string) => void;
    isPrivacyMode?: boolean;
}

export function WeeklyView({ habits, records, onToggleHabit, isPrivacyMode = false }: WeeklyViewProps) {
    // Stable today reference for "future" checks
    const today = useMemo(() => new Date(), []);

    // State for the currently visible week
    const [currentDate, setCurrentDate] = useState(new Date());

    // Determine the start of the visible week
    const weekStart = useMemo(() => startOfWeek(currentDate, { weekStartsOn: 1 }), [currentDate]); // Monday
    const weekEnd = useMemo(() => endOfWeek(currentDate, { weekStartsOn: 1 }), [currentDate]);

    const [selectedDate, setSelectedDate] = useState<Date | null>(null);

    const weekDays = useMemo(() => {
        return Array.from({ length: 7 }).map((_, i) => addDays(weekStart, i));
    }, [weekStart]);

    const handlePrevWeek = () => {
        setCurrentDate(prev => subDays(prev, 7));
    };

    const handleNextWeek = () => {
        setCurrentDate(prev => addDays(prev, 7));
    };

    // Formatted date range for title
    const dateRangeTitle = useMemo(() => {
        const start = format(weekStart, 'd', { locale: it });
        const end = format(weekEnd, 'd MMMM', { locale: it }); // e.g. "15 Ottobre"
        return `${start} - ${end}`;
    }, [weekStart, weekEnd]);

    const isCurrentWeek = isSameDay(startOfWeek(today, { weekStartsOn: 1 }), weekStart);

    return (
        <div className="w-full h-full p-6 animate-scale-in">
            <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-display font-bold capitalize">
                    {dateRangeTitle}
                </h2>
                <div className="flex items-center gap-2">
                    <button
                        onClick={handlePrevWeek}
                        className="p-2 rounded-lg hover:bg-white/5 transition-colors active:scale-95"
                    >
                        <ChevronLeft className="w-5 h-5" />
                    </button>
                    <button
                        onClick={handleNextWeek}
                        className="p-2 rounded-lg hover:bg-white/5 transition-colors active:scale-95"
                    >
                        <ChevronRight className="w-5 h-5" />
                    </button>
                </div>
            </div>

            <div className="grid grid-cols-7 gap-2 sm:gap-4">
                {weekDays.map((date) => {
                    const dateKey = format(date, 'yyyy-MM-dd');
                    const dayRecord = records[dateKey] || {};
                    const isToday = isSameDay(date, today);
                    // Check against actual today for future disabling
                    const todayMidnight = new Date(today);
                    todayMidnight.setHours(0, 0, 0, 0);
                    const isFuture = date > todayMidnight;

                    return (
                        <div key={dateKey} className="flex flex-col gap-2">
                            {/* Header */}
                            <button
                                onClick={() => !isFuture && setSelectedDate(date)}
                                disabled={isFuture}
                                className={cn(
                                    "text-center py-2 rounded-xl border border-transparent transition-all w-full",
                                    isToday && "bg-primary/10 border-primary/20 text-primary",
                                    !isFuture && "hover:bg-white/5 hover:border-white/10 cursor-pointer active:scale-95",
                                    isFuture && "opacity-50 cursor-default"
                                )}>
                                <div className="text-[10px] uppercase font-bold opacity-60">{format(date, 'EEE', { locale: it })}</div>
                                <div className="text-lg font-mono font-bold">{format(date, 'd')}</div>
                            </button>

                            <div className={cn("flex flex-col gap-2 transition-all duration-300", isPrivacyMode && "blur-[2px]")}>
                                {habits.map(habit => {
                                    const isStarted = habit.start_date <= dateKey;
                                    const isEnded = habit.end_date && habit.end_date < dateKey;

                                    if (!isStarted || isEnded) {
                                        return <div key={habit.id} className="aspect-square rounded-xl invisible" />;
                                    }

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
                                                !status && !isFuture && "bg-white/5",
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

            <DayDetailsModal
                isOpen={!!selectedDate}
                onClose={() => setSelectedDate(null)}
                date={selectedDate}
                habits={habits}
                records={records}
                onToggleHabit={(habitId) => selectedDate && onToggleHabit(selectedDate, habitId)}
                isPrivacyMode={isPrivacyMode}
            />
        </div >
    );
}
