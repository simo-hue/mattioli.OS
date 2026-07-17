import { format } from 'date-fns';

/**
 * Returns the current date as an ISO string (YYYY-MM-DD) based on the LOCAL time.
 * Using standard .toISOString() returns UTC, which can result in the wrong date
 * if the user is in a timezone ahead of UTC (e.g., UTC+1) late at night.
 */
export function getLocalDateKey(date: Date = new Date()): string {
    return format(date, 'yyyy-MM-dd');
}

/**
 * Checks if a date string is valid and within the start/end range of a goal.
 */
export function isDateInGoalRange(dateStr: string, startDateStr: string, endDateStr?: string | null): boolean {
    if (dateStr < startDateStr) return false;
    if (endDateStr && dateStr > endDateStr) return false;
    return true;
}
