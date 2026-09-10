const CUSTOMER_SESSION_COOKIE = '__Host-evil_customer_session';
const CUSTOMER_SESSION_TTL_SECONDS = 60 * 60 * 24 * 90;
const GOOGLE_REDIRECT_STATE_TTL_SECONDS = 10 * 60;
const GOOGLE_CSRF_COOKIE = 'g_csrf_token';
const MAX_DEVICE_JSON_BYTES = 4096;
const DEFAULT_BOT_USERNAME = 'CoworkingEvilAdminBot';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const route = `${request.method} ${url.pathname}`;

    try {
      if (route === 'POST /api/public/account/google') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return await handleGooglePopup(request, env);
      }
      if (route === 'POST /api/public/account/google/redirect/start') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return await handleGoogleRedirectStart(request, env, url);
      }
      if (route === 'POST /api/public/account/google/redirect') {
        return await handleGoogleRedirect(request, env, url);
      }
      return jsonError('Not found.', 404);
    } catch (error) {
      console.error('Google customer account error', safeError(error));
      if (url.pathname === '/api/public/account/google/redirect') {
        return redirectHome(url, 'error');
      }
      return jsonError('Google sign-in failed. Please try again.', 500);
    }
  },
};

async function handleGooglePopup(request, env) {
  const clientId = cleanShortText(env.GOOGLE_CLIENT_ID, 512);
  if (!clientId) return jsonError('Google registration is not configured yet.', 503);

  const body = await readJson(request, 32 * 1024);
  const idToken = typeof body?.idToken === 'string' ? body.idToken.trim() : '';
  if (!idToken || idToken.length > 8192) {
    return jsonError('Google credential is required.', 400);
  }

  const info = await verifyGoogleCredential(idToken, clientId);
  if (!info) return jsonError('Google sign-in could not be verified.', 401);

  const currentCustomerId = await authenticatedCustomerId(request, env);
  const result = await completeGoogleIdentity(
    env,
    info,
    currentCustomerId,
    sanitizeDeviceProfile(body?.device),
  );
  if (result.error) return jsonError(result.error, result.status);

  const session = await createCustomerSession(env, result.customerId);
  return json(
    {
      ok: true,
      authenticated: true,
      customer: await customerSnapshot(env, result.customerId),
      providers: providerConfig(env),
      registrationDiscountPercent: 50,
    },
    200,
    { 'Set-Cookie': sessionCookie(session.token, CUSTOMER_SESSION_TTL_SECONDS) },
  );
}

async function handleGoogleRedirectStart(request, env, url) {
  const clientId = cleanShortText(env.GOOGLE_CLIENT_ID, 512);
  if (!clientId) return jsonError('Google registration is not configured yet.', 503);

  const body = await readJson(request, 16 * 1024);
  const device = sanitizeDeviceProfile(body?.device);
  const state = randomToken(32);
  const stateDigest = await hashToken(state);
  const now = nowSeconds();
  const expiresAt = now + GOOGLE_REDIRECT_STATE_TTL_SECONDS;
  const customerId = await authenticatedCustomerId(request, env);

  await env.evil_space.batch([
    env.evil_space
      .prepare('DELETE FROM customer_google_redirect_states WHERE expires_at <= ? OR used_at IS NOT NULL')
      .bind(now),
    env.evil_space
      .prepare(`
        INSERT INTO customer_google_redirect_states
          (state_digest, customer_id, device_json, created_at, expires_at, used_at)
        VALUES (?, ?, ?, ?, ?, NULL)
      `)
      .bind(
        stateDigest,
        customerId || null,
        JSON.stringify(device ?? {}),
        now,
        expiresAt,
      ),
  ]);

  return json(
    {
      ok: true,
      state,
      loginUri: `${url.origin}/api/public/account/google/redirect`,
      expiresAt,
    },
    201,
  );
}

