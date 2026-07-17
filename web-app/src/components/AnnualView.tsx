
import { useState, useMemo } from 'react';
import { format, isSameDay, subDays, getDate, eachDayOfInterval, startOfMonth, endOfMonth, startOfYear } from 'date-fns';
import { it } from 'date-fns/locale';
import { ChevronLeft, ChevronRight, RotateCcw } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { Goal, GoalLogsMap } from '@/types/goals';
import { DayDetailsModal } from './DayDetailsModal';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

interface AnnualViewProps {
    habits: Goal[];
    records: GoalLogsMap;
    onToggleHabit: (date: Date, habitId: string) => void;
    isPrivacyMode?: boolean;
}

const MONTH_NAMES = ['GEN', 'FEB', 'MAR', 'APR', 'MAG', 'GIU', 'LUG', 'AGO', 'SET', 'OTT', 'NOV', 'DIC'];

export function AnnualView({ habits, records, onToggleHabit, isPrivacyMode = false }: AnnualViewProps) {
    const [currentDate, setCurrentDate] = useState(new Date());
    const [selectedDate, setSelectedDate] = useState<Date | null>(null);

    const year = currentDate.getFullYear();
    const today = new Date();

    const goToPrevYear = () => setCurrentDate(new Date(year - 1, 0, 1));
    const goToNextYear = () => setCurrentDate(new Date(year + 1, 0, 1));
    const goToThisYear = () => setCurrentDate(new Date());

    const isToday = (date: Date) => isSameDay(today, date);
    const isFuture = (date: Date) => date > today;

    // Generate months array with days
    const monthsData = useMemo(() => {
        return Array.from({ length: 12 }, (_, monthIndex) => {
            const monthStart = new Date(year, monthIndex, 1);
            const days = eachDayOfInterval({
                start: startOfMonth(monthStart),
                end: endOfMonth(monthStart)
            });
            return { monthIndex, days };
        });
    }, [year]);

    const renderDay = (date: Date) => {
        const dateKey = format(date, 'yyyy-MM-dd');
        const dayRecord = records[dateKey] || {};
        const future = isFuture(date);
        const formattedDate = format(date, 'd MMMM yyyy', { locale: it });

        // Filter habits valid for this date
        const validHabits = habits.filter(h => {
            const isStarted = h.start_date <= dateKey;
            const isNotEnded = !h.end_date || h.end_date >= dateKey;
            return isStarted && isNotEnded;
        });

        // Calculate daily progress
        const completedCount = validHabits.filter(h => dayRecord[h.id] === 'done').length;
        const missedCount = validHabits.filter(h => dayRecord[h.id] === 'missed').length;
        const markedCount = completedCount + missedCount;

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
                backgroundColor: `hsl(${hue}, 70%, 25%)`,
                borderColor: `hsl(${hue}, 80%, 50%)`,
            };
        }

        return (
            <TooltipProvider key={dateKey}>
                <Tooltip delayDuration={0}>
                    <TooltipTrigger asChild>
                        <button
                            onClick={() => !future && setSelectedDate(date)}
                            disabled={future}
                            style={style}
                            className={cn(
                                "w-full h-full rounded-[2px] flex items-center justify-center transition-all duration-200 relative border border-white/5 hover:border-white/40 hover:scale-110 hover:z-10",
                                future && "opacity-20 cursor-not-allowed border-none bg-white/5",
                                !future && !hasActivity && "bg-white/5",
                                isToday(date) && !hasActivity && "ring-1 ring-primary/50 bg-primary/10",
                            )}
                        />
                    </TooltipTrigger>
                    <TooltipContent className="bg-background/90 backdrop-blur border-white/10 text-xs">
                        <p className="capitalize font-medium">{formattedDate}</p>
                        {validHabits.length > 0 && (
                            <p className="text-muted-foreground">{completedCount}/{validHabits.length} completate</p>
                        )}
                    </TooltipContent>
                </Tooltip>
            </TooltipProvider>
        );
    };

    return (
        <>
            <div className="w-full h-full p-2 sm:p-6 animate-scale-in flex flex-col overflow-hidden">
                {/* Header */}
                <div className="flex items-center justify-between mb-4 shrink-0">
                    <Button variant="ghost" size="icon" onClick={goToPrevYear}>
                        <ChevronLeft className="h-5 w-5" />
                    </Button>

                    <div className="flex items-center gap-2">
                        <h2 className="text-xl sm:text-2xl font-display font-bold">
                            <span className="text-foreground">{year}</span>
                        </h2>
                        <Button variant="ghost" size="icon" onClick={goToThisYear} className="h-8 w-8 ml-2 opacity-0 hover:opacity-100 transition-opacity">
                            <RotateCcw className="h-3 w-3" />
                        </Button>
                    </div>

                    <Button variant="ghost" size="icon" onClick={goToNextYear}>
                        <ChevronRight className="h-5 w-5" />
                    </Button>
                </div>

                {/* Grid Container - Full Height */}
                <div className="flex-1 min-h-0 grid grid-cols-2 gap-x-6 gap-y-2">
                    {monthsData.map(({ monthIndex, days }) => (
                        <div key={monthIndex} className="flex items-center gap-2 min-h-0">
                            {/* Month Label */}
                            <span className="text-[10px] font-bold text-muted-foreground w-8 shrink-0">
                                {MONTH_NAMES[monthIndex]}
                            </span>
                            {/* Days Grid - 31 columns, each day fills space */}
                            <div
                                className="flex-1 h-full grid gap-[2px]"
                                style={{
                                    gridTemplateColumns: `repeat(${days.length}, 1fr)`,
                                }}
                            >
                                {days.map(day => renderDay(day))}
                            </div>
                        </div>
                    ))}
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
                readonly={selectedDate ? !(isSameDay(selectedDate, new Date()) || isSameDay(selectedDate, subDays(new Date(), 1))) : true}
            />
        </>
    );
}
