import { format } from 'date-fns';
import { it } from 'date-fns/locale';
import { Check, X, Calendar, Activity, CheckCircle2, XCircle, Circle, Flame, HeartCrack } from 'lucide-react';
import { calculateStreakForDay } from '@/lib/streakUtils';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Goal, GoalLogsMap } from '@/types/goals';
import { cn } from '@/lib/utils';
import { useEffect, useState } from 'react';

interface DayDetailsModalProps {
    isOpen: boolean;
    onClose: () => void;
    date: Date | null;
    habits: Goal[];
    records: GoalLogsMap;
    onToggleHabit: (habitId: string) => void;
    isPrivacyMode?: boolean;
    readonly?: boolean;
}

const ProgressRing = ({ percentage }: { percentage: number }) => {
    const radius = 24;
    const stroke = 4;
    const normalizedRadius = radius - stroke * 2;
    const circumference = normalizedRadius * 2 * Math.PI;
    const strokeDashoffset = circumference - (percentage / 100) * circumference;

    return (
        <div className="relative flex items-center justify-center">
            <svg
                height={radius * 2}
                width={radius * 2}
                className="rotate-[-90deg] transition-all duration-1000 ease-out"
            >
                <circle
                    stroke="currentColor"
                    fill="transparent"
                    strokeWidth={stroke}
                    strokeDasharray={circumference + ' ' + circumference}
                    style={{ strokeDashoffset: circumference }}
                    r={normalizedRadius}
                    cx={radius}
                    cy={radius}
                    className="text-muted/20"
                />
                <circle
                    stroke="currentColor"
                    fill="transparent"
                    strokeWidth={stroke}
                    strokeDasharray={circumference + ' ' + circumference}
                    style={{
                        strokeDashoffset,
                        transition: 'stroke-dashoffset 1s ease-in-out'
                    }}
                    r={normalizedRadius}
                    cx={radius}
                    cy={radius}
                    className="text-success drop-shadow-[0_0_4px_rgba(34,197,94,0.4)]"
                />
            </svg>
        </div>
    );
};

