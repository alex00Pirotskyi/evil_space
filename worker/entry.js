import legacyWorker from './index.js';
import {
  createCustomerTelegramLink,
  handleAdminTelegramDisconnect,
  handleAdminTelegramLink,
  handleAdminTelegramPreferences,
  handleAdminTelegramStatus,
  handlePublicBookingCancel,
  handleTelegramWebhook,
  handleWebAcceptBooking,
  handleWebDeclineBooking,
  notifyAdminsNewBooking,
  notifyAdminsPurchase,
} from './telegram.js';

const MAX_NAME_LENGTH = 100;
const MAX_CONTACT_LENGTH = 160;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/api/telegram/webhook') {
      return handleTelegramWebhook(request, env, ctx);
    }

    if (request.method === 'GET' && url.pathname === '/api/public/status') {
      return handlePublicStatus(env);
    }

    if (request.method === 'POST' && url.pathname === '/api/public/book') {
      if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
      return handlePublicBooking(request, env, ctx);
    }

    if (request.method === 'GET' && url.pathname === '/api/public/booking') {
      return handlePublicBookingStatus(url, env);
    }

    if (
      request.method === 'POST' &&
      url.pathname === '/api/public/booking/delete'
    ) {
      if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
      return handlePublicBookingCancel(request, env, ctx);
    }

    if (request.method === 'GET' && url.pathname === '/api/admin/telegram') {
      return handleAdminTelegramStatus(request, env);
    }

    if (
      request.method === 'POST' &&
      url.pathname === '/api/admin/telegram/link'
    ) {
      if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
      return handleAdminTelegramLink(request, env);
    }

    if (
      request.method === 'POST' &&
      url.pathname === '/api/admin/telegram/disconnect'
    ) {
      if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
      return handleAdminTelegramDisconnect(request, env);
    }

    if (
      request.method === 'POST' &&
      url.pathname === '/api/admin/telegram/preferences'
    ) {
      if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
      return handleAdminTelegramPreferences(request, env);
    }

    if (request.method === 'GET' && url.pathname === '/api/admin/operations') {
      const response = await legacyWorker.fetch(request, env, ctx);
      return filterOperationsToToday(response);
    }

    if (
      request.method === 'POST' &&
      url.pathname === '/api/admin/booking/accept'
    ) {
      if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
      return handleWebAcceptBooking(request, env, ctx);
    }

    if (
      request.method === 'POST' &&
      url.pathname === '/api/admin/booking/decline'
    ) {
      if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
      return handleWebDeclineBooking(request, env, ctx);
    }

    if (
      request.method === 'POST' &&
      url.pathname === '/api/admin/purchases'
    ) {
      const clone = request.clone();
      const body = await readJson(clone);
      const title = cleanText(body?.title, 180);
      const response = await legacyWorker.fetch(request, env, ctx);
      if (response.ok && title) {
        ctx.waitUntil(notifyAdminsPurchase(env, title));
      }
      return response;
    }

    return legacyWorker.fetch(request, env, ctx);
  },
};

async function handlePublicStatus(env) {
  const now = nowSeconds();
  const { start, end } = nhaTrangDayBounds(now);
  const row = await env.evil_space
    .prepare(`
      SELECT
        COALESCE((SELECT total_desks FROM site_state WHERE id = 1), 10) AS total,
        (SELECT COUNT(*) FROM visits WHERE created_at >= ? AND created_at < ?) AS occupied
    `)
    .bind(start, end)
    .first();

  const total = Math.max(1, Number(row?.total ?? 10));
  const occupied = Math.min(total, Math.max(0, Number(row?.occupied ?? 0)));
  return json({
    ok: true,
    status: {
      total,
      occupied,
      free: Math.max(0, total - occupied),
      updated: new Date(start * 1000).toISOString(),
    },
  });
}

