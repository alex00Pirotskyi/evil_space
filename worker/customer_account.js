const CUSTOMER_SESSION_COOKIE = '__Host-evil_customer_session';
const ADMIN_SESSION_COOKIE = '__Host-evil_admin_session';
const CUSTOMER_SESSION_TTL_SECONDS = 60 * 60 * 24 * 90;
const SIGNUP_TTL_SECONDS = 10 * 60;
const PHONE_OTP_TTL_SECONDS = 5 * 60;
const MAX_NAME_LENGTH = 100;
const MAX_DEVICE_JSON_BYTES = 4096;
const DEFAULT_BOT_USERNAME = 'CoworkingEvilAdminBot';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    try {
      if (request.method === 'GET' && url.pathname === '/api/public/account') {
        return handleAccountSnapshot(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/public/account/logout') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleLogout(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/public/account/phone/start') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handlePhoneStart(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/public/account/phone/verify') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handlePhoneVerify(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/public/account/telegram/start') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleTelegramStart(request, env);
      }
      if (request.method === 'GET' && url.pathname === '/api/public/account/telegram/status') {
        return handleTelegramStatus(url, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/public/account/google') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleGoogle(request, env);
      }
      return jsonError('Not found.', 404);
    } catch (error) {
      console.error('Customer account error', safeError(error));
      return jsonError('Account request failed. Please try again.', 500);
    }
  },
};

async function handleAccountSnapshot(request, env) {
  const [customer, adminAuthenticated] = await Promise.all([
    authenticatedCustomer(request, env),
    authenticatedAdmin(request, env),
  ]);
  if (customer) {
    await env.evil_space
      .prepare('UPDATE customer_sessions SET last_seen_at = ? WHERE id = ?')
      .bind(nowSeconds(), customer.session_id)
      .run()
      .catch(() => null);
  }
  return json({
    ok: true,
    authenticated: Boolean(customer),
    adminAuthenticated,
    customer: customer ? await customerSnapshot(env, customer.id) : null,
    providers: providerConfig(env),
    registrationDiscountPercent: 50,
  });
}

async function handleLogout(request, env) {
  const token = cookieValue(request, CUSTOMER_SESSION_COOKIE);
  if (token) {
    const tokenHash = await hashToken(token);
    await env.evil_space
      .prepare('DELETE FROM customer_sessions WHERE token_hash = ?')
      .bind(tokenHash)
      .run();
  }
  return json(
    { ok: true, authenticated: false, providers: providerConfig(env) },
    200,
    { 'Set-Cookie': sessionCookie('', 0) },
  );
}

async function handlePhoneStart(request, env) {
  if (!env.SMS_WEBHOOK_URL) {
    return jsonError('Phone verification is not configured yet.', 503);
  }
  const body = await readJson(request, 16 * 1024);
  const name = cleanName(body?.name);
  const phone = normalizeVietnamPhone(body?.phone);
  const device = sanitizeDeviceProfile(body?.device);
  if (!name) return jsonError('Name is required.', 400);
  if (!phone) return jsonError('Enter a valid phone number.', 400);

  const now = nowSeconds();
  const recent = await env.evil_space
    .prepare(`
      SELECT COUNT(*) AS count, MAX(created_at) AS latest
      FROM customer_phone_otps
      WHERE phone_e164 = ? AND created_at >= ?
    `)
    .bind(phone, now - 60 * 60)
    .first();
  if (Number(recent?.latest ?? 0) > now - 45) {
    return jsonError('Please wait before requesting another code.', 429);
  }
  if (Number(recent?.count ?? 0) >= 5) {
    return jsonError('Too many verification attempts. Try again later.', 429);
  }

  const challenge = randomToken(32);
  const challengeHash = await hashToken(challenge);
  const code = randomDigits(6);
  const codeHash = await hashToken(`${challenge}:${code}`);
  const expiresAt = now + PHONE_OTP_TTL_SECONDS;
  await env.evil_space
    .prepare(`
      INSERT INTO customer_phone_otps
        (challenge_hash, phone_e164, name, code_hash, device_json,
         attempts, created_at, expires_at, used_at)
      VALUES (?, ?, ?, ?, ?, 0, ?, ?, NULL)
    `)
    .bind(
      challengeHash,
      phone,
      name,
      codeHash,
      JSON.stringify(device ?? {}),
      now,
      expiresAt,
    )
    .run();

  try {
    await sendSms(env, phone, `Evil Space verification code: ${code}`);
  } catch (error) {
    await env.evil_space
      .prepare('DELETE FROM customer_phone_otps WHERE challenge_hash = ?')
      .bind(challengeHash)
      .run();
    console.error('SMS delivery failed', safeError(error));
    return jsonError('Could not send the verification code.', 503);
  }

  return json({ ok: true, challenge, phone, expiresAt }, 201);
}

