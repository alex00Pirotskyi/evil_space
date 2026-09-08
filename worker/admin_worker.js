import worker from './index.js';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === '/api/health' || url.pathname.startsWith('/api/admin/')) {
      return worker.fetch(request, env, ctx);
    }
    return new Response(JSON.stringify({ ok: false, error: 'Not found.' }), {
      status: 404,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
      },
    });
  },
};
