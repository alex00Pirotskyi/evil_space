import { applyTransaction } from './casso_webhook.js';

const PATH = '/api/webhooks/vcb-browser';
const ORIGIN = 'https://vcbdigibank.vietcombank.com.vn';
const EXTENSION_ORIGIN = /^chrome-extension:\/\/[a-p]{32}$/;
const MAX_BODY = 2048;
const encoder = new TextEncoder();

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== PATH) return response({ok: false, error: 'Not found'}, 404);
    const requestOrigin = request.headers.get('origin') ?? '';
    const authorizedOrigin = requestOrigin === ORIGIN || EXTENSION_ORIGIN.test(requestOrigin);
    if (request.method === 'OPTIONS') {
      return authorizedOrigin
        ? new Response(null, {status: 204, headers: {
          'Access-Control-Allow-Origin': requestOrigin,
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, X-Evil-Timestamp, X-Evil-Signature',
          'Access-Control-Max-Age': '600',
          'Vary': 'Origin',
        }})
        : response({ok: false, error: 'Origin not allowed'}, 403);
    }
    if (request.method !== 'POST') return response({ok: false, error: 'Not found'}, 404);
    if (!authorizedOrigin) return response({ok: false, error: 'Origin not allowed'}, 403);
    const secret = env.VCB_BROWSER_HMAC_SECRET;
    if (typeof secret !== 'string' || secret.length < 32 || secret.length > 256) {
      return response({ok: false, error: 'Browser listener not configured'}, 503, requestOrigin);
    }
    const stamp = request.headers.get('x-evil-timestamp') ?? '';
    const signature = request.headers.get('x-evil-signature') ?? '';
    if (!/^\d{10}$/.test(stamp) || !/^[a-f0-9]{64}$/i.test(signature) ||
      Math.abs(Date.now() / 1000 - Number(stamp)) > 300) {
      return response({ok: false, error: 'Unauthorized'}, 401, requestOrigin);
    }
    if (Number(request.headers.get('content-length') ?? 0) > MAX_BODY) {
      return response({ok: false, error: 'Payload too large'}, 413, requestOrigin);
    }
    const raw = await request.text();
    if (encoder.encode(raw).length > MAX_BODY) {
      return response({ok: false, error: 'Payload too large'}, 413, requestOrigin);
    }
    if (!await verify(secret, stamp + '\n' + raw, signature)) {
      return response({ok: false, error: 'Unauthorized'}, 401, requestOrigin);
    }
    let body;
    try { body = JSON.parse(raw); } catch { return response({ok: false, error: 'Invalid JSON'}, 400, requestOrigin); }
    if (body?.type === 'ping') return response({ok: true, type: 'pong'}, 200, requestOrigin);
    const expected = String(env.VIETQR_ACCOUNT_NUMBER ?? '').trim();
    if (!/^\d{6,20}$/.test(expected)) {
      return response({ok: false, error: 'Receiving account not configured'}, 503, requestOrigin);
    }
    const transaction = normalizeBrowserTransaction(body);
    if (!transaction || transaction.accountNumber !== expected) {
      return response({ok: true, status: 'ignored'}, 200, requestOrigin);
    }
    const preview = env.VCB_BROWSER_AUTO_CONFIRM !== '1';
    const status = await applyTransaction(env, transaction, 'vcb_browser', {preview});
    return response({ok: true, status, mode: preview ? 'observe' : 'auto', orderCode: transaction.orderCode}, 200, requestOrigin);
  },
};

export function normalizeBrowserTransaction(body, now = Date.now()) {
  if (!body || body.source !== 'vcb_web_history' || body.direction !== 'credit') return null;
  const accountNumber = String(body.accountNumber ?? '');
  const reference = String(body.reference ?? '').trim();
  const orderCode = String(body.orderCode ?? '').toUpperCase();
  const amountVnd = Number(body.amountVnd);
  const date = String(body.date ?? '');
  if (!/^\d{6,20}$/.test(accountNumber) || !/^[A-Za-z0-9._-]{6,80}$/.test(reference) ||
      !/^[A-HJ-NP-Z2-9]{6}$/.test(orderCode) || !Number.isSafeInteger(amountVnd) ||
      amountVnd <= 0 || amountVnd > 10_000_000_000 || !/^\d{2}\/\d{2}\/\d{4}$/.test(date)) return null;
  const [dd, mm, yyyy] = date.split('/').map(Number);
  const midnightUtc = Date.UTC(yyyy, mm - 1, dd);
  const calendar = new Date(midnightUtc);
  if (calendar.getUTCFullYear() !== yyyy || calendar.getUTCMonth() + 1 !== mm || calendar.getUTCDate() !== dd) return null;
  const localDay = calendar.toISOString().slice(0, 10);
  const today = vietnamDay(now);
  const yesterday = vietnamDay(now - 86_400_000);
  if (localDay !== today && localDay !== yesterday) return null;
  return {
    transactionId: 'ref:' + reference.toUpperCase(),
    bankReference: reference,
    amountVnd,
    orderCode,
    accountNumber,
    bankDate: localDay,
    transactionAt: null, // History shows date only; do not invent a bank timestamp.
  };
}

function vietnamDay(epochMs) {
  return new Date(epochMs + 7 * 3600_000).toISOString().slice(0, 10);
}

async function verify(secret, message, supplied) {
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret),
    {name: 'HMAC', hash: 'SHA-256'}, false, ['verify']);
  const sig = Uint8Array.from(supplied.match(/../g).map(x => Number.parseInt(x, 16)));
  return crypto.subtle.verify('HMAC', key, sig, encoder.encode(message));
}

function response(body, status = 200, corsOrigin = '') {
  return new Response(JSON.stringify(body), {status, headers: {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
    ...(corsOrigin ? {'Access-Control-Allow-Origin': corsOrigin, 'Vary': 'Origin'} : {}),
  }});
}
