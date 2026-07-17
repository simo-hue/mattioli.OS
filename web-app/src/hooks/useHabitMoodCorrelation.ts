import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { Goal, GoalLogsMap } from '@/types/goals';
import { DailyMood } from '@/types/mood';
import { format, parseISO } from 'date-fns';

export interface HabitMoodCorrelation {
    habitId: string;
    habitTitle: string;
    habitColor: string;

    // Average scores
    avgMoodWhenCompleted: number;
    avgMoodWhenMissed: number;
    avgEnergyWhenCompleted: number;
    avgEnergyWhenMissed: number;

    // Completion rates by mood/energy ranges
    completionRateByMood: {
        low: number;      // mood 1-4
        medium: number;   // mood 5-7
        high: number;     // mood 8-10
    };
    completionRateByEnergy: {
        low: number;      // energy 1-4
        medium: number;   // energy 5-7
        high: number;     // energy 8-10
    };

    // Correlation strength (-1 to 1)
    moodCorrelation: number;
    energyCorrelation: number;

    // Classification
    isMoodSensitive: boolean;    // Performs significantly better with high mood
    isEnergySensitive: boolean;  // Performs significantly better with high energy
    isResilient: boolean;        // Maintains good rate even with low mood/energy

    // Sample size for statistical validity
    totalDaysWithMoodData: number;
    daysCompleted: number;
    daysMissed: number;
}

export interface MoodEnergyInsights {
    // Most mood-sensitive habits (suffer with low mood)
    moodSensitiveHabits: HabitMoodCorrelation[];

    // Most energy-sensitive habits (suffer with low energy)
    energySensitiveHabits: HabitMoodCorrelation[];

    // Most resilient habits (maintained despite low mood/energy)
    resilientHabits: HabitMoodCorrelation[];

    // Best performers by mood/energy level
    bestAtHighMood: HabitMoodCorrelation[];
    bestAtLowMood: HabitMoodCorrelation[];
    bestAtHighEnergy: HabitMoodCorrelation[];
    bestAtLowEnergy: HabitMoodCorrelation[];
}

// Helper function to calculate Pearson correlation coefficient
function calculateCorrelation(x: number[], y: number[]): number {
    if (x.length !== y.length || x.length === 0) return 0;

    const n = x.length;
    const sumX = x.reduce((a, b) => a + b, 0);
    const sumY = y.reduce((a, b) => a + b, 0);
    const sumXY = x.reduce((sum, xi, i) => sum + xi * y[i], 0);
    const sumX2 = x.reduce((sum, xi) => sum + xi * xi, 0);
    const sumY2 = y.reduce((sum, yi) => sum + yi * yi, 0);

    const numerator = n * sumXY - sumX * sumY;
    const denominator = Math.sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));

    if (denominator === 0) return 0;
    return numerator / denominator;
}

// Helper function to categorize mood/energy score
function categorizeScore(score: number): 'low' | 'medium' | 'high' {
    if (score <= 4) return 'low';
    if (score <= 7) return 'medium';
    return 'high';
}

