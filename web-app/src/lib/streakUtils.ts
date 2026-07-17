import { format, subDays, isBefore, differenceInDays } from 'date-fns';
import { GoalLogsMap } from '@/types/goals';

export type StreakType = 'positive' | 'negative' | 'neutral';

export interface StreakResult {
    type: StreakType;
    count: number;
}

/**
 * Calculates the streak for a specific habit relative to a given date.
 * 
 * - Positive Streak (🔥): Consecutive 'done' days ending on (or just before) the date.
 * - Negative Streak (💔): Consecutive 'missed' days ending on (or just before) the date.
 * - Neutral: No current streak or start date in future.
 * 
 * Logic handles "pending" states: if today is not logged yet, it looks at yesterday to see if a streak is ongoing.
 */
export function calculateStreakForDay(
    habitId: string,
    date: Date,
    logs: GoalLogsMap,
    startDate: Date
): StreakResult {
    // Safety check: if date is before start date
    if (isBefore(date, startDate)) {
        return { type: 'neutral', count: 0 };
    }

    const checkDate = new Date(date);
    const dateKey = format(checkDate, 'yyyy-MM-dd');
    const status = logs[dateKey]?.[habitId];

    let type: StreakType = 'neutral';
    let count = 0;

    // determine initial direction based on today's status
    if (status === 'done') {
        type = 'positive';
        count = 1;
    } else if (status === 'missed') {
        type = 'negative';
        count = 1;
    } else {
        // Status is null/undefined (pending).
        // Check yesterday to see if we have an active streak to display "continuing"
        const yesterday = subDays(checkDate, 1);
        if (isBefore(yesterday, startDate)) return { type: 'neutral', count: 0 };

        const yesterdayKey = format(yesterday, 'yyyy-MM-dd');
        const yesterdayStatus = logs[yesterdayKey]?.[habitId];

        if (yesterdayStatus === 'done') {
            type = 'positive';
            // We start counting from yesterday
            // Reset checkDate to yesterday so loop flows correctly
            checkDate.setDate(checkDate.getDate() - 1);
            count = 1;
        } else if (yesterdayStatus === 'missed') {
            type = 'negative';
            checkDate.setDate(checkDate.getDate() - 1);
            count = 1;
        } else {
            return { type: 'neutral', count: 0 };
        }
    }

    // Iterate backwards
    let daysBack = 1;
    while (true) {
        const pastDate = subDays(checkDate, daysBack);
        if (isBefore(pastDate, startDate)) break;

        const key = format(pastDate, 'yyyy-MM-dd');
        const pastStatus = logs[key]?.[habitId];

        if (type === 'positive') {
            if (pastStatus === 'done') {
                count++;
            } else {
                // Break on missed or null (assuming null breaks strict streak, unless strictly defined otherwise)
                // For visualized streak, we usually break on non-done.
                break;
            }
        } else if (type === 'negative') {
            if (pastStatus === 'missed') {
                count++;
            } else {
                break;
            }
        }

        daysBack++;
        // Safety break
        if (daysBack > 365 * 10) break;
    }

    return { type, count };
}
