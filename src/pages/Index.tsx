import { BookOpen } from 'lucide-react';
import { ReadingCalendar } from '@/components/ReadingCalendar';
import { Dashboard } from '@/components/Dashboard';
import { useReadingTracker } from '@/hooks/useReadingTracker';

const Index = () => {
  const { getStatus, toggleStatus, getStats } = useReadingTracker();
  const stats = getStats();

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
        <div className="grid lg:grid-cols-3 gap-8">
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

          {/* Dashboard section */}
          <div className="lg:col-span-1">
            <Dashboard stats={stats} />
          </div>
        </div>
      </main>
    </div>
  );
};

export default Index;
