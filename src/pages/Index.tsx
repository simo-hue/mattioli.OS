import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useGoals } from '@/hooks/useGoals';
import { usePrivacy } from '@/context/PrivacyContext';
import { useAI } from '@/context/AIContext';
import { toast } from 'sonner';
import { HabitCalendar } from '@/components/HabitCalendar';
import { WeeklyView } from '@/components/WeeklyView';
import { AnnualView } from '@/components/AnnualView';
import { HabitSettings } from '@/components/HabitSettings';
import { MemoModal } from '@/components/MemoModal';
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Button } from '@/components/ui/button';
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,

} from "@/components/ui/alert-dialog";
import { LayoutGrid, Calendar, ListTodo, Download, Trash2, Eye, EyeOff, Wifi, WifiOff, AlertTriangle, HeartPulse, Circle, Database, Bot } from 'lucide-react';
import { MoodInput } from '@/components/mood/MoodInput';
import { useSystemStatus } from '@/hooks/useSystemStatus';
import { useTodaysMood } from '@/hooks/useMoods';
import { cn } from '@/lib/utils';
import { Drawer, DrawerContent, DrawerTrigger, DrawerHeader, DrawerTitle, DrawerDescription } from "@/components/ui/drawer";

const Index = () => {
  const navigate = useNavigate();
  const { status, latency } = useSystemStatus();
  const { data: todaysMood } = useTodaysMood();
  const {
    goals,
    logs: records, // Alias to keep prop compatibility
    allGoals,
    rawLogs,
    createGoal,
    updateGoal,
    deleteGoal,
    toggleGoal,
    isDeleting,
    isUpdating,
    resetAllData,
    isResetting
  } = useGoals();

  const { isPrivacyMode, setIsPrivacyMode } = usePrivacy();
  const { isAIEnabled, setIsAIEnabled } = useAI();

  const handleExport = () => {
    if (!rawLogs || !allGoals) {
      toast.error("Nessun dato da esportare");
      return;
    }

    try {
      // Create a map for quick goal title lookup
      const goalMap = new Map(allGoals.map(g => [g.id, g.title]));

      // CSV Header
      const csvRows = ['Date,Habit Name,Status,Value,Notes'];

      // CSV Rows
      rawLogs.forEach(log => {
        const goalName = goalMap.get(log.goal_id) || 'Archived Habit';
        // Excel/CSV escaping: quotes must be doubled, and fields containing commas/quotes wrapped in quotes
        const escape = (text: string) => `"${text.replace(/"/g, '""')}"`;

        const row = [
          log.date,
          escape(goalName),
          log.status,
          log.value || '',
          log.notes ? escape(log.notes) : ''
        ].join(',');
        csvRows.push(row);
      });

      // Create Blob and download
      const blob = new Blob([csvRows.join('\n')], { type: 'text/csv;charset=utf-8;' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `habit-tracker-export-${new Date().toISOString().split('T')[0]}.csv`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);

      toast.success('Export completato!');
    } catch (error) {
      console.error('Export failed:', error);
      toast.error('Errore durante l\'export');
    }
  };

  const [view, setView] = useState("month");

  return (
    <div className="flex-1 h-full overflow-hidden flex flex-col pt-4 lg:pt-8 pb-0 sm:pb-8 px-4 sm:px-8 animate-fade-in relative z-10 w-full max-w-[2400px] mx-auto">

      {/* Background Glow */}
      <div className="fixed top-[-20%] left-[-10%] w-[50%] h-[50%] bg-primary/5 blur-[120px] rounded-full pointer-events-none -z-10" />

      <div className="flex flex-col lg:grid lg:grid-cols-12 gap-2 lg:gap-8 w-full h-full lg:h-full">

        {/* SIDEBAR / COMMAND CENTER (Cols 1-3) */}
        <div className="lg:col-span-3 space-y-2 lg:space-y-8">
          {/* Header */}
          <div className="glass-panel p-4 lg:p-6 rounded-2xl space-y-4 transition-all">
            <div className="flex flex-row lg:flex-col items-center lg:items-start justify-between gap-4">
              <div>
                <h1 className="text-2xl lg:text-3xl font-display font-bold text-foreground">Protocollo</h1>
                <p className="text-muted-foreground text-xs lg:text-sm">Esecuzione giornaliera.</p>
              </div>

              <div className="flex items-center gap-4">
                <div className="flex items-center space-x-2">
                  <Switch
                    id="privacy-mode"
                    checked={isPrivacyMode}
                    onCheckedChange={setIsPrivacyMode}
                  />
                  <Label htmlFor="privacy-mode" className="text-xs text-muted-foreground flex items-center gap-2 cursor-pointer sr-only lg:not-sr-only lg:flex">
                    {isPrivacyMode ? <EyeOff className="w-3 h-3" /> : <Eye className="w-3 h-3" />}
                    Privacy
                  </Label>
                </div>
                <div className="flex items-center space-x-2">
                  <Switch
                    id="ai-mode"
                    checked={isAIEnabled}
                    onCheckedChange={setIsAIEnabled}
                  />
                  <Label htmlFor="ai-mode" className="text-xs text-muted-foreground flex items-center gap-2 cursor-pointer sr-only lg:not-sr-only lg:flex">
                    <Bot className="w-3 h-3" />
                    AI
                  </Label>
                </div>
              </div>
            </div>

            <div className="pt-0 lg:pt-4 border-t-0 lg:border-t border-white/5 flex gap-2 justify-end lg:justify-start">

              <div className="lg:hidden mr-auto relative">
                <Drawer shouldScaleBackground={false}>
                  <DrawerTrigger asChild>
                    <Button
                      variant="outline"
                      size="icon"
                      className={cn(
                        "h-10 w-10 sm:h-9 sm:w-9 border-primary/20 bg-primary/5 transition-all",
                        !todaysMood ? "text-primary border-primary/40 shadow-[0_0_10px_-3px_rgba(255,255,255,0.1)]" : "text-muted-foreground"
                      )}
                    >
                      <HeartPulse className={cn("h-4 w-4", !todaysMood && "animate-pulse")} />
                      {/* Notification Dot */}
                      {!todaysMood && (
                        <span className="absolute top-2 right-2.5 h-1.5 w-1.5 rounded-full bg-red-500 shadow-[0_0_8px_2px_rgba(239,68,68,0.5)] animate-pulse" />
                      )}
                    </Button>
                  </DrawerTrigger>
                  <DrawerContent>
                    <div className="mx-auto w-full max-w-sm">
                      <DrawerHeader>
                        <DrawerTitle>Daily Check-in</DrawerTitle>
                        <DrawerDescription>Traccia il tuo umore ed energia.</DrawerDescription>
                      </DrawerHeader>
                      <div className="p-4 pb-8">
                        <MoodInput />
                      </div>
                    </div>
                  </DrawerContent>
                </Drawer>
              </div>

              <MemoModal />
              <HabitSettings
                habits={goals}
                onAddHabit={createGoal}
                onUpdateHabit={updateGoal}
                onRemoveHabit={deleteGoal}
                isDeleting={isDeleting}
                isUpdating={isUpdating}
                isPrivacyMode={isPrivacyMode}
              />
              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <Button
                    variant="outline"
                    size="icon"
                    className="h-10 w-10 sm:h-9 sm:w-9"
                    title="Esporta dati CSV"
                  >
                    <Download className="h-4 w-4" />
                  </Button>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Esportare i dati?</AlertDialogTitle>
                    <AlertDialogDescription>
                      Verrà scaricato un file CSV contenente tutto lo storico delle tue abitudini. <br />
                      Vuoi procedere con il download?
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Annulla</AlertDialogCancel>
                    <AlertDialogAction onClick={handleExport}>
                      Esporta CSV
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>

              <Button
                variant="outline"
                size="icon"
                className="h-10 w-10 sm:h-9 sm:w-9 border-primary/20 bg-primary/5 hover:bg-primary/10"
                title="Backup Completo"
                onClick={() => navigate('/complete-backup')}
              >
                <Database className="h-4 w-4" />
              </Button>

              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-10 w-10 sm:h-9 sm:w-9 bg-red-500/10 text-red-500 hover:bg-red-500 hover:text-white border-red-500/20"
                    title="Hard Reset (Elimina tutto)"
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle className="text-destructive">Hard Reset: Attenzione!</AlertDialogTitle>
                    <AlertDialogDescription>
                      Questa azione eliminerà <strong>definitivamente</strong> tutte le tue abitudini e tutto lo storico dei progressi.
                      <br /><br />
                      I dati non potranno essere recuperati. Sei sicuro di voler procedere?
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Annulla</AlertDialogCancel>
                    <AlertDialogAction
                      onClick={() => resetAllData()}
                      className="bg-destructive hover:bg-destructive/90 text-destructive-foreground"
                      disabled={isResetting}
                    >
                      {isResetting ? 'Eliminazione...' : 'Conferma Reset Totale'}
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </div>
          </div>

          {/* Mini Stats / Quote */}
          <div className="glass-card p-6 rounded-2xl hidden lg:block transition-colors duration-300">
            <h3 className="text-sm font-medium text-muted-foreground uppercase tracking-widest mb-2 flex items-center justify-between">
              System Status
              {status === 'active' && <Wifi className="w-4 h-4 text-green-500" />}
              {status === 'offline' && <WifiOff className="w-4 h-4 text-yellow-500" />}
              {status === 'error' && <AlertTriangle className="w-4 h-4 text-red-500" />}
            </h3>
            <div className="flex items-baseline gap-2">
              <span className={cn(
                "text-2xl font-bold font-mono-nums transition-colors",
                status === 'active' ? "text-primary" :
                  status === 'offline' ? "text-yellow-500" : "text-red-500"
              )}>
                {status === 'active' ? 'Online' : status === 'offline' ? 'Offline' : 'Error'}
              </span>
              <span className={cn(
                "w-2 h-2 rounded-full animate-pulse",
                status === 'active' ? "bg-green-500" :
                  status === 'offline' ? "bg-yellow-500" : "bg-red-500"
              )} />
            </div>
            <p className="text-xs text-muted-foreground mt-4 flex justify-between items-center">
              <span>Mattioli.OS v4.1</span>
              {latency && <span className="font-mono opacity-50">{latency}ms</span>}
            </p>
          </div>

          {/* Mood Input - User Friendly & Professional */}
          <div className="hidden lg:block">
            <MoodInput />
          </div>
        </div>

        {/* MAIN STAGE (Cols 4-12) */}
        <div className="lg:col-span-9 flex flex-col flex-1 h-full min-h-0 overflow-hidden lg:overflow-visible">

          <Tabs defaultValue="month" value={view} onValueChange={setView} className="w-full h-full flex flex-col">
            <div className="flex flex-col sm:flex-row items-center justify-between gap-4 mb-4 lg:mb-4 shrink-0">
              <TabsList className="grid w-full grid-cols-3 bg-card/40 border border-white/10 backdrop-blur-md rounded-xl p-1 shadow-sm h-10 sm:h-auto">
                <TabsTrigger value="month" className="rounded-lg data-[state=active]:bg-primary/20 data-[state=active]:text-primary font-medium text-xs sm:text-sm h-full sm:py-2 flex items-center justify-center gap-1.5 sm:gap-2">
                  <Calendar className="w-4 h-4" />
                  <span className="xs:inline">Mese</span>
                </TabsTrigger>
                <TabsTrigger value="week" className="rounded-lg data-[state=active]:bg-primary/20 data-[state=active]:text-primary font-medium text-xs sm:text-sm h-full sm:py-2 flex items-center justify-center gap-1.5 sm:gap-2">
                  <LayoutGrid className="w-4 h-4" />
                  <span className="xs:inline">Settimana</span>
                </TabsTrigger>
                <TabsTrigger value="year" className="rounded-lg data-[state=active]:bg-primary/20 data-[state=active]:text-primary font-medium text-xs sm:text-sm h-full sm:py-2 flex items-center justify-center gap-1.5 sm:gap-2">
                  <ListTodo className="w-4 h-4" />
                  <span className="xs:inline">Anno</span>
                </TabsTrigger>
              </TabsList>
            </div>

            <div className="flex-1 flex flex-col min-h-0 glass-panel rounded-xl sm:rounded-2xl p-0 sm:p-2 overflow-hidden mb-2">
              <TabsContent value="month" className="mt-0 animate-scale-in h-full">
                <HabitCalendar
                  habits={goals}
                  records={records}
                  onToggleHabit={toggleGoal}
                  isPrivacyMode={isPrivacyMode}
                />
              </TabsContent>
              <TabsContent value="week" className="mt-0 animate-scale-in h-full">
                <WeeklyView
                  habits={goals}
                  records={records}
                  onToggleHabit={toggleGoal}
                  isPrivacyMode={isPrivacyMode}
                />
              </TabsContent>
              <TabsContent value="year" className="mt-0 animate-scale-in h-full">
                <AnnualView
                  habits={goals}
                  records={records}
                  onToggleHabit={toggleGoal}
                  isPrivacyMode={isPrivacyMode}
                />
              </TabsContent>
            </div>
          </Tabs>

        </div>

      </div>
    </div>
  );
};

export default Index;
