import { useState } from 'react';
import { format, isSameDay, subDays } from 'date-fns';
import { ChevronLeft, ChevronRight, RotateCcw } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { Goal, GoalLogsMap } from '@/types/goals';
import { DayDetailsModal } from './DayDetailsModal';

interface HabitCalendarProps {
    habits: Goal[];
    records: GoalLogsMap;
    onToggleHabit: (date: Date, habitId: string) => void;
    isPrivacyMode?: boolean;
}

const DAYS = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
const MONTHS = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
];

export function HabitCalendar({ habits, records, onToggleHabit, isPrivacyMode = false }: HabitCalendarProps) {
    const [currentDate, setCurrentDate] = useState(new Date());
    const [selectedDate, setSelectedDate] = useState<Date | null>(null);

    const year = currentDate.getFullYear();
    const month = currentDate.getMonth();

    const firstDayOfMonth = new Date(year, month, 1);
    const lastDayOfMonth = new Date(year, month + 1, 0);

    // Adjust for Monday start (0 = Monday, 6 = Sunday)
    let startDay = firstDayOfMonth.getDay() - 1;
    if (startDay < 0) startDay = 6;

    const daysInMonth = lastDayOfMonth.getDate();
    const today = new Date();

    const goToPrevMonth = () => setCurrentDate(new Date(year, month - 1, 1));
    const goToNextMonth = () => setCurrentDate(new Date(year, month + 1, 1));
    const goToToday = () => setCurrentDate(new Date());

    const isToday = (day: number) => {
        return (
            today.getDate() === day &&
            today.getMonth() === month &&
            today.getFullYear() === year
        );
    };

    const isFuture = (day: number) => {
        const date = new Date(year, month, day);
        const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        return date > todayStart;
    };

    // Calculate number of rows needed
    const totalSlots = startDay + daysInMonth;
    const numRows = Math.ceil(totalSlots / 7);

    const renderDays = () => {
        const days = [];

        // Empty cells
        for (let i = 0; i < startDay; i++) {
            days.push(<div key={`empty-${i}`} className="aspect-auto h-full" />);
        }

        // Days
        for (let day = 1; day <= daysInMonth; day++) {
            const date = new Date(year, month, day);
            const dateKey = format(date, 'yyyy-MM-dd');
            const dayRecord = records[dateKey] || {};
            const future = isFuture(day);

            // Filter habits valid for this date
            const validHabits = habits.filter(h => {
                const isStarted = h.start_date <= dateKey;
                const isNotEnded = !h.end_date || h.end_date >= dateKey;
                return isStarted && isNotEnded;
            });

            // Calculate daily progress
            const completedCount = validHabits.filter(h => dayRecord[h.id] === 'done').length;
            const missedCount = validHabits.filter(h => dayRecord[h.id] === 'missed').length; // Tracked but failed
            const markedCount = completedCount + missedCount;

            // Percentage based on TOTAL habits
            const totalHabits = validHabits.length;
            let completionPct = 0;
            if (totalHabits > 0) {
                completionPct = completedCount / totalHabits;
            }

            let style = {};
            const hasActivity = markedCount > 0;

            if (hasActivity && totalHabits > 0) {
                const hue = Math.round(completionPct * 142); // 0 to 142
                style = {
                    backgroundColor: `hsl(${hue}, 70%, 10%, 0.3)`,
                    borderColor: `hsl(${hue}, 80%, 40%, 0.5)`,
                    boxShadow: completionPct === 1 ? `0 0 10px hsl(${hue}, 80%, 40%, 0.2)` : 'none'
                };
            }

            days.push(
                <button
                    key={day}
                    onClick={() => !future && setSelectedDate(date)}
                    disabled={future}
                    style={style}
                    className={cn(
                        "w-full h-full rounded-xl flex flex-col items-center justify-start py-[clamp(4px,1vw,8px)] transition-all duration-300 relative border border-white/5 hover:border-white/20 hover:bg-white/5 group",
                        future && "opacity-30 cursor-not-allowed",
                        isToday(day) && !hasActivity && "bg-white/5 ring-1 ring-primary/50",
                        // Visual cue for editable days (Today or Yesterday < 12h)
                        !future && (isSameDay(date, new Date()) || (isSameDay(date, subDays(new Date(), 1)) && new Date().getHours() < 12)) && "ring-1 ring-primary/30 bg-primary/5"
                    )}
                >
                    <span className={cn(
                        "text-[clamp(0.7rem,2.5vw,0.9rem)] font-medium mb-[2px] font-mono-nums transition-all duration-300",
                        isToday(day) && "text-primary font-bold",
                        hasActivity && "text-foreground",
                        isPrivacyMode && "blur-[2px]"
                    )}>
                        {day}
                    </span>

                    {/* Dots Indicator - Refined for tech look */}
                    <div className={cn("flex flex-wrap items-center justify-center gap-0.5 px-1 w-full max-w-[80%] transition-all duration-300", isPrivacyMode && "blur-[1px]")}>
                        {validHabits.map(habit => {
                            const status = dayRecord[habit.id];
                            if (!status) return null;

                            return (
                                <div
                                    key={habit.id}
                                    className={cn(
                                        "w-1 h-1 rounded-sm", // Square dots for tech feel
                                        status === 'done' ? "opacity-80" : "opacity-0"
                                    )}
                                    style={{ backgroundColor: status === 'done' ? habit.color : undefined }}
                                />
                            );
                        })}
                    </div>
                </button>
            );
        }
        return days;
    };

    return (
        <>
            <div className="w-full h-full p-2 sm:p-4 animate-scale-in flex flex-col">
                {/* Header */}
                <div className="flex items-center justify-between mb-2 sm:mb-6 shrink-0">
                    <Button variant="ghost" size="icon" onClick={goToPrevMonth}>
                        <ChevronLeft className="h-5 w-5" />
                    </Button>

                    <div className="flex items-center gap-2">
                        <h2 className="text-xl sm:text-2xl font-display font-bold">
                            {MONTHS[month]} <span className="text-muted-foreground font-light">{year}</span>
                        </h2>
                        <Button variant="ghost" size="icon" onClick={goToToday} className="h-8 w-8 ml-2 opacity-0 hover:opacity-100 transition-opacity">
                            <RotateCcw className="h-3 w-3" />
                        </Button>
                    </div>

                    <Button variant="ghost" size="icon" onClick={goToNextMonth}>
                        <ChevronRight className="h-5 w-5" />
                    </Button>
                </div>

                {/* Calendar */}
                <div className="grid grid-cols-7 gap-x-[clamp(4px,1.5vw,12px)] mb-2 shrink-0">
                    {DAYS.map(d => (
                        <div key={d} className="text-center text-[10px] sm:text-xs font-semibold text-muted-foreground uppercase tracking-wider py-2">
                            {d}
                        </div>
                    ))}
                </div>
                {/* Days Grid: fills all available vertical space, rows distribute evenly */}
                <div
                    className="grid grid-cols-7 gap-[clamp(2px,1vw,8px)] flex-1 min-h-0"
                    style={{ gridTemplateRows: `repeat(${numRows}, 1fr)` }}
                >
                    {renderDays()}
                </div>
            </div>

            <DayDetailsModal
                isOpen={!!selectedDate}
                onClose={() => setSelectedDate(null)}
                date={selectedDate}
                habits={habits}
                records={records}
                onToggleHabit={(habitId) => selectedDate && onToggleHabit(selectedDate, habitId)}
                isPrivacyMode={isPrivacyMode}
                readonly={selectedDate ? !(isSameDay(selectedDate, new Date()) || (isSameDay(selectedDate, subDays(new Date(), 1)) && new Date().getHours() < 12)) : true}
            />
        </>
    );
}
