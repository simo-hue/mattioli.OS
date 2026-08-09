import { Outlet } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from '@/components/ui/toaster';
import { Toaster as Sonner } from '@/components/ui/sonner';
import { TooltipProvider } from '@/components/ui/tooltip';
import { PrivacyProvider } from '@/context/PrivacyContext';
import { AIProvider } from '@/context/AIContext';

/**
 * The provider shell that used to wrap <BrowserRouter> inside App.tsx.
 *
 * Under vite-react-ssg the router owns the tree, so the providers become the
 * root route's element and every page renders through <Outlet />.
 *
 * The QueryClient is created per render rather than at module scope: a module
 * singleton is shared across every page during a static build, so one route's
 * cached queries would leak into the next one's prerendered HTML.
 */
export default function AppProviders() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        // Nothing should be fetched while prerendering; pages render from props
        // and hydrate on the client.
        retry: false,
        refetchOnWindowFocus: false,
      },
    },
  });

  return (
    <QueryClientProvider client={queryClient}>
      <PrivacyProvider>
        <AIProvider>
          <TooltipProvider>
            <Toaster />
            <Sonner />
            <Outlet />
          </TooltipProvider>
        </AIProvider>
      </PrivacyProvider>
    </QueryClientProvider>
  );
}
