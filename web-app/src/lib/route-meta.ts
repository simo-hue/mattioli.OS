import { faqPairs } from '@/data/faq';

/**
 * Per-route head metadata and structured data, in one place.
 *
 * This used to live in scripts/apply-route-meta.js, a post-build pass that
 * rewrote the generated HTML. That worked for crawlers — each URL is fetched
 * fresh, so it always got the right <head> — but it could not update anything
 * during client-side navigation, so the browser tab kept whichever title the
 * visitor first landed on.
 *
 * Driving it from the component tree instead means the same definitions produce
 * the static HTML at build time AND update the live document on navigation.
 */

export const BASE = 'https://simo-hue.github.io/mattioli.OS/';

/**
 * The single canonical Person node for Simone Mattioli, defined on his portfolio.
 * Every property references this exact string so crawlers resolve them all to one
 * entity. Keep it byte-identical; never rebuild it from BASE.
 */
export const PERSON_ID = 'https://simo-hue.github.io/#person';
export const WEBSITE_ID = `${BASE}#website`;

export interface RouteMeta {
  title: string;
  description: string;
  /** Route path without leading slash; '' is the homepage. */
  path: string;
  faq?: boolean;
  profile?: boolean;
  app?: boolean;
}

export const ROUTE_META: Record<string, RouteMeta> = {
  home: {
    path: '',
    title: 'Mattioli.OS — Open Source Personal Operating System for Habits & Goals',
    description:
      'An open source personal operating system for daily habits, long-term goals and performance analysis. Free, MIT-licensed, and built around reducing friction rather than adding features.',
    app: true,
  },
  features: {
    path: 'features',
    title: 'Features — Mattioli.OS',
    description:
      'What Mattioli.OS does: daily habit protocols, macro goals, performance statistics, and native mobile and desktop clients backed by your own Supabase instance.',
  },
  faq: {
    path: 'faq',
    title: 'FAQ — Mattioli.OS',
    description:
      'Answers about Mattioli.OS: what it is, why it is called an operating system, how it differs from Notion and Todoist, whether it is really free, and who builds it.',
    faq: true,
  },
  tech: {
    path: 'tech',
    title: 'Technology — Mattioli.OS',
    description:
      'The stack behind Mattioli.OS: the core technologies, how the clients stay in sync, and how the Supabase backend is put together.',
  },
  philosophy: {
    path: 'philosophy',
    title: 'Philosophy — Mattioli.OS',
    description:
      'The methodology Mattioli.OS is founded on, built around the three pillars and the idea from Atomic Habits that we fall to the level of our systems rather than rising to our goals.',
  },
  'get-started': {
    path: 'get-started',
    title: 'Get Started — Mattioli.OS',
    description:
      'Set up Mattioli.OS: install the prerequisites, create your free Supabase backend, download the engine, and run the setup commands.',
  },
  creator: {
    path: 'creator',
    title: 'Simone Mattioli — Creator of Mattioli.OS',
    description:
      'Mattioli.OS is built by Simone Mattioli, an Italian computer science engineer and AI researcher who develops iOS applications and open-source tools.',
    profile: true,
  },
  privacy: {
    path: 'privacy',
    title: 'Privacy Policy — Mattioli.OS',
    description:
      'How Mattioli.OS handles your data. The system runs on your own Supabase instance, so the data stays yours.',
  },
  terms: {
    path: 'terms',
    title: 'Terms of Service — Mattioli.OS',
    description: 'The terms covering use of Mattioli.OS, an open source project released under the MIT licence.',
  },
};

export const urlFor = (meta: RouteMeta) => (meta.path ? `${BASE}${meta.path}/` : BASE);

/** The JSON-LD graph for a route. Kept here so markup and schema cannot disagree. */
export function graphFor(meta: RouteMeta) {
  const url = urlFor(meta);
  const graph: Record<string, unknown>[] = [
    {
      '@type': 'WebSite',
      '@id': WEBSITE_ID,
      url: BASE,
      name: 'Mattioli.OS',
      inLanguage: 'en',
      publisher: { '@id': PERSON_ID },
    },
    {
      '@type': 'WebPage',
      '@id': `${url}#webpage`,
      url,
      name: meta.title,
      description: meta.description,
      isPartOf: { '@id': WEBSITE_ID },
      about: { '@id': PERSON_ID },
      inLanguage: 'en',
    },
    // Reference only. The full Person is defined once, on the portfolio.
    { '@type': 'Person', '@id': PERSON_ID, name: 'Simone Mattioli', url: 'https://simo-hue.github.io/' },
  ];

  if (meta.app) {
    graph.push({
      '@type': 'SoftwareApplication',
      '@id': `${BASE}#app`,
      name: 'Mattioli.OS',
      applicationCategory: 'ProductivityApplication',
      operatingSystem: 'Web, iOS, macOS',
      url: BASE,
      description: meta.description,
      author: { '@id': PERSON_ID },
      publisher: { '@id': PERSON_ID },
      isAccessibleForFree: true,
      license: 'https://opensource.org/licenses/MIT',
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
      sameAs: 'https://github.com/simo-hue/mattioli.OS',
    });
  }

  if (meta.faq) {
    graph.push({
      '@type': 'FAQPage',
      '@id': `${url}#faq`,
      isPartOf: { '@id': WEBSITE_ID },
      mainEntity: faqPairs.map((p) => ({
        '@type': 'Question',
        name: p.q,
        acceptedAnswer: { '@type': 'Answer', text: p.a },
      })),
    });
  }

  if (meta.profile) {
    graph.push({
      '@type': 'ProfilePage',
      '@id': `${url}#profilepage`,
      url,
      mainEntity: { '@id': PERSON_ID },
      isPartOf: { '@id': WEBSITE_ID },
    });
  }

  return { '@context': 'https://schema.org', '@graph': graph };
}
