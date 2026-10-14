import { applyTransaction, extractOrderCode } from './casso_webhook.js';

const PATH = '/api/webhooks/vcb-device';
const encoder = new TextEncoder();
const MAX_BODY = 4096;

export default {
  async fetch(request, env) {
    if (request.method !== 'POST' || new URL(request.url).pathname !== PATH) {
      return json({ok: false, error: 'Not found'}, 404);
    }
    const secret = env.VCB_DEVICE_HMAC_SECRET;
    if (typeof secret !== 'string' || secret.length < 32) {
      return json({ok: false, error: 'Device listener not configured'}, 503);
    }
    const timeString = request.headers.get('x-evil-timestamp') ?? '';
    const supplied = request.headers.get('x-evil-signature') ?? '';
    if (!/^\d{10}$/.test(timeString) || !/^[a-f0-9]{64}$/i.test(supplied) ||
        Math.abs(Date.now() / 1000 - Number(timeString)) > 300) {
      return json({ok: false, error: 'Unauthorized'}, 401);
    }
    if (Number(request.headers.get('content-length') ?? 0) > MAX_BODY) {
      return json({ok: false, error: 'Payload too large'}, 413);
    }
    const raw = await request.text();
    if (encoder.encode(raw).length > MAX_BODY) {
      return json({ok: false, error: 'Payload too large'}, 413);
    }
    if (!await verifySignature(secret, timeString + '\n' + raw, supplied)) {
      return json({ok: false, error: 'Unauthorized'}, 401);
    }
    let body;
    try { body = JSON.parse(raw); } catch { return json({ok: false, error: 'Invalid JSON'}, 400); }
    if (body?.type === 'ping') return json({ok: true, type: 'pong'});
    if (!/^\d{6,20}$/.test(String(env.VIETQR_ACCOUNT_NUMBER ?? ''))) {
      return json({ok: false, error: 'Receiving account not configured'}, 503);
    }
    const normalized = await normalizeDeviceTransaction(body);
    if (!normalized) return json({ok: true, status: 'ignored'});
    const status = await applyTransaction(env, normalized, 'vcb_device');
    return json({ok: true, status, orderCode: normalized.orderCode});
  },
};

export async function normalizeDeviceTransaction(body) {
  if (!body || typeof body !== 'object' || body.source !== 'com.VCB') return null;
  const accountNumber = String(body.accountNumber ?? '');
  const amountVnd = Number(body.amountVnd);
  const description = String(body.description ?? '').trim().replace(/\s+/g, ' ');
  const transactionAt = String(body.transactionAt ?? '');
  if (!/^\d{6,20}$/.test(accountNumber) ||
      !Number.isSafeInteger(amountVnd) || amountVnd <= 0 || amountVnd > 10000000000 ||
      description.length < 6 || description.length > 512 ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+07:00$/.test(transactionAt) ||
      !Number.isFinite(Date.parse(transactionAt))) return null;
  const orderCode = extractOrderCode(description);
  if (!orderCode) return null;
  const digestData = accountNumber + '\n' + amountVnd + '\n' + transactionAt + '\n' + description.toUpperCase();
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(digestData)));
  const transactionId = 'sha256:' + Array.from(hash, x => x.toString(16).padStart(2, '0')).join('');
  return {
    transactionId, bankReference: description.slice(0, 180),
    amountVnd, description, orderCode, accountNumber, transactionAt,
  };
}

async function verifySignature(secret, message, supplied) {
  const key = await crypto.subtle.importKey(
    'raw', encoder.encode(secret), {name: 'HMAC', hash: 'SHA-256'}, false, ['verify'],
  );
  const signature = Uint8Array.from(supplied.match(/../g).map(x => parseInt(x, 16)));
  return crypto.subtle.verify('HMAC', key, signature, encoder.encode(message));
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {status, headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  }});
}
