import { useMemo } from 'react';
import { ReadingRecord, ReadingStatus } from './useReadingTracker';

export interface DayStats {
  date: string;
  status: ReadingStatus;
  dayOfWeek: number;
  weekOfYear: number;
  month: number;
  year: number;
}

export interface WeekStats {
  weekNumber: number;
  year: number;
  daysRead: number;
  daysMissed: number;
  daysTotal: number;
  percentage: number;
}

export interface MonthStats {
  month: number;
  year: number;
  name: string;
  daysRead: number;
  daysMissed: number;
  daysTotal: number;
  percentage: number;
  bestStreak: number;
}

export interface YearStats {
  year: number;
  totalDaysRead: number;
  totalDaysMissed: number;
  totalDaysMarked: number;
  percentage: number;
  bestMonth: MonthStats | null;
  worstMonth: MonthStats | null;
  longestStreak: number;
  averagePerWeek: number;
  averagePerMonth: number;
  monthlyBreakdown: MonthStats[];
  weeklyBreakdown: WeekStats[];
}

export interface WeeklyTrend {
  weekNumber: number;
  weekLabel: string;
  daysRead: number;
  percentage: number;
  trend: 'up' | 'down' | 'stable';
}

export interface OverallStats {
  totalDaysRead: number;
  totalDaysMissed: number;
  totalDaysMarked: number;
  percentage: number;
  currentStreak: number;
  longestStreak: number;
  firstRecordDate: Date | null;
  lastRecordDate: Date | null;
  daysSinceStart: number;
  consistencyScore: number;
  bestDayOfWeek: { day: string; percentage: number } | null;
  worstDayOfWeek: { day: string; percentage: number } | null;
  dayOfWeekDistribution: { [key: number]: { done: number; total: number } };
  averageTimeBetweenSessions: number | null; // in days
  monthlyGoalPrediction: { predictedDays: number; onTrack: boolean; daysNeeded: number } | null;
  weeklyTrend: WeeklyTrend[];
}

const MONTH_NAMES = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
];

