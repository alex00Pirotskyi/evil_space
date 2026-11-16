import { applyTransaction } from './casso_webhook.js';

const PATH = '/api/webhooks/vcb-browser';
const ORIGIN = 'https://vcbdigibank.vietcombank.com.vn';
const MAX_BODY = 2048;
const encoder = new TextEncoder();

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== PATH) return response({ok: false, error: 'Not found'}, 404);
    if (request.method === 'OPTIONS') {
      return request.headers.get('origin') === ORIGIN
        ? new Response(null, {status: 204, headers: {
          'Access-Control-Allow-Origin': ORIGIN,
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, X-Evil-Timestamp, X-Evil-Signature',
          'Access-Control-Max-Age': '600',
          'Vary': 'Origin',
        }})
        : response({ok: false, error: 'Origin not allowed'}, 403);
    }
    if (request.method !== 'POST') return response({ok: false, error: 'Not found'}, 404);
    if (request.headers.get('origin') !== ORIGIN) return response({ok: false, error: 'Origin not allowed'}, 403);
    const secret = env.VCB_BROWSER_HMAC_SECRET;
    if (typeof secret !== 'string' || secret.length < 32 || secret.length > 256) {
      return response({ok: false, error: 'Browser listener not configured'}, 503, true);
    }
    const stamp = request.headers.get('x-evil-timestamp') ?? '';
    const signature = request.headers.get('x-evil-signature') ?? '';
    if (!/^\d{10}$/.test(stamp) || !/^[a-f0-9]{64}$/i.test(signature) ||
      Math.abs(Date.now() / 1000 - Number(stamp)) > 300) {
      return response({ok: false, error: 'Unauthorized'}, 401, true);
    }
    if (Number(request.headers.get('content-length') ?? 0) > MAX_BODY) {
      return response({ok: false, error: 'Payload too large'}, 413, true);
    }
    const raw = await request.text();
    if (encoder.encode(raw).length > MAX_BODY) {
      return response({ok: false, error: 'Payload too large'}, 413, true);
    }
    if (!await verify(secret, stamp + '\n' + raw, signature)) {
      return response({ok: false, error: 'Unauthorized'}, 401, true);
    }
    let body;
    try { body = JSON.parse(raw); } catch { return response({ok: false, error: 'Invalid JSON'}, 400, true); }
    if (body?.type === 'ping') return response({ok: true, type: 'pong'}, 200, true);
    const expected = String(env.VIETQR_ACCOUNT_NUMBER ?? '').trim();
    if (!/^\d{6,20}$/.test(expected)) {
      return response({ok: false, error: 'Receiving account not configured'}, 503, true);
    }
    const transaction = normalizeBrowserTransaction(body);
    if (!transaction || transaction.accountNumber !== expected) {
      return response({ok: true, status: 'ignored'}, 200, true);
    }
    const preview = env.VCB_BROWSER_AUTO_CONFIRM !== '1';
    const status = await applyTransaction(env, transaction, 'vcb_browser', {preview});
    return response({ok: true, status, mode: preview ? 'observe' : 'auto', orderCode: transaction.orderCode}, 200, true);
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
    transactionAt: localDay + 'T00:00:00+07:00',
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

function response(body, status = 200, cors = false) {
  return new Response(JSON.stringify(body), {status, headers: {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
    ...(cors ? {'Access-Control-Allow-Origin': ORIGIN, 'Vary': 'Origin'} : {}),
  }});
}