async function handlePhoneVerify(request, env) {
  const body = await readJson(request, 16 * 1024);
  const challenge = typeof body?.challenge === 'string' ? body.challenge.trim() : '';
  const code = typeof body?.code === 'string' ? body.code.trim() : '';
  if (!isReasonableToken(challenge) || !/^\d{6}$/.test(code)) {
    return jsonError('Invalid verification code.', 400);
  }

  const challengeHash = await hashToken(challenge);
  const now = nowSeconds();
  const row = await env.evil_space
    .prepare(`
      SELECT phone_e164, name, code_hash, device_json, attempts, expires_at, used_at
      FROM customer_phone_otps
      WHERE challenge_hash = ?
      LIMIT 1
    `)
    .bind(challengeHash)
    .first();
  if (!row || row.used_at != null || Number(row.expires_at) <= now) {
    return jsonError('This verification request has expired.', 410);
  }
  if (Number(row.attempts) >= 5) return jsonError('Too many incorrect codes.', 429);

  const candidate = await hashToken(`${challenge}:${code}`);
  if (!constantTimeEqual(candidate, String(row.code_hash))) {
    await env.evil_space
      .prepare('UPDATE customer_phone_otps SET attempts = attempts + 1 WHERE challenge_hash = ?')
      .bind(challengeHash)
      .run();
    return jsonError('Incorrect verification code.', 401);
  }

  const customerId = await getOrCreateCustomerForIdentity(env, {
    provider: 'phone',
    subject: String(row.phone_e164),
    displayValue: String(row.phone_e164),
    name: String(row.name),
    phone: String(row.phone_e164),
  });
  await env.evil_space
    .prepare('UPDATE customer_phone_otps SET used_at = ? WHERE challenge_hash = ?')
    .bind(now, challengeHash)
    .run();

  let device = null;
  try {
    device = sanitizeDeviceProfile(JSON.parse(String(row.device_json ?? '{}')));
  } catch {}
  if (device) await upsertDevice(env, customerId, device);
  const session = await createCustomerSession(env, customerId);
  return json(
    {
      ok: true,
      authenticated: true,
      customer: await customerSnapshot(env, customerId),
      providers: providerConfig(env),
    },
    200,
    { 'Set-Cookie': sessionCookie(session.token, CUSTOMER_SESSION_TTL_SECONDS) },
  );
}

async function handleTelegramStart(request, env) {
  if (!env.TELEGRAM_BOT_TOKEN) return jsonError('Telegram registration is not configured yet.', 503);
  const body = await readJson(request, 16 * 1024);
  const device = sanitizeDeviceProfile(body?.device);
  const token = randomToken(32);
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const expiresAt = now + SIGNUP_TTL_SECONDS;
  await env.evil_space
    .prepare(`
      INSERT INTO customer_signup_tokens
        (token_hash, provider, customer_id, state, payload_json,
         created_at, expires_at, used_at)
      VALUES (?, 'telegram', NULL, 'pending', ?, ?, ?, NULL)
    `)
    .bind(tokenHash, JSON.stringify({ device: device ?? null }), now, expiresAt)
    .run();

  const username = telegramBotUsername(env);
  return json(
    {
      ok: true,
      token,
      url: `https://t.me/${username}?start=signup_${token}`,
      expiresAt,
    },
    201,
  );
}