async function handleGoogleRedirect(request, env, url) {
  const clientId = cleanShortText(env.GOOGLE_CLIENT_ID, 512);
  if (!clientId) return redirectHome(url, 'not-configured');

  const form = await readForm(request, 32 * 1024);
  if (!form) return redirectHome(url, 'invalid-response');

  const csrfBody = form.get('g_csrf_token') ?? '';
  const csrfCookie = cookieValue(request, GOOGLE_CSRF_COOKIE);
  if (!csrfTokensMatch(csrfCookie, csrfBody)) {
    return redirectHome(url, 'csrf');
  }

  const state = form.get('state') ?? '';
  const idToken = form.get('credential') ?? '';
  if (!isReasonableToken(state) || !idToken || idToken.length > 8192) {
    return redirectHome(url, 'invalid-response');
  }

  const stateDigest = await hashToken(state);
  const now = nowSeconds();
  const stored = await env.evil_space
    .prepare(`
      SELECT customer_id, device_json, expires_at, used_at
      FROM customer_google_redirect_states
      WHERE state_digest = ?
      LIMIT 1
    `)
    .bind(stateDigest)
    .first();
  if (!stored || stored.used_at != null || Number(stored.expires_at) <= now) {
    return redirectHome(url, 'expired');
  }

  const info = await verifyGoogleCredential(idToken, clientId);
  if (!info) return redirectHome(url, 'verification');

  const consumed = await env.evil_space
    .prepare(`
      UPDATE customer_google_redirect_states
      SET used_at = ?
      WHERE state_digest = ? AND used_at IS NULL AND expires_at > ?
    `)
    .bind(now, stateDigest, now)
    .run();
  if (Number(consumed.meta?.changes ?? 0) !== 1) {
    return redirectHome(url, 'expired');
  }

  let device = null;
  try {
    device = sanitizeDeviceProfile(JSON.parse(String(stored.device_json ?? '{}')));
  } catch {}

  const result = await completeGoogleIdentity(
    env,
    info,
    Number(stored.customer_id ?? 0),
    device,
  );
  if (result.error) return redirectHome(url, 'account-conflict');

  const session = await createCustomerSession(env, result.customerId);
  return redirectHome(
    url,
    'success',
    sessionCookie(session.token, CUSTOMER_SESSION_TTL_SECONDS),
  );
}

async function verifyGoogleCredential(idToken, clientId) {
  const response = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
    { headers: { Accept: 'application/json' } },
  );
  const info = await response.json().catch(() => null);
  if (!response.ok || !validateGoogleTokenInfo(info, clientId, nowSeconds())) {
    return null;
  }
  return info;
}

async function completeGoogleIdentity(env, info, currentCustomerId, device) {
  const now = nowSeconds();
  const subject = String(info.sub);
  const email = String(info.email).trim().toLowerCase();
  const name =
    cleanName(info.name) ||
    cleanName(info.given_name) ||
    cleanName(email.split('@')[0]) ||
    'Evil Space member';

  const existingIdentity = await env.evil_space
    .prepare(`
      SELECT customer_id
      FROM customer_identities
      WHERE provider = 'google' AND provider_subject = ?
      LIMIT 1
    `)
    .bind(subject)
    .first();
  const identityCustomerId = Number(existingIdentity?.customer_id ?? 0);

  if (
    currentCustomerId &&
    identityCustomerId &&
    identityCustomerId !== currentCustomerId
  ) {
    return {
      error: 'This Google account is already linked to another Evil Space account.',
      status: 409,
    };
  }

  let customerId = currentCustomerId || identityCustomerId;
  if (!customerId) {
    const inserted = await env.evil_space
      .prepare(`
        INSERT INTO customers
          (name, phone, email, telegram, created_at, updated_at)
        VALUES (?, NULL, ?, NULL, ?, ?)
      `)
      .bind(name, email, now, now)
      .run();
    customerId = Number(inserted.meta?.last_row_id ?? 0);
  }
  if (!customerId) throw new Error('Could not create customer account.');

  if (!identityCustomerId) {
    await env.evil_space
      .prepare(`
        INSERT INTO customer_identities
          (customer_id, provider, provider_subject, display_value,
           verified_at, created_at, updated_at)
        VALUES (?, 'google', ?, ?, ?, ?, ?)
      `)
      .bind(customerId, subject, email, now, now, now)
      .run();
  } else {
    await env.evil_space
      .prepare(`
        UPDATE customer_identities
        SET display_value = ?, updated_at = ?
        WHERE customer_id = ?
          AND provider = 'google'
          AND provider_subject = ?
      `)
      .bind(email, now, customerId, subject)
      .run();
  }

  await env.evil_space
    .prepare(`
      UPDATE customers
      SET email = ?,
          name = CASE
            WHEN trim(COALESCE(name, '')) = '' OR name = 'Evil Space member'
              THEN ?
            ELSE name
          END,
          updated_at = ?
      WHERE id = ?
    `)
    .bind(email, name, now, customerId)
    .run();

  if (device) await upsertDevice(env, customerId, device);
  return { customerId };
}

