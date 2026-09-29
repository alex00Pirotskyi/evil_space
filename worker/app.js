import adminReview from './admin_review.js';
import adminWorker from './admin_worker.js';
import featureWorker from './entry.js';
import menuWorker from './menu_cart.js';
import menuBuilderWorker from './menu_builder.js';
import promoWorker from './promo_engine.js';
import customerAccountWorker, { handleCustomerTelegramShortcut } from './customer_account.js';
import googleAccountWorker from './google_account.js';
import { handleMenuTelegramShortcut } from './menu_telegram.js';

const FEATURE_ROUTES = new Set([
  'POST /api/telegram/webhook',
  'GET /api/public/status',
  'POST /api/public/book',
  'GET /api/public/booking',
  'POST /api/public/booking/delete',
  'GET /api/admin/telegram',
  'POST /api/admin/telegram/link',
  'POST /api/admin/telegram/disconnect',
  'POST /api/admin/telegram/preferences',
  'GET /api/admin/operations',
  'POST /api/admin/booking/accept',
  'POST /api/admin/booking/decline',
  'POST /api/admin/purchases',
]);

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const route = `${request.method} ${url.pathname}`;

    if (route === 'GET /api/public/status') {
      return cachedPublicStatus(request, env, ctx);
    }

    if (route === 'GET /api/admin/review') {
      return adminReview.review(url, env);
    }
    if (route === 'POST /api/admin/decision') {
      return adminReview.decision(request, env);
    }
    if (url.pathname.startsWith('/api/public/account/google')) {
      return googleAccountWorker.fetch(request, env, ctx);
    }
    if (url.pathname.startsWith('/api/public/account/promos')) {
      return promoWorker.fetch(request, env, ctx);
    }
    if (url.pathname.startsWith('/api/public/account')) {
      return customerAccountWorker.fetch(request, env, ctx);
    }
    if (url.pathname === '/api/public/menu/promos') {
      return promoWorker.fetch(request, env, ctx);
    }
    if (
      url.pathname === '/api/admin/menu/draft' ||
      url.pathname === '/api/admin/menu/publish'
    ) {
      return menuBuilderWorker.fetch(request, env, ctx);
    }
    if (url.pathname.startsWith('/api/admin/promos') || url.pathname.startsWith('/api/admin/customers')) {
      return promoWorker.fetch(request, env, ctx);
    }
    if (
      url.pathname.startsWith('/api/public/menu') ||
      url.pathname.startsWith('/api/admin/menu')
    ) {
      return menuWorker.fetch(request, env, ctx);
    }
    if (route === 'POST /api/telegram/webhook') {
      const accountShortcut = await handleCustomerTelegramShortcut(request, env);
      if (accountShortcut) return accountShortcut;
      const menuShortcut = await handleMenuTelegramShortcut(request, env);
      if (menuShortcut) return menuShortcut;
    }
    if (FEATURE_ROUTES.has(route)) {
      return featureWorker.fetch(request, env, ctx);
    }
    if (url.pathname === '/api/health' || url.pathname.startsWith('/api/admin/')) {
      return adminWorker.fetch(request, env, ctx);
    }
    return jsonError('Not found.', 404);
  },
};

async function cachedPublicStatus(request, env, ctx) {
  const cache =
    typeof caches !== 'undefined' && caches.default ? caches.default : null;
  if (!cache) return featureWorker.fetch(request, env, ctx);

  const cacheUrl = new URL(request.url);
  cacheUrl.search = '';
  const cacheKey = new Request(cacheUrl.toString(), { method: 'GET' });
  const cached = await cache.match(cacheKey);
  if (cached) return cached;

  const response = await featureWorker.fetch(request, env, ctx);
  if (!response.ok) return response;

  const headers = new Headers(response.headers);
  headers.set('Cache-Control', 'public, max-age=5, s-maxage=8');
  headers.set('CDN-Cache-Control', 'max-age=8');
  const cacheable = new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });

  const write = cache
    .put(cacheKey, cacheable.clone())
    .catch((error) => console.error('Public status cache failed', error));
  if (ctx && typeof ctx.waitUntil === 'function') ctx.waitUntil(write);
  else await write;

  return cacheable;
}

function jsonError(message, status) {
  return new Response(JSON.stringify({ ok: false, error: message }), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}
