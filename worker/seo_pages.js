import { landingPages, SEO_ORIGIN } from '../seo/pages.mjs';

// The booking application stays at /. Crawlable language guides are real HTML
// documents, not Flutter app-shell clones, and have their own canonical URLs.
const landingByPath = new Map(landingPages.map((page) => [page.path, page]));
const retiredPages = new Set([
  '', 'index.html',
  'pricing', 'pricing/', 'pricing/index.html',
  'visit', 'visit/', 'visit/index.html',
]);

export async function seoResponse(request, env) {
  const url = new URL(request.url);
  const match = /^\/(en|ru|vi)(?:\/(.*))?$/.exec(url.pathname);
  if (match) {
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response(null, { status: 405, headers: { Allow: 'GET, HEAD' } });
    }

    const path = url.pathname;
    const normalized = path.endsWith('/index.html')
      ? path.slice(0, -'index.html'.length)
      : path.endsWith('/') ? path : path + '/';
    const page = landingByPath.get(normalized);
    if (page) {
      if (path !== page.path) {
        return Response.redirect(SEO_ORIGIN + page.path + url.search, 301);
      }
      // Cloudflare ASSETS serves /en/<slug>/index.html at the canonical /en/<slug>/.
      // The worker runs first for /en/*, /ru/* and /vi/* in wrangler.toml.
      const response = await env.ASSETS.fetch(request);
      return new Response(request.method === 'HEAD' ? null : response.body, {
        status: response.status,
        headers: response.headers,
      });
    }

    const rest = match[2];
    if (retiredPages.has(rest ?? '')) {
      return Response.redirect(SEO_ORIGIN + '/', 301);
    }
    return new Response(request.method === 'HEAD' ? null : 'Page not found', {
      status: 404,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'X-Robots-Tag': 'noindex',
        'Cache-Control': 'no-store',
      },
    });
  }

  // Keep functional Flutter deep links available, but not indexable. Unknown
  // paths must return 404 rather than creating duplicate app shell URLs.
  if (url.pathname === '/admin' || url.pathname.startsWith('/admin/') ||
      url.pathname === '/menu' || url.pathname === '/menu/' ||
      url.pathname === '/qr' || url.pathname === '/qr/') {
    if (request.method !== 'GET' && request.method !== 'HEAD') return null;
    const response = await env.ASSETS.fetch(new Request(new URL('/', request.url), request));
    const headers = new Headers(response.headers);
    headers.set('X-Robots-Tag', 'noindex, follow');
    return new Response(request.method === 'HEAD' ? null : response.body, {
      status: response.status,
      headers,
    });
  }
  return null;
}
