/* eslint-disable @typescript-eslint/no-explicit-any */
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { toast } from 'sonner';

export type HabitStatus = 'done' | 'missed' | null;

export interface Habit {
    id: string;
    title: string;
    color: string;
}

export interface DayRecord {
    [habitId: string]: HabitStatus;
}

export interface HabitRecord {
    [date: string]: DayRecord;
}

const DEFAULT_HABIT: Habit = {
    id: 'reading',
    title: 'Reading',
    color: 'hsl(var(--reading-done))' // adapting existing variable
};

export function useHabitTracker() {
    const [habits, setHabits] = useState<Habit[]>([DEFAULT_HABIT]);
    const [records, setRecords] = useState<HabitRecord>({});
    const [isLoading, setIsLoading] = useState(true);

    // Load Habits and Records
    useEffect(() => {
        const fetchData = async () => {
            setIsLoading(true);
            try {
                // 1. Fetch Habits from user_settings
                const { data: settingsData, error: settingsError } = await supabase
                    .from('user_settings')
                    .select('*')
                    .eq('key', 'habits')
                    .single();

                if (settingsError && settingsError.code !== 'PGRST116') {
                    console.error('Error fetching habits:', settingsError);
                }

                if ((settingsData as any)?.value) {
                    try {
                        setHabits(JSON.parse((settingsData as any).value));
                    } catch (e) {
                        console.error('Error parsing habits JSON:', e);
                    }
                }

                // 2. Fetch Records from reading_logs
                const { data: logsData, error: logsError } = await supabase
                    .from('reading_logs')
                    .select('date, status');

                if (logsError) throw logsError;

                if (logsData) {
                    const newRecords: HabitRecord = {};
                    logsData.forEach((row: { date: string, status: string }) => {
                        let dayRecord: DayRecord = {};
                        // Backward compatibility: check if status is simple string
                        if (row.status === 'done' || row.status === 'missed') {
                            dayRecord = { [DEFAULT_HABIT.id]: row.status as HabitStatus };
                        } else {
                            try {
                                dayRecord = JSON.parse(row.status);
                            } catch (e) {
                                // Fallback for unexpected format
                                console.warn('Failed to parse status JSON for date', row.date, row.status);
                            }
                        }
                        newRecords[row.date] = dayRecord;
                    });
                    setRecords(newRecords);
                }

            } catch (error) {
                console.error('Failed to load data:', error);
                toast.error('Failed to load data');
            } finally {
                setIsLoading(false);
            }
        };

        fetchData();
    }, []);

    const saveHabits = async (newHabits: Habit[]) => {
        setHabits(newHabits);
        try {
            const { error } = await supabase
                .from('user_settings')
                .upsert({
                    key: 'habits',
                    value: JSON.stringify(newHabits)
                } as any, { onConflict: 'key' });

            if (error) throw error;
        } catch (error) {
            console.error('Failed to save habits:', error);
            toast.error('Failed to save settings');
        }
    };

    const addHabit = (title: string, color: string) => {
        const newHabit: Habit = {
            id: crypto.randomUUID(),
            title,
            color
        };
        saveHabits([...habits, newHabit]);
    };

    const removeHabit = (id: string) => {
        saveHabits(habits.filter(h => h.id !== id));
    };

    const toggleHabitStatus = async (date: Date, habitId: string) => {
        const dateKey = date.toISOString().split('T')[0];
        const currentRecord = records[dateKey] || {};
        const currentStatus = currentRecord[habitId];

        let newStatus: HabitStatus;
        if (!currentStatus) newStatus = 'done';
        else if (currentStatus === 'done') newStatus = 'missed';
        else newStatus = null;

        const newDayRecord = { ...currentRecord };
        if (newStatus === null) {
            delete newDayRecord[habitId];
        } else {
            newDayRecord[habitId] = newStatus;
        }

        // Update Local State
        const newRecords = { ...records };
        if (Object.keys(newDayRecord).length === 0) {
            delete newRecords[dateKey];
        } else {
            newRecords[dateKey] = newDayRecord;
        }
        setRecords(newRecords);

        // Persist to Supabase
        try {
            if (Object.keys(newDayRecord).length === 0) {
                await supabase.from('reading_logs').delete().eq('date', dateKey);
            } else {
                await supabase.from('reading_logs').upsert({
                    date: dateKey,
                    status: JSON.stringify(newDayRecord)
                } as any, { onConflict: 'date' });
            }
        } catch (error) {
            console.error('Failed to save status:', error);
            toast.error('Failed to save progress');
            // Revert state on error (optional, simplified here)
        }
    };

    const getDayStatus = useCallback((date: Date) => {
        const dateKey = date.toISOString().split('T')[0];
        return records[dateKey] || {};
    }, [records]);

    return {
        habits,
        records,
        isLoading,
        addHabit,
        removeHabit,
        toggleHabitStatus,
        getDayStatus,
    };
}
