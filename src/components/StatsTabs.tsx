import { useState } from 'react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { YearlyHeatmap } from './YearlyHeatmap';
import { MonthlyChart } from './MonthlyChart';
import { AdvancedDashboard } from './AdvancedDashboard';
import { ReadingRecord } from '@/hooks/useReadingTracker';
import { useReadingStats, YearStats } from '@/hooks/useReadingStats';
import { BarChart2, Grid3X3, PieChart } from 'lucide-react';

interface StatsTabsProps {
  records: ReadingRecord;
  monthlyGoal: number;
  onGoalChange: (newGoal: number) => void;
}

export function StatsTabs({ records, monthlyGoal, onGoalChange }: StatsTabsProps) {
  const stats = useReadingStats(records);
  const currentYear = new Date().getFullYear();
  const [selectedYear, setSelectedYear] = useState(currentYear);
  
  const availableYears = stats.yearlyStats.length > 0 
    ? stats.yearlyStats.map(y => y.year)
    : [currentYear];
  
  const selectedYearStats = stats.yearlyStats.find(y => y.year === selectedYear);

  return (
    <div className="space-y-6">
      <Tabs defaultValue="overview" className="w-full">
        <TabsList className="grid w-full grid-cols-3 mb-6">
          <TabsTrigger value="overview" className="flex items-center gap-2">
            <PieChart className="w-4 h-4" />
            <span className="hidden sm:inline">Panoramica</span>
          </TabsTrigger>
          <TabsTrigger value="heatmap" className="flex items-center gap-2">
            <Grid3X3 className="w-4 h-4" />
            <span className="hidden sm:inline">Mappa</span>
          </TabsTrigger>
          <TabsTrigger value="monthly" className="flex items-center gap-2">
            <BarChart2 className="w-4 h-4" />
            <span className="hidden sm:inline">Mensile</span>
          </TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="mt-0">
          <AdvancedDashboard 
            overall={stats.overall}
            currentYearStats={stats.currentYearStats}
            currentMonthStats={stats.currentMonthStats}
            records={records}
            monthlyGoal={monthlyGoal}
            onGoalChange={onGoalChange}
          />
        </TabsContent>

        <TabsContent value="heatmap" className="mt-0 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-display font-semibold text-foreground">
              Mappa attività
            </h2>
            <Select 
              value={selectedYear.toString()} 
              onValueChange={(v) => setSelectedYear(parseInt(v))}
            >
              <SelectTrigger className="w-32">
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
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              <div className="bg-card rounded-lg p-4 border border-border text-center">
                <p className="text-2xl font-display font-bold text-success">{selectedYearStats.totalDaysRead}</p>
                <p className="text-xs text-muted-foreground">Giorni letti</p>
              </div>
              <div className="bg-card rounded-lg p-4 border border-border text-center">
                <p className="text-2xl font-display font-bold text-destructive">{selectedYearStats.totalDaysMissed}</p>
                <p className="text-xs text-muted-foreground">Giorni saltati</p>
              </div>
              <div className="bg-card rounded-lg p-4 border border-border text-center">
                <p className="text-2xl font-display font-bold text-primary">{selectedYearStats.longestStreak}</p>
                <p className="text-xs text-muted-foreground">Serie record</p>
              </div>
              <div className="bg-card rounded-lg p-4 border border-border text-center">
                <p className="text-2xl font-display font-bold text-foreground">{selectedYearStats.percentage}%</p>
                <p className="text-xs text-muted-foreground">Tasso successo</p>
              </div>
            </div>
          )}
        </TabsContent>

        <TabsContent value="monthly" className="mt-0 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-display font-semibold text-foreground">
              Analisi mensile
            </h2>
            <Select 
              value={selectedYear.toString()} 
              onValueChange={(v) => setSelectedYear(parseInt(v))}
            >
              <SelectTrigger className="w-32">
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
            <div className="bg-card rounded-xl p-8 border border-border text-center">
              <p className="text-muted-foreground">Nessun dato per {selectedYear}</p>
            </div>
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
