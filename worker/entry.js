import legacyWorker from './index.js';

const DAY_PASS_VND = 250000;
const MAX_NAME_LENGTH = 100;
const MAX_CONTACT_LENGTH = 160;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/api/public/status') {
      return handlePublicStatus(env);
    }

    if (request.method === 'POST' && url.pathname === '/api/public/book') {
      if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
      return handlePublicBooking(request, env);
    }

    if (request.method === 'GET' && url.pathname === '/api/public/booking') {
      return handlePublicBookingStatus(url, env);
    }

    if (
      request.method === 'POST' &&
      url.pathname === '/api/public/booking/delete'
    ) {
      if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
      return handlePublicBookingDelete(request, env);
    }

    if (request.method === 'GET' && url.pathname === '/api/admin/operations') {
      const response = await legacyWorker.fetch(request, env, ctx);
      return filterOperationsToToday(response);
    }

    if (
      request.method === 'POST' &&
      url.pathname === '/api/admin/booking/accept'
    ) {
      const clone = request.clone();
      const body = await readJson(clone);
      const bookingId = toPositiveInt(body?.id);
      if (bookingId) {
        const stale = await isBookingFromPreviousDay(bookingId, env);
        if (stale) {
          return jsonError('This desk request expired at midnight.', 410);
        }
      }

      const response = await legacyWorker.fetch(request, env, ctx);
      if (response.ok && bookingId) {
        await linkAcceptedVisit(bookingId, env);
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

async function handlePublicBooking(request, env) {
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

  return json(
    {
      ok: true,
      token,
      status: 'pending',
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
      SELECT id, status, created_at
      FROM booking_requests
      WHERE client_token_hash = ?
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

  return json({
    ok: true,
    status: booking.status === 'accepted' ? 'accepted' : 'pending',
  });
}

async function handlePublicBookingDelete(request, env) {
  const body = await readJson(request);
  const token = typeof body?.token === 'string' ? body.token : '';
  if (!isReasonableToken(token)) return jsonError('Invalid booking.', 400);

  const tokenHash = await hashToken(token);
  const booking = await env.evil_space
    .prepare(`
      SELECT id, status, customer_id, handled_at, accepted_visit_id
      FROM booking_requests
      WHERE client_token_hash = ?
      LIMIT 1
    `)
    .bind(tokenHash)
    .first();

  if (!booking) return json({ ok: true });

  let visitId = toPositiveInt(booking.accepted_visit_id);
  if (!visitId && booking.status === 'accepted') {
    const customerId = toPositiveInt(booking.customer_id);
    const handledAt = Number(booking.handled_at ?? 0);
    if (customerId && handledAt > 0) {
      const visit = await env.evil_space
        .prepare(`
          SELECT id
          FROM visits
          WHERE customer_id = ?
            AND created_at = ?
            AND kind = 'day'
            AND amount = ?
          ORDER BY id DESC
          LIMIT 1
        `)
        .bind(customerId, handledAt, DAY_PASS_VND)
        .first();
      visitId = toPositiveInt(visit?.id);
    }
  }

  const statements = [];
  if (visitId) {
    statements.push(
      env.evil_space.prepare('DELETE FROM visits WHERE id = ?').bind(visitId),
    );
  }
  statements.push(
    env.evil_space
      .prepare('DELETE FROM booking_requests WHERE id = ?')
      .bind(booking.id),
  );
  await env.evil_space.batch(statements);

  return json({ ok: true });
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

async function isBookingFromPreviousDay(bookingId, env) {
  const booking = await env.evil_space
    .prepare(`
      SELECT created_at
      FROM booking_requests
      WHERE id = ? AND status = 'new'
      LIMIT 1
    `)
    .bind(bookingId)
    .first();

  if (!booking) return false;
  const { start, end } = nhaTrangDayBounds(nowSeconds());
  const createdAt = Number(booking.created_at ?? 0);
  return createdAt < start || createdAt >= end;
}

async function linkAcceptedVisit(bookingId, env) {
  const booking = await env.evil_space
    .prepare(`
      SELECT id, status, customer_id, handled_at, accepted_visit_id
      FROM booking_requests
      WHERE id = ?
    `)
    .bind(bookingId)
    .first();

  if (
    !booking ||
    booking.status !== 'accepted' ||
    toPositiveInt(booking.accepted_visit_id)
  ) {
    return;
  }

  const customerId = toPositiveInt(booking.customer_id);
  const handledAt = Number(booking.handled_at ?? 0);
  if (!customerId || handledAt <= 0) return;

  const visit = await env.evil_space
    .prepare(`
      SELECT id
      FROM visits
      WHERE customer_id = ?
        AND created_at = ?
        AND kind = 'day'
        AND amount = ?
      ORDER BY id DESC
      LIMIT 1
    `)
    .bind(customerId, handledAt, DAY_PASS_VND)
    .first();

  const visitId = toPositiveInt(visit?.id);
  if (!visitId) return;

  await env.evil_space
    .prepare(`
      UPDATE booking_requests
      SET accepted_visit_id = ?
      WHERE id = ? AND accepted_visit_id IS NULL
    `)
    .bind(visitId, bookingId)
    .run();
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

function toPositiveInt(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : null;
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