async function handlePublicBooking(request, env, ctx) {
  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const name = cleanText(body.name, MAX_NAME_LENGTH);
  const contactType =
    body.contactType === 'phone' || body.contactType === 'telegram'
      ? body.contactType
      : '';
  const contactValue = cleanText(body.contactValue, MAX_CONTACT_LENGTH);

  if (!name) return jsonError('Name is required.', 400);
  if (!contactType || contactValue.length < 3) {
    return jsonError('Phone or Telegram is required.', 400);
  }

  const token = randomToken(32);
  const tokenHash = await hashToken(token);
  const created = await env.evil_space
    .prepare(`
      INSERT INTO booking_requests
        (name, contact_type, contact_value, status, created_at, client_token_hash)
      VALUES (?, ?, ?, 'new', ?, ?)
      RETURNING id
    `)
    .bind(name, contactType, contactValue, nowSeconds(), tokenHash)
    .first();

  if (!created?.id) return jsonError('Could not create desk request.', 500);

  let telegramLinkUrl = null;
  if (contactType === 'telegram') {
    telegramLinkUrl = await createCustomerTelegramLink(
      env,
      created.id,
      body.language,
    );
  }

  ctx.waitUntil(notifyAdminsNewBooking(env, created.id));

  return json(
    {
      ok: true,
      token,
      status: 'pending',
      telegramLinkUrl,
      telegramLinked: false,
      message: 'Desk request sent. Evil Space staff can now see it.',
    },
    201,
  );
}

async function handlePublicBookingStatus(url, env) {
  const token = url.searchParams.get('token') ?? '';
  if (!isReasonableToken(token)) return jsonError('Invalid booking.', 400);

  const tokenHash = await hashToken(token);
  const booking = await env.evil_space
    .prepare(`
      SELECT
        b.id,
        b.status,
        b.created_at,
        CASE
          WHEN b.customer_id IS NOT NULL AND EXISTS (
            SELECT 1
            FROM customer_telegram_links l
            WHERE l.customer_id = b.customer_id
          ) THEN 1
          ELSE 0
        END AS telegram_linked
      FROM booking_requests b
      WHERE b.client_token_hash = ?
      LIMIT 1
    `)
    .bind(tokenHash)
    .first();

  if (!booking) return jsonError('Booking not found.', 404);

  const now = nowSeconds();
  const { start, end } = nhaTrangDayBounds(now);
  const createdAt = Number(booking.created_at ?? 0);
  if (createdAt < start || createdAt >= end) {
    return jsonError('Booking expired.', 410);
  }

  const status = booking.status === 'accepted'
    ? 'accepted'
    : booking.status === 'declined'
      ? 'declined'
      : booking.status === 'cancelled'
        ? 'cancelled'
        : 'pending';

  return json({
    ok: true,
    status,
    telegramLinked: Number(booking.telegram_linked ?? 0) === 1,
  });
}

async function filterOperationsToToday(response) {
  if (!response.ok) return response;

  let payload;
  try {
    payload = await response.json();
  } catch {
    return response;
  }

  const requests = payload?.snapshot?.booking_requests;
  if (Array.isArray(requests)) {
    const { start, end } = nhaTrangDayBounds(nowSeconds());
    payload.snapshot.booking_requests = requests.filter((booking) => {
      const createdAt = Number(booking?.created_at ?? 0);
      return createdAt >= start && createdAt < end;
    });
  }

  return json(payload, response.status);
}

async function readJson(request) {
  const length = Number(request.headers.get('content-length') ?? 0);
  if (length > 16384) return null;
  try {
    const body = await request.json();
    return body && typeof body === 'object' ? body : null;
  } catch {
    return null;
  }
}

function cleanText(value, maxLength) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  if (!text || text.length > maxLength) return '';
  return text;
}

function nhaTrangDayBounds(now) {
  const offset = 7 * 3600;
  const local = new Date((now + offset) * 1000);
  const localMidnightUtc =
    Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) /
    1000;
  const start = localMidnightUtc - offset;
  return { start, end: start + 86400 };
}

async function hashToken(token) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(token),
  );
  return toBase64Url(new Uint8Array(digest));
}

function randomToken(byteLength) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return toBase64Url(bytes);
}

function toBase64Url(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/g, '');
}

function isReasonableToken(token) {
  return (
    token.length >= 32 &&
    token.length <= 128 &&
    /^[A-Za-z0-9_-]+$/.test(token)
  );
}

function isSameOrigin(request, url) {
  const origin = request.headers.get('origin');
  return origin === null || origin === url.origin;
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function jsonError(message, status) {
  return json({ ok: false, error: message }, status);
}
