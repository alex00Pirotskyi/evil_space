import app from './app.js';
import { securityGate } from './security.js';

export default {
  async fetch(request, env, ctx) {
    const blocked = await securityGate(request, env);
    if (blocked) return blocked;
    return app.fetch(request, env, ctx);
  },
};
