import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

/**
 * Post-processes the HTML that vite-react-ssg has already prerendered.
 *
 * SSG gives every route the real React output. What it does not give us is the
 * per-route head: without this pass every page still carries the title,
 * description and canonical baked into index.html, so /creator/ and /faq/ would
 * once again declare themselves duplicates of the homepage.
 *
 * This only ever rewrites <head>. The body is whatever React rendered — this
 * script must never invent page content, or the static HTML starts disagreeing
 * with what a browser shows.
 *
 * FAQ entries are parsed from src/pages/FAQ.tsx at build time rather than copied
 * here, so the structured data cannot drift from the rendered page.
 */
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const DIST_DIR = join(__dirname, '..', 'dist');
const SRC_DIR = join(__dirname, '..', 'src');
const INDEX_HTML = join(DIST_DIR, 'index.html');

const BASE = 'https://simo-hue.github.io/mattioli.OS/';

/**
 * The one canonical Person node for Simone Mattioli, defined on his portfolio.
 * Every property he owns references this exact string so that crawlers resolve
 * them to a single entity rather than one thin node per site. Keep it
 * byte-identical; do not rebuild it from BASE.
 */
const PERSON_ID = 'https://simo-hue.github.io/#person';
const WEBSITE_ID = `${BASE}#website`;
const APP_ID = `${BASE}#app`;

const escapeHtml = (s) =>
  String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** Pull the { q, a } pairs straight out of the FAQ component. */
