import { useMemo } from 'react';
import { cn } from '@/lib/utils';
import { ReadingRecord } from '@/hooks/useReadingTracker';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';

interface HexHeatmapProps {
    records: ReadingRecord;
    year: number;
}

const MONTHS = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
const DAYS = ['Lun', '', 'Mer', '', 'Ven', '', 'Dom'];

export function HexHeatmap({ records, year }: HexHeatmapProps) {
    const weeks = useMemo(() => {
        const result: { date: Date; status: 'done' | 'missed' | null }[][] = [];

        // Start from first day of year
        const startDate = new Date(year, 0, 1);
        // Adjust to Monday
        const startDay = startDate.getDay();
        const daysToSubtract = startDay === 0 ? 6 : startDay - 1;
        startDate.setDate(startDate.getDate() - daysToSubtract);

        const endDate = new Date(year, 11, 31);

        // Use a fresh date object for iteration to avoid mutation issues if any
        const currentDate = new Date(startDate);
        let currentWeek: { date: Date; status: 'done' | 'missed' | null }[] = [];
        const today = new Date();

        // Safety break to prevent infinite loops
        let iterations = 0;
        while ((currentDate <= endDate || currentWeek.length > 0) && iterations < 400) {
            iterations++;

            const dateKey = currentDate.toISOString().split('T')[0];
            const isInYear = currentDate.getFullYear() === year;
            const isFuture = currentDate > today;

            let status: 'done' | 'missed' | null = null;
            if (isInYear && !isFuture && records[dateKey]) {
                status = records[dateKey];
            }

            currentWeek.push({
                date: new Date(currentDate),
                status: isInYear ? status : null,
            });

            if (currentWeek.length === 7) {
                result.push(currentWeek);
                currentWeek = [];
            }

            currentDate.setDate(currentDate.getDate() + 1);

            // If we went past end date and filled the last week, break.
            if (currentDate > endDate && currentWeek.length === 0) break;
        }

        if (currentWeek.length > 0) {
            result.push(currentWeek);
        }

        return result;
    }, [records, year]);

    const monthLabels = useMemo(() => {
        const labels: { month: string; weekIndex: number }[] = [];
        let lastMonth = -1;

        weeks.forEach((week, weekIndex) => {
            const firstDayOfWeek = week.find(d => d.date.getFullYear() === year);
            if (firstDayOfWeek) {
                const month = firstDayOfWeek.date.getMonth();
                if (month !== lastMonth) {
                    labels.push({ month: MONTHS[month], weekIndex });
                    lastMonth = month;
                }
            }
        });

        return labels;
    }, [weeks, year]);

    const formatDate = (date: Date) => {
        return date.toLocaleDateString('it-IT', {
            weekday: 'long',
            day: 'numeric',
            month: 'long'
        });
    };

    // Hexagon Math
    const hexRadius = 6;
    const hexWidth = Math.sqrt(3) * hexRadius; // ~10.39
    // const hexHeight = 2 * hexRadius; // 12

    const colWidth = 14;
    const rowHeight = 15;
    const oddColOffset = 7;

    return (
        <div className="w-full overflow-x-auto pb-4 pt-2">
            <div className="min-w-max relative select-none">

                {/* Month Labels */}
                <div className="flex relative h-6 mb-2">
                    {monthLabels.map(({ month, weekIndex }) => (
                        <div
                            key={month}
                            className="absolute text-[10px] uppercase font-bold tracking-widest text-muted-foreground/60"
                            style={{
                                left: `${weekIndex * colWidth + 30}px`, // +30 for left padding
                            }}
                        >
                            {month}
                        </div>
                    ))}
                </div>

                <div className="flex">
                    {/* Day Labels - Left Side */}
                    <div className="flex flex-col justify-between py-1 pr-2 h-[110px]">
                        {DAYS.map((day, i) => (
                            <div key={i} className="text-[9px] font-mono text-muted-foreground/40 h-[10px] leading-[10px] text-right w-6">
                                {day}
                            </div>
                        ))}
                    </div>

                    {/* SVG Grid */}
                    <svg
                        width={weeks.length * colWidth + 20}
                        height={7 * rowHeight + 10}
                        className="overflow-visible"
                    >
                        {weeks.map((week, weekIndex) => (
                            <g key={weekIndex} transform={`translate(${weekIndex * colWidth}, 0)`}>
                                {week.map((day, dayIndex) => {
                                    const isCurrentYear = day.date.getFullYear() === year;
                                    const isFuture = day.date > new Date();

                                    // Calculate positions
                                    const x = 0;
                                    const y = dayIndex * rowHeight + ((weekIndex % 2) * oddColOffset);

                                    // Hex path (pointy topped) representing ~10px size
                                    // Center at (x + 6, y + 6)
                                    // M 6 0 L 11.2 3 L 11.2 9 L 6 12 L 0.8 9 L 0.8 3 Z
                                    const pathData = "M 6 0 L 11.2 3 L 11.2 9 L 6 12 L 0.8 9 L 0.8 3 Z";

                                    let fillClass = "fill-white/5";
                                    let strokeClass = "stroke-white/5";
                                    let filter = "";

                                    if (!isCurrentYear) {
                                        fillClass = "fill-transparent";
                                        strokeClass = "stroke-transparent";
                                    } else if (isFuture) {
                                        fillClass = "fill-white/5";
                                        strokeClass = "stroke-white/10";
                                    } else if (day.status === 'done') {
                                        fillClass = "fill-success";
                                        strokeClass = "stroke-success";
                                        filter = "drop-shadow(0 0 4px rgba(34,197,94,0.6))";
                                    } else if (day.status === 'missed') {
                                        fillClass = "fill-destructive";
                                        strokeClass = "stroke-destructive";
                                        filter = "drop-shadow(0 0 2px rgba(239,68,68,0.4))";
                                    } else {
                                        // Empty but passed
                                        fillClass = "fill-white/5";
                                        strokeClass = "stroke-white/20";
                                    }

                                    return (
                                        <Tooltip key={dayIndex}>
                                            <TooltipTrigger asChild>
                                                <g
                                                    transform={`translate(${x}, ${y})`}
                                                    className="cursor-pointer group hover:brightness-125 transition-all duration-300 origin-center"
                                                    style={{
                                                        transformBox: 'fill-box',
                                                        transformOrigin: 'center'
                                                    }}
                                                >
                                                    {/* Invisible hover target for easier mouse interaction */}
                                                    <circle cx="6" cy="6" r="7" fill="transparent" />

                                                    {/* Actual Hexagon */}
                                                    <path
                                                        d={pathData}
                                                        className={cn("transition-colors duration-300", fillClass, strokeClass)}
                                                        strokeWidth="1"
                                                        style={{ filter }}
                                                    />
                                                </g>
                                            </TooltipTrigger>
                                            {isCurrentYear && !isFuture && (
                                                <TooltipContent side="top" className="text-xs bg-background/90 backdrop-blur border-white/10">
                                                    <p className="font-mono font-bold mb-0.5">{formatDate(day.date)}</p>
                                                    <p className="text-muted-foreground">
                                                        {day.status === 'done' && <span className="text-success">Completato</span>}
                                                        {day.status === 'missed' && <span className="text-destructive">Mancato</span>}
                                                        {day.status === null && 'Nessuna attività'}
                                                    </p>
                                                </TooltipContent>
                                            )}
                                        </Tooltip>
                                    );
                                })}
                            </g>
                        ))}
                    </svg>
                </div>
            </div>

            {/* Legend */}
            <div className="flex items-center justify-between mt-6 pt-4 border-t border-white/5 max-w-[800px]">
                <p className="text-[10px] text-muted-foreground uppercase tracking-widest">Stato Missione</p>
                <div className="flex items-center gap-3 text-[10px] text-muted-foreground font-mono">
                    <div className="flex items-center gap-1.5 ">
                        <div className="w-3 h-3 rounded-[1px] bg-white/5 border border-white/10" />
                        <span>Futuro/Vuoto</span>
                    </div>
                    <div className="flex items-center gap-1.5">
                        <div className="w-3 h-3 rounded-[1px] bg-destructive border border-destructive shadow-[0_0_4px_rgba(239,68,68,0.4)]" />
                        <span>Fallito</span>
                    </div>
                    <div className="flex items-center gap-1.5">
                        <div className="w-3 h-3 rounded-[1px] bg-success border border-success shadow-[0_0_8px_rgba(34,197,94,0.6)]" />
                        <span>Completato</span>
                    </div>
                </div>
            </div>
        </div>
    );
}
