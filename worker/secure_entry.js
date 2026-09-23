import app from './app.js';
import { securityGate } from './security.js';
import { seoResponse } from './seo_pages.js';

export default {
  async fetch(request, env, ctx) {
    const page = await seoResponse(request, env);
    if (page) return page;
    const blocked = await securityGate(request, env);
    if (blocked) return blocked;
    return app.fetch(request, env, ctx);
  },
};
