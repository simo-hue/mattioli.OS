import { useState } from 'react';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { YearlyHeatmap } from '@/components/YearlyHeatmap';
import { useReadingTracker } from '@/hooks/useReadingTracker';
import { useReadingStats } from '@/hooks/useReadingStats';

const Mappa = () => {
  const { records } = useReadingTracker();
  const stats = useReadingStats(records);
  const currentYear = new Date().getFullYear();
  const [selectedYear, setSelectedYear] = useState(currentYear);

  const availableYears = stats.yearlyStats.length > 0
    ? stats.yearlyStats.map(y => y.year)
    : [currentYear];

  const selectedYearStats = stats.yearlyStats.find(y => y.year === selectedYear);

  return (
    <div className="container mx-auto px-3 sm:px-4 py-4 sm:py-8 max-w-4xl">
      <div className="space-y-4 sm:space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h1 className="text-xl sm:text-2xl font-display font-semibold text-foreground">
              Mappa attività
            </h1>
            <p className="text-sm text-muted-foreground">
              Visualizza il tuo anno di lettura
            </p>
          </div>
          <Select 
            value={selectedYear.toString()} 
            onValueChange={(v) => setSelectedYear(parseInt(v))}
          >
            <SelectTrigger className="w-full sm:w-32">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {availableYears.map(year => (
                <SelectItem key={year} value={year.toString()}>
                  {year}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        
        <YearlyHeatmap records={records} year={selectedYear} />
        
        {selectedYearStats && (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
            <div className="bg-card rounded-lg p-3 sm:p-4 border border-border text-center">
              <p className="text-xl sm:text-2xl font-display font-bold text-success">{selectedYearStats.totalDaysRead}</p>
              <p className="text-[10px] sm:text-xs text-muted-foreground">Giorni letti</p>
            </div>
            <div className="bg-card rounded-lg p-3 sm:p-4 border border-border text-center">
              <p className="text-xl sm:text-2xl font-display font-bold text-destructive">{selectedYearStats.totalDaysMissed}</p>
              <p className="text-[10px] sm:text-xs text-muted-foreground">Giorni saltati</p>
            </div>
            <div className="bg-card rounded-lg p-3 sm:p-4 border border-border text-center">
              <p className="text-xl sm:text-2xl font-display font-bold text-primary">{selectedYearStats.longestStreak}</p>
              <p className="text-[10px] sm:text-xs text-muted-foreground">Serie record</p>
            </div>
            <div className="bg-card rounded-lg p-3 sm:p-4 border border-border text-center">
              <p className="text-xl sm:text-2xl font-display font-bold text-foreground">{selectedYearStats.percentage}%</p>
              <p className="text-[10px] sm:text-xs text-muted-foreground">Tasso successo</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default Mappa;
