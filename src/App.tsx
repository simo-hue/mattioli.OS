import { useState, useEffect } from "react";
import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route, Navigate, useLocation } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
// import { Layout } from "./components/Layout";
// import Index from "./pages/Index";
// import Stats from "./pages/Stats";
// import Mappa from "./pages/Mappa";
// import Auth from "./pages/Auth";
// import NotFound from "./pages/NotFound";

// const queryClient = new QueryClient();

// const ProtectedRoute = ({ children }: { children: React.ReactNode }) => {
//   return <>{children}</>;
// };

const App = () => (
  // <QueryClientProvider client={queryClient}>
  //   <TooltipProvider>
  //     <Toaster />
  //     <Sonner />
  //     <BrowserRouter>
  //       <Routes>
  //         <Route path="/auth" element={<Auth />} />

  //         <Route element={
  //           <ProtectedRoute>
  //             <Layout />
  //           </ProtectedRoute>
  //         }>
  //           <Route path="/" element={<Index />} />
  //           <Route path="/stats" element={<Stats />} />
  //           <Route path="/mappa" element={<Mappa />} />
  //         </Route>

  //         {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
  //         <Route path="*" element={<NotFound />} />
  //       </Routes>
  //     </BrowserRouter>
  //   </TooltipProvider>
  // </QueryClientProvider>
  <div style={{ color: 'green', fontSize: '30px' }}>App Minimal Works</div>
);

export default App;
