import { OverallStats, YearStats, MonthStats } from '@/hooks/useReadingStats';
import { ReadingRecord } from '@/hooks/useReadingTracker';
import { useBadges } from '@/hooks/useBadges';
import { cn } from '@/lib/utils';
import { 
  Book, BookX, Flame, Trophy, Calendar, TrendingUp, 
  Target, Activity, Star, Clock, Award, Zap, Timer, Lightbulb
} from 'lucide-react';
import { StatsCard } from './StatsCard';
import { WeeklyTrendChart } from './WeeklyTrendChart';
import { BadgesDisplay } from './BadgesDisplay';
import { MonthlyGoalSetting } from './MonthlyGoalSetting';

interface AdvancedDashboardProps {
  overall: OverallStats;
  currentYearStats: YearStats | null;
  currentMonthStats: MonthStats;
  records: ReadingRecord;
  monthlyGoal: number;
  onGoalChange: (newGoal: number) => void;
}

export function AdvancedDashboard({ overall, currentYearStats, currentMonthStats, records, monthlyGoal, onGoalChange }: AdvancedDashboardProps) {
  const { badges, unlockedCount, totalBadges } = useBadges(
    overall,
    records,
    currentMonthStats,
    currentYearStats,
    monthlyGoal
  );

  const today = new Date();
  const daysInCurrentMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="animate-fade-in">
        <h2 className="text-2xl font-display font-semibold text-foreground mb-1">
          Panoramica
        </h2>
        <p className="text-muted-foreground">
          Le tue statistiche di lettura complete
        </p>
      </div>

      {/* Streak highlight */}
      <div className="bg-gradient-to-br from-primary/10 via-accent/20 to-primary/5 rounded-2xl p-6 border border-primary/20 animate-fade-in">
        <div className="flex items-center gap-4">
          <div className="p-3 bg-primary/20 rounded-xl">
            <Flame className="w-8 h-8 text-primary" />
          </div>
          <div className="flex-1">
            <p className="text-sm font-medium text-muted-foreground">Serie attuale</p>
            <p className="text-4xl font-display font-bold text-foreground">
              {overall.currentStreak} <span className="text-xl text-muted-foreground">giorni</span>
            </p>
          </div>
          <div className="text-right">
            <p className="text-xs text-muted-foreground">Record</p>
            <p className="text-lg font-semibold text-primary flex items-center gap-1">
              <Trophy className="w-4 h-4" />
              {overall.longestStreak}
            </p>
          </div>
        </div>
      </div>

      {/* Monthly Goal & Badges */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <MonthlyGoalSetting
          goal={monthlyGoal}
          onGoalChange={onGoalChange}
          currentProgress={currentMonthStats.daysRead}
          daysInMonth={daysInCurrentMonth}
        />
        <BadgesDisplay
          badges={badges}
          unlockedCount={unlockedCount}
          totalBadges={totalBadges}
        />
      </div>

      {/* Quick stats grid */}
      <div className="grid grid-cols-2 gap-3">
        <StatsCard
          title="Totale letti"
          value={overall.totalDaysRead}
          icon={Book}
          variant="success"
          delay={100}
        />
        <StatsCard
          title="Totale saltati"
          value={overall.totalDaysMissed}
          icon={BookX}
          variant="destructive"
          delay={150}
        />
        <StatsCard
          title="Consistenza"
          value={`${overall.consistencyScore}%`}
          icon={Target}
          variant={overall.consistencyScore >= 70 ? 'success' : 'default'}
          delay={200}
        />
        <StatsCard
          title="Giorni attivo"
          value={overall.daysSinceStart}
          icon={Clock}
          delay={250}
        />
      </div>

      {/* Best/Worst day of week */}
      {(overall.bestDayOfWeek || overall.worstDayOfWeek) && (
        <div className="grid grid-cols-2 gap-3 animate-fade-in" style={{ animationDelay: '300ms' }}>
          {overall.bestDayOfWeek && (
            <div className="bg-success/5 border border-success/20 rounded-xl p-4">
              <div className="flex items-center gap-2 mb-1">
                <Star className="w-4 h-4 text-success" />
                <span className="text-xs text-muted-foreground">Giorno migliore</span>
              </div>
              <p className="font-semibold text-foreground">{overall.bestDayOfWeek.day}</p>
              <p className="text-sm text-success">{overall.bestDayOfWeek.percentage}% lettura</p>
            </div>
          )}
          {overall.worstDayOfWeek && (
            <div className="bg-destructive/5 border border-destructive/20 rounded-xl p-4">
              <div className="flex items-center gap-2 mb-1">
                <Activity className="w-4 h-4 text-destructive" />
                <span className="text-xs text-muted-foreground">Da migliorare</span>
              </div>
              <p className="font-semibold text-foreground">{overall.worstDayOfWeek.day}</p>
              <p className="text-sm text-destructive">{overall.worstDayOfWeek.percentage}% lettura</p>
            </div>
          )}
        </div>
      )}

      {/* New Advanced Metrics */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 animate-fade-in" style={{ animationDelay: '280ms' }}>
        {/* Average time between sessions */}
        {overall.averageTimeBetweenSessions !== null && (
          <div className="bg-card border border-border rounded-xl p-4">
            <div className="flex items-center gap-2 mb-2">
              <Timer className="w-4 h-4 text-primary" />
              <span className="text-xs text-muted-foreground">Tempo medio tra sessioni</span>
            </div>
            <p className="text-2xl font-display font-bold text-foreground">
              {overall.averageTimeBetweenSessions} <span className="text-sm text-muted-foreground">giorni</span>
            </p>
            <p className="text-xs text-muted-foreground mt-1">
              {overall.averageTimeBetweenSessions <= 1.5 ? 'Ottima costanza!' : 
               overall.averageTimeBetweenSessions <= 3 ? 'Buon ritmo' : 'Prova a leggere più spesso'}
            </p>
          </div>
        )}

        {/* Monthly goal prediction */}
        {overall.monthlyGoalPrediction && (
          <div className={cn(
            "border rounded-xl p-4",
            overall.monthlyGoalPrediction.onTrack 
              ? "bg-success/5 border-success/20" 
              : "bg-warning/5 border-warning/20"
          )}>
            <div className="flex items-center gap-2 mb-2">
              <Lightbulb className={cn(
                "w-4 h-4",
                overall.monthlyGoalPrediction.onTrack ? "text-success" : "text-warning"
              )} />
              <span className="text-xs text-muted-foreground">Previsione mensile</span>
            </div>
            <p className="text-2xl font-display font-bold text-foreground">
              ~{overall.monthlyGoalPrediction.predictedDays} <span className="text-sm text-muted-foreground">giorni</span>
            </p>
            <p className={cn(
              "text-xs mt-1",
              overall.monthlyGoalPrediction.onTrack ? "text-success" : "text-warning"
            )}>
              {overall.monthlyGoalPrediction.onTrack 
                ? 'Sei in linea con l\'obiettivo!' 
                : `Ti mancano ${overall.monthlyGoalPrediction.daysNeeded} giorni per completare il mese`}
            </p>
          </div>
        )}
      </div>

      {/* Weekly Trend Chart */}
      {overall.weeklyTrend.length > 0 && (
        <div className="bg-card rounded-xl p-5 border border-border animate-fade-in" style={{ animationDelay: '320ms' }}>
          <div className="flex items-center gap-2 mb-4">
            <TrendingUp className="w-5 h-5 text-primary" />
            <h3 className="font-display font-semibold text-foreground">
              Trend settimanale
            </h3>
          </div>
          <WeeklyTrendChart data={overall.weeklyTrend} />
        </div>
      )}

      {/* Current month details */}
      <div className="bg-card rounded-xl p-5 border border-border animate-fade-in" style={{ animationDelay: '350ms' }}>
        <div className="flex items-center gap-2 mb-4">
          <Calendar className="w-5 h-5 text-primary" />
          <h3 className="font-display font-semibold text-foreground">
            {currentMonthStats.name} {currentMonthStats.year}
          </h3>
        </div>
        
        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <span className="text-sm text-muted-foreground">Giorni letti</span>
            <span className="font-semibold text-success">{currentMonthStats.daysRead}</span>
          </div>
          <div className="flex justify-between items-center">
            <span className="text-sm text-muted-foreground">Giorni saltati</span>
            <span className="font-semibold text-destructive">{currentMonthStats.daysMissed}</span>
          </div>
          <div className="flex justify-between items-center">
            <span className="text-sm text-muted-foreground">Serie migliore</span>
            <span className="font-semibold text-primary">{currentMonthStats.bestStreak} giorni</span>
          </div>
          
          <div className="pt-2">
            <div className="flex justify-between text-xs mb-1">
              <span className="text-muted-foreground">Progresso</span>
              <span className={cn(
                "font-semibold",
                currentMonthStats.percentage >= 70 ? "text-success" : 
                currentMonthStats.percentage >= 40 ? "text-foreground" : "text-destructive"
              )}>
                {currentMonthStats.percentage}%
              </span>
            </div>
            <div className="h-2 bg-muted rounded-full overflow-hidden">
              <div 
                className={cn(
                  "h-full rounded-full transition-all duration-500",
                  currentMonthStats.percentage >= 70 ? "bg-success" : 
                  currentMonthStats.percentage >= 40 ? "bg-primary" : "bg-destructive"
                )}
                style={{ width: `${currentMonthStats.percentage}%` }}
              />
            </div>
          </div>
        </div>
      </div>

      {/* Year summary */}
      {currentYearStats && (
        <div className="bg-card rounded-xl p-5 border border-border animate-fade-in" style={{ animationDelay: '400ms' }}>
          <div className="flex items-center gap-2 mb-4">
            <Award className="w-5 h-5 text-primary" />
            <h3 className="font-display font-semibold text-foreground">
              Anno {currentYearStats.year}
            </h3>
          </div>
          
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-xs text-muted-foreground">Media settimanale</p>
              <p className="text-xl font-display font-bold text-foreground">
                {currentYearStats.averagePerWeek} <span className="text-sm text-muted-foreground">giorni</span>
              </p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Media mensile</p>
              <p className="text-xl font-display font-bold text-foreground">
                {currentYearStats.averagePerMonth} <span className="text-sm text-muted-foreground">giorni</span>
              </p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Serie record</p>
              <p className="text-xl font-display font-bold text-primary flex items-center gap-1">
                <Zap className="w-4 h-4" />
                {currentYearStats.longestStreak}
              </p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Tasso successo</p>
              <p className={cn(
                "text-xl font-display font-bold",
                currentYearStats.percentage >= 70 ? "text-success" : 
                currentYearStats.percentage >= 40 ? "text-foreground" : "text-destructive"
              )}>
                {currentYearStats.percentage}%
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
