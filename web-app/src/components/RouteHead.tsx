import { Head } from 'vite-react-ssg';
import { ROUTE_META, graphFor, urlFor } from '@/lib/route-meta';

/**
 * Per-route <head>: title, description, canonical, Open Graph, Twitter and JSON-LD.
 *
 * vite-react-ssg's <Head> writes into the static HTML during the prerender AND
 * into document.head on the client, so a route's title is correct both for a
 * crawler fetching the URL directly and for a visitor navigating within the SPA.
 * The previous post-build script could only do the former, which left the browser
 * tab showing whichever page the visitor happened to land on first.
 *
 * Drop <RouteHead route="faq" /> at the top of a page component. The key must
 * exist in ROUTE_META; an unknown key renders nothing rather than a half-built
 * head, so a typo fails visibly in the build check instead of shipping a page
 * that quietly claims to be the homepage.
 */
export default function RouteHead({ route }: { route: keyof typeof ROUTE_META }) {
  const meta = ROUTE_META[route];
  if (!meta) {
    if (import.meta.env.DEV) console.warn(`[RouteHead] unknown route key: ${String(route)}`);
    return null;
  }

  const url = urlFor(meta);
  const image = `${'https://simo-hue.github.io/mattioli.OS/'}logo.jpg`;

  return (
    <>
      <Head>
        <title>{meta.title}</title>
        <meta name="description" content={meta.description} />
        <link rel="canonical" href={url} />

        <meta property="og:type" content="website" />
        <meta property="og:url" content={url} />
        <meta property="og:title" content={meta.title} />
        <meta property="og:description" content={meta.description} />
        <meta property="og:image" content={image} />

        <meta property="twitter:card" content="summary_large_image" />
        <meta property="twitter:url" content={url} />
        <meta property="twitter:title" content={meta.title} />
        <meta property="twitter:description" content={meta.description} />
        <meta property="twitter:image" content={image} />
      </Head>

      {/*
        JSON-LD is rendered here rather than inside <Head>. vite-react-ssg's Head
        wraps react-helmet, which handles title and meta but drops <script>
        children — the build check caught nine pages silently shipping no
        structured data at all. Google reads JSON-LD anywhere in the document, so
        emitting it in the body is valid and avoids the limitation entirely.

        dangerouslySetInnerHTML keeps the JSON unescaped; as a React child, the
        quotes in the payload would be HTML-escaped and the block would not parse.
      */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(graphFor(meta)) }}
      />
    </>
  );
}
