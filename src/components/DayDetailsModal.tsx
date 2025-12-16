import { format } from 'date-fns';
import { it } from 'date-fns/locale';
import { Check, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { Goal } from '@/types/goals';
import { cn } from '@/lib/utils';

interface DayDetailsModalProps {
    isOpen: boolean;
    onClose: () => void;
    date: Date | null;
    habits: Goal[];
    dayRecord: { [key: string]: string | null };
    onToggleHabit: (habitId: string) => void;
}

export function DayDetailsModal({
    date,
    isOpen,
    onClose,
    habits,
    dayRecord,
    onToggleHabit,
}: DayDetailsModalProps) {
    if (!date) return null;

    return (
        <Dialog open={isOpen} onOpenChange={onClose}>
            <DialogContent className="sm:max-w-[400px]">
                <DialogHeader>
                    <DialogTitle className="text-xl font-display capitalize">
                        {format(date, 'EEEE d MMMM', { locale: it })}
                    </DialogTitle>
                    <DialogDescription className="sr-only">
                        Dettagli delle attività giornaliere
                    </DialogDescription>
                </DialogHeader>

                <div className="py-2">
                    <ScrollArea className="max-h-[60vh]">
                        <div className="space-y-3 pr-4">
                            {habits.map((habit) => {
                                const status = dayRecord[habit.id];
                                const isDone = status === 'done';
                                const isMissed = status === 'missed';

                                return (
                                    <div
                                        key={habit.id}
                                        onClick={() => onToggleHabit(habit.id)}
                                        className={cn(
                                            "flex items-center justify-between p-3 rounded-xl border transition-all cursor-pointer",
                                            "hover:shadow-md hover:scale-[1.02] active:scale-[0.98]",
                                            isDone && "bg-success/15 border-success/30",
                                            isMissed && "bg-destructive/15 border-destructive/30",
                                            !status && "bg-card hover:bg-accent border-border"
                                        )}
                                    >
                                        <div className="flex items-center gap-3">
                                            <div
                                                className="h-3 w-3 rounded-full ring-2 ring-offset-2 ring-offset-background"
                                                style={{ backgroundColor: habit.color }}
                                            />
                                            <span className={cn(
                                                "font-medium transition-colors",
                                                isDone && "text-success-foreground",
                                                isMissed && "text-destructive-foreground"
                                            )}>
                                                {habit.title}
                                            </span>
                                        </div>

                                        <div className="flex items-center gap-2">
                                            {isDone && <Check className="h-5 w-5 text-success" />}
                                            {isMissed && <X className="h-5 w-5 text-destructive" />}
                                            {!status && (
                                                <div className="h-5 w-5 rounded-full border-2 border-muted-foreground/30" />
                                            )}
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    </ScrollArea>
                </div>
            </DialogContent>
        </Dialog>
    );
}