async function handleTelegramStatus(url, env) {
  const token = url.searchParams.get('token') ?? '';
  if (!isReasonableToken(token)) return jsonError('Registration not found.', 404);
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const row = await env.evil_space
    .prepare(`
      SELECT customer_id, state, payload_json, expires_at, used_at
      FROM customer_signup_tokens
      WHERE token_hash = ? AND provider = 'telegram'
      LIMIT 1
    `)
    .bind(tokenHash)
    .first();
  if (!row) return jsonError('Registration not found.', 404);
  if (Number(row.expires_at) <= now && row.state === 'pending') {
    await env.evil_space
      .prepare("UPDATE customer_signup_tokens SET state = 'expired' WHERE token_hash = ? AND state = 'pending'")
      .bind(tokenHash)
      .run();
    return json({ ok: true, status: 'expired' }, 410);
  }
  if (row.state !== 'completed' || !row.customer_id) {
    return json({ ok: true, status: String(row.state) });
  }

  let payload = {};
  try {
    payload = JSON.parse(String(row.payload_json ?? '{}'));
  } catch {}
  const device = sanitizeDeviceProfile(payload?.device);
  if (device) await upsertDevice(env, Number(row.customer_id), device);
  await env.evil_space
    .prepare("UPDATE customer_signup_tokens SET state = 'used', used_at = ? WHERE token_hash = ? AND state = 'completed'")
    .bind(now, tokenHash)
    .run();
  const session = await createCustomerSession(env, Number(row.customer_id));
  return json(
    {
      ok: true,
      status: 'completed',
      authenticated: true,
      customer: await customerSnapshot(env, Number(row.customer_id)),
      providers: providerConfig(env),
    },
    200,
    { 'Set-Cookie': sessionCookie(session.token, CUSTOMER_SESSION_TTL_SECONDS) },
  );
}

async function handleGoogle(request, env) {
  if (!env.GOOGLE_CLIENT_ID) return jsonError('Google registration is not configured yet.', 503);
  const body = await readJson(request, 32 * 1024);
  const idToken = typeof body?.idToken === 'string' ? body.idToken.trim() : '';
  if (!idToken || idToken.length > 8192) return jsonError('Google credential is required.', 400);

  const response = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
    { headers: { Accept: 'application/json' } },
  );
  const info = await response.json().catch(() => null);
  const now = nowSeconds();
  if (
    !response.ok ||
    !info?.sub ||
    String(info.aud) !== String(env.GOOGLE_CLIENT_ID) ||
    Number(info.exp ?? 0) <= now ||
    String(info.email_verified) !== 'true'
  ) {
    return jsonError('Google sign-in could not be verified.', 401);
  }

  const name = cleanName(info.name) || cleanName(info.given_name) || String(info.email).split('@')[0];
  const customerId = await getOrCreateCustomerForIdentity(env, {
    provider: 'google',
    subject: String(info.sub),
    displayValue: String(info.email ?? ''),
    name,
    email: String(info.email ?? ''),
  });
  const device = sanitizeDeviceProfile(body?.device);
  if (device) await upsertDevice(env, customerId, device);
  const session = await createCustomerSession(env, customerId);
  return json(
    {
      ok: true,
      authenticated: true,
      customer: await customerSnapshot(env, customerId),
      providers: providerConfig(env),
    },
    200,
    { 'Set-Cookie': sessionCookie(session.token, CUSTOMER_SESSION_TTL_SECONDS) },
  );
}

