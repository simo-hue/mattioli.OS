import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';

export type ReadingStatus = 'done' | 'missed' | null;

export interface ReadingRecord {
  [date: string]: ReadingStatus;
}

export function useReadingTracker() {
  const [records, setRecords] = useState<ReadingRecord>({});
  const [isLoading, setIsLoading] = useState(true);

  // Load from Supabase on mount
  useEffect(() => {
    const fetchRecords = async () => {
      setIsLoading(true);
      const { data, error } = await supabase
        .from('reading_logs')
        .select('date, status');
      
      if (error) {
        console.error('Failed to fetch reading records:', error);
      } else if (data) {
        const recordsMap: ReadingRecord = {};
        data.forEach((row) => {
          recordsMap[row.date] = row.status as ReadingStatus;
        });
        setRecords(recordsMap);
      }
      setIsLoading(false);
    };

    fetchRecords();
  }, []);

  const getDateKey = (date: Date): string => {
    return date.toISOString().split('T')[0];
  };

  const getStatus = useCallback((date: Date): ReadingStatus => {
    return records[getDateKey(date)] || null;
  }, [records]);

  const setStatus = useCallback(async (date: Date, status: ReadingStatus) => {
    const key = getDateKey(date);
    
    // Optimistic update
    setRecords(prev => {
      if (status === null) {
        const { [key]: _, ...rest } = prev;
        return rest;
      }
      return { ...prev, [key]: status };
    });

    if (status === null) {
      // Delete from database
      const { error } = await supabase
        .from('reading_logs')
        .delete()
        .eq('date', key);
      
      if (error) {
        console.error('Failed to delete reading record:', error);
      }
    } else {
      // Upsert to database
      const { error } = await supabase
        .from('reading_logs')
        .upsert(
          { date: key, status },
          { onConflict: 'date' }
        );
      
      if (error) {
        console.error('Failed to save reading record:', error);
      }
    }
  }, []);

  const toggleStatus = useCallback((date: Date) => {
    const currentStatus = getStatus(date);
    let newStatus: ReadingStatus;
    
    if (currentStatus === null) {
      newStatus = 'done';
    } else if (currentStatus === 'done') {
      newStatus = 'missed';
    } else {
      newStatus = null;
    }
    
    setStatus(date, newStatus);
  }, [getStatus, setStatus]);

  const getStats = useCallback(() => {
    const today = new Date();
    const currentMonth = today.getMonth();
    const currentYear = today.getFullYear();
    
    let totalDone = 0;
    let totalMissed = 0;
    let monthDone = 0;
    let monthMissed = 0;
    let currentStreak = 0;
    let longestStreak = 0;
    let tempStreak = 0;

    // Calculate totals
    Object.entries(records).forEach(([dateStr, status]) => {
      const date = new Date(dateStr);
      
      if (status === 'done') {
        totalDone++;
        if (date.getMonth() === currentMonth && date.getFullYear() === currentYear) {
          monthDone++;
        }
      } else if (status === 'missed') {
        totalMissed++;
        if (date.getMonth() === currentMonth && date.getFullYear() === currentYear) {
          monthMissed++;
        }
      }
    });

    // Calculate streaks (sort dates and iterate)
    const sortedDates = Object.keys(records)
      .filter(date => records[date] === 'done')
      .sort();

    for (let i = 0; i < sortedDates.length; i++) {
      const current = new Date(sortedDates[i]);
      const prev = i > 0 ? new Date(sortedDates[i - 1]) : null;
      
      if (prev) {
        const diffDays = Math.floor((current.getTime() - prev.getTime()) / (1000 * 60 * 60 * 24));
        if (diffDays === 1) {
          tempStreak++;
        } else {
          tempStreak = 1;
        }
      } else {
        tempStreak = 1;
      }
      
      longestStreak = Math.max(longestStreak, tempStreak);
    }

    // Calculate current streak (from today backwards)
    const todayKey = getDateKey(today);
    let checkDate = new Date(today);
    
    while (true) {
      const key = getDateKey(checkDate);
      if (records[key] === 'done') {
        currentStreak++;
        checkDate.setDate(checkDate.getDate() - 1);
      } else if (key === todayKey && !records[key]) {
        // Today hasn't been marked yet, check yesterday
        checkDate.setDate(checkDate.getDate() - 1);
      } else {
        break;
      }
    }

    return {
      totalDone,
      totalMissed,
      monthDone,
      monthMissed,
      currentStreak,
      longestStreak,
    };
  }, [records]);

  return {
    records,
    isLoading,
    getStatus,
    setStatus,
    toggleStatus,
    getStats,
  };
}
