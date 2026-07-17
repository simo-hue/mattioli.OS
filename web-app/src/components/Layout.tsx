import { Outlet, Link } from 'react-router-dom';
import { Command } from 'lucide-react';

import { GlobalNav } from './GlobalNav';
import { MobileNav } from './MobileNav';

export function Layout() {
  return (
    <div className="h-dvh lg:min-h-screen bg-background flex flex-col relative w-full overflow-x-hidden selection:bg-primary/20">
      {/* Header */}
      <header className="border-b border-border bg-background/80 backdrop-blur-md sticky top-0 z-50 transition-all duration-300">
        <div className="h-16 flex items-center justify-between px-4 sm:px-8 max-w-[2400px] mx-auto w-full relative">

          <div className="absolute inset-0 bg-gradient-to-r from-primary/5 via-transparent to-primary/5 pointer-events-none lg:hidden" />

          <Link to="/sw/dashboard" className="flex items-center gap-2 sm:gap-3 group relative z-10 active:scale-95 transition-transform">
            <div className="relative">
              <Command className="h-6 w-6 sm:h-6 sm:w-6 text-primary animate-pulse" />
              <div className="absolute inset-0 bg-primary/20 blur-lg rounded-full opacity-50" />
            </div>
            <span className="font-display font-bold text-lg sm:text-lg tracking-tight group-hover:text-primary transition-colors">
              Mattioli.OS
            </span>
          </Link>

          <div className="hidden lg:block">
            <GlobalNav />
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="flex-1 min-h-0 pb-28 lg:pb-0">
        <Outlet />
      </main>

      {/* Mobile Navigation */}
      <MobileNav />
    </div>
  );
}
