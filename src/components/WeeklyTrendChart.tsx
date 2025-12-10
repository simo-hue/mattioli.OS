import { WeeklyTrend } from '@/hooks/useReadingStats';
import { TrendingUp, TrendingDown, Minus } from 'lucide-react';
import { cn } from '@/lib/utils';

interface WeeklyTrendChartProps {
  data: WeeklyTrend[];
}

export function WeeklyTrendChart({ data }: WeeklyTrendChartProps) {
  const maxPercentage = Math.max(...data.map(d => d.percentage), 100);
  
  return (
    <div className="space-y-3">
      {data.map((week, index) => (
        <div 
          key={week.weekNumber} 
          className="flex items-center gap-3 animate-fade-in"
          style={{ animationDelay: `${index * 50}ms` }}
        >
          <div className="w-20 text-xs text-muted-foreground shrink-0">
            {week.weekLabel}
          </div>
          
          <div className="flex-1 h-6 bg-muted/50 rounded-full overflow-hidden relative">
            <div 
              className={cn(
                "h-full rounded-full transition-all duration-500",
                week.percentage >= 70 ? "bg-success" : 
                week.percentage >= 40 ? "bg-primary" : "bg-destructive"
              )}
              style={{ width: `${(week.percentage / maxPercentage) * 100}%` }}
            />
            <span className="absolute inset-0 flex items-center justify-center text-xs font-medium text-foreground">
              {week.daysRead} giorni ({week.percentage}%)
            </span>
          </div>
          
          <div className="w-6 shrink-0">
            {week.trend === 'up' && (
              <TrendingUp className="w-4 h-4 text-success" />
            )}
            {week.trend === 'down' && (
              <TrendingDown className="w-4 h-4 text-destructive" />
            )}
            {week.trend === 'stable' && (
              <Minus className="w-4 h-4 text-muted-foreground" />
            )}
          </div>
        </div>
      ))}
    </div>
  );
}