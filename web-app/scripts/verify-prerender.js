import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

/**
 * Build-time check on the prerendered output.
 *
 * Head metadata now comes from <RouteHead> inside the components, which is the
 * right place for it — the same definitions serve the static build and
 * client-side navigation. The risk that creates is silence: if a page forgets
 * <RouteHead>, or the SSG pass quietly falls back to an empty shell, nothing
 * complains and the site regresses to the state this work removed. This fails
 * the build instead.
 *
 * Every one of these has actually gone wrong at some point in this codebase:
 * identical canonicals across routes, an empty #root, a page missing entirely.
 */

const __dirname = dirname(fileURLToPath(import.meta.url));
const DIST = join(__dirname, '..', 'dist');
const BASE = 'https://simo-hue.github.io/mattioli.OS/';

const ROUTES = ['', 'features', 'faq', 'tech', 'philosophy', 'get-started', 'creator', 'privacy', 'terms'];
const MIN_BODY_TEXT = 300; // a real page; an empty shell renders well under this

const fail = [];
const rows = [];

for (const route of ROUTES) {
  const file = route ? join(DIST, route, 'index.html') : join(DIST, 'index.html');
  const label = route || '(home)';

  if (!existsSync(file)) {
    fail.push(`${label}: not prerendered (${file} missing)`);
    continue;
  }

  const html = readFileSync(file, 'utf-8');
  const expected = route ? `${BASE}${route}/` : BASE;

  const title = (html.match(/<title[^>]*>([^<]*)<\/title>/) || [])[1] || '';
  const canonical = (html.match(/<link[^>]*rel="canonical"[^>]*href="([^"]+)"/) || [])[1] || '';

  const body = (html.match(/<body[^>]*>([\s\S]*)<\/body>/) || ['', ''])[1];
  const text = body
    .replace(/<script[\s\S]*?<\/script>/g, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  let ldBlocks = 0;
  let ldBad = 0;
  for (const m of html.matchAll(/<script type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/g)) {
    ldBlocks++;
    try {
      JSON.parse(m[1]);
    } catch {
      ldBad++;
    }
  }

  const canonCount = (html.match(/<link[^>]*rel="canonical"/g) || []).length;
  const descCount = (html.match(/<meta[^>]*name="description"/g) || []).length;

  if (!title) fail.push(`${label}: no <title>`);
  // Duplicates shipped once: index.html declared its own canonical/description
  // while RouteHead also emitted them, leaving two of each on every page.
  if (canonCount > 1) fail.push(`${label}: ${canonCount} canonical tags (expected 1)`);
  if (descCount > 1) fail.push(`${label}: ${descCount} description tags (expected 1)`);
  if (canonical !== expected) fail.push(`${label}: canonical is "${canonical}", expected "${expected}"`);
  if (text.length < MIN_BODY_TEXT) fail.push(`${label}: only ${text.length} chars of body text — not prerendered?`);
  if (ldBlocks === 0) fail.push(`${label}: no JSON-LD`);
  if (ldBad > 0) fail.push(`${label}: ${ldBad} invalid JSON-LD block(s)`);

  rows.push({ label, title, canonical, text: text.length, ldBlocks });
}

console.log('\n🔎 Prerender verification\n');
for (const r of rows) {
  console.log(
    `   ${r.label.padEnd(12)} ${String(r.text).padStart(5)} chars  ld=${r.ldBlocks}  ${r.title.slice(0, 46)}`
  );
}

// Duplicate titles or canonicals are the specific failure that made every route
// look like the homepage, so check them across the set rather than per page.
const titles = new Set(rows.map((r) => r.title));
const canonicals = new Set(rows.map((r) => r.canonical));
if (rows.length && titles.size !== rows.length) fail.push(`only ${titles.size} distinct titles across ${rows.length} routes`);
if (rows.length && canonicals.size !== rows.length)
  fail.push(`only ${canonicals.size} distinct canonicals across ${rows.length} routes`);

if (fail.length) {
  console.error('\n❌ Prerender verification failed:\n');
  for (const f of fail) console.error(`   • ${f}`);
  console.error('');
  process.exit(1);
}

console.log(`\n✅ ${rows.length} routes: distinct titles and canonicals, real body text, valid JSON-LD.\n`);
