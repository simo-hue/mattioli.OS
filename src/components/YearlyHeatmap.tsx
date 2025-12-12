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
    
    let currentDate = new Date(startDate);
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
    <div className="bg-card rounded-lg sm:rounded-xl p-3 sm:p-4 border border-border overflow-x-auto">
      <h3 className="font-display font-semibold text-sm sm:text-base text-foreground mb-3 sm:mb-4">
        Mappa annuale {year}
      </h3>
      
      <div className="inline-flex flex-col gap-1 min-w-max">
        {/* Month labels */}
        <div className="flex ml-6 sm:ml-8 mb-1">
          {monthLabels.map(({ month, weekIndex }, i) => (
            <div
              key={`${month}-${i}`}
              className="text-[10px] sm:text-xs text-muted-foreground"
              style={{ 
                position: 'relative',
                left: `${weekIndex * 12}px`,
                marginRight: i < monthLabels.length - 1 
                  ? `${(monthLabels[i + 1].weekIndex - weekIndex - 1) * 12}px`
                  : 0
              }}
            >
              {month}
            </div>
          ))}
        </div>
        
        <div className="flex gap-0.5 sm:gap-1">
          {/* Day labels */}
          <div className="flex flex-col gap-0.5 sm:gap-1 mr-0.5 sm:mr-1">
            {DAYS.map((day, i) => (
              <div key={i} className="w-5 sm:w-6 h-2.5 sm:h-3 text-[8px] sm:text-xs text-muted-foreground flex items-center">
                {day}
              </div>
            ))}
          </div>
          
          {/* Heatmap grid */}
          <div className="flex gap-[1px] sm:gap-[2px]">
            {weeks.map((week, weekIndex) => (
              <div key={weekIndex} className="flex flex-col gap-[1px] sm:gap-[2px]">
                {week.map((day, dayIndex) => {
                  const isCurrentYear = day.date.getFullYear() === year;
                  const isFuture = day.date > new Date();
                  
                  return (
                    <Tooltip key={dayIndex}>
                      <TooltipTrigger asChild>
                        <div
                          className={cn(
                            "w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-sm transition-all",
                            !isCurrentYear && "opacity-0",
                            isCurrentYear && isFuture && "bg-muted/30",
                            isCurrentYear && !isFuture && day.status === null && "bg-reading-neutral/50",
                            day.status === 'done' && "bg-reading-done",
                            day.status === 'missed' && "bg-reading-missed",
                          )}
                        />
                      </TooltipTrigger>
                      {isCurrentYear && !isFuture && (
                        <TooltipContent side="top" className="text-xs">
                          <p className="font-medium">{formatDate(day.date)}</p>
                          <p className="text-muted-foreground">
                            {day.status === 'done' && 'Letto ✓'}
                            {day.status === 'missed' && 'Non letto ✗'}
                            {day.status === null && 'Non segnato'}
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
      <div className="flex items-center gap-2 sm:gap-4 mt-3 sm:mt-4 text-[10px] sm:text-xs text-muted-foreground">
        <span>Meno</span>
        <div className="flex gap-0.5 sm:gap-1">
          <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-sm bg-reading-neutral/50" />
          <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-sm bg-reading-missed/50" />
          <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-sm bg-reading-missed" />
          <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-sm bg-reading-done/50" />
          <div className="w-2.5 h-2.5 sm:w-3 sm:h-3 rounded-sm bg-reading-done" />
        </div>
        <span>Più</span>
      </div>
    </div>
  );
}