export function validateGoogleTokenInfo(info, clientId, now) {
  if (!info || typeof info !== 'object') return false;
  const issuer = String(info.iss ?? '');
  const emailVerified = info.email_verified === true || String(info.email_verified) === 'true';
  const subject = String(info.sub ?? '').trim();
  const email = String(info.email ?? '').trim();
  const audience = String(info.aud ?? '');
  const expiresAt = Number(info.exp ?? 0);

  return (
    (issuer === 'accounts.google.com' || issuer === 'https://accounts.google.com') &&
    subject.length > 0 &&
    subject.length <= 255 &&
    email.length > 3 &&
    email.length <= 320 &&
    email.includes('@') &&
    emailVerified &&
    audience === String(clientId) &&
    Number.isFinite(expiresAt) &&
    expiresAt > Number(now)
  );
}

export function csrfTokensMatch(cookieToken, bodyToken) {
  return (
    typeof cookieToken === 'string' &&
    typeof bodyToken === 'string' &&
    cookieToken.length >= 8 &&
    cookieToken.length <= 512 &&
    constantTimeEqual(cookieToken, bodyToken)
  );
}

async function authenticatedCustomerId(request, env) {
  const token = cookieValue(request, CUSTOMER_SESSION_COOKIE);
  if (!isReasonableToken(token)) return 0;
  const tokenHash = await hashToken(token);
  const row = await env.evil_space
    .prepare(`
      SELECT s.customer_id
      FROM customer_sessions s
      JOIN customers c ON c.id = s.customer_id
      WHERE s.token_hash = ? AND s.expires_at > ?
      LIMIT 1
    `)
    .bind(tokenHash, nowSeconds())
    .first();
  return Number(row?.customer_id ?? 0);
}

async function createCustomerSession(env, customerId) {
  const token = randomToken(32);
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const expiresAt = now + CUSTOMER_SESSION_TTL_SECONDS;
  await env.evil_space.batch([
    env.evil_space
      .prepare('DELETE FROM customer_sessions WHERE expires_at <= ?')
      .bind(now),
    env.evil_space
      .prepare(`
        INSERT INTO customer_sessions
          (customer_id, token_hash, created_at, expires_at, last_seen_at)
        VALUES (?, ?, ?, ?, ?)
      `)
      .bind(customerId, tokenHash, now, expiresAt, now),
  ]);
  return { token, expiresAt };
}

async function customerSnapshot(env, customerId) {
  const [customer, identities, devices] = await Promise.all([
    env.evil_space
      .prepare(
        'SELECT id, name, phone, email, telegram FROM customers WHERE id = ? LIMIT 1',
      )
      .bind(customerId)
      .first(),
    env.evil_space
      .prepare(`
        SELECT provider, display_value, verified_at
        FROM customer_identities
        WHERE customer_id = ?
        ORDER BY verified_at, id
      `)
      .bind(customerId)
      .all(),
    env.evil_space
      .prepare('SELECT COUNT(*) AS count FROM customer_devices WHERE customer_id = ?')
      .bind(customerId)
      .first(),
  ]);
  if (!customer) return null;
  return {
    id: Number(customer.id),
    name: String(customer.name ?? ''),
    phone: customer.phone == null ? null : String(customer.phone),
    email: customer.email == null ? null : String(customer.email),
    telegram: customer.telegram == null ? null : String(customer.telegram),
    identities: (identities.results ?? []).map((row) => ({
      provider: String(row.provider),
      displayValue: String(row.display_value ?? ''),
      verifiedAt: Number(row.verified_at),
    })),
    deviceCount: Number(devices?.count ?? 0),
  };
}

function sanitizeDeviceProfile(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const deviceId = cleanShortText(value.deviceId, 100);
  if (!/^[A-Za-z0-9_-]{16,100}$/.test(deviceId)) return null;
  const result = {
    deviceId,
    platform: cleanShortText(value.platform, 100),
    userAgent: cleanShortText(value.userAgent, 512),
    language: cleanShortText(value.language, 40),
    timezoneOffsetMinutes: toBoundedInt(value.timezoneOffsetMinutes, -1440, 1440),
    screenWidth: toBoundedInt(value.screenWidth, 0, 20000),
    screenHeight: toBoundedInt(value.screenHeight, 0, 20000),
    viewportWidth: toBoundedInt(value.viewportWidth, 0, 20000),
    viewportHeight: toBoundedInt(value.viewportHeight, 0, 20000),
    pixelRatio: toBoundedNumber(value.pixelRatio, 0, 20),
    touchPoints: toBoundedInt(value.touchPoints, 0, 100),
    hardwareConcurrency: toBoundedInt(value.hardwareConcurrency, 0, 1024),
    vendor: cleanShortText(value.vendor, 120),
    referrer: cleanShortText(value.referrer, 512),
  };
  if (
    new TextEncoder().encode(JSON.stringify(result)).length >
    MAX_DEVICE_JSON_BYTES
  ) {
    return null;
  }
  return result;
}

