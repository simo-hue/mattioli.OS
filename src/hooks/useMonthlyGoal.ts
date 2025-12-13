import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';

const GOAL_KEY = 'monthly_goal';
const DEFAULT_GOAL = 20;

export function useMonthlyGoal() {
  const [goal, setGoal] = useState<number>(DEFAULT_GOAL);
  const [isLoading, setIsLoading] = useState(true);

  // Load from Supabase on mount
  useEffect(() => {
    const fetchGoal = async () => {
      setIsLoading(true);
      const { data, error } = await supabase
        .from('user_settings')
        .select('value')
        .eq('key', GOAL_KEY)
        .maybeSingle();
      
      if (error) {
        console.error('Failed to fetch monthly goal:', error);
      } else if (data) {
        setGoal(parseInt(data.value, 10));
      }
      setIsLoading(false);
    };

    fetchGoal();
  }, []);

  const updateGoal = async (newGoal: number) => {
    const clampedGoal = Math.max(1, Math.min(31, newGoal));
    
    // Optimistic update
    setGoal(clampedGoal);

    // Upsert to database
    const { error } = await supabase
      .from('user_settings')
      .upsert(
        { key: GOAL_KEY, value: clampedGoal.toString() },
        { onConflict: 'key' }
      );
    
    if (error) {
      console.error('Failed to save monthly goal:', error);
    }
  };

  return { goal, updateGoal, isLoading };
}
