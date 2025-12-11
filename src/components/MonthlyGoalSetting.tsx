import { cn } from '@/lib/utils';
import { Target, Minus, Plus, Check } from 'lucide-react';
import { Button } from '@/components/ui/button';

interface MonthlyGoalSettingProps {
  goal: number;
  onGoalChange: (newGoal: number) => void;
  currentProgress: number;
  daysInMonth: number;
}

export function MonthlyGoalSetting({ 
  goal, 
  onGoalChange, 
  currentProgress,
  daysInMonth 
}: MonthlyGoalSettingProps) {
  const progressPercentage = Math.min(100, Math.round((currentProgress / goal) * 100));
  const isGoalReached = currentProgress >= goal;
  const daysRemaining = daysInMonth - new Date().getDate();
  const daysNeeded = Math.max(0, goal - currentProgress);
  const canReachGoal = daysNeeded <= daysRemaining;

  return (
    <div className="bg-card rounded-xl p-5 border border-border animate-fade-in">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Target className="w-5 h-5 text-primary" />
          <h3 className="font-display font-semibold text-foreground">
            Obiettivo mensile
          </h3>
        </div>
      </div>

      {/* Goal adjuster */}
      <div className="flex items-center justify-center gap-4 mb-4">
        <Button
          variant="outline"
          size="icon"
          onClick={() => onGoalChange(goal - 1)}
          disabled={goal <= 1}
          className="h-8 w-8"
        >
          <Minus className="w-4 h-4" />
        </Button>
        <div className="text-center">
          <span className="text-3xl font-display font-bold text-foreground">{goal}</span>
          <span className="text-sm text-muted-foreground ml-1">giorni</span>
        </div>
        <Button
          variant="outline"
          size="icon"
          onClick={() => onGoalChange(goal + 1)}
          disabled={goal >= 31}
          className="h-8 w-8"
        >
          <Plus className="w-4 h-4" />
        </Button>
      </div>

      {/* Progress */}
      <div className="space-y-2">
        <div className="flex justify-between text-sm">
          <span className="text-muted-foreground">Progresso</span>
          <span className={cn(
            'font-semibold',
            isGoalReached ? 'text-success' : 'text-foreground'
          )}>
            {currentProgress}/{goal}
            {isGoalReached && <Check className="w-4 h-4 inline ml-1" />}
          </span>
        </div>
        <div className="h-3 bg-muted rounded-full overflow-hidden">
          <div
            className={cn(
              'h-full rounded-full transition-all duration-500',
              isGoalReached ? 'bg-success' : 'bg-primary'
            )}
            style={{ width: `${progressPercentage}%` }}
          />
        </div>
        <p className={cn(
          'text-xs text-center',
          isGoalReached ? 'text-success' : canReachGoal ? 'text-muted-foreground' : 'text-warning'
        )}>
          {isGoalReached 
            ? '🎉 Obiettivo raggiunto!' 
            : canReachGoal 
              ? `Ti mancano ${daysNeeded} giorni (${daysRemaining} giorni rimanenti)`
              : `Difficile: servono ${daysNeeded} giorni ma ne restano ${daysRemaining}`
          }
        </p>
      </div>
    </div>
  );
}
