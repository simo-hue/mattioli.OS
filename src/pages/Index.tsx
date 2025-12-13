import { useState } from 'react';
import { HabitCalendar } from '@/components/HabitCalendar';
import { WeeklyView } from '@/components/WeeklyView';
import { DailyView } from '@/components/DailyView';
import { HabitSettings } from '@/components/HabitSettings';
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { LayoutGrid, Calendar, ListTodo } from 'lucide-react';
import { useGoals } from '@/hooks/useGoals';

const Index = () => {
  const {
    goals,
    logs: records, // Alias to keep prop compatibility
    createGoal,
    deleteGoal,
    toggleGoal
  } = useGoals();

  const [view, setView] = useState("month");

  return (
    <div className="flex-1 min-h-dvh flex flex-col pt-8 pb-12 px-4 sm:px-8 animate-fade-in relative z-10 w-full max-w-[2400px] mx-auto">

      {/* Background Glow */}
      <div className="fixed top-[-20%] left-[-10%] w-[50%] h-[50%] bg-primary/5 blur-[120px] rounded-full pointer-events-none -z-10" />

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 w-full">

        {/* SIDEBAR / COMMAND CENTER (Cols 1-3) */}
        <div className="lg:col-span-3 space-y-8">
          {/* Header */}
          <div className="glass-panel p-6 rounded-2xl space-y-4">
            <div>
              <h1 className="text-3xl font-display font-bold text-foreground">Protocollo</h1>
              <p className="text-muted-foreground text-sm">Esecuzione giornaliera.</p>
            </div>

            <div className="pt-4 border-t border-white/5">
              <HabitSettings
                habits={goals}
                onAddHabit={createGoal}
                onRemoveHabit={deleteGoal}
              />
            </div>
          </div>

          {/* Mini Stats / Quote (Placeholder for now) */}
          <div className="glass-card p-6 rounded-2xl hidden lg:block">
            <h3 className="text-sm font-medium text-muted-foreground uppercase tracking-widest mb-2">Status</h3>
            <div className="flex items-baseline gap-2">
              <span className="text-2xl font-bold font-mono-nums text-primary">Active</span>
              <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
            </div>
            <p className="text-xs text-muted-foreground mt-4">
              Mattioli.OS v1.0<br />
              System Optimized
            </p>
          </div>
        </div>

        {/* MAIN STAGE (Cols 4-12) */}
        <div className="lg:col-span-9 space-y-6">

          <Tabs defaultValue="month" value={view} onValueChange={setView} className="w-full">
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mb-6">
              <TabsList className="grid w-full sm:w-auto sm:inline-grid grid-cols-3 bg-card/40 border border-white/10 backdrop-blur-md rounded-xl p-1">
                <TabsTrigger value="month" className="rounded-lg data-[state=active]:bg-primary/20 data-[state=active]:text-primary font-medium text-xs sm:text-sm px-6">
                  <Calendar className="w-4 h-4 mr-2" />
                  Mese
                </TabsTrigger>
                <TabsTrigger value="week" className="rounded-lg data-[state=active]:bg-primary/20 data-[state=active]:text-primary font-medium text-xs sm:text-sm px-6">
                  <LayoutGrid className="w-4 h-4 mr-2" />
                  Settimana
                </TabsTrigger>
                <TabsTrigger value="day" className="rounded-lg data-[state=active]:bg-primary/20 data-[state=active]:text-primary font-medium text-xs sm:text-sm px-6">
                  <ListTodo className="w-4 h-4 mr-2" />
                  Oggi
                </TabsTrigger>
              </TabsList>
            </div>

            <div className="min-h-[600px] glass-panel rounded-2xl p-1 sm:p-2">
              <TabsContent value="month" className="mt-0 animate-scale-in h-full">
                <HabitCalendar
                  habits={goals}
                  records={records}
                  onToggleHabit={toggleGoal}
                />
              </TabsContent>
              <TabsContent value="week" className="mt-0 animate-scale-in h-full">
                <WeeklyView
                  habits={goals}
                  records={records}
                  onToggleHabit={toggleGoal}
                />
              </TabsContent>
              <TabsContent value="day" className="mt-0 animate-scale-in h-full">
                <div className="flex justify-center h-full">
                  <DailyView
                    habits={goals}
                    records={records}
                    onToggleHabit={toggleGoal}
                  />
                </div>
              </TabsContent>
            </div>
          </Tabs>

        </div>

      </div>
    </div>
  );
};

export default Index;
