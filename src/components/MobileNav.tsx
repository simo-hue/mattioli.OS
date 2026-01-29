import { NavLink } from 'react-router-dom';
import { cn } from '@/lib/utils';
import { PieChart, Home, BarChart2 } from 'lucide-react';

const mobileNavItems = [
    { to: '/sw/dashboard', label: 'Home', icon: Home },
    { to: '/sw/stats', label: 'Stats', icon: BarChart2 },
    { to: '/sw/macro-goals', label: 'Obiettivi', icon: PieChart },
];

export function MobileNav() {
    return (
        <nav className="fixed bottom-0 left-0 right-0 z-50 bg-[#0a0a0a]/80 backdrop-blur-xl border-t border-white/10 pb-6 pt-2 px-6 lg:hidden">
            <div className="flex items-center justify-around max-w-md mx-auto">
                {mobileNavItems.map(({ to, label, icon: Icon }) => (
                    <NavLink
                        key={to}
                        to={to}
                        className={({ isActive }) =>
                            cn(
                                "flex flex-col items-center justify-center gap-1 p-2 rounded-2xl transition-all duration-300 w-16 group active:scale-95",
                                isActive
                                    ? "text-primary"
                                    : "text-muted-foreground hover:text-foreground"
                            )
                        }
                    >
                        {({ isActive }) => (
                            <>
                                <div className={cn(
                                    "relative p-1.5 rounded-xl transition-all duration-300",
                                    isActive ? "bg-primary/20" : "group-hover:bg-white/5"
                                )}>
                                    <Icon className={cn("w-6 h-6")} />
                                    {isActive && (
                                        <span className="absolute inset-0 rounded-xl ring-2 ring-primary/20 animate-pulse-success" />
                                    )}
                                </div>
                                <span className="text-[10px] font-medium tracking-wide">{label}</span>
                            </>
                        )}
                    </NavLink>
                ))}
            </div>
        </nav>
    );
}
