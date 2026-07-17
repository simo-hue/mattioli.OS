import { useMemo } from 'react';
import { format, startOfYear, addMonths, differenceInMonths, startOfMonth, endOfMonth, eachDayOfInterval } from 'date-fns';
import { it } from 'date-fns/locale';
import { cn } from '@/lib/utils';
import { Goal, GoalLogsMap } from '@/types/goals';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

interface LifeViewProps {
    habits: Goal[];
    records: GoalLogsMap;
    isPrivacyMode?: boolean;
}

const BIRTH_YEAR = 2003;
const END_YEAR = 2088; // 85 years old
const MONTHS_PER_ROW = 29;

export function LifeView({ habits, records, isPrivacyMode = false }: LifeViewProps) {
    const today = new Date();
    const currentYear = today.getFullYear();
    const currentMonth = startOfMonth(today);

    // Calculate the first month of goal tracking
    const firstTrackingDate = useMemo(() => {
        if (!habits || habits.length === 0) return today;

        const earliestDate = habits.reduce((earliest, goal) => {
            const goalStartDate = new Date(goal.start_date);
            return goalStartDate < earliest ? goalStartDate : earliest;
        }, today);

        return startOfMonth(earliestDate);
    }, [habits, today]);

    // Generate flat array of all months
    const allMonthsData = useMemo(() => {
        const months: Array<{ date: Date; year: number }> = [];

        for (let year = BIRTH_YEAR; year <= END_YEAR; year++) {
            const yearStart = startOfYear(new Date(year, 0, 1));

            for (let monthNum = 0; monthNum < 12; monthNum++) {
                const monthStart = addMonths(yearStart, monthNum);
                months.push({ date: monthStart, year });
            }
        }

        return months;
    }, []);

    // Group months into rows
    const monthRows = useMemo(() => {
        const rows = [];
        for (let i = 0; i < allMonthsData.length; i += MONTHS_PER_ROW) {
            rows.push(allMonthsData.slice(i, i + MONTHS_PER_ROW));
        }
        return rows;
    }, [allMonthsData]);

    // Calculate statistics for each month
    const monthStats = useMemo(() => {
        const stats: Map<number, { completed: number; total: number; percentage: number }> = new Map();

        allMonthsData.forEach(({ date: monthStart }) => {
            const monthTimestamp = monthStart.getTime();
            const monthEnd = endOfMonth(monthStart);
            const daysInMonth = eachDayOfInterval({ start: monthStart, end: monthEnd });

            let totalCompleted = 0;
            let totalPossible = 0;

            daysInMonth.forEach(day => {
                const dateKey = format(day, 'yyyy-MM-dd');
                const dayRecord = records[dateKey];
                if (!dayRecord) return;

                const validHabits = habits.filter(h => {
                    const isStarted = h.start_date <= dateKey;
                    const isNotEnded = !h.end_date || h.end_date >= dateKey;
                    return isStarted && isNotEnded;
                });

                const completedCount = validHabits.filter(h => dayRecord[h.id] === 'done').length;
                totalCompleted += completedCount;
                totalPossible += validHabits.length;
            });

            const percentage = totalPossible > 0 ? (totalCompleted / totalPossible) : 0;
            stats.set(monthTimestamp, { completed: totalCompleted, total: totalPossible, percentage });
        });

        return stats;
    }, [allMonthsData, records, habits]);

    const renderMonth = (monthStart: Date) => {
        const monthTimestamp = monthStart.getTime();
        const currentMonthTimestamp = currentMonth.getTime();

        const isCurrentMonth = monthTimestamp === currentMonthTimestamp;
        const isFuture = monthStart > today;
        const isPreTracking = monthStart < firstTrackingDate;
        const stats = monthStats.get(monthTimestamp);
        const hasActivity = stats && stats.total > 0;

        let bgColor = 'rgba(255, 255, 255, 0.05)';

        if (isFuture) {
            bgColor = 'rgba(255, 255, 255, 0.05)';
        } else if (isPreTracking) {
            bgColor = 'hsl(200, 70%, 50%)';
        } else if (hasActivity) {
            const hue = Math.round(stats.percentage * 142);
            bgColor = `hsl(${hue}, 70%, 40%)`;
        }

        const monthLabel = format(monthStart, 'MMMM yyyy', { locale: it });

        return (
            <TooltipProvider key={monthTimestamp}>
                <Tooltip delayDuration={100}>
                    <TooltipTrigger asChild>
                        <div
                            style={{ backgroundColor: bgColor }}
                            className={cn(
                                "rounded-sm transition-all duration-150 hover:scale-110 hover:z-10 border border-black/40",
                                isCurrentMonth && "ring-2 ring-primary ring-offset-1 ring-offset-background shadow-[0_0_8px_rgba(255,255,255,0.4)]",
                                !isFuture && "hover:brightness-125 hover:border-white/30",
                                isPreTracking && !isFuture && "opacity-30",
                                isFuture && "opacity-20",
                                isPrivacyMode && hasActivity && "blur-[1px]"
                            )}
                        />
                    </TooltipTrigger>
                    <TooltipContent className="bg-background/95 backdrop-blur border-white/10 text-xs">
                        <div className="space-y-1">
                            <p className="font-bold capitalize">{monthLabel}</p>
                            {isCurrentMonth && <p className="text-primary font-medium">Mese corrente</p>}
                            {isFuture && <p className="text-muted-foreground">Futuro</p>}
                            {isPreTracking && !isFuture && <p className="text-blue-400">Pre-tracciamento</p>}
                            {hasActivity && (
                                <>
                                    <p className="text-muted-foreground">
                                        {stats.completed}/{stats.total} completati
                                    </p>
                                    <p className="text-muted-foreground">
                                        Performance: {Math.round(stats.percentage * 100)}%
                                    </p>
                                </>
                            )}
                        </div>
                    </TooltipContent>
                </Tooltip>
            </TooltipProvider>
        );
    };

    const totalYears = END_YEAR - BIRTH_YEAR + 1;
    const totalMonths = totalYears * 12;
    const currentAge = currentYear - BIRTH_YEAR;
    const monthsLived = differenceInMonths(today, new Date(BIRTH_YEAR, 0, 1));
    const monthsRemaining = (85 * 12) - monthsLived;

    return (
        <div className="w-full h-full p-2 sm:p-4 animate-scale-in flex flex-col">
            {/* Header */}
            <div className="flex flex-col sm:flex-row items-center justify-between mb-2 sm:mb-3 shrink-0 gap-1">
                <div>
                    <h2 className="text-base sm:text-lg font-display font-bold">
                        La Mia Vita Produttiva
                    </h2>
                    <p className="text-[9px] sm:text-[10px] text-muted-foreground">
                        {BIRTH_YEAR} - {END_YEAR} • {totalMonths.toLocaleString()} mesi
                    </p>
                </div>
                <div className="flex items-center gap-2 text-[9px] sm:text-[10px]">
                    <div className="flex items-center gap-1">
                        <div className="w-1.5 h-1.5 rounded-sm" style={{ backgroundColor: 'hsl(200, 70%, 50%)', opacity: 0.3 }} />
                        <span className="text-muted-foreground">Pre-tracking</span>
                    </div>
                    <div className="flex items-center gap-1">
                        <div className="w-1.5 h-1.5 rounded-sm ring-1 ring-primary" style={{ backgroundColor: 'hsl(71, 70%, 40%)' }} />
                        <span className="text-muted-foreground">Attuale</span>
                    </div>
                </div>
            </div>

            {/* Stats Bar */}
            <div className="mb-2 sm:mb-3 shrink-0 glass-card p-2 rounded-lg">
                <div className="grid grid-cols-3 gap-2 text-center">
                    <div>
                        <p className="text-sm sm:text-base font-bold text-primary">{monthsLived.toLocaleString()}</p>
                        <p className="text-[8px] sm:text-[9px] text-muted-foreground uppercase">Mesi Vissuti</p>
                    </div>
                    <div>
                        <p className="text-sm sm:text-base font-bold text-foreground">{currentAge}</p>
                        <p className="text-[8px] sm:text-[9px] text-muted-foreground uppercase">Anni</p>
                    </div>
                    <div>
                        <p className="text-sm sm:text-base font-bold text-muted-foreground/70">{monthsRemaining.toLocaleString()}</p>
                        <p className="text-[8px] sm:text-[9px] text-muted-foreground uppercase">Mesi Rimanenti</p>
                    </div>
                </div>
            </div>

            {/* Grid - Simple grid layout without flex conflicts */}
            <div
                className="flex-1 min-h-0 grid gap-1.5 content-start overflow-hidden"
                style={{
                    gridTemplateRows: `repeat(${monthRows.length}, 1fr)`,
                }}
            >
                {monthRows.map((rowMonths, rowIndex) => {
                    const isFirstRow = rowIndex === 0;
                    const isLastRow = rowIndex === monthRows.length - 1;
                    const rowLabel = isFirstRow ? 'nato' : isLastRow ? 'morto' : '';

                    return (
                        <div key={rowIndex} className="flex items-center gap-1 min-h-0">
                            <div className="w-6 sm:w-8 shrink-0 text-[8px] sm:text-[9px] font-bold text-right text-muted-foreground">
                                {rowLabel}
                            </div>
                            <div
                                className="flex-1 grid gap-1.5 h-full"
                                style={{ gridTemplateColumns: `repeat(${MONTHS_PER_ROW}, 1fr)` }}
                            >
                                {rowMonths.map(({ date }) => renderMonth(date))}
                            </div>
                        </div>
                    );
                })}
            </div>
        </div>
    );
}
