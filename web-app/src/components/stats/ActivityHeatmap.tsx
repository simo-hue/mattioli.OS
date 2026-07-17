import { DayActivity } from '@/hooks/useHabitStats';
import { cn } from '@/lib/utils';
import { differenceInDays, subDays, format } from 'date-fns';

interface ActivityHeatmapProps {
    data: DayActivity[];
}

export function ActivityHeatmap({ data }: ActivityHeatmapProps) {
    // We want to show roughly the last 3-4 months on mobile, more on desktop
    // For simplicity, let's just show the last ~100 days
    const today = new Date();
    const daysToShow = 105; // 15 weeks * 7 days

    const relevantData = data.filter(d =>
        differenceInDays(today, new Date(d.date)) < daysToShow
    );

    // Fill in missing days
    const fullData: DayActivity[] = [];
    for (let i = daysToShow - 1; i >= 0; i--) {
        const date = subDays(today, i);
        const key = format(date, 'yyyy-MM-dd');
        const found = relevantData.find(d => d.date === key);
        fullData.push(found || { date: key, count: 0, intensity: 0 });
    }

    return (
        <div className="bg-card/50 backdrop-blur-sm rounded-3xl p-6 border border-white/5 shadow-xl">
            <h3 className="text-lg font-display font-semibold mb-4">Costanza</h3>
            <div className="flex flex-wrap gap-1 justify-center sm:justify-start">
                {fullData.map((day) => (
                    <div
                        key={day.date}
                        className={cn(
                            "w-3 h-3 sm:w-4 sm:h-4 rounded-sm transition-all hover:scale-125 hover:z-10 relative cursor-pointer",
                            day.intensity === 0 && "bg-muted/10",
                            day.intensity === 1 && "bg-primary/30",
                            day.intensity === 2 && "bg-primary/50",
                            day.intensity === 3 && "bg-primary/70",
                            day.intensity === 4 && "bg-primary",
                        )}
                        title={`${day.date}: ${day.count} habits`}
                    />
                ))}
            </div>
            <div className="flex items-center justify-end gap-2 mt-4 text-xs text-muted-foreground">
                <span>Meno</span>
                <div className="flex gap-1">
                    <div className="w-3 h-3 rounded-sm bg-muted/10" />
                    <div className="w-3 h-3 rounded-sm bg-primary/30" />
                    <div className="w-3 h-3 rounded-sm bg-primary/50" />
                    <div className="w-3 h-3 rounded-sm bg-primary/70" />
                    <div className="w-3 h-3 rounded-sm bg-primary" />
                </div>
                <span>Più</span>
            </div>
        </div>
    );
}
