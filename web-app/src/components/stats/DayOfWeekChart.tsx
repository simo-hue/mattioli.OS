import { Bar, BarChart, ResponsiveContainer, XAxis, Tooltip, Cell, YAxis } from 'recharts';
import { cn } from '@/lib/utils';

interface DayOfWeekChartProps {
    data: {
        dayIndex: number;
        dayName: string;
        rate: number;
    }[];
}

export function DayOfWeekChart({ data }: DayOfWeekChartProps) {
    // Determine max for scaling if needed, or fixed 0-100 domain

    // Find best day for highlighting
    const maxRate = Math.max(...data.map(d => d.rate));

    const CustomTooltip = ({ active, payload, label }: { active?: boolean, payload?: { value: number; payload: { fullDate: string } }[], label?: string }) => {
        if (active && payload && payload.length) {
            return (
                <div className="bg-background/95 backdrop-blur text-xs p-2 rounded-lg border border-border shadow-xl">
                    <p className="font-semibold mb-1">{label}</p>
                    <p className="text-primary space-x-2">
                        <span>Success Rate:</span>
                        <span className="font-mono font-bold">{payload[0].value}%</span>
                    </p>
                </div>
            );
        }
        return null;
    };

    return (
        <div className="w-full h-full min-h-[200px]">
            <ResponsiveContainer width="100%" height="100%">
                <BarChart data={data} margin={{ top: 10, right: 0, left: 0, bottom: 0 }}>
                    <XAxis
                        dataKey="dayName"
                        axisLine={false}
                        tickLine={false}
                        tick={{ fill: 'hsl(var(--muted-foreground))', fontSize: 10 }}
                        tickFormatter={(val) => val.slice(0, 3).toUpperCase()}
                        dy={10}
                    />
                    <YAxis
                        hide
                        domain={[0, 100]}
                    />
                    <Tooltip content={<CustomTooltip />} cursor={{ fill: 'hsl(var(--muted)/0.2)' }} />
                    <Bar dataKey="rate" radius={[4, 4, 0, 0]} maxBarSize={40}>
                        {data.map((entry, index) => (
                            <Cell
                                key={`cell-${index}`}
                                fill={entry.rate === maxRate && entry.rate > 0 ? 'hsl(var(--primary))' : 'hsl(var(--primary)/0.3)'}
                                className="transition-all duration-300 hover:opacity-80"
                            />
                        ))}
                    </Bar>
                </BarChart>
            </ResponsiveContainer>
        </div>
    );
}