export async function handleCustomerTelegramShortcut(request, env) {
  if (!env.TELEGRAM_WEBHOOK_SECRET || !env.TELEGRAM_BOT_TOKEN) return null;
  const supplied = request.headers.get('X-Telegram-Bot-Api-Secret-Token') ?? '';
  if (!constantTimeEqual(supplied, String(env.TELEGRAM_WEBHOOK_SECRET))) return null;

  let update;
  try {
    update = await request.clone().json();
  } catch {
    return null;
  }
  const message = update?.message;
  const text = typeof message?.text === 'string' ? message.text.trim() : '';
  const match = /^\/start(?:@[A-Za-z0-9_]+)?\s+signup_([A-Za-z0-9_-]{32,80})$/.exec(text);
  if (!match) return null;

  const token = match[1];
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const signup = await env.evil_space
    .prepare(`
      SELECT state, payload_json, expires_at
      FROM customer_signup_tokens
      WHERE token_hash = ? AND provider = 'telegram'
      LIMIT 1
    `)
    .bind(tokenHash)
    .first();
  if (!signup || signup.state !== 'pending' || Number(signup.expires_at) <= now) {
    await telegramApi(env, 'sendMessage', {
      chat_id: message?.chat?.id,
      text: 'This Evil Space registration link has expired. Open evils.space and start again.',
    }).catch(() => null);
    return json({ ok: true });
  }

  const from = message?.from ?? {};
  const userId = Number(from.id ?? 0);
  const chatId = Number(message?.chat?.id ?? 0);
  if (!userId || !chatId) return json({ ok: true });
  const username = cleanTelegramUsername(from.username);
  const fullName = cleanName([from.first_name, from.last_name].filter(Boolean).join(' ')) ||
    (username ? `@${username}` : 'Telegram member');
  const customerId = await getOrCreateCustomerForIdentity(env, {
    provider: 'telegram',
    subject: String(userId),
    displayValue: username ? `@${username}` : String(userId),
    name: fullName,
    telegramUserId: userId,
    telegramChatId: chatId,
    telegramUsername: username,
  });

  let payload = {};
  try {
    payload = JSON.parse(String(signup.payload_json ?? '{}'));
  } catch {}
  payload.telegram = {
    userId,
    chatId,
    username,
    firstName: cleanName(from.first_name),
    lastName: cleanName(from.last_name),
    languageCode: cleanShortText(from.language_code, 16),
  };
  await env.evil_space
    .prepare(`
      UPDATE customer_signup_tokens
      SET customer_id = ?, state = 'completed', payload_json = ?
      WHERE token_hash = ? AND state = 'pending'
    `)
    .bind(customerId, JSON.stringify(payload), tokenHash)
    .run();

  await telegramApi(env, 'sendMessage', {
    chat_id: chatId,
    text: '✅ Evil Space account connected. Return to evils.space — registration will complete automatically.',
  }).catch(() => null);
  return json({ ok: true });
}

async function getOrCreateCustomerForIdentity(env, identity) {
  const existingIdentity = await env.evil_space
    .prepare(`
      SELECT customer_id FROM customer_identities
      WHERE provider = ? AND provider_subject = ?
      LIMIT 1
    `)
    .bind(identity.provider, identity.subject)
    .first();
  if (existingIdentity?.customer_id) {
    const customerId = Number(existingIdentity.customer_id);
    await updateCustomerFromIdentity(env, customerId, identity);
    await touchIdentity(env, customerId, identity);
    return customerId;
  }

  let customerId = null;
  if (identity.provider === 'phone' && identity.phone) {
    const existing = await env.evil_space
      .prepare('SELECT id FROM customers WHERE phone = ? ORDER BY id LIMIT 1')
      .bind(identity.phone)
      .first();
    if (existing?.id) customerId = Number(existing.id);
  } else if (identity.provider === 'telegram' && identity.telegramUserId) {
    const existing = await env.evil_space
      .prepare('SELECT customer_id FROM customer_telegram_links WHERE telegram_user_id = ? LIMIT 1')
      .bind(identity.telegramUserId)
      .first();
    if (existing?.customer_id) customerId = Number(existing.customer_id);
  } else if (identity.provider === 'google' && identity.email) {
    const existing = await env.evil_space
      .prepare('SELECT id FROM customers WHERE lower(email) = lower(?) ORDER BY id LIMIT 1')
      .bind(identity.email)
      .first();
    if (existing?.id) customerId = Number(existing.id);
  }

  const now = nowSeconds();
  if (!customerId) {
    const inserted = await env.evil_space
      .prepare(`
        INSERT INTO customers (name, phone, email, telegram, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `)
      .bind(
        cleanName(identity.name) || 'Evil Space member',
        identity.phone ?? null,
        identity.email ?? null,
        identity.telegramUsername ? `@${identity.telegramUsername}` : null,
        now,
        now,
      )
      .run();
    customerId = Number(inserted.meta?.last_row_id ?? 0);
  }
  if (!customerId) throw new Error('Could not create customer account.');

  await env.evil_space
    .prepare(`
      INSERT INTO customer_identities
        (customer_id, provider, provider_subject, display_value,
         verified_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `)
    .bind(
      customerId,
      identity.provider,
      identity.subject,
      identity.displayValue ?? '',
      now,
      now,
      now,
    )
    .run();
  await updateCustomerFromIdentity(env, customerId, identity);
  return customerId;
}

