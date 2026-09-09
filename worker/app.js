import adminReview from './admin_review.js';
import adminWorker from './admin_worker.js';
import featureWorker from './entry.js';
import menuWorker from './menu_cart.js';
import customerAccountWorker, { handleCustomerTelegramShortcut } from './customer_account.js';
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

    if (route === 'GET /api/admin/review') {
      return adminReview.review(url, env);
    }
    if (route === 'POST /api/admin/decision') {
      return adminReview.decision(request, env);
    }
    if (url.pathname.startsWith('/api/public/account')) {
      return customerAccountWorker.fetch(request, env, ctx);
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
