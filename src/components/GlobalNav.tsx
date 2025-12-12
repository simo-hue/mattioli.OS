import { NavLink } from 'react-router-dom';
import { cn } from '@/lib/utils';
import { PieChart, Grid3X3, BarChart2 } from 'lucide-react';

const navItems = [
  { to: '/panoramica', label: 'Panoramica', icon: PieChart },
  { to: '/mappa', label: 'Mappa', icon: Grid3X3 },
  { to: '/mensile', label: 'Mensile', icon: BarChart2 },
];

export function GlobalNav() {
  return (
    <nav className="flex items-center justify-center gap-1 sm:gap-2">
      {navItems.map(({ to, label, icon: Icon }) => (
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
