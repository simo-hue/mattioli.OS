import { useState, useEffect } from "react";
import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { Layout } from "./components/Layout";
import LandingPage from "./pages/LandingPage";
import FAQPage from "./pages/FAQ";
import TechPage from "./pages/TechPage";
import PhilosophyPage from "./pages/PhilosophyPage";
import FeaturesPage from "./pages/FeaturesPage";
import GetStartedPage from "./pages/GetStartedPage";
import CreatorPage from "./pages/CreatorPage";
import { supabase } from "@/integrations/supabase/client";
import Index from "./pages/Index";
import Stats from "./pages/Stats";
import MacroGoals from "./pages/MacroGoals";
import AICoach from "./pages/AICoach";
import CompleteBackup from "./pages/CompleteBackup";

import Auth from "./pages/Auth";
import NotFound from "./pages/NotFound";
import { PrivacyProvider } from "@/context/PrivacyContext";
import { AIProvider } from "@/context/AIContext";

const queryClient = new QueryClient();

const ProtectedRoute = ({ children }: { children: React.ReactNode }) => {
  const [session, setSession] = useState<boolean | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(!!session);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(!!session);
    });

    return () => subscription.unsubscribe();
  }, []);

  if (session === null) {
    return null; // Loading state
  }

  if (!session) {
    return <Navigate to="/auth" replace />;
  }

  return <>{children}</>;
};

const App = () => {
  return (
    <QueryClientProvider client={queryClient}>
      <PrivacyProvider>
        <AIProvider>
          <TooltipProvider>
            <Toaster />
            <Sonner />
            <BrowserRouter basename="/mattioli.OS" future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
              <Routes>
                <Route path="/auth" element={<Auth />} />
                <Route path="/" element={<LandingPage />} />
                <Route path="/faq" element={<FAQPage />} />
                <Route path="/tech" element={<TechPage />} />
                <Route path="/philosophy" element={<PhilosophyPage />} />
                <Route path="/features" element={<FeaturesPage />} />
                <Route path="/get-started" element={<GetStartedPage />} />
                <Route path="/creator" element={<CreatorPage />} />

                <Route path="sw" element={
                  <ProtectedRoute>
                    <Layout />
                  </ProtectedRoute>
                }>
                  <Route path="dashboard" element={<Index />} />
                  <Route path="stats" element={<Stats />} />
                  <Route path="macro-goals" element={<MacroGoals />} />
                  <Route path="ai-coach" element={<AICoach />} />
                  <Route path="complete-backup" element={<CompleteBackup />} />
                </Route>

                {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
                <Route path="*" element={<NotFound />} />
              </Routes>
            </BrowserRouter>
          </TooltipProvider>
        </AIProvider>
      </PrivacyProvider>
    </QueryClientProvider>
  );
};

export default App;
