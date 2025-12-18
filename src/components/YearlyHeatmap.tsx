import { useMemo } from 'react';
import { cn } from '@/lib/utils';
import { ReadingRecord } from '@/hooks/useReadingTracker';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';

interface YearlyHeatmapProps {
  records: ReadingRecord;
  year: number;
}

const MONTHS = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
const DAYS = ['Lun', '', 'Mer', '', 'Ven', '', 'Dom'];

export function YearlyHeatmap({ records, year }: YearlyHeatmapProps) {
  const weeks = useMemo(() => {
    const result: { date: Date; status: 'done' | 'missed' | null }[][] = [];

    // Start from first day of year
    const startDate = new Date(year, 0, 1);
    // Adjust to Monday
    const startDay = startDate.getDay();
    const daysToSubtract = startDay === 0 ? 6 : startDay - 1;
    startDate.setDate(startDate.getDate() - daysToSubtract);

    const endDate = new Date(year, 11, 31);
    const today = new Date();

    const currentDate = new Date(startDate);
    let currentWeek: { date: Date; status: 'done' | 'missed' | null }[] = [];

    while (currentDate <= endDate || currentWeek.length > 0) {
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

  return (
    <div className="glass-card rounded-2xl p-4 sm:p-6 overflow-x-auto">
      <h3 className="font-display font-semibold text-lg text-foreground mb-4 flex items-center gap-2">
        <span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" />
        Mappa Annuale {year}
      </h3>

      <div className="inline-flex flex-col gap-1 min-w-max">
        {/* Month labels */}
        <div className="flex ml-8 mb-2">
          {monthLabels.map(({ month, weekIndex }, i) => (
            <div
              key={`${month}-${i}`}
              className="text-[10px] uppercase font-bold tracking-widest text-muted-foreground/50"
              style={{
                position: 'relative',
                left: `${weekIndex * 14}px`, // Adjusted for larger gap
                marginRight: i < monthLabels.length - 1
                  ? `${(monthLabels[i + 1].weekIndex - weekIndex - 1) * 14}px`
                  : 0
              }}
            >
              {month}
            </div>
          ))}
        </div>

        <div className="flex gap-2">
          {/* Day labels */}
          <div className="flex flex-col gap-[3px] mt-[1px]">
            {DAYS.map((day, i) => (
              <div key={i} className="h-3 text-[9px] font-mono text-muted-foreground/40 flex items-center justify-end w-6">
                {day}
              </div>
            ))}
          </div>

          {/* Heatmap grid */}
          <div className="flex gap-[3px]">
            {weeks.map((week, weekIndex) => (
              <div key={weekIndex} className="flex flex-col gap-[3px]">
                {week.map((day, dayIndex) => {
                  const isCurrentYear = day.date.getFullYear() === year;
                  const isFuture = day.date > new Date();

                  return (
                    <Tooltip key={dayIndex}>
                      <TooltipTrigger asChild>
                        <div
                          className={cn(
                            "w-3 h-3 rounded-[2px] transition-all duration-300",
                            !isCurrentYear && "opacity-0",
                            isCurrentYear && isFuture && "bg-white/5 border border-white/5",
                            isCurrentYear && !isFuture && day.status === null && "bg-white/5 border border-white/5 hover:border-white/20",
                            day.status === 'done' && "bg-success/20 border border-success/40 shadow-[0_0_8px_rgba(34,197,94,0.3)]",
                            day.status === 'missed' && "bg-destructive/20 border border-destructive/40",
                          )}
                        />
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
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Legend */}
      <div className="flex items-center justify-between mt-6 pt-4 border-t border-white/5">
        <p className="text-[10px] text-muted-foreground uppercase tracking-widest">Intensità attività</p>
        <div className="flex items-center gap-2 text-[10px] text-muted-foreground font-mono">
          <span>Meno</span>
          <div className="flex gap-1">
            <div className="w-3 h-3 rounded-[2px] bg-white/5 border border-white/5" />
            <div className="w-3 h-3 rounded-[2px] bg-destructive/20 border border-destructive/40" />
            <div className="w-3 h-3 rounded-[2px] bg-success/20 border border-success/40" />
            <div className="w-3 h-3 rounded-[2px] bg-success/40 border border-success/60 shadow-[0_0_4px_rgba(34,197,94,0.4)]" />
          </div>
          <span>Più</span>
        </div>
      </div>
    </div>
  );
}
