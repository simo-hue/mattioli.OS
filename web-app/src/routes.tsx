import type { RouteRecord } from 'vite-react-ssg';
import { Navigate } from 'react-router-dom';
import { lazy } from 'react';

import AppProviders from './AppProviders';
import LandingPage from './pages/LandingPage';
import FAQPage from './pages/FAQ';
import TechPage from './pages/TechPage';
import PhilosophyPage from './pages/PhilosophyPage';
import FeaturesPage from './pages/FeaturesPage';
import GetStartedPage from './pages/GetStartedPage';
import CreatorPage from './pages/CreatorPage';
import PrivacyPolicy from './pages/PrivacyPolicy';
import TermsOfService from './pages/TermsOfService';
import NotFound from './pages/NotFound';

/**
 * Route table for vite-react-ssg.
 *
 * This replaces the <BrowserRouter><Routes> tree that used to live in App.tsx.
 * The SSG build needs routes as data so it can walk them at build time and
 * render each one to static HTML; it cannot introspect JSX <Route> children.
 *
 * PUBLIC pages are prerendered. Everything behind auth is NOT: those routes are
 * loaded lazily and excluded from `getStaticPaths`, because prerendering a page
 * that immediately redirects to /auth would publish an empty shell at a URL that
 * should not be indexed in the first place.
 */

// Authenticated area — client-only, never prerendered.
const Auth = lazy(() => import('./pages/Auth'));
const Layout = lazy(() => import('./components/Layout').then((m) => ({ default: m.Layout })));
const ProtectedRoute = lazy(() => import('./components/ProtectedRoute'));
const Index = lazy(() => import('./pages/Index'));
const Stats = lazy(() => import('./pages/Stats'));
const MacroGoals = lazy(() => import('./pages/MacroGoals'));
const AICoach = lazy(() => import('./pages/AICoach'));
const CompleteBackup = lazy(() => import('./pages/CompleteBackup'));

/** The routes that become static HTML files. Keep in step with scripts/route-meta.js. */
export const PRERENDERED_PATHS = [
  '/',
  '/faq',
  '/tech',
  '/philosophy',
  '/features',
  '/get-started',
  '/creator',
  '/privacy',
  '/terms',
];

export const routes: RouteRecord[] = [
  {
    path: '/',
    element: <AppProviders />,
    children: [
      { index: true, element: <LandingPage />, entry: 'src/pages/LandingPage.tsx' },
      { path: 'faq', element: <FAQPage /> },
      { path: 'tech', element: <TechPage /> },
      { path: 'philosophy', element: <PhilosophyPage /> },
      { path: 'features', element: <FeaturesPage /> },
      { path: 'get-started', element: <GetStartedPage /> },
      { path: 'creator', element: <CreatorPage /> },
      { path: 'privacy', element: <PrivacyPolicy /> },
      { path: 'terms', element: <TermsOfService /> },

      // Client-only from here down.
      { path: 'auth', element: <Auth />, entry: 'src/pages/Auth.tsx' },
      {
        path: 'sw',
        element: (
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        ),
        children: [
          { index: true, element: <Navigate to="dashboard" replace /> },
          { path: 'dashboard', element: <Index /> },
          { path: 'stats', element: <Stats /> },
          { path: 'macro-goals', element: <MacroGoals /> },
          { path: 'ai-coach', element: <AICoach /> },
          { path: 'complete-backup', element: <CompleteBackup /> },
        ],
      },

      { path: '*', element: <NotFound /> },
    ],
  },
];
