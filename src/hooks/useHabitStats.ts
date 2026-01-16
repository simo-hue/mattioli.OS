import { useMemo } from 'react';
import { Goal, GoalLogsMap } from '@/types/goals';
import { format, subDays, subWeeks, subMonths, subYears, eachDayOfInterval, differenceInCalendarDays, isBefore, isAfter, startOfDay, startOfWeek, endOfWeek, startOfMonth, endOfMonth, startOfYear, endOfYear } from 'date-fns';
import { it } from 'date-fns/locale';

export interface HabitStat {
    id: string;
    title: string;
    color: string;
    currentStreak: number;
    longestStreak: number;
    worstStreak: number;
    totalDays: number;
    completionRate: number;
}

export interface DayActivity {
    date: string;
    count: number;
    intensity: number; // 0-4 scale for heatmap
}

export interface TrendData {
    date: string;
    [habitId: string]: number | string; // percentage
}

export interface ComparisonStat {
    previous: number;
    current: number;
    change: number;
    trend: 'up' | 'down' | 'neutral';
}

export interface HabitComparison {
    habitId: string;
    week: ComparisonStat;
    month: ComparisonStat;
    year: ComparisonStat;
}

export interface CriticalHabitStat {
    habitId: string;
    title: string;
    color: string;
    completionRate: number;
    worstDay: string; // e.g., "Monday"
    worstDayRate: number; // Completion rate on that specific day
}

export type Timeframe = 'weekly' | 'monthly' | 'annual' | 'all';

