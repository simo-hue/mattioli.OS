import { cn } from '@/lib/utils';
import { LucideIcon } from 'lucide-react';

interface StatsCardProps {
  title: string;
  value: number | string;
  icon: LucideIcon;
  variant?: 'default' | 'success' | 'destructive';
  delay?: number;
}

export function StatsCard({ title, value, icon: Icon, variant = 'default', delay = 0 }: StatsCardProps) {
  return (
    <div 
      className={cn(
        "bg-card rounded-xl p-5 border border-border shadow-sm transition-all duration-300 hover:shadow-md animate-fade-in",
        variant === 'success' && "border-l-4 border-l-success",
        variant === 'destructive' && "border-l-4 border-l-destructive",
      )}
      style={{ animationDelay: `${delay}ms` }}
    >
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm font-medium text-muted-foreground">{title}</p>
          <p className={cn(
            "text-3xl font-display font-bold mt-1",
            variant === 'success' && "text-success",
            variant === 'destructive' && "text-destructive",
            variant === 'default' && "text-foreground",
          )}>
            {value}
          </p>
        </div>
        <div className={cn(
          "p-2 rounded-lg",
          variant === 'success' && "bg-success/10",
          variant === 'destructive' && "bg-destructive/10",
          variant === 'default' && "bg-primary/10",
        )}>
          <Icon className={cn(
            "w-5 h-5",
            variant === 'success' && "text-success",
            variant === 'destructive' && "text-destructive",
            variant === 'default' && "text-primary",
          )} />
        </div>
      </div>
    </div>
  );
}