async function updateCustomerFromIdentity(env, customerId, identity) {
  const now = nowSeconds();
  const name = cleanName(identity.name);
  if (identity.provider === 'phone') {
    await env.evil_space
      .prepare('UPDATE customers SET name = COALESCE(NULLIF(?, \'\'), name), phone = ?, updated_at = ? WHERE id = ?')
      .bind(name, identity.phone, now, customerId)
      .run();
  } else if (identity.provider === 'google') {
    await env.evil_space
      .prepare('UPDATE customers SET name = COALESCE(NULLIF(?, \'\'), name), email = ?, updated_at = ? WHERE id = ?')
      .bind(name, identity.email, now, customerId)
      .run();
  } else if (identity.provider === 'telegram') {
    const telegram = identity.telegramUsername ? `@${identity.telegramUsername}` : String(identity.telegramUserId ?? '');
    await env.evil_space
      .prepare('UPDATE customers SET name = COALESCE(NULLIF(?, \'\'), name), telegram = ?, updated_at = ? WHERE id = ?')
      .bind(name, telegram, now, customerId)
      .run();
    await env.evil_space
      .prepare(`
        INSERT INTO customer_telegram_links
          (customer_id, telegram_user_id, telegram_chat_id, telegram_username, linked_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(customer_id) DO UPDATE SET
          telegram_user_id = excluded.telegram_user_id,
          telegram_chat_id = excluded.telegram_chat_id,
          telegram_username = excluded.telegram_username,
          updated_at = excluded.updated_at
      `)
      .bind(
        customerId,
        identity.telegramUserId,
        identity.telegramChatId,
        identity.telegramUsername ?? '',
        now,
        now,
      )
      .run();
  }
}

async function touchIdentity(env, customerId, identity) {
  await env.evil_space
    .prepare(`
      UPDATE customer_identities
      SET display_value = ?, updated_at = ?
      WHERE customer_id = ? AND provider = ? AND provider_subject = ?
    `)
    .bind(identity.displayValue ?? '', nowSeconds(), customerId, identity.provider, identity.subject)
    .run();
}