export function DayDetailsModal({
    date,
    isOpen,
    onClose,
    habits,
    records,
    onToggleHabit,
    isPrivacyMode = false,
    readonly = false
}: DayDetailsModalProps) {
    // Animation state
    const [isVisible, setIsVisible] = useState(false);

    useEffect(() => {
        if (isOpen) {
            setIsVisible(true);
        } else {
            setIsVisible(false);
        }
    }, [isOpen]);

    if (!date) return null;

    const dateKey = format(date, 'yyyy-MM-dd');
    const validHabits = habits.filter(h => {
        const isStarted = h.start_date <= dateKey;
        const isNotEnded = !h.end_date || h.end_date >= dateKey;
        return isStarted && isNotEnded;
    });

    const dayRecord = records[dateKey] || {};
    const doneCount = validHabits.filter(h => dayRecord[h.id] === 'done').length;
    const missedCount = validHabits.filter(h => dayRecord[h.id] === 'missed').length;
    const totalCount = validHabits.length;
    const remainingCount = totalCount - doneCount - missedCount;
    const completionPercentage = totalCount > 0 ? (doneCount / totalCount) * 100 : 0;

    return (
        <Dialog open={isOpen} onOpenChange={onClose}>
            <DialogContent aria-describedby={undefined} className="sm:max-w-[420px] p-0 gap-0 overflow-hidden border-white/10 bg-background/60 backdrop-blur-xl shadow-2xl">
                {/* Header Section */}
                <div className="relative p-5 pb-6 overflow-hidden">
                    {/* Background Gradient/Glow */}
                    <div className="absolute top-0 right-0 w-64 h-64 bg-primary/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2 pointer-events-none" />
                    <div className="absolute top-0 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-white/10 to-transparent" />

                    <div className="relative flex items-center justify-between">
                        <div className="space-y-0.5">
                            <DialogTitle className="flex items-baseline gap-2 text-xl font-display font-bold tracking-tight">
                                <span className="text-foreground capitalize">{format(date, 'EEEE', { locale: it })}</span>
                                <span className="text-base font-normal text-muted-foreground">
                                    {format(date, 'd MMMM yyyy', { locale: it })}
                                </span>
                            </DialogTitle>
                        </div>

                        <div className="flex items-center justify-center gap-2 bg-card/30 p-1.5 pr-2 rounded-2xl border border-white/5 backdrop-blur-sm mr-8">
                            <span className="text-[10px] font-medium text-muted-foreground font-mono-nums ml-1">
                                {doneCount}/{totalCount}
                            </span>
                            <ProgressRing percentage={completionPercentage} />
                        </div>
                    </div>

                    {/* Gradient Accent Line */}
                    <div className="absolute bottom-0 left-6 right-6 h-[1px] bg-gradient-to-r from-transparent via-primary/30 to-transparent" />
                </div>

                {/* Habits List */}
                <div className="px-4 py-2 max-h-[60vh] overflow-y-auto no-scrollbar">
                    <div className="space-y-2 pb-4">
                        {validHabits.map((habit, index) => {
                            const status = dayRecord[habit.id];
                            const isDone = status === 'done';
                            const isMissed = status === 'missed';

                            // Calculate Streak
                            const streak = calculateStreakForDay(
                                habit.id,
                                date,
                                records,
                                new Date(habit.start_date)
                            );

                            return (
                                <div
                                    key={habit.id}
                                    onClick={() => !readonly && onToggleHabit(habit.id)}
                                    style={{
                                        animationDelay: `${index * 50}ms`,
                                        opacity: 0 // Start hidden for animation
                                    }}
                                    className={cn(
                                        "group flex items-center justify-between p-3.5 rounded-xl border transition-all duration-300 animate-[slide-in-row_0.4s_ease-out_forwards]",
                                        !readonly && "cursor-pointer hover:scale-[1.01] active:scale-[0.99]",
                                        readonly && "opacity-80",
                                        // Dynamic styling based on status
                                        isDone ? "bg-success/5 border-success/30 shadow-[0_0_15px_-5px_var(--success)]" :
                                            isMissed ? "bg-destructive/5 border-destructive/30" :
                                                // Pending state - Yellow as requested
                                                "bg-yellow-500/10 border-yellow-500/30 hover:bg-yellow-500/20"
                                    )}
                                >
                                    <div className="flex items-center gap-3.5">
                                        <div className={cn(
                                            "relative flex items-center justify-center w-8 h-8 rounded-lg transition-colors duration-300",
                                            isDone ? "bg-success/20 text-success" :
                                                isMissed ? "bg-destructive/10 text-destructive" :
                                                    // Pending state - Yellow
                                                    "bg-yellow-500/20 text-yellow-500"
                                        )}>
                                            {/* Habit Color Dot */}
                                            {!isDone && !isMissed && (
                                                <div
                                                    className="w-2 h-2 rounded-full absolute"
                                                    style={{ backgroundColor: habit.color }}
                                                />
                                            )}
                                            {/* Status Icons */}
                                            {isDone && <Check className="w-4 h-4" />}
                                            {isMissed && <X className="w-4 h-4" />}
                                        </div>

                                        <div className="flex flex-col">
                                            <div className="flex items-center gap-2">
                                                <span className={cn(
                                                    "font-medium prose-sm transition-all duration-300",
                                                    isDone && "text-success",
                                                    isMissed && "text-muted-foreground line-through decoration-destructive/50",
                                                    !isDone && !isMissed && "text-foreground group-hover:text-primary",
                                                    isPrivacyMode && "blur-sm"
                                                )}>
                                                    {habit.title}
                                                </span>

                                                {/* Visual Streak Badge */}
                                                {streak.count > 0 && (
                                                    <div className={cn(
                                                        "flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-bold border shadow-sm animate-in zoom-in duration-300",
                                                        streak.type === 'positive'
                                                            ? "bg-orange-500/10 border-orange-500/20 text-orange-500"
                                                            : "bg-destructive/10 border-destructive/20 text-destructive"
                                                    )}>
                                                        {streak.type === 'positive' ? (
                                                            <Flame className="w-3 h-3 fill-orange-500 animate-pulse" />
                                                        ) : (
                                                            <HeartCrack className="w-3 h-3 fill-destructive/20" />
                                                        )}
                                                        <span>{streak.count}</span>
                                                    </div>
                                                )}
                                            </div>
                                        </div>
                                    </div>

                                    {/* Action Indicator - Removed per user request */}
                                    <div className="flex items-center">
                                        {readonly && (
                                            <div className="text-xs font-medium text-muted-foreground">
                                                {isDone ? 'Completed' : isMissed ? 'Missed' : 'Pending'}
                                            </div>
                                        )}
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                </div>

                {/* Footer Stats */}
                <div className="bg-card/50 backdrop-blur-md border-t border-white/5 p-3 flex items-center justify-between text-xs font-medium text-muted-foreground px-6">
                    <div className="flex items-center gap-4">
                        <div className="flex items-center gap-1.5 transition-colors duration-300 hover:text-success">
                            <CheckCircle2 className="w-3.5 h-3.5 text-success/70" />
                            <span>{doneCount} completati</span>
                        </div>
                        <div className="flex items-center gap-1.5 transition-colors duration-300 hover:text-destructive">
                            <XCircle className="w-3.5 h-3.5 text-destructive/70" />
                            <span>{missedCount} mancati</span>
                        </div>
                        <div className="flex items-center gap-1.5 transition-colors duration-300 hover:text-primary">
                            <Circle className="w-3.5 h-3.5 text-primary/40" />
                            <span>{remainingCount} rimanenti</span>
                        </div>
                    </div>
                </div>
            </DialogContent>
        </Dialog>
    );
}