export function useHabitStats(goals: Goal[], logs: GoalLogsMap, trendTimeframe: Timeframe = 'weekly') {
    return useMemo(() => {
        const today = startOfDay(new Date());
        // Flatten logs to get all active dates for global calculations
        const allLogDates = Object.keys(logs).sort();

        // 1. Calculate Individual Goal Stats
        const habitStats: HabitStat[] = goals.map(goal => {
            const startDate = startOfDay(new Date(goal.start_date));
            const goalId = goal.id;

            let currentStreak = 0;
            let longestStreak = 0;
            let tempStreak = 0;
            let worstStreak = 0;
            let tempNegativeStreak = 0;
            let totalDone = 0;

            // Calculate validity period (days since start_date until today)
            // If start_date is in future, totalValidDays is 0
            const daysSinceStart = Math.max(0, differenceInCalendarDays(today, startDate) + 1);

            // Iterate through all logs to catch "done" status
            // Note: This relies on logs. If a user didn't log anything for a day, it's missing from `logs`.
            // But for streaks/rate, we need to know consecutive days.

            // Streaks Calculation
            // We iterate strictly from today backwards for current streak
            const checkDate = new Date(today);
            let isStreakActive = true;

            // Check today first
            const todayKey = format(checkDate, 'yyyy-MM-dd');
            const todayStatus = logs[todayKey]?.[goalId];

            if (todayStatus === 'done') {
                currentStreak++;
            } else if (todayStatus === 'missed') {
                isStreakActive = false;
            }
            // If neither done nor missed (null), we assume streak is potentially alive if yesterday was done?
            // "Skipped" maintains streak? Let's say yes for now or ignore. 
            // Usually: 
            // Done -> +1
            // Missed -> Break
            // Null -> Break (if strict) OR Continue (if lenient). 
            // Mattioli.OS should be strict: you must execute.
            else {
                // If today is NOT done, streak is officially 0 unless we are lenient.
                // But usually currentStreak counts CONSECUTIVE days ending today or yesterday.
                // If I haven't done it TODAY yet, but I did it YESTERDAY, my streak is usually kept "pending".
                // So if today is null, we don't break yet, we check yesterday.
            }

            // Loop backwards from yesterday
            let daysBack = 1;
            while (true) {
                const pastDate = subDays(today, daysBack);
                if (isBefore(pastDate, startDate)) break; // Don't go before start date

                const key = format(pastDate, 'yyyy-MM-dd');
                const status = logs[key]?.[goalId];

                if (status === 'done') {
                    if (isStreakActive) currentStreak++;
                } else if (status === 'missed') {
                    // Missed: Break streak
                    if (daysBack === 1 && todayStatus !== 'missed' && todayStatus !== 'done') {
                        isStreakActive = false;
                    } else {
                        isStreakActive = false;
                    }
                } else {
                    // Skipped or Null (Empty) -> Treat as Rest Day.
                    // Do NOT break streak. Do NOT increment streak.
                    // Just continue searching backwards.
                }

                if (!isStreakActive) break;

                // Safety break to prevent infinite loops if start_date is weird or huge data
                if (daysBack > 365 * 5) break;

                daysBack++;
            }

            // Simplified loop for Longest Streak, Worst Streak & Total Done
            // Iterate all days from start_date to today
            if (daysSinceStart > 0) {
                for (let i = 0; i < daysSinceStart; i++) {
                    const date = subDays(today, i);
                    const key = format(date, 'yyyy-MM-dd');
                    const status = logs[key]?.[goalId];

                    if (status === 'done') {
                        totalDone++;
                        tempStreak++;
                        // Reset negative streak when task is completed
                        worstStreak = Math.max(worstStreak, tempNegativeStreak);
                        tempNegativeStreak = 0;
                    } else if (status === 'missed' || status === null) {
                        // Count as negative streak (missed or not tracked)
                        tempNegativeStreak++;
                        // Only reset positive streak on missed
                        if (status === 'missed') {
                            longestStreak = Math.max(longestStreak, tempStreak);
                            tempStreak = 0;
                        }
                    } else {
                        // Skipped -> Continue without resetting
                        // This effectively "bridges" the gap for positive streaks
                        // but doesn't count as negative either
                    }
                }
                longestStreak = Math.max(longestStreak, tempStreak);
                worstStreak = Math.max(worstStreak, tempNegativeStreak);
            }

            // Completion Rate (Last 30 days)
            let rateDays = 0;
            let rateDone = 0;
            const last30 = subDays(today, 29);

            // Interval: max(last30, start_date) to today
            const rateStart = isAfter(startDate, last30) ? startDate : last30;

            if (!isAfter(rateStart, today)) {
                eachDayOfInterval({ start: rateStart, end: today }).forEach(day => {
                    rateDays++;
                    const key = format(day, 'yyyy-MM-dd');
                    if (logs[key]?.[goalId] === 'done') rateDone++;
                });
            }

            const completionRate = rateDays > 0 ? Math.round((rateDone / rateDays) * 100) : 0;

            return {
                id: goal.id,
                title: goal.title,
                color: goal.color,
                currentStreak, // Simplified for now
                longestStreak,
                worstStreak,
                totalDays: totalDone,
                completionRate
            };
        });

        // 2. Heatmap Data (Activity intensity)
        const heatmapData: DayActivity[] = [];
        const oneYearAgo = subDays(today, 365);

        eachDayOfInterval({ start: oneYearAgo, end: today }).forEach(day => {
            const key = format(day, 'yyyy-MM-dd');
            // Count how many goals were active AND done this day
            let possibleGoals = 0;
            let doneGoals = 0;

            goals.forEach(g => {
                const gStart = new Date(g.start_date);
                if (isBefore(startOfDay(day), startOfDay(gStart))) return; // Too early

                possibleGoals++;
                if (logs[key]?.[g.id] === 'done') doneGoals++;
            });

            let intensity = 0;
            if (possibleGoals > 0 && doneGoals > 0) {
                const pct = doneGoals / possibleGoals;
                if (pct <= 0.25) intensity = 1;
                else if (pct <= 0.50) intensity = 2;
                else if (pct <= 0.75) intensity = 3;
                else intensity = 4;
            }

            heatmapData.push({
                date: key,
                count: doneGoals,
                intensity
            });
        });

        // 3. Trend Data
        const trendData: TrendData[] = [];
        let trendStartStr: Date;
        let trendEnd: Date = today;
        let interval: 'day' | 'month' = 'day';

        // Determine start date and interval based on timeframe
        switch (trendTimeframe) {
            case 'weekly':
                trendStartStr = subDays(today, 6);
                interval = 'day';
                break;
            case 'monthly':
                trendStartStr = subDays(today, 29);
                interval = 'day';
                break;
            case 'annual':
                trendStartStr = subMonths(today, 11);
                interval = 'month';
                break;
            case 'all':
                const earliest = goals.reduce((min, g) => isBefore(new Date(g.start_date), min) ? new Date(g.start_date) : min, today);
                trendStartStr = earliest;
                if (differenceInCalendarDays(today, earliest) > 90) {
                    interval = 'month';
                    trendStartStr = startOfMonth(trendStartStr);
                } else {
                    interval = 'day';
                }
                break;
            default:
                trendStartStr = subDays(today, 6);
        }

        if (interval === 'day') {
            eachDayOfInterval({ start: trendStartStr, end: trendEnd }).forEach(day => {
                const key = format(day, 'yyyy-MM-dd');
                let dateLabel = format(day, 'EEE', { locale: it });
                if (trendTimeframe === 'monthly' || trendTimeframe === 'all') {
                    dateLabel = format(day, 'dd/MM', { locale: it });
                }

                const dataPoint: TrendData = { date: dateLabel };
                let dailyDone = 0;
                let dailyActive = 0;

                goals.forEach(goal => {
                    const gStart = new Date(goal.start_date);
                    if (isBefore(startOfDay(day), startOfDay(gStart))) {
                        dataPoint[goal.id] = 0;
                        return;
                    }

                    dailyActive++;
                    const status = logs[key]?.[goal.id];
                    const isDone = status === 'done';
                    if (isDone) dailyDone++;

                    dataPoint[goal.id] = isDone ? 100 : 0;
                });

                const overall = dailyActive > 0 ? Math.round((dailyDone / dailyActive) * 100) : 0;
                dataPoint['overall'] = overall;
                trendData.push(dataPoint);
            });
        } else {
            let currentMonth = startOfMonth(trendStartStr);
            while (!isAfter(currentMonth, trendEnd)) {
                const monthEnd = endOfMonth(currentMonth);
                const actualEnd = isBefore(monthEnd, trendEnd) ? monthEnd : trendEnd;

                const dataPoint: TrendData = {
                    date: format(currentMonth, 'MMM yy', { locale: it })
                };

                let monthTotalActive = 0;
                let monthTotalDone = 0;

                goals.forEach(goal => {
                    const gStart = new Date(goal.start_date);
                    const effStart = isBefore(currentMonth, gStart) ? gStart : currentMonth;

                    if (isAfter(effStart, actualEnd)) {
                        dataPoint[goal.id] = 0;
                        return;
                    }

                    let gDone = 0;
                    let gTotal = 0;

                    eachDayOfInterval({ start: effStart, end: actualEnd }).forEach(d => {
                        const k = format(d, 'yyyy-MM-dd');
                        gTotal++;
                        if (logs[k]?.[goal.id] === 'done') gDone++;
                    });

                    const gRate = gTotal > 0 ? Math.round((gDone / gTotal) * 100) : 0;
                    dataPoint[goal.id] = gRate;

                    monthTotalActive += gTotal;
                    monthTotalDone += gDone;
                });

                const overall = monthTotalActive > 0 ? Math.round((monthTotalDone / monthTotalActive) * 100) : 0;
                dataPoint['overall'] = overall;
                trendData.push(dataPoint);

                currentMonth = startOfMonth(subDays(currentMonth, -32));
            }
        }

        // 4. Weekday Stats
        const weekdayStats = [0, 0, 0, 0, 0, 0, 0].map((_, i) => ({
            dayIndex: i,
            dayName: format(new Date(2024, 0, 7 + i), 'EEEE', { locale: it }),
            totalActive: 0,
            totalDone: 0,
            rate: 0
        }));

        const earliestStart = goals.reduce((min, g) => isBefore(new Date(g.start_date), min) ? new Date(g.start_date) : min, today);
        const analysisStart = isAfter(earliestStart, subDays(today, 365)) ? earliestStart : subDays(today, 365);

        if (!isAfter(analysisStart, today)) {
            eachDayOfInterval({ start: analysisStart, end: today }).forEach(day => {
                const dayIndex = day.getDay();
                const key = format(day, 'yyyy-MM-dd');

                goals.forEach(goal => {
                    const gStart = new Date(goal.start_date);
                    if (isBefore(day, gStart)) return;

                    weekdayStats[dayIndex].totalActive++;

                    if (logs[key]?.[goal.id] === 'done') {
                        weekdayStats[dayIndex].totalDone++;
                    }
                });
            });
        }

        weekdayStats.forEach(stat => {
            stat.rate = stat.totalActive > 0 ? Math.round((stat.totalDone / stat.totalActive) * 100) : 0;
        });

        // Global Stats
        const totalActiveDays = allLogDates.length;
        const globalSuccessRate = habitStats.length > 0
            ? Math.round(habitStats.reduce((acc, curr) => acc + curr.completionRate, 0) / habitStats.length)
            : 0;

        // 6. Calculate Critical Stats
        const criticalHabits = calculateCriticalStats(goals, logs, today, habitStats);

        // 5. Calculate Comparisons
        // Week
        const currentWeekStart = startOfWeek(today, { locale: it, weekStartsOn: 1 });
        const currentWeekEnd = today;
        const prevWeekStart = subWeeks(currentWeekStart, 1);
        const prevWeekEnd = subDays(currentWeekStart, 1);

        // Month
        const currentMonthStart = startOfMonth(today);
        const currentMonthEnd = today;
        const prevMonthStart = subMonths(currentMonthStart, 1);
        const prevMonthEnd = subDays(currentMonthStart, 1);

        // Year
        const currentYearStart = startOfYear(today);
        const currentYearEnd = today;
        const prevYearStart = subYears(currentYearStart, 1);
        const prevYearEnd = subDays(currentYearStart, 1);

        const weekStats = calculatePeriodStats(goals, logs, currentWeekStart, currentWeekEnd, prevWeekStart, prevWeekEnd, 'week');
        const monthStats = calculatePeriodStats(goals, logs, currentMonthStart, currentMonthEnd, prevMonthStart, prevMonthEnd, 'month');
        const yearStats = calculatePeriodStats(goals, logs, currentYearStart, currentYearEnd, prevYearStart, prevYearEnd, 'year');

        const comparisons: HabitComparison[] = goals.map(g => ({
            habitId: g.id,
            week: weekStats[g.id],
            month: monthStats[g.id],
            year: yearStats[g.id]
        }));

        const statsResult = {
            habitStats,
            heatmapData,
            trendData,
            weekdayStats: weekdayStats.sort((a, b) => {
                // Sort to start Monday (1) -> Sunday (0)
                if (a.dayIndex === 0) return 1;
                if (b.dayIndex === 0) return -1;
                return a.dayIndex - b.dayIndex;
            }),
            totalActiveDays,
            globalSuccessRate,
            bestStreak: Math.max(...habitStats.map(h => h.longestStreak), 0),
            worstDay: weekdayStats.reduce((min, curr) => curr.rate < min.rate && curr.totalActive > 0 ? curr : min, weekdayStats[0]).dayName,
            comparisons: comparisons,
            criticalHabits: criticalHabits.sort((a, b) => a.completionRate - b.completionRate)
        };

        return statsResult;

    }, [goals, logs, trendTimeframe]);
}

