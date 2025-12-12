import { AdvancedDashboard } from '@/components/AdvancedDashboard';
import { useReadingTracker } from '@/hooks/useReadingTracker';
import { useReadingStats } from '@/hooks/useReadingStats';
import { useMonthlyGoal } from '@/hooks/useMonthlyGoal';

const Panoramica = () => {
  const { records } = useReadingTracker();
  const stats = useReadingStats(records);
  const { goal, updateGoal } = useMonthlyGoal();

  return (
    <div className="container mx-auto px-3 sm:px-4 py-4 sm:py-8 max-w-3xl">
      <AdvancedDashboard 
        overall={stats.overall}
        currentYearStats={stats.currentYearStats}
        currentMonthStats={stats.currentMonthStats}
        records={records}
        monthlyGoal={goal}
        onGoalChange={updateGoal}
      />
    </div>
  );
};

export default Panoramica;
