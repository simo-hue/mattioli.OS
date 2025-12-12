import { useState } from 'react';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { MonthlyChart } from '@/components/MonthlyChart';
import { useReadingTracker } from '@/hooks/useReadingTracker';
import { useReadingStats } from '@/hooks/useReadingStats';

const Mensile = () => {
  const { records } = useReadingTracker();
  const stats = useReadingStats(records);
  const currentYear = new Date().getFullYear();
  const [selectedYear, setSelectedYear] = useState(currentYear);

  const availableYears = stats.yearlyStats.length > 0
    ? stats.yearlyStats.map(y => y.year)
    : [currentYear];

  const selectedYearStats = stats.yearlyStats.find(y => y.year === selectedYear);

  return (
    <div className="container mx-auto px-3 sm:px-4 py-4 sm:py-8 max-w-3xl">
      <div className="space-y-4 sm:space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h1 className="text-xl sm:text-2xl font-display font-semibold text-foreground">
              Analisi mensile
            </h1>
            <p className="text-sm text-muted-foreground">
              Andamento mese per mese
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
        
        {selectedYearStats ? (
          <MonthlyChart yearStats={selectedYearStats} />
        ) : (
          <div className="bg-card rounded-xl p-6 sm:p-8 border border-border text-center">
            <p className="text-muted-foreground">Nessun dato per {selectedYear}</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default Mensile;