export const useHabitMoodCorrelation = (goals: Goal[], logs: GoalLogsMap) => {
    // Fetch mood data
    const { data: moods } = useQuery({
        queryKey: ['moods'],
        queryFn: async () => {
            const { data, error } = await supabase
                .from('daily_moods')
                .select('*')
                .order('date', { ascending: false });

            if (error) throw error;
            return data as DailyMood[];
        }
    });

    const correlations = useMemo(() => {
        if (!moods || moods.length === 0 || goals.length === 0) return [];

        // Create a map of date -> mood/energy for quick lookup
        const moodMap = new Map<string, { mood: number; energy: number }>();
        moods.forEach(mood => {
            moodMap.set(mood.date, {
                mood: mood.mood_score,
                energy: mood.energy_score
            });
        });

        return goals.map(goal => {
            const habitLogs: {
                date: string;
                completed: boolean;
                mood: number;
                energy: number;
            }[] = [];

            // Collect all logs for this habit that have corresponding mood data
            Object.entries(logs).forEach(([date, goalStatuses]) => {
                const status = goalStatuses[goal.id];
                const moodData = moodMap.get(date);

                if (status && moodData) {
                    habitLogs.push({
                        date,
                        completed: status === 'done',
                        mood: moodData.mood,
                        energy: moodData.energy
                    });
                }
            });

            // Calculate statistics
            const completedLogs = habitLogs.filter(log => log.completed);
            const missedLogs = habitLogs.filter(log => !log.completed);

            const avgMoodWhenCompleted = completedLogs.length > 0
                ? completedLogs.reduce((sum, log) => sum + log.mood, 0) / completedLogs.length
                : 0;

            const avgMoodWhenMissed = missedLogs.length > 0
                ? missedLogs.reduce((sum, log) => sum + log.mood, 0) / missedLogs.length
                : 0;

            const avgEnergyWhenCompleted = completedLogs.length > 0
                ? completedLogs.reduce((sum, log) => sum + log.energy, 0) / completedLogs.length
                : 0;

            const avgEnergyWhenMissed = missedLogs.length > 0
                ? missedLogs.reduce((sum, log) => sum + log.energy, 0) / missedLogs.length
                : 0;

            // Calculate completion rates by mood/energy ranges
            const moodRanges = { low: 0, medium: 0, high: 0 };
            const moodRangeTotals = { low: 0, medium: 0, high: 0 };
            const energyRanges = { low: 0, medium: 0, high: 0 };
            const energyRangeTotals = { low: 0, medium: 0, high: 0 };

            habitLogs.forEach(log => {
                const moodCategory = categorizeScore(log.mood);
                const energyCategory = categorizeScore(log.energy);

                moodRangeTotals[moodCategory]++;
                energyRangeTotals[energyCategory]++;

                if (log.completed) {
                    moodRanges[moodCategory]++;
                    energyRanges[energyCategory]++;
                }
            });

            const completionRateByMood = {
                low: moodRangeTotals.low > 0 ? (moodRanges.low / moodRangeTotals.low) * 100 : 0,
                medium: moodRangeTotals.medium > 0 ? (moodRanges.medium / moodRangeTotals.medium) * 100 : 0,
                high: moodRangeTotals.high > 0 ? (moodRanges.high / moodRangeTotals.high) * 100 : 0,
            };

            const completionRateByEnergy = {
                low: energyRangeTotals.low > 0 ? (energyRanges.low / energyRangeTotals.low) * 100 : 0,
                medium: energyRangeTotals.medium > 0 ? (energyRanges.medium / energyRangeTotals.medium) * 100 : 0,
                high: energyRangeTotals.high > 0 ? (energyRanges.high / energyRangeTotals.high) * 100 : 0,
            };

            // Calculate correlation coefficients
            const completionValues = habitLogs.map(log => log.completed ? 1 : 0);
            const moodValues = habitLogs.map(log => log.mood);
            const energyValues = habitLogs.map(log => log.energy);

            const moodCorrelation = calculateCorrelation(moodValues, completionValues);
            const energyCorrelation = calculateCorrelation(energyValues, completionValues);

            // Classification logic
            // Mood-sensitive: completion rate drops significantly (>30%) from high to low mood
            const moodDrop = completionRateByMood.high - completionRateByMood.low;
            const isMoodSensitive = moodDrop > 30 && moodCorrelation > 0.3;

            // Energy-sensitive: completion rate drops significantly (>30%) from high to low energy
            const energyDrop = completionRateByEnergy.high - completionRateByEnergy.low;
            const isEnergySensitive = energyDrop > 30 && energyCorrelation > 0.3;

            // Resilient: maintains >60% completion rate even at low mood/energy
            const isResilient = completionRateByMood.low >= 60 && completionRateByEnergy.low >= 60;

            const correlation: HabitMoodCorrelation = {
                habitId: goal.id,
                habitTitle: goal.title,
                habitColor: goal.color,
                avgMoodWhenCompleted,
                avgMoodWhenMissed,
                avgEnergyWhenCompleted,
                avgEnergyWhenMissed,
                completionRateByMood,
                completionRateByEnergy,
                moodCorrelation,
                energyCorrelation,
                isMoodSensitive,
                isEnergySensitive,
                isResilient,
                totalDaysWithMoodData: habitLogs.length,
                daysCompleted: completedLogs.length,
                daysMissed: missedLogs.length,
            };

            return correlation;
        });
    }, [goals, logs, moods]);

    const insights = useMemo((): MoodEnergyInsights => {
        // Filter out habits with insufficient data (< 5 days)
        const validCorrelations = correlations.filter(c => c.totalDaysWithMoodData >= 5);

        return {
            moodSensitiveHabits: validCorrelations
                .filter(c => c.isMoodSensitive)
                .sort((a, b) => b.moodCorrelation - a.moodCorrelation)
                .slice(0, 3),

            energySensitiveHabits: validCorrelations
                .filter(c => c.isEnergySensitive)
                .sort((a, b) => b.energyCorrelation - a.energyCorrelation)
                .slice(0, 3),

            resilientHabits: validCorrelations
                .filter(c => c.isResilient)
                .sort((a, b) =>
                    (b.completionRateByMood.low + b.completionRateByEnergy.low) -
                    (a.completionRateByMood.low + a.completionRateByEnergy.low)
                )
                .slice(0, 3),

            bestAtHighMood: validCorrelations
                .sort((a, b) => b.completionRateByMood.high - a.completionRateByMood.high)
                .slice(0, 3),

            bestAtLowMood: validCorrelations
                .sort((a, b) => b.completionRateByMood.low - a.completionRateByMood.low)
                .slice(0, 3),

            bestAtHighEnergy: validCorrelations
                .sort((a, b) => b.completionRateByEnergy.high - a.completionRateByEnergy.high)
                .slice(0, 3),

            bestAtLowEnergy: validCorrelations
                .sort((a, b) => b.completionRateByEnergy.low - a.completionRateByEnergy.low)
                .slice(0, 3),
        };
    }, [correlations]);

    return {
        correlations,
        insights,
        isLoading: !moods,
    };
};
