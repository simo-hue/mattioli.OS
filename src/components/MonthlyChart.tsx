import { forwardRef } from 'react';
import { YearStats, MonthStats } from '@/hooks/useReadingStats';
import { cn } from '@/lib/utils';
import { TrendingUp, TrendingDown, BarChart3 } from 'lucide-react';

interface MonthlyChartProps {
  yearStats: YearStats;
}

export const MonthlyChart = forwardRef<HTMLDivElement, MonthlyChartProps>(
  function MonthlyChart({ yearStats }, ref) {
  const maxDays = Math.max(...yearStats.monthlyBreakdown.map(m => m.daysTotal), 1);
  
  return (
    <div ref={ref} className="bg-card rounded-lg sm:rounded-xl p-4 sm:p-5 border border-border">
      <div className="flex items-center gap-2 mb-3 sm:mb-4">
        <BarChart3 className="w-4 h-4 sm:w-5 sm:h-5 text-primary" />
        <h3 className="font-display font-semibold text-sm sm:text-base text-foreground">
          Andamento mensile {yearStats.year}
        </h3>
      </div>
      
      <div className="space-y-2 sm:space-y-3">
        {yearStats.monthlyBreakdown.map((month) => (
          <MonthBar key={month.month} month={month} maxDays={maxDays} />
        ))}
      </div>
      
      {/* Summary cards */}
      <div className="grid grid-cols-2 gap-2 sm:gap-4 mt-4 sm:mt-6 pt-3 sm:pt-4 border-t border-border">
        {yearStats.bestMonth && (
          <div className="flex items-start gap-2 sm:gap-3 p-2 sm:p-3 bg-success/5 rounded-lg border border-success/20">
            <TrendingUp className="w-4 h-4 sm:w-5 sm:h-5 text-success mt-0.5 flex-shrink-0" />
            <div className="min-w-0">
              <p className="text-[10px] sm:text-xs text-muted-foreground">Mese migliore</p>
              <p className="font-semibold text-sm sm:text-base text-foreground truncate">{yearStats.bestMonth.name}</p>
              <p className="text-xs sm:text-sm text-success">{yearStats.bestMonth.percentage}%</p>
            </div>
          </div>
        )}
        
        {yearStats.worstMonth && yearStats.worstMonth.daysTotal > 0 && (
          <div className="flex items-start gap-2 sm:gap-3 p-2 sm:p-3 bg-destructive/5 rounded-lg border border-destructive/20">
            <TrendingDown className="w-4 h-4 sm:w-5 sm:h-5 text-destructive mt-0.5 flex-shrink-0" />
            <div className="min-w-0">
              <p className="text-[10px] sm:text-xs text-muted-foreground">Mese peggiore</p>
              <p className="font-semibold text-sm sm:text-base text-foreground truncate">{yearStats.worstMonth.name}</p>
              <p className="text-xs sm:text-sm text-destructive">{yearStats.worstMonth.percentage}%</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
});

function MonthBar({ month, maxDays }: { month: MonthStats; maxDays: number }) {
  const today = new Date();
  const isCurrentMonth = month.month === today.getMonth() && month.year === today.getFullYear();
  const isFutureMonth = new Date(month.year, month.month, 1) > today;
  
  const doneWidth = maxDays > 0 ? (month.daysRead / maxDays) * 100 : 0;
  const missedWidth = maxDays > 0 ? (month.daysMissed / maxDays) * 100 : 0;
  
  return (
    <div className={cn(
      "group",
      isFutureMonth && "opacity-30"
    )}>
      <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-1 gap-0.5 sm:gap-0">
        <div className="flex items-center gap-1.5 sm:gap-2">
          <span className={cn(
            "text-xs sm:text-sm font-medium w-12 sm:w-20",
            isCurrentMonth ? "text-primary" : "text-foreground"
          )}>
            {month.name.slice(0, 3)}
          </span>
          {isCurrentMonth && (
            <span className="text-[10px] sm:text-xs bg-primary/10 text-primary px-1.5 sm:px-2 py-0.5 rounded-full">
              Attuale
            </span>
          )}
        </div>
        <div className="flex items-center gap-2 sm:gap-3 text-[10px] sm:text-xs text-muted-foreground">
          <span className="text-success">{month.daysRead} letti</span>
          <span className="text-destructive">{month.daysMissed} saltati</span>
          {month.daysTotal > 0 && (
            <span className={cn(
              "font-semibold",
              month.percentage >= 70 ? "text-success" : month.percentage >= 40 ? "text-foreground" : "text-destructive"
            )}>
              {month.percentage}%
            </span>
          )}
        </div>
      </div>
      
      <div className="h-1.5 sm:h-2 bg-muted rounded-full overflow-hidden flex">
        <div 
          className="h-full bg-success transition-all duration-500"
          style={{ width: `${doneWidth}%` }}
        />
        <div 
          className="h-full bg-destructive transition-all duration-500"
          style={{ width: `${missedWidth}%` }}
        />
      </div>
    </div>
  );
}
