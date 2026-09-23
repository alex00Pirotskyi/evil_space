// Localized marketing pages are built as static assets beside the Flutter app.
// Whitelist the public page URLs here so unknown /en, /ru and /vi paths return
// an actual 404 instead of Cloudflare's Flutter SPA fallback.
const pages = new Set(['', 'pricing/', 'visit/']);

export async function seoResponse(request, env) {
  const url = new URL(request.url);
  const match = /^\/(en|ru|vi)(?:\/(.*))?$/.exec(url.pathname);
  if (match) {
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response(null, { status: 405, headers: { Allow: 'GET, HEAD' } });
    }

    const lang = match[1];
    const rest = match[2];
    if (rest === undefined || rest === 'pricing' || rest === 'visit' ||
        rest === 'index.html' || rest === 'pricing/index.html' || rest === 'visit/index.html') {
      const page = rest === undefined || rest === 'index.html' ? '' :
        rest.startsWith('pricing') ? 'pricing/' : 'visit/';
      return Response.redirect(`${url.origin}/${lang}/${page}${url.search}`, 308);
    }
    if (!pages.has(rest)) {
      return new Response(request.method === 'HEAD' ? null : 'Page not found', {
        status: 404,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'X-Robots-Tag': 'noindex',
          'Cache-Control': 'no-store',
        },
      });
    }

    const response = await env.ASSETS.fetch(request);
    const headers = new Headers(response.headers);
    headers.set('Content-Language', lang);
    headers.set('Cache-Control', 'public, max-age=0, must-revalidate');
    headers.set('X-Content-Type-Options', 'nosniff');
    headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    headers.set('X-Frame-Options', 'SAMEORIGIN');
    return new Response(request.method === 'HEAD' ? null : response.body, {
      status: response.status,
      headers,
    });
  }

  // Preserve Flutter's existing deep links but keep duplicate app and admin
  // routes out of search results. The root still works as the booking app.
  if (url.pathname === '/admin' || url.pathname.startsWith('/admin/') ||
      url.pathname === '/menu' || url.pathname === '/qr') {
    if (request.method !== 'GET' && request.method !== 'HEAD') return null;
    const response = await env.ASSETS.fetch(request);
    const headers = new Headers(response.headers);
    headers.set('X-Robots-Tag', 'noindex, follow');
    return new Response(request.method === 'HEAD' ? null : response.body, {
      status: response.status,
      headers,
    });
  }
  return null;
}
