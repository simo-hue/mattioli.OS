import { Outlet, Link } from 'react-router-dom';
import { BookOpen } from 'lucide-react';
import { GlobalNav } from './GlobalNav';

export function Layout() {
  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Header */}
      {/* Header */}
      <header className="border-b border-border bg-background/80 backdrop-blur-md sticky top-0 z-50">
        <div className="h-16 flex items-center justify-between px-4 sm:px-8 max-w-[2400px] mx-auto w-full">
          <Link to="/" className="flex items-center gap-2 sm:gap-3 group">
            <div className="bg-primary/10 p-1.5 sm:p-2 rounded-lg border border-primary/20 group-hover:border-primary/50 transition-colors">
              <BookOpen className="h-4 w-4 sm:h-5 sm:w-5 text-primary" />
            </div>
            <span className="font-display font-bold text-base sm:text-lg tracking-tight group-hover:text-primary transition-colors">
              Mattioli.OS
            </span>
          </Link>

          <GlobalNav />
        </div>
      </header>

      {/* Main content */}
      <main className="flex-1">
        <Outlet />
      </main>
    </div>
  );
}
