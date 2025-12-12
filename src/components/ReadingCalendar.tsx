import { useState } from 'react';
import { ChevronLeft, ChevronRight, Book, BookX, RotateCcw } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { ReadingStatus } from '@/hooks/useReadingTracker';

interface ReadingCalendarProps {
  getStatus: (date: Date) => ReadingStatus;
  toggleStatus: (date: Date) => void;
}

const DAYS = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
const MONTHS = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
];

export function ReadingCalendar({ getStatus, toggleStatus }: ReadingCalendarProps) {
  const [currentDate, setCurrentDate] = useState(new Date());
  const [animatingDay, setAnimatingDay] = useState<string | null>(null);

  const year = currentDate.getFullYear();
  const month = currentDate.getMonth();

  const firstDayOfMonth = new Date(year, month, 1);
  const lastDayOfMonth = new Date(year, month + 1, 0);
  
  // Adjust for Monday start (0 = Monday, 6 = Sunday)
  let startDay = firstDayOfMonth.getDay() - 1;
  if (startDay < 0) startDay = 6;

  const daysInMonth = lastDayOfMonth.getDate();
  const today = new Date();

  const goToPrevMonth = () => {
    setCurrentDate(new Date(year, month - 1, 1));
  };

  const goToNextMonth = () => {
    setCurrentDate(new Date(year, month + 1, 1));
  };

  const goToToday = () => {
    setCurrentDate(new Date());
  };

  const handleDayClick = (day: number) => {
    const date = new Date(year, month, day);
    const dateKey = date.toISOString().split('T')[0];
    
    setAnimatingDay(dateKey);
    toggleStatus(date);
    
    setTimeout(() => setAnimatingDay(null), 600);
  };

  const isToday = (day: number) => {
    return (
      today.getDate() === day &&
      today.getMonth() === month &&
      today.getFullYear() === year
    );
  };

  const isFuture = (day: number) => {
    const date = new Date(year, month, day);
    const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    return date > todayStart;
  };

  const renderDays = () => {
    const days = [];
    
    // Empty cells for days before the first of the month
    for (let i = 0; i < startDay; i++) {
      days.push(<div key={`empty-${i}`} className="aspect-square" />);
    }

    // Days of the month
    for (let day = 1; day <= daysInMonth; day++) {
      const date = new Date(year, month, day);
      const status = getStatus(date);
      const dateKey = date.toISOString().split('T')[0];
      const isAnimating = animatingDay === dateKey;
      const future = isFuture(day);

      days.push(
        <button
          key={day}
          onClick={() => !future && handleDayClick(day)}
          disabled={future}
          className={cn(
            "aspect-square rounded-md sm:rounded-lg flex flex-col items-center justify-center gap-0 sm:gap-0.5 transition-all duration-300 relative",
            "hover:scale-105 hover:shadow-md",
            future && "opacity-40 cursor-not-allowed hover:scale-100 hover:shadow-none",
            status === 'done' && "bg-reading-done text-success-foreground",
            status === 'missed' && "bg-reading-missed text-destructive-foreground",
            status === null && "bg-reading-neutral hover:bg-accent",
            isToday(day) && "ring-1 sm:ring-2 ring-primary ring-offset-1 sm:ring-offset-2 ring-offset-background",
            isAnimating && status === 'done' && "animate-pulse-success",
            isAnimating && status === 'missed' && "animate-pulse-missed",
          )}
        >
          <span className={cn(
            "text-xs sm:text-sm font-medium",
            status !== null && "font-semibold"
          )}>
            {day}
          </span>
          {status === 'done' && <Book className="w-2.5 h-2.5 sm:w-3.5 sm:h-3.5" />}
          {status === 'missed' && <BookX className="w-2.5 h-2.5 sm:w-3.5 sm:h-3.5" />}
        </button>
      );
    }

    return days;
  };

  return (
    <div className="bg-card rounded-2xl p-4 sm:p-6 shadow-lg border border-border animate-scale-in">
      {/* Header */}
      <div className="flex items-center justify-between mb-4 sm:mb-6">
        <Button
          variant="ghost"
          size="icon"
          onClick={goToPrevMonth}
          className="hover:bg-accent h-8 w-8 sm:h-10 sm:w-10"
        >
          <ChevronLeft className="h-4 w-4 sm:h-5 sm:w-5" />
        </Button>
        
        <div className="flex items-center gap-2 sm:gap-3">
          <h2 className="text-lg sm:text-2xl font-display font-semibold text-foreground">
            {MONTHS[month]} {year}
          </h2>
          <Button
            variant="ghost"
            size="icon"
            onClick={goToToday}
            className="hover:bg-accent h-7 w-7 sm:h-8 sm:w-8"
            title="Vai a oggi"
          >
            <RotateCcw className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
          </Button>
        </div>
        
        <Button
          variant="ghost"
          size="icon"
          onClick={goToNextMonth}
          className="hover:bg-accent h-8 w-8 sm:h-10 sm:w-10"
        >
          <ChevronRight className="h-4 w-4 sm:h-5 sm:w-5" />
        </Button>
      </div>

      {/* Day headers */}
      <div className="grid grid-cols-7 gap-1 sm:gap-2 mb-1 sm:mb-2">
        {DAYS.map(day => (
          <div
            key={day}
            className="text-center text-[10px] sm:text-xs font-medium text-muted-foreground py-1 sm:py-2"
          >
            {day}
          </div>
        ))}
      </div>

      {/* Calendar grid */}
      <div className="grid grid-cols-7 gap-1 sm:gap-2">
        {renderDays()}
      </div>

      {/* Legend */}
      <div className="flex items-center justify-center gap-3 sm:gap-6 mt-4 sm:mt-6 pt-3 sm:pt-4 border-t border-border flex-wrap">
        <div className="flex items-center gap-1.5 sm:gap-2">
          <div className="w-3 h-3 sm:w-4 sm:h-4 rounded bg-reading-done" />
          <span className="text-xs sm:text-sm text-muted-foreground">Letto</span>
        </div>
        <div className="flex items-center gap-1.5 sm:gap-2">
          <div className="w-3 h-3 sm:w-4 sm:h-4 rounded bg-reading-missed" />
          <span className="text-xs sm:text-sm text-muted-foreground">Non letto</span>
        </div>
        <div className="flex items-center gap-1.5 sm:gap-2">
          <div className="w-3 h-3 sm:w-4 sm:h-4 rounded bg-reading-neutral" />
          <span className="text-xs sm:text-sm text-muted-foreground">Non segnato</span>
        </div>
      </div>
    </div>
  );
}
