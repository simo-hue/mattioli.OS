import { useMemo } from 'react';
import { ReadingRecord } from './useReadingTracker';
import { OverallStats, YearStats, MonthStats } from './useReadingStats';

export interface Badge {
  id: string;
  name: string;
  description: string;
  icon: string;
  unlocked: boolean;
  unlockedAt?: Date;
  progress?: number;
  maxProgress?: number;
  tier?: 'bronze' | 'silver' | 'gold' | 'platinum';
}

interface BadgeDefinition {
  id: string;
  name: string;
  description: string;
  icon: string;
  tier: 'bronze' | 'silver' | 'gold' | 'platinum';
  check: (stats: OverallStats, records: ReadingRecord, monthStats: MonthStats | null, yearStats: YearStats | null, goal: number) => { unlocked: boolean; progress?: number; maxProgress?: number };
}

const BADGE_DEFINITIONS: BadgeDefinition[] = [
  // Streak badges
  {
    id: 'streak_3',
    name: 'Inizio promettente',
    description: 'Leggi per 3 giorni consecutivi',
    icon: '🔥',
    tier: 'bronze',
    check: (stats) => ({
      unlocked: stats.longestStreak >= 3,
      progress: Math.min(stats.longestStreak, 3),
      maxProgress: 3,
    }),
  },
  {
    id: 'streak_7',
    name: 'Una settimana',
    description: 'Leggi per 7 giorni consecutivi',
    icon: '📅',
    tier: 'bronze',
    check: (stats) => ({
      unlocked: stats.longestStreak >= 7,
      progress: Math.min(stats.longestStreak, 7),
      maxProgress: 7,
    }),
  },
  {
    id: 'streak_14',
    name: 'Due settimane',
    description: 'Leggi per 14 giorni consecutivi',
    icon: '⚡',
    tier: 'silver',
    check: (stats) => ({
      unlocked: stats.longestStreak >= 14,
      progress: Math.min(stats.longestStreak, 14),
      maxProgress: 14,
    }),
  },
  {
    id: 'streak_30',
    name: 'Un mese di fuoco',
    description: 'Leggi per 30 giorni consecutivi',
    icon: '🏆',
    tier: 'gold',
    check: (stats) => ({
      unlocked: stats.longestStreak >= 30,
      progress: Math.min(stats.longestStreak, 30),
      maxProgress: 30,
    }),
  },
  {
    id: 'streak_100',
    name: 'Leggenda',
    description: 'Leggi per 100 giorni consecutivi',
    icon: '👑',
    tier: 'platinum',
    check: (stats) => ({
      unlocked: stats.longestStreak >= 100,
      progress: Math.min(stats.longestStreak, 100),
      maxProgress: 100,
    }),
  },
  // Total days badges
  {
    id: 'total_10',
    name: 'Primo traguardo',
    description: 'Leggi per 10 giorni in totale',
    icon: '📖',
    tier: 'bronze',
    check: (stats) => ({
      unlocked: stats.totalDaysRead >= 10,
      progress: Math.min(stats.totalDaysRead, 10),
      maxProgress: 10,
    }),
  },
  {
    id: 'total_50',
    name: 'Lettore assiduo',
    description: 'Leggi per 50 giorni in totale',
    icon: '📚',
    tier: 'silver',
    check: (stats) => ({
      unlocked: stats.totalDaysRead >= 50,
      progress: Math.min(stats.totalDaysRead, 50),
      maxProgress: 50,
    }),
  },
  {
    id: 'total_100',
    name: 'Centurione',
    description: 'Leggi per 100 giorni in totale',
    icon: '🎖️',
    tier: 'gold',
    check: (stats) => ({
      unlocked: stats.totalDaysRead >= 100,
      progress: Math.min(stats.totalDaysRead, 100),
      maxProgress: 100,
    }),
  },
  {
    id: 'total_365',
    name: 'Un anno di letture',
    description: 'Leggi per 365 giorni in totale',
    icon: '🌟',
    tier: 'platinum',
    check: (stats) => ({
      unlocked: stats.totalDaysRead >= 365,
      progress: Math.min(stats.totalDaysRead, 365),
      maxProgress: 365,
    }),
  },
  // Consistency badges
  {
    id: 'consistency_50',
    name: 'Costante',
    description: 'Raggiungi il 50% di consistenza',
    icon: '🎯',
    tier: 'bronze',
    check: (stats) => ({
      unlocked: stats.consistencyScore >= 50,
      progress: Math.min(stats.consistencyScore, 50),
      maxProgress: 50,
    }),
  },
  {
    id: 'consistency_80',
    name: 'Determinato',
    description: 'Raggiungi l\'80% di consistenza',
    icon: '💪',
    tier: 'silver',
    check: (stats) => ({
      unlocked: stats.consistencyScore >= 80,
      progress: Math.min(stats.consistencyScore, 80),
      maxProgress: 80,
    }),
  },
  {
    id: 'consistency_95',
    name: 'Inarrestabile',
    description: 'Raggiungi il 95% di consistenza',
    icon: '🔱',
    tier: 'gold',
    check: (stats) => ({
      unlocked: stats.consistencyScore >= 95,
      progress: Math.min(stats.consistencyScore, 95),
      maxProgress: 95,
    }),
  },
  // Monthly goal badges
  {
    id: 'monthly_goal',
    name: 'Obiettivo mensile',
    description: 'Raggiungi l\'obiettivo mensile',
    icon: '🏅',
    tier: 'silver',
    check: (stats, records, monthStats, yearStats, goal) => {
      const achieved = monthStats ? monthStats.daysRead >= goal : false;
      return {
        unlocked: achieved,
        progress: monthStats?.daysRead || 0,
        maxProgress: goal,
      };
    },
  },
  // Perfect week badge
  {
    id: 'perfect_week',
    name: 'Settimana perfetta',
    description: 'Leggi tutti i 7 giorni di una settimana',
    icon: '✨',
    tier: 'silver',
    check: (stats) => {
      const hasPerfectWeek = stats.weeklyTrend.some(w => w.percentage === 100 && w.daysRead === 7);
      return {
        unlocked: hasPerfectWeek,
      };
    },
  },
  // Early bird (first record)
  {
    id: 'first_step',
    name: 'Primo passo',
    description: 'Registra la tua prima lettura',
    icon: '🚀',
    tier: 'bronze',
    check: (stats) => ({
      unlocked: stats.totalDaysRead >= 1,
      progress: Math.min(stats.totalDaysRead, 1),
      maxProgress: 1,
    }),
  },
];

export function useBadges(
  overallStats: OverallStats,
  records: ReadingRecord,
  currentMonthStats: MonthStats | null,
  currentYearStats: YearStats | null,
  monthlyGoal: number
) {
  const badges = useMemo(() => {
    return BADGE_DEFINITIONS.map((def): Badge => {
      const result = def.check(overallStats, records, currentMonthStats, currentYearStats, monthlyGoal);
      return {
        id: def.id,
        name: def.name,
        description: def.description,
        icon: def.icon,
        tier: def.tier,
        unlocked: result.unlocked,
        progress: result.progress,
        maxProgress: result.maxProgress,
      };
    });
  }, [overallStats, records, currentMonthStats, currentYearStats, monthlyGoal]);

  const unlockedBadges = badges.filter(b => b.unlocked);
  const lockedBadges = badges.filter(b => !b.unlocked);
  const totalBadges = badges.length;
  const unlockedCount = unlockedBadges.length;

  return {
    badges,
    unlockedBadges,
    lockedBadges,
    totalBadges,
    unlockedCount,
  };
}
