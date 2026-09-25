import {
  handlePublicBooking,
  handlePublicBookingStatus,
  handlePublicStatus,
} from './entry.js';

const KEY_MIN_LENGTH = 32;

export function assistantKeyConfigured(env) {
  return typeof env.ASSISTANT_BOOKING_KEY === 'string' &&
    env.ASSISTANT_BOOKING_KEY.length >= KEY_MIN_LENGTH;
}

export function assistantKeyAuthorized(request, env) {
  if (!assistantKeyConfigured(env)) return false;
  const header = request.headers.get('Authorization') ?? '';
  const supplied = /^Bearer ([A-Za-z0-9_-]{32,128})$/.exec(header)?.[1] ?? '';
  const expected = env.ASSISTANT_BOOKING_KEY;
  if (supplied.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i += 1) {
    diff |= expected.charCodeAt(i) ^ supplied.charCodeAt(i);
  }
  return diff === 0;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/api/assistant/availability') {
      const result = await handlePublicStatus(env);
      if (!result.ok) return result;
      const { status } = await result.json();
      return json({
        ok: true,
        business: 'Evil Space coworking, Nha Trang',
        timeZone: 'Asia/Ho_Chi_Minh',
        openingHours: '11:00–23:00 daily',
        currency: 'VND',
        days: [
          { date: status.todayDate, freeDesks: status.free, dayPassPriceVnd: status.todayPrice },
          { date: status.tomorrowDate, freeDesks: status.tomorrowFree, dayPassPriceVnd: status.tomorrowPrice },
        ],
        note: 'Free desks count accepted visits, not pending requests. A desk is confirmed only after Evil Space staff accepts the request.',
      });
    }

    if (url.pathname === '/api/assistant/booking' &&
        (request.method === 'POST' || request.method === 'GET')) {
      if (!assistantKeyConfigured(env)) {
        return jsonError('Assistant booking is not configured.', 503);
      }
      if (!assistantKeyAuthorized(request, env)) {
        return jsonError('A valid assistant booking credential is required.', 401);
      }
      if (request.method === 'GET') return handlePublicBookingStatus(url, env);

      const body = await readJson(request);
      if (!body) return jsonError('Invalid booking request.', 400);
      if (body.userConfirmed !== true) {
        return jsonError('Ask the customer to confirm this booking request first.', 400);
      }
      if (!validContact(body.contactType, body.contactValue)) {
        return jsonError('Provide a valid phone number or Telegram username.', 400);
      }
      // Reuse the website's live pricing, capacity check, duplicate check,
      // staff notification, and pending/accepted booking lifecycle.
      return handlePublicBooking(requestFromBody(url, body), env, ctx);
    }

    return jsonError('Not found.', 404);
  },
};

function validContact(type, raw) {
  if (typeof raw !== 'string') return false;
  const value = raw.trim();
  if (type === 'telegram') return /^@[A-Za-z0-9_]{5,32}$/.test(value);
  if (type === 'phone') {
    const digits = value.replace(/\D/g, '');
    return /^\+?[0-9][0-9 ()-]{6,22}$/.test(value) &&
      digits.length >= 8 && digits.length <= 15;
  }
  return false;
}

function requestFromBody(url, body) {
  return new Request(new URL('/api/public/book', url), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

async function readJson(request) {
  const length = Number(request.headers.get('content-length') ?? 0);
  if (length > 16384) return null;
  try {
    const raw = await request.text();
    if (raw.length > 16384) return null;
    const value = JSON.parse(raw);
    return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
  } catch {
    return null;
  }
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function jsonError(message, status) {
  return json({ ok: false, error: message }, status);
}