function readFaqPairs() {
  const src = join(SRC_DIR, 'pages', 'FAQ.tsx');
  if (!existsSync(src)) return [];
  const text = readFileSync(src, 'utf-8');
  const pairs = [];
  const re = /\{\s*q:\s*"((?:[^"\\]|\\.)*)"\s*,\s*a:\s*"((?:[^"\\]|\\.)*)"\s*\}/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    pairs.push({ q: m[1].replace(/\\"/g, '"'), a: m[2].replace(/\\"/g, '"') });
  }
  return pairs;
}

/**
 * Copy is taken from what the pages actually say. Nothing here describes a
 * feature the app does not have — if a route's real content changes, update it
 * here too, or the static version starts lying about the rendered one.
 */
const ROUTES = [
  {
    path: '',
    title: 'Mattioli.OS — Open Source Personal Operating System for Habits & Goals',
    description:
      'An open source personal operating system for daily habits, long-term goals and performance analysis. Free, MIT-licensed, and built around reducing friction rather than adding features.',
    h1: 'Mattioli.OS',
    intro:
      'A complete operating system for personal growth — not just a habit tracker, but an integrated suite for managing daily habits, long-term goals and performance analysis. Open source under the MIT licence, and free.',
    points: [
      'Daily Protocol — the list of non-negotiable daily habits at the heart of the system.',
      'Macro goals with quantitative progress tracking.',
      'Native mobile and desktop clients alongside the web app.',
      'Your own Supabase backend, so the data stays yours.',
    ],
  },
  {
    path: 'features',
    title: 'Features — Mattioli.OS',
    description:
      'What Mattioli.OS does: daily habit protocols, macro goals, performance statistics, and native mobile and desktop clients backed by your own Supabase instance.',
    h1: 'Features',
    intro: 'Mobile and desktop native, with the same data behind every client.',
  },
  {
    path: 'faq',
    title: 'FAQ — Mattioli.OS',
    description:
      'Answers about Mattioli.OS: what it is, why it is called an operating system, how it differs from Notion and Todoist, whether it is really free, and who builds it.',
    h1: 'Frequently Asked Questions',
    intro: 'Common questions about what Mattioli.OS is, how it works, and who makes it.',
    faq: true,
  },
  {
    path: 'tech',
    title: 'Technology — Mattioli.OS',
    description:
      'The stack behind Mattioli.OS: the core technologies, how the clients stay in sync, and how the Supabase backend is put together.',
    h1: 'Technology',
    intro: 'Core technologies, and how the clients stay connected to your own backend.',
  },
  {
    path: 'philosophy',
    title: 'Philosophy — Mattioli.OS',
    description:
      'The methodology Mattioli.OS is founded on, built around the three pillars and the idea from Atomic Habits that we fall to the level of our systems rather than rising to our goals.',
    h1: 'Philosophy',
    intro:
      'The methodology on which Mattioli.OS is founded: the Three Pillars, and the principle from Atomic Habits that we do not rise to the level of our goals, we fall to the level of our systems.',
  },
  {
    path: 'get-started',
    title: 'Get Started — Mattioli.OS',
    description:
      'Set up Mattioli.OS: install the prerequisites, create your free Supabase backend, download the engine, and run the setup commands.',
    h1: 'Get Started',
    intro:
      'Install the prerequisites, create your free Supabase backend, then download and run the engine on your own machine.',
  },
  {
    path: 'creator',
    title: 'Simone Mattioli — Creator of Mattioli.OS',
    description:
      'Mattioli.OS is built by Simone Mattioli, an Italian computer science engineer and AI researcher who develops iOS applications and open-source tools.',
    h1: 'Simone Mattioli',
    intro:
      'I am Simone Mattioli, a developer interested in productivity and data visualisation. I built this tool for myself first.',
    profile: true,
  },
  {
    path: 'privacy',
    title: 'Privacy Policy — Mattioli.OS',
    description: 'How Mattioli.OS handles your data. The system runs on your own Supabase instance, so the data stays yours.',
    h1: 'Privacy Policy',
    intro: 'How Mattioli.OS handles your data.',
  },
  {
    path: 'terms',
    title: 'Terms of Service — Mattioli.OS',
    description: 'The terms covering use of Mattioli.OS, an open source project released under the MIT licence.',
    h1: 'Terms of Service',
    intro: 'Terms covering use of Mattioli.OS.',
  },
];

function buildGraph(route, faqPairs) {
  const url = route.path ? `${BASE}${route.path}/` : BASE;
  const graph = [
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
      name: route.title,
      description: route.description,
      isPartOf: { '@id': WEBSITE_ID },
      about: { '@id': PERSON_ID },
      inLanguage: 'en',
    },
    // Reference only. The full Person is defined once, on the portfolio.
    { '@type': 'Person', '@id': PERSON_ID, name: 'Simone Mattioli', url: 'https://simo-hue.github.io/' },
  ];

  if (!route.path) {
    graph.push({
      '@type': 'SoftwareApplication',
      '@id': APP_ID,
      name: 'Mattioli.OS',
      applicationCategory: 'ProductivityApplication',
      operatingSystem: 'Web, iOS, macOS',
      url: BASE,
      description: route.description,
      author: { '@id': PERSON_ID },
      publisher: { '@id': PERSON_ID },
      isAccessibleForFree: true,
      license: 'https://opensource.org/licenses/MIT',
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
      sameAs: 'https://github.com/simo-hue/mattioli.OS',
    });
  }

  if (route.faq && faqPairs.length) {
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

  if (route.profile) {
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

function renderRoute(shell, route, faqPairs) {
  const url = route.path ? `${BASE}${route.path}/` : BASE;
  let html = shell;

  html = html.replace(/<title>[\s\S]*?<\/title>/, `<title>${escapeHtml(route.title)}</title>`);
  html = html.replace(
    /<meta name="description"[\s\S]*?\/>/,
    `<meta name="description" content="${escapeHtml(route.description)}" />`
  );
  html = html.replace(
    /<link rel="canonical"[^>]*>/,
    `<link rel="canonical" href="${url}" />`
  );
  html = html.replace(/<meta property="og:url"[^>]*>/, `<meta property="og:url" content="${url}" />`);
  html = html.replace(
    /<meta property="og:title"[^>]*>/,
    `<meta property="og:title" content="${escapeHtml(route.title)}" />`
  );
  html = html.replace(
    /<meta property="og:description"[\s\S]*?\/>/,
    `<meta property="og:description" content="${escapeHtml(route.description)}" />`
  );
  html = html.replace(
    /<meta property="twitter:url"[^>]*>/,
    `<meta property="twitter:url" content="${url}" />`
  );
  html = html.replace(
    /<meta property="twitter:title"[^>]*>/,
    `<meta property="twitter:title" content="${escapeHtml(route.title)}" />`
  );
  html = html.replace(
    /<meta property="twitter:description"[^>]*>/,
    `<meta property="twitter:description" content="${escapeHtml(route.description)}" />`
  );

  const ld = `  <script type="application/ld+json">\n${JSON.stringify(buildGraph(route, faqPairs), null, 2)}\n  </script>\n`;
  html = html.replace('</head>', `${ld}</head>`);

  return html;
}

function applyRouteMeta() {
  console.log('\n🔎 Applying per-route metadata to the prerendered HTML...\n');

  const faqPairs = readFaqPairs();
  console.log(`   Parsed ${faqPairs.length} FAQ entries from src/pages/FAQ.tsx`);

  let ok = 0;
  let missing = 0;

  for (const route of ROUTES) {
    const file = route.path ? join(DIST_DIR, route.path, 'index.html') : INDEX_HTML;
    if (!existsSync(file)) {
      console.warn(`   ⚠️  ${route.path || '(home)'} — not prerendered; skipped`);
      missing++;
      continue;
    }
    const rendered = readFileSync(file, 'utf-8');
    const out = renderRoute(rendered, route, faqPairs);
    writeFileSync(file, out);

    // A prerendered page should carry real markup, not an empty mount point.
    const rootEmpty = /<div id="root">\s*<\/div>/.test(out);
    console.log(
      `✅ ${(route.path || '(home)').padEnd(12)} ${String(out.length).padStart(7)} bytes` +
        (rootEmpty ? '   ⚠️  #root is EMPTY — not actually prerendered' : '')
    );
    ok++;
  }

  console.log(`\n🎉 ${ok} routes decorated${missing ? `, ${missing} missing` : ''}.`);
  if (missing) process.exit(1);
}

applyRouteMeta();