function calculatePeriodStats(
    goals: Goal[],
    logs: GoalLogsMap,
    startCurrent: Date,
    endCurrent: Date,
    startPrev: Date,
    endPrev: Date,
    type: 'week' | 'month' | 'year' = 'month'
): { [habitId: string]: ComparisonStat } {
    const result: { [habitId: string]: ComparisonStat } = {};
    const habitIds = goals.map(g => g.id);

    // Helper to calculate rate for a period
    const calculateRate = (habitId: string, start: Date, end: Date, goalStart: Date) => {
        // Effective start for this period: max(periodStart, goalStart)
        const effectiveStart = isBefore(start, goalStart) ? goalStart : start;

        if (isAfter(effectiveStart, end)) return 0;

        let totalDays = 0;
        let doneDays = 0;

        // Optimization: iterate only effective range
        eachDayOfInterval({ start: effectiveStart, end }).forEach(day => {
            totalDays++;
            const key = format(day, 'yyyy-MM-dd');
            if (logs[key]?.[habitId] === 'done') doneDays++;
        });

        return totalDays > 0 ? Math.round((doneDays / totalDays) * 100) : 0;
    };

    habitIds.forEach(id => {
        const goal = goals.find(g => g.id === id);
        if (!goal) return;
        const gStart = new Date(goal.start_date);

        const currentRate = calculateRate(id, startCurrent, endCurrent, gStart);
        const prevRate = calculateRate(id, startPrev, endPrev, gStart);
        const change = currentRate - prevRate;

        let trend: 'up' | 'down' | 'neutral' = 'neutral';
        if (change > 0) trend = 'up';
        if (change < 0) trend = 'down';

        result[id] = {
            previous: prevRate,
            current: currentRate,
            change,
            trend
        };
    });

    return result;
}