async function upsertDevice(env, customerId, device) {
  const now = nowSeconds();
  await env.evil_space
    .prepare(`
      INSERT INTO customer_devices
        (customer_id, device_id, platform, user_agent, language,
         timezone_offset_minutes, info_json, first_seen_at, last_seen_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(customer_id, device_id) DO UPDATE SET
        platform = excluded.platform,
        user_agent = excluded.user_agent,
        language = excluded.language,
        timezone_offset_minutes = excluded.timezone_offset_minutes,
        info_json = excluded.info_json,
        last_seen_at = excluded.last_seen_at
    `)
    .bind(
      customerId,
      device.deviceId,
      device.platform,
      device.userAgent,
      device.language,
      device.timezoneOffsetMinutes,
      JSON.stringify(device),
      now,
      now,
    )
    .run();
}

function providerConfig(env) {
  return {
    phone: Boolean(env.SMS_WEBHOOK_URL),
    telegram: Boolean(env.TELEGRAM_BOT_TOKEN),
    telegramBotUsername: telegramBotUsername(env),
    google: Boolean(env.GOOGLE_CLIENT_ID),
    googleClientId: env.GOOGLE_CLIENT_ID ? String(env.GOOGLE_CLIENT_ID) : null,
  };
}

function telegramBotUsername(env) {
  const value = cleanShortText(env.TELEGRAM_BOT_USERNAME, 64).replace(/^@/, '');
  return /^[A-Za-z0-9_]{5,64}$/.test(value) ? value : DEFAULT_BOT_USERNAME;
}

function cleanName(value) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  return text && text.length <= 100 ? text : '';
}

function cleanShortText(value, maxLength) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, maxLength);
}

function toBoundedInt(value, min, max) {
  const number = Number(value);
  return Number.isFinite(number)
    ? Math.min(max, Math.max(min, Math.round(number)))
    : null;
}

function toBoundedNumber(value, min, max) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.min(max, Math.max(min, number)) : null;
}

function randomToken(size) {
  const bytes = crypto.getRandomValues(new Uint8Array(size));
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/g, '');
}

async function hashToken(token) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(token),
  );
  let binary = '';
  for (const byte of new Uint8Array(digest)) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/g, '');
}

function constantTimeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let index = 0; index < a.length; index += 1) {
    diff |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return diff === 0;
}

function isReasonableToken(value) {
  return (
    typeof value === 'string' &&
    value.length >= 32 &&
    value.length <= 256 &&
    /^[A-Za-z0-9_-]+$/.test(value)
  );
}

function cookieValue(request, name) {
  const header = request.headers.get('Cookie') ?? '';
  for (const chunk of header.split(';')) {
    const [key, ...rest] = chunk.trim().split('=');
    if (key !== name) continue;
    try {
      return decodeURIComponent(rest.join('='));
    } catch {
      return rest.join('=');
    }
  }
  return '';
}

function sessionCookie(value, maxAge) {
  return `${CUSTOMER_SESSION_COOKIE}=${encodeURIComponent(value)}; Path=/; Max-Age=${maxAge}; HttpOnly; Secure; SameSite=Lax`;
}

function isSameOrigin(request, url) {
  const origin = request.headers.get('Origin');
  return !origin || origin === url.origin;
}

async function readJson(request, maxBytes) {
  const length = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(length) && length > maxBytes) return null;
  try {
    const text = await request.text();
    if (new TextEncoder().encode(text).length > maxBytes) return null;
    const value = JSON.parse(text);
    return value && typeof value === 'object' ? value : null;
  } catch {
    return null;
  }
}

async function readForm(request, maxBytes) {
  const type = request.headers.get('content-type') ?? '';
  if (!type.toLowerCase().startsWith('application/x-www-form-urlencoded')) {
    return null;
  }
  const length = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(length) && length > maxBytes) return null;
  try {
    const text = await request.text();
    if (new TextEncoder().encode(text).length > maxBytes) return null;
    return new URLSearchParams(text);
  } catch {
    return null;
  }
}

function redirectHome(url, result, setCookie = null) {
  const target = new URL('/', url);
  target.searchParams.set('google', result);
  const headers = {
    Location: target.toString(),
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  };
  if (setCookie) headers['Set-Cookie'] = setCookie;
  return new Response(null, { status: 303, headers });
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function json(payload, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      ...extraHeaders,
    },
  });
}

function jsonError(message, status) {
  return json({ ok: false, error: message }, status);
}

function safeError(error) {
  return error instanceof Error ? error.message : String(error);
}
