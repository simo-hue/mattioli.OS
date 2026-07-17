import { useMemo } from 'react';
import { Goal, GoalLogsMap } from '@/types/goals';

export interface HabitPairCorrelation {
    habitA: {
        id: string;
        title: string;
        color: string;
    };
    habitB: {
        id: string;
        title: string;
        color: string;
    };

    // Statistical measures
    correlationCoefficient: number;  // Pearson r (-1 to 1)
    coOccurrenceRate: number;         // % giorni done insieme
    totalDaysTracked: number;         // Sample size

    // Classification
    strength: 'weak' | 'moderate' | 'strong';
    type: 'positive' | 'negative' | 'none';
    isKeystonePair: boolean;          // Entrambe alte performance

    // Actionable insights
    suggestion: string;               // Testo human-readable
}

export interface KeystoneHabit {
    habitId: string;
    title: string;
    color: string;
    avgCorrelation: number;           // Media correlazioni con altre
    connectedHabits: number;          // Quante abitudini correlate
    impact: 'high' | 'medium' | 'low';
    connections: {
        habitId: string;
        title: string;
        correlation: number;
    }[];
}

export interface CorrelationInsights {
    // Top correlations (filtered by |r| >= 0.3)
    strongestPositive: HabitPairCorrelation[];
    strongestNegative: HabitPairCorrelation[];

    // Special patterns
    keystoneHabits: KeystoneHabit[];

    // Network metrics
    totalPairs: number;
    avgCorrelation: number;
    isolatedHabits: string[];  // Abitudini senza correlazioni significative
}

// Helper function to calculate Pearson correlation coefficient
// Reused from useHabitMoodCorrelation.ts
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

// Helper to classify correlation strength
function classifyStrength(r: number): 'weak' | 'moderate' | 'strong' {
    const absR = Math.abs(r);
    if (absR >= 0.6) return 'strong';
    if (absR >= 0.3) return 'moderate';
    return 'weak';
}

// Helper to classify correlation type
function classifyType(r: number): 'positive' | 'negative' | 'none' {
    if (r >= 0.3) return 'positive';
    if (r <= -0.3) return 'negative';
    return 'none';
}

// Generate human-readable suggestion
function generateSuggestion(correlation: HabitPairCorrelation): string {
    const { habitA, habitB, correlationCoefficient, coOccurrenceRate, type } = correlation;

    if (type === 'positive') {
        const percentage = Math.round(coOccurrenceRate);
        if (correlationCoefficient >= 0.6) {
            return `Quando completi "${habitA.title}", hai una probabilità del ${percentage}% di completare anche "${habitB.title}". Considera di farle insieme come routine consolidata.`;
        } else {
            return `"${habitA.title}" e "${habitB.title}" tendono ad essere completate insieme (${percentage}%). Prova a collegarle per rafforzare entrambe.`;
        }
    } else if (type === 'negative') {
        return `"${habitA.title}" e "${habitB.title}" raramente vengono completate lo stesso giorno. Potrebbero competere per tempo/energia - considera di pianificarle in giorni diversi.`;
    }

    return `Correlazione debole tra "${habitA.title}" e "${habitB.title}".`;
}