function calculateCriticalStats(goals: Goal[], logs: GoalLogsMap, today: Date, habitStats: HabitStat[]): CriticalHabitStat[] {
    const criticalStats: CriticalHabitStat[] = [];
    const analysisStart = subDays(today, 90);

    goals.forEach(goal => {
        const weekdayCounts = [0, 0, 0, 0, 0, 0, 0].map(() => ({ total: 0, done: 0 }));
        const effectiveStart = isBefore(analysisStart, new Date(goal.start_date)) ? new Date(goal.start_date) : analysisStart;

        // Calculate days active for dynamic threshold
        const daysActive = Math.max(0, differenceInCalendarDays(today, new Date(goal.start_date))) + 1;

        // Dynamic Threshold Logic:
        // < 8 days: 1 occurrence (Immediate feedback)
        // 8 - 14 days: 2 occurrences
        // 15 - 28 days: 3 occurrences
        // > 28 days: 4 occurrences
        let dynamicThreshold = 4;
        if (daysActive < 8) dynamicThreshold = 1;
        else if (daysActive < 15) dynamicThreshold = 2;
        else if (daysActive < 29) dynamicThreshold = 3;

        if (!isAfter(effectiveStart, today)) {
            eachDayOfInterval({ start: effectiveStart, end: today }).forEach(day => {
                const dayIndex = day.getDay();
                const key = format(day, 'yyyy-MM-dd');

                weekdayCounts[dayIndex].total++;
                if (logs[key]?.[goal.id] === 'done') {
                    weekdayCounts[dayIndex].done++;
                }
            });
        }

        // Calculate rate per day
        let worstDay = '';
        let worstDayRate = 101;

        weekdayCounts.forEach((stat, index) => {
            if (stat.total < dynamicThreshold) return;

            const rate = Math.round((stat.done / stat.total) * 100);
            if (rate < worstDayRate) {
                worstDayRate = rate;
                const date = new Date(2024, 0, 7 + index); // Sunday 7th Jan 2024
                worstDay = format(date, 'EEEE', { locale: it });
            }
        });

        const mainStat = habitStats.find(h => h.id === goal.id);
        const completionRate = mainStat ? mainStat.completionRate : 0;

        if (worstDayRate === 101) {
            worstDay = 'N/A';
            worstDayRate = completionRate;
        }

        criticalStats.push({
            habitId: goal.id,
            title: goal.title,
            color: goal.color,
            completionRate,
            worstDay,
            worstDayRate
        });
    });

    return criticalStats;
}
