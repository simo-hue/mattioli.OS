import { NavLink } from 'react-router-dom';
import { cn } from '@/lib/utils';
import { PieChart, BarChart2, Sparkles } from 'lucide-react';
import { useAI } from '@/context/AIContext';

const navItems = [
  { to: '/sw/stats', label: 'Statistiche', icon: BarChart2 },
  { to: '/sw/ai-coach', label: 'AI Coach', icon: Sparkles },
  { to: '/sw/macro-goals', label: 'Macro Obiettivi', icon: PieChart },
];

export function GlobalNav() {
  const { isAIEnabled } = useAI();

  // Filter navigation items based on AI state
  const visibleNavItems = navItems.filter(item => {
    // Hide AI Coach if AI is disabled
    if (item.to === '/sw/ai-coach' && !isAIEnabled) {
      return false;
    }
    return true;
  });

  return (
    <nav className="flex items-center justify-center gap-1 sm:gap-2">
      {visibleNavItems.map(({ to, label, icon: Icon }) => (
        <NavLink
          key={to}
          to={to}
          className={({ isActive }) =>
            cn(
              "flex items-center gap-1.5 sm:gap-2 px-2.5 sm:px-4 py-2 rounded-lg text-xs sm:text-sm font-medium transition-all",
              "hover:bg-accent",
              isActive
                ? "bg-primary text-primary-foreground hover:bg-primary/90"
                : "text-muted-foreground"
            )
          }
        >
          <Icon className="w-4 h-4" />
          <span className="hidden xs:inline sm:inline">{label}</span>
        </NavLink>
      ))}
    </nav>
  );
}
