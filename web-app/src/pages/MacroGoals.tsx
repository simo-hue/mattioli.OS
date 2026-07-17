import { LongTermGoals } from '@/components/goals/LongTermGoals';


const MacroGoals = () => {
    return (
        <div className="flex-1 min-h-dvh flex flex-col pt-8 pb-12 px-4 sm:px-8 animate-fade-in relative z-10 w-full max-w-[1200px] mx-auto">
            <div className="fixed top-[-20%] right-[-10%] w-[50%] h-[50%] bg-purple-500/5 blur-[120px] rounded-full pointer-events-none -z-10" />

            {/* Top Nav Placeholder - Ideally should be consistent with Index.tsx */}
            {/* Assuming we might want a back button or just the global nav if it persists layout. 
           For now, let's keep it simple. */}

            <div className="mb-8 flex items-center justify-between">
                <div>
                    <h1 className="text-3xl font-display font-bold text-foreground">Macro Obiettivi</h1>
                    <p className="text-muted-foreground">Pianificazione a lungo termine.</p>
                </div>

            </div>

            <div className="glass-panel p-6 rounded-2xl min-h-[600px]">
                <LongTermGoals />
            </div>
        </div>
    );
};

export default MacroGoals;