async function createCustomerSession(env, customerId) {
  const token = randomToken(32);
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const expiresAt = now + CUSTOMER_SESSION_TTL_SECONDS;
  await env.evil_space.batch([
    env.evil_space.prepare('DELETE FROM customer_sessions WHERE expires_at <= ?').bind(now),
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

async function authenticatedCustomer(request, env) {
  const token = cookieValue(request, CUSTOMER_SESSION_COOKIE);
  if (!isReasonableToken(token)) return null;
  const tokenHash = await hashToken(token);
  return env.evil_space
    .prepare(`
      SELECT s.id AS session_id, c.id, c.name
      FROM customer_sessions s
      JOIN customers c ON c.id = s.customer_id
      WHERE s.token_hash = ? AND s.expires_at > ?
      LIMIT 1
    `)
    .bind(tokenHash, nowSeconds())
    .first();
}

async function authenticatedAdmin(request, env) {
  const token = cookieValue(request, ADMIN_SESSION_COOKIE);
  if (!isReasonableToken(token)) return false;
  const tokenHash = await hashToken(token);
  const row = await env.evil_space
    .prepare(`
      SELECT a.id
      FROM admin_sessions s
      JOIN admins a ON a.id = s.admin_id
      WHERE s.token_hash = ? AND s.expires_at > ? AND a.status = 'approved'
      LIMIT 1
    `)
    .bind(tokenHash, nowSeconds())
    .first();
  return Boolean(row?.id);
}

async function customerSnapshot(env, customerId) {
  const [customer, identities, devices] = await Promise.all([
    env.evil_space
      .prepare('SELECT id, name, phone, email, telegram FROM customers WHERE id = ? LIMIT 1')
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

export function normalizeVietnamPhone(value) {
  if (typeof value !== 'string') return '';
  let text = value.trim().replace(/[\s().-]/g, '');
  if (text.startsWith('00')) text = `+${text.slice(2)}`;
  if (/^0\d{8,10}$/.test(text)) text = `+84${text.slice(1)}`;
  else if (/^84\d{8,10}$/.test(text)) text = `+${text}`;
  return /^\+[1-9]\d{7,14}$/.test(text) ? text : '';
}

export function sanitizeDeviceProfile(value) {
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
  if (new TextEncoder().encode(JSON.stringify(result)).length > MAX_DEVICE_JSON_BYTES) return null;
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

async function sendSms(env, phone, message) {
  const headers = { 'Content-Type': 'application/json', Accept: 'application/json' };
  if (env.SMS_WEBHOOK_TOKEN) headers.Authorization = `Bearer ${env.SMS_WEBHOOK_TOKEN}`;
  const response = await fetch(String(env.SMS_WEBHOOK_URL), {
    method: 'POST',
    headers,
    body: JSON.stringify({ to: phone, message }),
  });
  if (!response.ok) throw new Error(`SMS provider returned ${response.status}.`);
}

async function telegramApi(env, method, payload) {
  const response = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const data = await response.json().catch(() => null);
  if (!response.ok || data?.ok !== true) throw new Error(`Telegram ${method} failed (${response.status}).`);
  return data;
}

function telegramBotUsername(env) {
  const value = cleanShortText(env.TELEGRAM_BOT_USERNAME, 64).replace(/^@/, '');
  return /^[A-Za-z0-9_]{5,64}$/.test(value) ? value : DEFAULT_BOT_USERNAME;
}

function cleanTelegramUsername(value) {
  const text = cleanShortText(value, 64).replace(/^@/, '');
  return /^[A-Za-z0-9_]{1,64}$/.test(text) ? text : '';
}

function cleanName(value) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  return text && text.length <= MAX_NAME_LENGTH ? text : '';
}

function cleanShortText(value, maxLength) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, maxLength);
}

function toBoundedInt(value, min, max) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.min(max, Math.max(min, Math.round(number))) : null;
}

function toBoundedNumber(value, min, max) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.min(max, Math.max(min, number)) : null;
}

function randomDigits(length) {
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return [...bytes].map((byte) => String(byte % 10)).join('');
}

function randomToken(size) {
  const bytes = crypto.getRandomValues(new Uint8Array(size));
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
}

async function hashToken(token) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  let binary = '';
  for (const byte of new Uint8Array(digest)) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
}

function constantTimeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let diff = 0;
  for (let index = 0; index < a.length; index += 1) diff |= a.charCodeAt(index) ^ b.charCodeAt(index);
  return diff === 0;
}

function isReasonableToken(value) {
  return typeof value === 'string' && value.length >= 32 && value.length <= 256 && /^[A-Za-z0-9_-]+$/.test(value);
}

function cookieValue(request, name) {
  const header = request.headers.get('Cookie') ?? '';
  for (const chunk of header.split(';')) {
    const [key, ...rest] = chunk.trim().split('=');
    if (key === name) return decodeURIComponent(rest.join('='));
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