export const useHabitCorrelation = (goals: Goal[], logs: GoalLogsMap) => {
    const correlations = useMemo(() => {
        if (goals.length < 2) return [];

        const pairs: HabitPairCorrelation[] = [];

        // Get all unique date keys
        const allDates = Object.keys(logs).sort();

        // Calculate correlations for each habit pair
        for (let i = 0; i < goals.length; i++) {
            for (let j = i + 1; j < goals.length; j++) {
                const habitA = goals[i];
                const habitB = goals[j];

                const dataPoints: { dateStr: string; aComplete: number; bComplete: number }[] = [];

                // Collect data points where both habits were tracked
                allDates.forEach(dateStr => {
                    const dayLogs = logs[dateStr];
                    const statusA = dayLogs?.[habitA.id];
                    const statusB = dayLogs?.[habitB.id];

                    // Only include days where both habits have a status
                    if (statusA && statusB) {
                        dataPoints.push({
                            dateStr,
                            aComplete: statusA === 'done' ? 1 : 0,
                            bComplete: statusB === 'done' ? 1 : 0,
                        });
                    }
                });

                // Minimum sample size required for statistical validity
                const MIN_SAMPLE_SIZE = 10;
                if (dataPoints.length < MIN_SAMPLE_SIZE) continue;

                // Calculate metrics
                const aValues = dataPoints.map(d => d.aComplete);
                const bValues = dataPoints.map(d => d.bComplete);

                const r = calculateCorrelation(aValues, bValues);

                // Filter out weak correlations (|r| < 0.3)
                const CORRELATION_THRESHOLD = 0.3;
                if (Math.abs(r) < CORRELATION_THRESHOLD) continue;

                // Calculate co-occurrence rate (both done together)
                const bothDone = dataPoints.filter(d => d.aComplete === 1 && d.bComplete === 1).length;
                const aDone = dataPoints.filter(d => d.aComplete === 1).length;
                const coOccurrenceRate = aDone > 0 ? (bothDone / aDone) * 100 : 0;

                const strength = classifyStrength(r);
                const type = classifyType(r);

                // Check if both habits have high performance (>70% completion)
                const aCompletionRate = (aValues.reduce((a, b) => a + b, 0) / aValues.length) * 100;
                const bCompletionRate = (bValues.reduce((a, b) => a + b, 0) / bValues.length) * 100;
                const isKeystonePair = aCompletionRate >= 70 && bCompletionRate >= 70;

                const correlation: HabitPairCorrelation = {
                    habitA: {
                        id: habitA.id,
                        title: habitA.title,
                        color: habitA.color,
                    },
                    habitB: {
                        id: habitB.id,
                        title: habitB.title,
                        color: habitB.color,
                    },
                    correlationCoefficient: r,
                    coOccurrenceRate,
                    totalDaysTracked: dataPoints.length,
                    strength,
                    type,
                    isKeystonePair,
                    suggestion: '',
                };

                // Generate suggestion after creating object
                correlation.suggestion = generateSuggestion(correlation);

                pairs.push(correlation);
            }
        }

        return pairs;
    }, [goals, logs]);

    const insights = useMemo((): CorrelationInsights => {
        // Sort by absolute correlation strength
        const sortedByStrength = [...correlations].sort(
            (a, b) => Math.abs(b.correlationCoefficient) - Math.abs(a.correlationCoefficient)
        );

        // Split positive and negative
        const positive = sortedByStrength.filter(c => c.type === 'positive');
        const negative = sortedByStrength.filter(c => c.type === 'negative');

        // Calculate keystone habits (habits with many connections)
        const habitConnectionMap = new Map<string, {
            habit: Goal;
            correlations: number[];
            connections: { habitId: string; title: string; correlation: number }[];
        }>();

        goals.forEach(goal => {
            habitConnectionMap.set(goal.id, {
                habit: goal,
                correlations: [],
                connections: []
            });
        });

        correlations.forEach(corr => {
            const r = corr.correlationCoefficient;

            const dataA = habitConnectionMap.get(corr.habitA.id);
            if (dataA) {
                dataA.correlations.push(r);
                dataA.connections.push({
                    habitId: corr.habitB.id,
                    title: corr.habitB.title,
                    correlation: r
                });
            }

            const dataB = habitConnectionMap.get(corr.habitB.id);
            if (dataB) {
                dataB.correlations.push(r);
                dataB.connections.push({
                    habitId: corr.habitA.id,
                    title: corr.habitA.title,
                    correlation: r
                });
            }
        });

        const keystoneHabits: KeystoneHabit[] = [];

        habitConnectionMap.forEach((data, habitId) => {
            // Require at least 2 significant correlations to be keystone
            if (data.correlations.length >= 2) {
                const avgCorrelation = data.correlations.reduce((a, b) => a + b, 0) / data.correlations.length;

                let impact: 'high' | 'medium' | 'low' = 'low';
                if (data.correlations.length >= 4) impact = 'high';
                else if (data.correlations.length >= 3) impact = 'medium';

                // Sort connections by correlation strength
                const sortedConnections = [...data.connections].sort(
                    (a, b) => Math.abs(b.correlation) - Math.abs(a.correlation)
                );

                keystoneHabits.push({
                    habitId,
                    title: data.habit.title,
                    color: data.habit.color,
                    avgCorrelation,
                    connectedHabits: data.correlations.length,
                    impact,
                    connections: sortedConnections,
                });
            }
        });

        // Sort keystone habits by impact
        keystoneHabits.sort((a, b) => b.connectedHabits - a.connectedHabits);

        // Identify isolated habits (no significant correlations)
        const isolatedHabits = goals
            .filter(goal => !habitConnectionMap.get(goal.id)?.correlations.length)
            .map(goal => goal.id);

        // Calculate average correlation
        const avgCorrelation = correlations.length > 0
            ? correlations.reduce((sum, c) => sum + Math.abs(c.correlationCoefficient), 0) / correlations.length
            : 0;

        return {
            strongestPositive: positive.slice(0, 5),
            strongestNegative: negative.slice(0, 3),
            keystoneHabits: keystoneHabits.slice(0, 3),
            totalPairs: correlations.length,
            avgCorrelation,
            isolatedHabits,
        };
    }, [correlations, goals]);

    return {
        correlations,
        insights,
    };
};
