import { BookOpen } from 'lucide-react';
import { ReadingCalendar } from '@/components/ReadingCalendar';
import { StatsTabs } from '@/components/StatsTabs';
import { useReadingTracker } from '@/hooks/useReadingTracker';
import { useMonthlyGoal } from '@/hooks/useMonthlyGoal';

const Index = () => {
  const { records, getStatus, toggleStatus } = useReadingTracker();
  const { goal, updateGoal } = useMonthlyGoal();

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-10">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-primary/10 rounded-lg">
              <BookOpen className="w-6 h-6 text-primary" />
            </div>
            <div>
              <h1 className="text-xl font-display font-bold text-foreground">
                Reading Tracker
              </h1>
              <p className="text-sm text-muted-foreground">
                Traccia le tue abitudini di lettura
              </p>
            </div>
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="container mx-auto px-4 py-8">
        <div className="grid lg:grid-cols-5 gap-8">
          {/* Calendar section */}
          <div className="lg:col-span-2">
            <ReadingCalendar 
              getStatus={getStatus} 
              toggleStatus={toggleStatus} 
            />
            
            {/* Instructions */}
            <div className="mt-6 p-4 bg-accent/30 rounded-xl border border-border animate-fade-in" style={{ animationDelay: '400ms' }}>
              <p className="text-sm text-muted-foreground">
                <strong className="text-foreground">Come funziona:</strong> Clicca su un giorno per segnare se hai letto. 
                Il primo click segna "letto" (verde), il secondo "non letto" (rosso), il terzo rimuove la selezione.
              </p>
            </div>
          </div>

          {/* Stats section */}
          <div className="lg:col-span-3">
            <StatsTabs records={records} monthlyGoal={goal} onGoalChange={updateGoal} />
          </div>
        </div>
      </main>
    </div>
  );
};

export default Index;
