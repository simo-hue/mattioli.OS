import { useState, useEffect } from 'react';

const STORAGE_KEY = 'reading-monthly-goal';
const DEFAULT_GOAL = 20;

export function useMonthlyGoal() {
  const [goal, setGoal] = useState<number>(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored ? parseInt(stored, 10) : DEFAULT_GOAL;
  });

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, goal.toString());
  }, [goal]);

  const updateGoal = (newGoal: number) => {
    const clampedGoal = Math.max(1, Math.min(31, newGoal));
    setGoal(clampedGoal);
  };

  return { goal, updateGoal };
}
