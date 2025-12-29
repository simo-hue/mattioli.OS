import { useState } from 'react';
import { format } from 'date-fns';
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

    const renderDays = () => {
        const days = [];

        // Empty cells
        for (let i = 0; i < startDay; i++) {
            days.push(<div key={`empty-${i}`} className="aspect-square" />);
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

            // Percentage based on TOTAL habits, not just marked ones, for "Today's Goal" feel?
            // User said "number of tasks to complete". That implies total habits.
            const totalHabits = validHabits.length;
            let completionPct = 0;
            if (totalHabits > 0) {
                completionPct = completedCount / totalHabits;
            }

            // Calculate color
            // Hue: 0 (Red) -> 142 (Green)
            // Saturation: ~70%
            // Lightness: ~90% for background (so text remains readable)
            // Or maybe stronger colors with white text?
            // "Gradient from green to red" usually implies solid fill.

            let style = {};
            // Only apply color if there is at least one completion or miss, OR if it's in the past/today?
            // If nothing is marked, should it be red? Maybe neutral until marked?
            // If the user hasn't done anything yet today, it shouldn't scream RED immediately? 
            // "to see if a day was good or not" implies retroactive checking.

            // Let's apply color if > 0 habits are completed OR if the day is in the past and marked?
            // Actually simply: if completedCount > 0, show color. 
            // If completedCount == 0, is it "bad" (Red) or "neutral" (White)?
            // If I marked a habit as "missed", it counts towards being "bad".

            const hasActivity = markedCount > 0;
            const isFullSuccess = totalHabits > 0 && completedCount === totalHabits;

            if (hasActivity && totalHabits > 0) {
                const hue = Math.round(completionPct * 142); // 0 to 142
                // Tech look: Dark background, colored border/glow
                style = {
                    backgroundColor: `hsl(${hue}, 70%, 10%, 0.3)`, // Darker, transparent bg
                    borderColor: `hsl(${hue}, 80%, 40%, 0.5)`, // Subtle border
                    boxShadow: completionPct === 1 ? `0 0 10px hsl(${hue}, 80%, 40%, 0.2)` : 'none' // Glow for 100%
                };
            }

            days.push(
                <button
                    key={day}
                    onClick={() => !future && setSelectedDate(date)}
                    disabled={future}
                    style={style}
                    className={cn(
                        "aspect-square rounded-xl flex flex-col items-center justify-start py-[clamp(4px,1vw,8px)] transition-all duration-300 relative border border-white/5 hover:border-white/20 hover:bg-white/5 group",
                        future && "opacity-30 cursor-not-allowed",
                        isToday(day) && !hasActivity && "bg-white/5 ring-1 ring-primary/50",
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
            <div className="w-full h-full p-4 sm:p-6 animate-scale-in">
                {/* Header */}
                <div className="flex items-center justify-between mb-6">
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
                <div className="grid grid-cols-7 gap-[clamp(4px,1.5vw,12px)] mb-2">
                    {DAYS.map(d => (
                        <div key={d} className="text-center text-[10px] sm:text-xs font-semibold text-muted-foreground uppercase tracking-wider py-2">
                            {d}
                        </div>
                    ))}
                </div>
                <div className="grid grid-cols-7 gap-[clamp(4px,1.5vw,12px)]">
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
            />
        </>
    );
}
