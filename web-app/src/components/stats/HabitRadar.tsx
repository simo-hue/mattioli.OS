import { Radar, RadarChart, PolarGrid, PolarAngleAxis, ResponsiveContainer } from 'recharts';
import { HabitStat } from '@/hooks/useHabitStats';

interface HabitRadarProps {
    stats: HabitStat[];
}

export function HabitRadar({ stats }: HabitRadarProps) {
    const data = stats.map(s => ({
        subject: s.title,
        A: s.completionRate,
        fullMark: 100
    }));

    if (stats.length < 3) {
        return (
            <div className="bg-card/50 backdrop-blur-sm rounded-3xl p-6 border border-white/5 shadow-xl h-[300px] flex items-center justify-center text-center">
                <p className="text-muted-foreground text-sm">
                    Add at least 3 habits <br /> to unlock Radar view.
                </p>
            </div>
        )
    }

    return (
        <div className="w-full h-full min-h-0">
            <ResponsiveContainer width="100%" height="100%">
                <RadarChart cx="50%" cy="50%" outerRadius="70%" data={data}>
                    <PolarGrid stroke="hsl(var(--border))" />
                    <PolarAngleAxis
                        dataKey="subject"
                        tick={{ fill: 'hsl(var(--muted-foreground))', fontSize: 10 }}
                    />
                    <Radar
                        name="Completion"
                        dataKey="A"
                        stroke="hsl(var(--primary))"
                        strokeWidth={2}
                        fill="hsl(var(--primary))"
                        fillOpacity={0.4}
                    />
                </RadarChart>
            </ResponsiveContainer>
        </div>
    );
}
