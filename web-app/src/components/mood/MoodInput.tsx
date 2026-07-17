import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Slider } from "@/components/ui/slider";
import { Button } from "@/components/ui/button";
import { HeartPulse, Zap, Save } from "lucide-react";
import { useTodaysMood, useLogMood } from "@/hooks/useMoods";
import { format } from "date-fns";
import { cn } from "@/lib/utils";

export const MoodInput = () => {
    const { data: todaysMood, isLoading } = useTodaysMood();
    const logMood = useLogMood();

    const [mood, setMood] = useState([5]);
    const [energy, setEnergy] = useState([5]);

    useEffect(() => {
        if (todaysMood) {
            setMood([todaysMood.mood_score]);
            setEnergy([todaysMood.energy_score]);
        }
    }, [todaysMood]);

    const handleSave = () => {
        logMood.mutate({
            date: format(new Date(), "yyyy-MM-dd"),
            mood_score: mood[0],
            energy_score: energy[0],
        });
    };

    const getEmoji = (val: number) => {
        if (val >= 8) return "🤩";
        if (val >= 6) return "😊";
        if (val >= 4) return "😐";
        if (val >= 3) return "😕";
        return "😫";
    };

    const getColor = (val: number) => {
        // Monochromatic scale: 
        // 1-3: muted/dark (sad)
        // 4-6: medium (neutral)
        // 7-10: bright/foreground (happy)
        return "text-foreground";
    };

    if (isLoading) return <div className="h-40 animate-pulse bg-muted rounded-xl" />;

    return (
        <Card className="w-full border shadow-sm overflow-hidden relative">
            <CardHeader className="pb-2">
                <CardTitle className="text-lg font-medium flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        Daily Check-in
                    </div>
                    {!todaysMood && (
                        <span className="flex h-2 w-2">
                            <span className="animate-ping absolute inline-flex h-2 w-2 rounded-full bg-primary opacity-75"></span>
                            <span className="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
                        </span>
                    )}
                </CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
                {/* Mood Slider */}
                <div className="space-y-4">
                    <div className="flex justify-between items-center">
                        <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
                            <HeartPulse className="w-4 h-4" />
                            Mood
                        </div>
                        <span className={cn("text-lg font-bold transition-colors", getColor(mood[0]))}>
                            {getEmoji(mood[0])} {mood[0]}/10
                        </span>
                    </div>
                    <Slider
                        value={mood}
                        onValueChange={setMood}
                        max={10}
                        min={1}
                        step={1}
                        className="cursor-pointer"
                    />
                </div>

                {/* Energy Slider */}
                <div className="space-y-4">
                    <div className="flex justify-between items-center">
                        <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
                            <Zap className="w-4 h-4" />
                            Energy
                        </div>
                        <span className={cn("text-lg font-bold transition-colors", getColor(energy[0]))}>
                            ⚡ {energy[0]}/10
                        </span>
                    </div>
                    <Slider
                        value={energy}
                        onValueChange={setEnergy}
                        max={10}
                        min={1}
                        step={1}
                        className="cursor-pointer"
                    />
                </div>

                <Button
                    onClick={handleSave}
                    disabled={logMood.isPending}
                    className="w-full mt-2 transition-all duration-300 transform hover:scale-[1.02]"
                >
                    {logMood.isPending ? "Saving..." : (
                        <>
                            <Save className="w-4 h-4 mr-2" />
                            {todaysMood ? "Update Daily Status" : "Insert Daily Status"}
                        </>
                    )}
                </Button>
            </CardContent>
        </Card>
    );
};
