import { Book, BookX, Flame, Trophy, Calendar, TrendingUp } from 'lucide-react';
import { StatsCard } from './StatsCard';

interface DashboardProps {
  stats: {
    totalDone: number;
    totalMissed: number;
    monthDone: number;
    monthMissed: number;
    currentStreak: number;
    longestStreak: number;
  };
}

export function Dashboard({ stats }: DashboardProps) {
  const monthTotal = stats.monthDone + stats.monthMissed;
  const monthPercentage = monthTotal > 0 
    ? Math.round((stats.monthDone / monthTotal) * 100) 
    : 0;

  return (
    <div className="space-y-6">
      <div className="animate-fade-in">
        <h2 className="text-2xl font-display font-semibold text-foreground mb-1">
          Le tue statistiche
        </h2>
        <p className="text-muted-foreground">
          Monitora i tuoi progressi di lettura
        </p>
      </div>

      {/* Streak highlight */}
      <div className="bg-gradient-to-br from-primary/10 via-accent/20 to-primary/5 rounded-2xl p-6 border border-primary/20 animate-fade-in" style={{ animationDelay: '100ms' }}>
        <div className="flex items-center gap-4">
          <div className="p-3 bg-primary/20 rounded-xl">
            <Flame className="w-8 h-8 text-primary" />
          </div>
          <div>
            <p className="text-sm font-medium text-muted-foreground">Serie attuale</p>
            <p className="text-4xl font-display font-bold text-foreground">
              {stats.currentStreak} <span className="text-xl text-muted-foreground">giorni</span>
            </p>
          </div>
        </div>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-2 gap-4">
        <StatsCard
          title="Giorni letti"
          value={stats.totalDone}
          icon={Book}
          variant="success"
          delay={150}
        />
        <StatsCard
          title="Giorni saltati"
          value={stats.totalMissed}
          icon={BookX}
          variant="destructive"
          delay={200}
        />
        <StatsCard
          title="Serie record"
          value={stats.longestStreak}
          icon={Trophy}
          delay={250}
        />
        <StatsCard
          title="Questo mese"
          value={`${monthPercentage}%`}
          icon={TrendingUp}
          variant={monthPercentage >= 70 ? 'success' : monthPercentage >= 40 ? 'default' : 'destructive'}
          delay={300}
        />
      </div>

      {/* Monthly breakdown */}
      <div className="bg-card rounded-xl p-5 border border-border animate-fade-in" style={{ animationDelay: '350ms' }}>
        <div className="flex items-center gap-2 mb-4">
          <Calendar className="w-5 h-5 text-primary" />
          <h3 className="font-display font-semibold text-foreground">Questo mese</h3>
        </div>
        
        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <span className="text-sm text-muted-foreground">Giorni letti</span>
            <span className="font-semibold text-success">{stats.monthDone}</span>
          </div>
          <div className="flex justify-between items-center">
            <span className="text-sm text-muted-foreground">Giorni saltati</span>
            <span className="font-semibold text-destructive">{stats.monthMissed}</span>
          </div>
          <div className="h-2 bg-muted rounded-full overflow-hidden mt-2">
            <div 
              className="h-full bg-success rounded-full transition-all duration-500"
              style={{ width: `${monthPercentage}%` }}
            />
          </div>
        </div>
      </div>
    </div>
  );
}
