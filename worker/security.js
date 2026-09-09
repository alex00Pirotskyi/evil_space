const SESSION_COOKIE = '__Host-evil_admin_session';
const MAX_JSON_BYTES = 16384;

export async function securityGate(request, env) {
  if (request.method !== 'POST') return null;

  const url = new URL(request.url);
  const ip = clientIp(request);
  let limiter = null;
  let scope = '';
  let identity = '';

  if (
    url.pathname === '/api/admin/login' ||
    url.pathname === '/api/admin/register'
  ) {
    const body = await readJsonClone(request);
    const email = normalizeEmail(body?.email);
    if (!validEmail(email)) return null;
    limiter = env.AUTH_RATE_LIMITER;
    scope = url.pathname.endsWith('/login') ? 'admin-login' : 'admin-register';
    identity = email;
  } else if (url.pathname === '/api/admin/delete') {
    const session = cookieValue(request, SESSION_COOKIE);
    if (!session) return null;
    limiter = env.AUTH_RATE_LIMITER;
    scope = 'admin-delete';
    identity = session;
  } else if (url.pathname === '/api/public/book') {
    const body = await readJsonClone(request);
    const contactType =
      body?.contactType === 'phone' || body?.contactType === 'telegram'
        ? body.contactType
        : '';
    const contactValue = cleanText(body?.contactValue, 160);
    if (!contactType || contactValue.length < 3) return null;
    limiter = env.PUBLIC_BOOKING_RATE_LIMITER;
    scope = 'public-book';
    identity = `${contactType}:${contactValue.toLowerCase()}`;
  } else if (url.pathname === '/api/public/menu/order') {
    const body = await readJsonClone(request);
    const itemId = cleanText(body?.itemId, 64);
    if (!itemId) return null;
    limiter = env.PUBLIC_BOOKING_RATE_LIMITER;
    scope = 'public-menu-order';
    identity = itemId.toLowerCase();
  } else {
    return null;
  }

  if (!limiter || typeof limiter.limit !== 'function') return null;

  try {
    const key = await rateLimitKey(scope, identity, ip);
    const result = await limiter.limit({ key });
    if (result?.success === true) return null;
    return rateLimitResponse();
  } catch (error) {
    console.error('Security rate limiter failed', safeError(error));
    return jsonError('Security check unavailable. Please try again.', 503);
  }
}

async function readJsonClone(request) {
  const length = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(length) && length > MAX_JSON_BYTES) return null;
  try {
    const body = await request.clone().json();
    return body && typeof body === 'object' ? body : null;
  } catch {
    return null;
  }
}

async function rateLimitKey(scope, identity, ip) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(`${scope}\n${identity}\n${ip}`),
  );
  const bytes = new Uint8Array(digest);
  let hex = '';
  for (const byte of bytes) hex += byte.toString(16).padStart(2, '0');
  return `${scope}:${hex}`;
}

function clientIp(request) {
  const value = request.headers.get('cf-connecting-ip')?.trim();
  return value || 'unknown';
}

function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function validEmail(value) {
  return (
    value.length > 0 &&
    value.length <= 254 &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)
  );
}

function cleanText(value, maxLength) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  if (!text || text.length > maxLength) return '';
  return text;
}

function cookieValue(request, name) {
  const raw = request.headers.get('cookie') ?? '';
  for (const part of raw.split(';')) {
    const separator = part.indexOf('=');
    if (separator < 0) continue;
    const key = part.slice(0, separator).trim();
    if (key === name) return part.slice(separator + 1).trim();
  }
  return null;
}

function rateLimitResponse() {
  return jsonError(
    'Too many attempts. Please try again in a minute.',
    429,
    { 'Retry-After': '60' },
  );
}

function jsonError(message, status, extraHeaders = {}) {
  return new Response(JSON.stringify({ ok: false, error: message }), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      ...extraHeaders,
    },
  });
}

function safeError(error) {
  if (error instanceof Error) return error.message;
  return String(error);
}