const DAY_NAMES = ['Domenica', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato'];

function getWeekNumber(date: Date): number {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
}

function calculateStreak(sortedDates: string[], records: ReadingRecord): number {
  if (sortedDates.length === 0) return 0;

  let maxStreak = 1;
  let currentStreak = 1;

  for (let i = 1; i < sortedDates.length; i++) {
    const prev = new Date(sortedDates[i - 1]);
    const curr = new Date(sortedDates[i]);
    const diffDays = Math.floor((curr.getTime() - prev.getTime()) / (1000 * 60 * 60 * 24));

    if (diffDays === 1) {
      // Consecutive days
      currentStreak++;
    } else {
      // Gap detected. Check if any day in between is 'missed'
      let isBroken = false;
      const checkDate = new Date(prev);
      checkDate.setDate(checkDate.getDate() + 1);

      while (checkDate < curr) {
        const key = checkDate.toISOString().split('T')[0];
        if (records[key] === 'missed') {
          isBroken = true;
          break;
        }
        checkDate.setDate(checkDate.getDate() + 1);
      }

      if (isBroken) {
        currentStreak = 1;
      } else {
        // Gap was only empty days (rest days), streak continues
        currentStreak++;
      }
    }
    maxStreak = Math.max(maxStreak, currentStreak);
  }

  return maxStreak;
}

export function useReadingStats(records: ReadingRecord) {
  const stats = useMemo(() => {
    const allDays: DayStats[] = Object.entries(records).map(([dateStr, status]) => {
      const date = new Date(dateStr);
      return {
        date: dateStr,
        status,
        dayOfWeek: date.getDay(),
        weekOfYear: getWeekNumber(date),
        month: date.getMonth(),
        year: date.getFullYear(),
      };
    });

    const readDates = allDays
      .filter(d => d.status === 'done')
      .map(d => d.date)
      .sort();

    const missedDates = allDays
      .filter(d => d.status === 'missed')
      .map(d => d.date)
      .sort();

    // Overall stats
    const totalDaysRead = readDates.length;
    const totalDaysMissed = missedDates.length;
    const totalDaysMarked = totalDaysRead + totalDaysMissed;
    const percentage = totalDaysMarked > 0 ? Math.round((totalDaysRead / totalDaysMarked) * 100) : 0;
    const longestStreak = calculateStreak(readDates, records);

    // Current streak - if today is 'missed', streak is 0
    let currentStreak = 0;
    const today = new Date();
    const todayKey = today.toISOString().split('T')[0];

    // If today is marked as missed, streak is 0
    if (records[todayKey] === 'missed') {
      currentStreak = 0;
    } else {
      const checkDate = new Date(today);

      // If today is 'done', we start counting from today.
      // If today is empty, we check yesterday to see if the streak is alive.
      // If today is empty AND yesterday is 'missed' -> streak 0.
      // If today is empty AND yesterday is empty -> keep going back.
      // Basically we look for the most recent 'done' or 'missed'.
      // If we find 'done' first -> streak is alive, calculate it.
      // If we find 'missed' first -> streak is dead (0).

      // However, the standard "current streak" usually implies "chain ending today".
      // If I haven't done it today (empty), is my streak active?
      // Yes, usually, until I miss it.

      // Algorithm:
      // 1. Find the most recent 'done' date.
      // 2. Check if there are any 'missed' days between that date and today.
      // 3. If no missed days, the streak is valid. Calculate it ending at that recent date.

      const lastDoneDateStr = readDates[readDates.length - 1]; // sorted ascending
      if (!lastDoneDateStr) {
        currentStreak = 0;
      } else {
        const lastDoneDate = new Date(lastDoneDateStr);

        // Check for cracks between lastDoneDate and Today
        let isStreakBrokenSinceLastDone = false;
        const tempCheck = new Date(lastDoneDate);
        tempCheck.setDate(tempCheck.getDate() + 1);

        while (tempCheck <= today) {
          const key = tempCheck.toISOString().split('T')[0];
          if (records[key] === 'missed') {
            isStreakBrokenSinceLastDone = true;
            break;
          }
          tempCheck.setDate(tempCheck.getDate() + 1);
        }

        if (isStreakBrokenSinceLastDone) {
          currentStreak = 0;
        } else {
          // Streak is alive! Now calculate its length going backwards from lastDoneDate
          // We can use the logic from calculateStreak but localized
          currentStreak = 0;
          // Re-calculate specifically for the chain ending at lastDoneDate

          // Optimization: We could just iterate backwards from lastDoneDate
          // counting 'done' and skipping 'empty', stopping at 'missed'.

          let counterDate = new Date(lastDoneDate);
          const firstRecordedDate = new Date(readDates[0]); // Don't go past beginning of time

          while (counterDate >= firstRecordedDate) {
            const key = counterDate.toISOString().split('T')[0];
            const status = records[key];

            if (status === 'done') {
              currentStreak++;
            } else if (status === 'missed') {
              break;
            }
            // if empty, continue (gap day)

            counterDate.setDate(counterDate.getDate() - 1);
          }
        }
      }
    }

    // First and last record dates
    const allDates = Object.keys(records).sort();
    const firstRecordDate = allDates.length > 0 ? new Date(allDates[0]) : null;
    const lastRecordDate = allDates.length > 0 ? new Date(allDates[allDates.length - 1]) : null;
    const daysSinceStart = firstRecordDate
      ? Math.floor((today.getTime() - firstRecordDate.getTime()) / (1000 * 60 * 60 * 24)) + 1
      : 0;

    // Consistency score (% of days marked since start)
    const consistencyScore = daysSinceStart > 0
      ? Math.round((totalDaysMarked / daysSinceStart) * 100)
      : 0;

    // Day of week analysis
    const dayOfWeekStats: { [key: number]: { done: number; total: number } } = {};
    for (let i = 0; i < 7; i++) {
      dayOfWeekStats[i] = { done: 0, total: 0 };
    }
    allDays.forEach(day => {
      dayOfWeekStats[day.dayOfWeek].total++;
      if (day.status === 'done') {
        dayOfWeekStats[day.dayOfWeek].done++;
      }
    });

    let bestDayOfWeek: { day: string; percentage: number } | null = null;
    let worstDayOfWeek: { day: string; percentage: number } | null = null;
    let bestPct = -1;
    let worstPct = 101;
    let bestDayNum = -1;
    let worstDayNum = -1;

    Object.entries(dayOfWeekStats).forEach(([dayNum, stats]) => {
      if (stats.total > 0) {
        const pct = Math.round((stats.done / stats.total) * 100);
        const dayIndex = parseInt(dayNum);
        if (pct > bestPct) {
          bestPct = pct;
          bestDayNum = dayIndex;
          bestDayOfWeek = { day: DAY_NAMES[dayIndex], percentage: pct };
        }
        if (pct < worstPct) {
          worstPct = pct;
          worstDayNum = dayIndex;
          worstDayOfWeek = { day: DAY_NAMES[dayIndex], percentage: pct };
        }
      }
    });

    // If best and worst are the same, don't show worst
    if (bestDayNum === worstDayNum) {
      worstDayOfWeek = null;
    }

    // Average time between reading sessions
    let averageTimeBetweenSessions: number | null = null;
    if (readDates.length >= 2) {
      let totalGaps = 0;
      for (let i = 1; i < readDates.length; i++) {
        const prev = new Date(readDates[i - 1]);
        const curr = new Date(readDates[i]);
        const diffDays = Math.floor((curr.getTime() - prev.getTime()) / (1000 * 60 * 60 * 24));
        totalGaps += diffDays;
      }
      averageTimeBetweenSessions = Math.round((totalGaps / (readDates.length - 1)) * 10) / 10;
    }

    // Monthly goal prediction (assuming goal is reading every day)
    const todayMonth = today.getMonth();
    const todayYear = today.getFullYear();
    const daysInCurrentMonth = new Date(todayYear, todayMonth + 1, 0).getDate();
    const daysElapsedThisMonth = today.getDate();
    const daysRemainingThisMonth = daysInCurrentMonth - daysElapsedThisMonth;
    const currentMonthReadCount = allDays.filter(d => d.month === todayMonth && d.year === todayYear && d.status === 'done').length;

    let monthlyGoalPrediction: { predictedDays: number; onTrack: boolean; daysNeeded: number } | null = null;
    if (daysElapsedThisMonth > 0) {
      const dailyRate = currentMonthReadCount / daysElapsedThisMonth;
      const predictedDays = Math.round(currentMonthReadCount + (dailyRate * daysRemainingThisMonth));
      const daysNeeded = daysInCurrentMonth - currentMonthReadCount;
      const onTrack = dailyRate >= 0.7; // 70% is considered on track
      monthlyGoalPrediction = { predictedDays, onTrack, daysNeeded };
    }

    // Weekly trend (last 4 weeks)
    const weeklyTrend: WeeklyTrend[] = [];
    for (let i = 3; i >= 0; i--) {
      const weekStart = new Date(today);
      weekStart.setDate(today.getDate() - today.getDay() - (i * 7)); // Start of week (Sunday)
      weekStart.setHours(0, 0, 0, 0);

      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekStart.getDate() + 6);
      weekEnd.setHours(23, 59, 59, 999);

      let daysRead = 0;
      let daysInWeek = 0;

      for (let d = new Date(weekStart); d <= weekEnd && d <= today; d.setDate(d.getDate() + 1)) {
        const key = d.toISOString().split('T')[0];
        daysInWeek++;
        if (records[key] === 'done') {
          daysRead++;
        }
      }

      const pct = daysInWeek > 0 ? Math.round((daysRead / daysInWeek) * 100) : 0;
      const weekNum = getWeekNumber(weekStart);

      weeklyTrend.push({
        weekNumber: weekNum,
        weekLabel: i === 0 ? 'Questa' : i === 1 ? 'Scorsa' : `${i} sett. fa`,
        daysRead,
        percentage: pct,
        trend: 'stable',
      });
    }

    // Calculate trends
    for (let i = 1; i < weeklyTrend.length; i++) {
      const diff = weeklyTrend[i].percentage - weeklyTrend[i - 1].percentage;
      if (diff > 10) {
        weeklyTrend[i].trend = 'up';
      } else if (diff < -10) {
        weeklyTrend[i].trend = 'down';
      }
    }

    const overall: OverallStats = {
      totalDaysRead,
      totalDaysMissed,
      totalDaysMarked,
      percentage,
      currentStreak,
      longestStreak,
      firstRecordDate,
      lastRecordDate,
      daysSinceStart,
      consistencyScore,
      bestDayOfWeek,
      worstDayOfWeek,
      dayOfWeekDistribution: dayOfWeekStats,
      averageTimeBetweenSessions,
      monthlyGoalPrediction,
      weeklyTrend,
    };

    // Year stats
    const years = [...new Set(allDays.map(d => d.year))].sort();
    const yearlyStats: YearStats[] = years.map(year => {
      const yearDays = allDays.filter(d => d.year === year);
      const yearReadDates = yearDays.filter(d => d.status === 'done').map(d => d.date).sort();
      const yearMissedDates = yearDays.filter(d => d.status === 'missed');

      const totalDaysRead = yearReadDates.length;
      const totalDaysMissed = yearMissedDates.length;
      const totalDaysMarked = totalDaysRead + totalDaysMissed;
      const percentage = totalDaysMarked > 0 ? Math.round((totalDaysRead / totalDaysMarked) * 100) : 0;
      const longestStreak = calculateStreak(yearReadDates, records);

      // Monthly breakdown
      const monthlyBreakdown: MonthStats[] = [];
      for (let month = 0; month < 12; month++) {
        const monthDays = yearDays.filter(d => d.month === month);
        const monthReadDates = monthDays.filter(d => d.status === 'done').map(d => d.date).sort();
        const monthMissedDates = monthDays.filter(d => d.status === 'missed');

        const daysRead = monthReadDates.length;
        const daysMissed = monthMissedDates.length;
        const daysTotal = daysRead + daysMissed;

        monthlyBreakdown.push({
          month,
          year,
          name: MONTH_NAMES[month],
          daysRead,
          daysMissed,
          daysTotal,
          percentage: daysTotal > 0 ? Math.round((daysRead / daysTotal) * 100) : 0,
          bestStreak: calculateStreak(monthReadDates, records),
        });
      }

      // Weekly breakdown
      const weeklyBreakdown: WeekStats[] = [];
      const weeks = [...new Set(yearDays.map(d => d.weekOfYear))].sort((a, b) => a - b);
      weeks.forEach(weekNumber => {
        const weekDays = yearDays.filter(d => d.weekOfYear === weekNumber);
        const daysRead = weekDays.filter(d => d.status === 'done').length;
        const daysMissed = weekDays.filter(d => d.status === 'missed').length;
        const daysTotal = daysRead + daysMissed;

        weeklyBreakdown.push({
          weekNumber,
          year,
          daysRead,
          daysMissed,
          daysTotal,
          percentage: daysTotal > 0 ? Math.round((daysRead / daysTotal) * 100) : 0,
        });
      });

      const monthsWithData = monthlyBreakdown.filter(m => m.daysTotal > 0);
      const bestMonth = monthsWithData.length > 0
        ? monthsWithData.reduce((a, b) => a.percentage > b.percentage ? a : b)
        : null;
      const worstMonth = monthsWithData.length > 0
        ? monthsWithData.reduce((a, b) => a.percentage < b.percentage ? a : b)
        : null;

      const weeksWithData = weeklyBreakdown.filter(w => w.daysTotal > 0);
      const averagePerWeek = weeksWithData.length > 0
        ? Math.round(totalDaysRead / weeksWithData.length * 10) / 10
        : 0;
      const averagePerMonth = monthsWithData.length > 0
        ? Math.round(totalDaysRead / monthsWithData.length * 10) / 10
        : 0;

      return {
        year,
        totalDaysRead,
        totalDaysMissed,
        totalDaysMarked,
        percentage,
        bestMonth,
        worstMonth,
        longestStreak,
        averagePerWeek,
        averagePerMonth,
        monthlyBreakdown,
        weeklyBreakdown,
      };
    });

    // Current month stats - reusing already calculated values
    const currentMonthDays = allDays.filter(d => d.month === todayMonth && d.year === todayYear);
    const currentMonthReadDates = currentMonthDays.filter(d => d.status === 'done').map(d => d.date).sort();
    const markedDaysThisMonth = currentMonthDays.length;

    const monthStats: MonthStats = {
      month: todayMonth,
      year: todayYear,
      name: MONTH_NAMES[todayMonth],
      daysRead: currentMonthReadDates.length,
      daysMissed: currentMonthDays.filter(d => d.status === 'missed').length,
      daysTotal: markedDaysThisMonth,
      // Use marked days for percentage if any exist, otherwise 0
      percentage: markedDaysThisMonth > 0
        ? Math.round((currentMonthReadDates.length / markedDaysThisMonth) * 100)
        : 0,
      bestStreak: calculateStreak(currentMonthReadDates, records),
    };

    return {
      overall,
      yearlyStats,
      currentMonthStats: monthStats,
      currentYearStats: yearlyStats.find(y => y.year === todayYear) || null,
    };
  }, [records]);

  return stats;
}
