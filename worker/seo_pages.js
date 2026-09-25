// Redirect the retired localized marketing pages to the sole public homepage.
// Keep unknown paths out of the Flutter SPA fallback so they cannot be indexed.
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

    const rest = match[2];
    if (retiredPages.has(rest ?? '')) {
      return Response.redirect('https://evils.space/', 301);
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
