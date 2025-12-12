import { ReadingCalendar } from '@/components/ReadingCalendar';
import { useReadingTracker } from '@/hooks/useReadingTracker';

const Index = () => {
  const { getStatus, toggleStatus } = useReadingTracker();

  return (
    <div className="flex-1 flex items-center justify-center p-3 sm:p-4">
      <div className="w-full max-w-md">
        <ReadingCalendar 
          getStatus={getStatus} 
          toggleStatus={toggleStatus} 
        />
        
        {/* Instructions */}
        <div className="mt-4 sm:mt-6 p-3 sm:p-4 bg-accent/30 rounded-xl border border-border animate-fade-in" style={{ animationDelay: '400ms' }}>
          <p className="text-xs sm:text-sm text-muted-foreground text-center">
            <strong className="text-foreground">Come funziona:</strong> Clicca su un giorno per segnare se hai letto. 
            Il primo click segna "letto" (verde), il secondo "non letto" (rosso), il terzo rimuove la selezione.
          </p>
        </div>
      </div>
    </div>
  );
};

export default Index;
