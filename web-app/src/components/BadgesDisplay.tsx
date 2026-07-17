import { Badge } from '@/hooks/useBadges';
import { cn } from '@/lib/utils';
import { Trophy, Lock } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';

interface BadgesDisplayProps {
  badges: Badge[];
  unlockedCount: number;
  totalBadges: number;
}

const TIER_COLORS = {
  bronze: 'from-amber-600/20 to-amber-800/20 border-amber-600/40',
  silver: 'from-slate-300/20 to-slate-500/20 border-slate-400/40',
  gold: 'from-yellow-400/20 to-amber-500/20 border-yellow-500/40',
  platinum: 'from-cyan-300/20 to-purple-400/20 border-cyan-400/40',
};

const TIER_TEXT = {
  bronze: 'text-amber-600',
  silver: 'text-slate-400',
  gold: 'text-yellow-500',
  platinum: 'text-cyan-400',
};

function BadgeCard({ badge }: { badge: Badge }) {
  const tierColor = badge.tier ? TIER_COLORS[badge.tier] : '';
  const tierText = badge.tier ? TIER_TEXT[badge.tier] : '';

  return (
    <div
      className={cn(
        'relative rounded-xl p-3 border transition-all duration-300',
        badge.unlocked
          ? `bg-gradient-to-br ${tierColor}`
          : 'bg-muted/30 border-border opacity-50'
      )}
    >
      <div className="flex items-start gap-3">
        <div
          className={cn(
            'text-2xl flex-shrink-0',
            !badge.unlocked && 'grayscale'
          )}
        >
          {badge.unlocked ? badge.icon : <Lock className="w-6 h-6 text-muted-foreground" />}
        </div>
        <div className="flex-1 min-w-0">
          <p className={cn(
            'font-semibold text-sm truncate',
            badge.unlocked ? 'text-foreground' : 'text-muted-foreground'
          )}>
            {badge.name}
          </p>
          <p className="text-xs text-muted-foreground line-clamp-2">
            {badge.description}
          </p>
          {badge.progress !== undefined && badge.maxProgress !== undefined && !badge.unlocked && (
            <div className="mt-2">
              <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                <div
                  className={cn('h-full rounded-full bg-primary/60')}
                  style={{ width: `${(badge.progress / badge.maxProgress) * 100}%` }}
                />
              </div>
              <p className="text-xs text-muted-foreground mt-1">
                {badge.progress}/{badge.maxProgress}
              </p>
            </div>
          )}
        </div>
      </div>
      {badge.unlocked && badge.tier && (
        <span className={cn('absolute top-2 right-2 text-xs font-medium capitalize', tierText)}>
          {badge.tier}
        </span>
      )}
    </div>
  );
}

export function BadgesDisplay({ badges, unlockedCount, totalBadges }: BadgesDisplayProps) {
  const unlockedBadges = badges.filter(b => b.unlocked);
  const lockedBadges = badges.filter(b => !b.unlocked);

  // Show first 4 unlocked or close-to-unlock badges in preview
  const previewBadges = [
    ...unlockedBadges.slice(0, 3),
    ...lockedBadges.slice(0, Math.max(0, 3 - unlockedBadges.length)),
  ].slice(0, 3);

  return (
    <Dialog>
      <DialogTrigger asChild>
        <div className="bg-card rounded-xl p-5 border border-border cursor-pointer hover:border-primary/50 transition-colors animate-fade-in">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <Trophy className="w-5 h-5 text-primary" />
              <h3 className="font-display font-semibold text-foreground">
                Achievement
              </h3>
            </div>
            <span className="text-sm text-muted-foreground">
              {unlockedCount}/{totalBadges}
            </span>
          </div>

          <div className="grid grid-cols-3 gap-2">
            {previewBadges.map((badge) => (
              <div
                key={badge.id}
                className={cn(
                  'aspect-square rounded-lg flex items-center justify-center text-2xl',
                  badge.unlocked
                    ? 'bg-primary/10'
                    : 'bg-muted/30'
                )}
              >
                {badge.unlocked ? badge.icon : <Lock className="w-5 h-5 text-muted-foreground" />}
              </div>
            ))}
          </div>

          <p className="text-xs text-muted-foreground text-center mt-3">
            Tocca per vedere tutti i badge
          </p>
        </div>
      </DialogTrigger>

      <DialogContent className="max-w-md max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Trophy className="w-5 h-5 text-primary" />
            I tuoi Achievement ({unlockedCount}/{totalBadges})
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4 mt-4">
          {unlockedBadges.length > 0 && (
            <div>
              <h4 className="text-sm font-medium text-foreground mb-2">Sbloccati</h4>
              <div className="grid gap-2">
                {unlockedBadges.map((badge) => (
                  <BadgeCard key={badge.id} badge={badge} />
                ))}
              </div>
            </div>
          )}

          {lockedBadges.length > 0 && (
            <div>
              <h4 className="text-sm font-medium text-muted-foreground mb-2">Da sbloccare</h4>
              <div className="grid gap-2">
                {lockedBadges.map((badge) => (
                  <BadgeCard key={badge.id} badge={badge} />
                ))}
              </div>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
