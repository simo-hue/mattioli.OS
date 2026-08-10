import { ViteReactSSG } from 'vite-react-ssg';
import { routes } from './routes';
import './index.css';

/**
 * Entry point for vite-react-ssg.
 *
 * Previously this was createRoot(...).render(<App />), which produced a single
 * empty shell copied to every route — invisible to any crawler that does not run
 * JavaScript, which is all of them on the AI side. The build now renders the real
 * React tree to HTML for each public route and hydrates it in the browser.
 *
 * Only the public marketing pages are prerendered. Everything under /sw is behind
 * a Supabase session and would prerender to an empty redirect.
 */
export const createRoot = ViteReactSSG(
  {
    routes,
    basename: '/mattioli.OS',
    future: { v7_startTransition: true, v7_relativeSplatPath: true },
  },
);
