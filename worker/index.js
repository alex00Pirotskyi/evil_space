const encoder = new TextEncoder();

const OWNER_EMAIL = 'evilssspace79@gmail.com';
const FROM_EMAIL = 'admin@evils.space';
const SESSION_COOKIE = '__Host-evil_admin_session';
const SESSION_TTL_SECONDS = 60 * 60 * 24 * 14;
const APPROVAL_TTL_SECONDS = 60 * 60 * 24;
const PBKDF2_ITERATIONS = 50000;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (!url.pathname.startsWith('/api/')) {
      return new Response('Not found', { status: 404 });
    }

    try {
      if (request.method === 'GET' && url.pathname === '/api/health') {
        return json({ ok: true, service: 'evil-space' });
      }

      if (request.method === 'GET' && url.pathname === '/api/admin/session') {
        return handleSession(request, env);
      }

      if (request.method === 'POST' && url.pathname === '/api/admin/register') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleRegister(request, env, url);
      }

      if (request.method === 'POST' && url.pathname === '/api/admin/login') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleLogin(request, env);
      }

      if (request.method === 'POST' && url.pathname === '/api/admin/logout') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleLogout(request, env);
      }

      if (request.method === 'GET' && url.pathname === '/api/admin/review') {
        return handleReview(url, env);
      }

      if (request.method === 'POST' && url.pathname === '/api/admin/decision') {
        if (!isSameOrigin(request, url)) {
          return htmlMessage('Request blocked', 'Invalid origin.', 403);
        }
        return handleDecision(request, env);
      }

      if (request.method === 'GET' && url.pathname === '/api/admin/admins') {
        return handleAdmins(request, env);
      }

      if (request.method === 'POST' && url.pathname === '/api/admin/delete') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleDeleteAdmin(request, env);
      }

      return jsonError('Not found.', 404);
    } catch (error) {
      console.error('Unhandled API error', error);
      return jsonError('Server error. Please try again.', 500);
    }
  },
};

async function handleSession(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return json({ ok: true, authenticated: false });

  return json({
    ok: true,
    authenticated: true,
    email: session.email,
  });
}

async function handleRegister(request, env, url) {
  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const email = normalizeEmail(body.email);
  const password = typeof body.password === 'string' ? body.password : '';

  const validation = validateCredentials(email, password);
  if (validation) return jsonError(validation, 400);

  const now = nowSeconds();
  const existing = await env.evil_space
    .prepare('SELECT id, status, created_at FROM admins WHERE email = ?')
    .bind(email)
    .first();

  if (existing?.status === 'approved') {
    return jsonError('This admin is already approved. Sign in instead.', 409);
  }

  if (existing?.status === 'pending' && Number(existing.created_at) > now - 60) {
    return jsonError(
      'An approval email was just sent. Please wait a minute before retrying.',
      429,
    );
  }

  const salt = randomBase64(16);
  const passwordHash = await hashPassword(password, salt);
  const approvalToken = randomToken(32);
  const approvalTokenHash = await hashToken(approvalToken);
  const approvalExpiresAt = now + APPROVAL_TTL_SECONDS;

  if (existing) {
    await env.evil_space
      .prepare(`
        UPDATE admins
        SET password_hash = ?, password_salt = ?, status = 'pending',
            approval_token_hash = ?, approval_expires_at = ?,
            created_at = ?, approved_at = NULL
        WHERE id = ?
      `)
      .bind(
        passwordHash,
        salt,
        approvalTokenHash,
        approvalExpiresAt,
        now,
        existing.id,
      )
      .run();
  } else {
    await env.evil_space
      .prepare(`
        INSERT INTO admins
          (email, password_hash, password_salt, status,
           approval_token_hash, approval_expires_at, created_at)
        VALUES (?, ?, ?, 'pending', ?, ?, ?)
      `)
      .bind(
        email,
        passwordHash,
        salt,
        approvalTokenHash,
        approvalExpiresAt,
        now,
      )
      .run();
  }

  const reviewUrl = `${url.origin}/api/admin/review?token=${encodeURIComponent(approvalToken)}`;

  try {
    await env.ADMIN_EMAIL.send({
      to: OWNER_EMAIL,
      from: FROM_EMAIL,
      subject: `Approve Evil Space admin: ${email}`,
      text: [
        'A new Evil Space admin account is requesting access.',
        '',
        `Email: ${email}`,
        '',
        'Approve this admin:',
        reviewUrl,
        '',
        'The page has one APPROVE ADMIN button. This link expires in 24 hours.',
      ].join('\n'),
      html: `
        <h2>Evil Space admin request</h2>
        <p><strong>Email:</strong> ${escapeHtml(email)}</p>
        <p><a href="${escapeHtml(reviewUrl)}"><strong>APPROVE ADMIN</strong></a></p>
        <p>This link expires in 24 hours.</p>
      `,
    });
  } catch (error) {
    console.error('Admin approval email failed', error);
    await env.evil_space
      .prepare("DELETE FROM admins WHERE email = ? AND status = 'pending'")
      .bind(email)
      .run();
    return jsonError(
      'Could not send the approval email. Verify the owner destination and evils.space sender domain in Cloudflare Email Service.',
      503,
    );
  }

  return json(
    {
      ok: true,
      message: `Approval request sent to ${OWNER_EMAIL}.`,
    },
    202,
  );
}

async function handleLogin(request, env) {
  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const email = normalizeEmail(body.email);
  const password = typeof body.password === 'string' ? body.password : '';

  const validation = validateCredentials(email, password);
  if (validation) return jsonError('Invalid email or password.', 401);

  const admin = await env.evil_space
    .prepare(`
      SELECT id, email, password_hash, password_salt, status
      FROM admins
      WHERE email = ?
    `)
    .bind(email)
    .first();

  if (!admin) return jsonError('Invalid email or password.', 401);

  if (admin.status === 'pending') {
    return jsonError('This account is waiting for owner approval.', 403);
  }

  if (admin.status !== 'approved') {
    return jsonError('This admin request was not approved.', 403);
  }

  const candidateHash = await hashPassword(password, admin.password_salt);
  if (!timingSafeEqual(candidateHash, admin.password_hash)) {
    return jsonError('Invalid email or password.', 401);
  }

  const token = randomToken(32);
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const expiresAt = now + SESSION_TTL_SECONDS;

  await env.evil_space.batch([
    env.evil_space
      .prepare('DELETE FROM admin_sessions WHERE expires_at <= ?')
      .bind(now),
    env.evil_space
      .prepare(`
        INSERT INTO admin_sessions (admin_id, token_hash, created_at, expires_at)
        VALUES (?, ?, ?, ?)
      `)
      .bind(admin.id, tokenHash, now, expiresAt),
  ]);

  return json(
    {
      ok: true,
      authenticated: true,
      email: admin.email,
    },
    200,
    {
      'Set-Cookie': sessionCookie(token, SESSION_TTL_SECONDS),
    },
  );
}

async function handleLogout(request, env) {
  const token = cookieValue(request, SESSION_COOKIE);

  if (token) {
    const tokenHash = await hashToken(token);
    await env.evil_space
      .prepare('DELETE FROM admin_sessions WHERE token_hash = ?')
      .bind(tokenHash)
      .run();
  }

  return json(
    { ok: true },
    200,
    {
      'Set-Cookie': sessionCookie('', 0),
    },
  );
}

async function handleReview(url, env) {
  const token = url.searchParams.get('token') ?? '';
  if (!isReasonableToken(token)) {
    return htmlMessage('Invalid request', 'This approval link is invalid.', 400);
  }

  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const admin = await env.evil_space
    .prepare(`
      SELECT email, approval_expires_at
      FROM admins
      WHERE approval_token_hash = ? AND status = 'pending'
    `)
    .bind(tokenHash)
    .first();

  if (!admin) {
    return htmlMessage(
      'Request unavailable',
      'This request was already handled or the link is invalid.',
      404,
    );
  }

  if (Number(admin.approval_expires_at) <= now) {
    return htmlMessage(
      'Request expired',
      'This approval link has expired. Ask the admin to register again.',
      410,
    );
  }

  const safeEmail = escapeHtml(admin.email);
  const safeToken = escapeHtml(token);

  return new Response(
    `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Approve Evil Space admin</title>
<style>
body{margin:0;background:#f2f0e8;color:#1c1c1a;font-family:Georgia,serif}
main{max-width:620px;margin:64px auto;padding:24px}
small{font-family:"Courier New",monospace;font-weight:700;letter-spacing:.08em}
h1{font-weight:400;font-size:42px;line-height:1;margin:18px 0}
.card{border-top:1px solid #1c1c1a;border-bottom:1px solid #1c1c1a;padding:24px 0;margin:28px 0}
.email{font-family:"Courier New",monospace;font-weight:700;word-break:break-all}
button{width:100%;min-height:54px;padding:0 18px;border:1px solid #1c1c1a;background:#1c1c1a;color:#f8f6ef;font:700 13px "Courier New",monospace;cursor:pointer}
</style>
</head>
<body>
<main>
<small>EVIL SPACE / ADMIN</small>
<h1>Approve admin.</h1>
<div class="card">
<p class="email">${safeEmail}</p>
</div>
<form method="post" action="/api/admin/decision">
<input type="hidden" name="token" value="${safeToken}">
<input type="hidden" name="decision" value="approve">
<button type="submit">APPROVE ADMIN</button>
</form>
</main>
</body>
</html>`,
    { status: 200, headers: htmlHeaders() },
  );
}

async function handleDecision(request, env) {
  const form = await request.formData();
  const token = String(form.get('token') ?? '');
  const decision = String(form.get('decision') ?? '');

  if (!isReasonableToken(token) || decision !== 'approve') {
    return htmlMessage('Invalid request', 'The approval request is invalid.', 400);
  }

  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  const admin = await env.evil_space
    .prepare(`
      SELECT id, email, approval_expires_at
      FROM admins
      WHERE approval_token_hash = ? AND status = 'pending'
    `)
    .bind(tokenHash)
    .first();

  if (!admin) {
    return htmlMessage(
      'Request unavailable',
      'This request was already handled or the link is invalid.',
      404,
    );
  }

  if (Number(admin.approval_expires_at) <= now) {
    return htmlMessage('Request expired', 'This approval link has expired.', 410);
  }

  await env.evil_space
    .prepare(`
      UPDATE admins
      SET status = 'approved', approved_at = ?,
          approval_token_hash = NULL, approval_expires_at = NULL
      WHERE id = ?
    `)
    .bind(now, admin.id)
    .run();

  return htmlMessage(
    'Admin approved',
    `${admin.email} can now sign in at /admin.`,
    200,
    '/admin',
  );
}

async function handleAdmins(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);

  const result = await env.evil_space
    .prepare(`
      SELECT email, status, created_at, approved_at
      FROM admins
      ORDER BY
        CASE status WHEN 'approved' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END,
        email COLLATE NOCASE
    `)
    .all();

  return json({
    ok: true,
    admins: result.results ?? [],
    currentEmail: session.email,
  });
}

async function handleDeleteAdmin(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);

  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const email = normalizeEmail(body.email);
  const superPassword =
    typeof body.superPassword === 'string' ? body.superPassword : '';

  if (!email) return jsonError('Admin email is required.', 400);

  if (
    typeof env.SUPER_ADMIN_PASSWORD !== 'string' ||
    env.SUPER_ADMIN_PASSWORD.length === 0
  ) {
    return jsonError('Super password is not configured on the Worker.', 503);
  }

  if (!timingSafeEqual(superPassword, env.SUPER_ADMIN_PASSWORD)) {
    return jsonError('Wrong super password.', 403);
  }

  const admin = await env.evil_space
    .prepare('SELECT id, email FROM admins WHERE email = ?')
    .bind(email)
    .first();

  if (!admin) return jsonError('Admin not found.', 404);

  await env.evil_space.prepare('DELETE FROM admins WHERE id = ?').bind(admin.id).run();

  const deletedSelf = normalizeEmail(session.email) === normalizeEmail(admin.email);

  return json(
    {
      ok: true,
      email: admin.email,
      deletedSelf,
    },
    200,
    deletedSelf ? { 'Set-Cookie': sessionCookie('', 0) } : {},
  );
}

async function authenticatedAdmin(request, env) {
  const token = cookieValue(request, SESSION_COOKIE);
  if (!token) return null;

  const tokenHash = await hashToken(token);
  const now = nowSeconds();

  const session = await env.evil_space
    .prepare(`
      SELECT a.id, a.email, s.expires_at
      FROM admin_sessions s
      JOIN admins a ON a.id = s.admin_id
      WHERE s.token_hash = ? AND s.expires_at > ? AND a.status = 'approved'
    `)
    .bind(tokenHash, now)
    .first();

  return session ?? null;
}

function validateCredentials(email, password) {
  if (
    !email ||
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    return 'Enter a valid email address.';
  }
  if (password.length < 4) return 'Password must be at least 4 characters.';
  if (password.length > 200) return 'Password is too long.';
  return null;
}

function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
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

async function hashPassword(password, saltBase64) {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );

  const bits = await crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      hash: 'SHA-256',
      iterations: PBKDF2_ITERATIONS,
      salt: fromBase64(saltBase64),
    },
    key,
    256,
  );

  return toBase64(new Uint8Array(bits));
}

async function hashToken(token) {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(token));
  return toBase64Url(new Uint8Array(digest));
}

function randomToken(byteLength) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return toBase64Url(bytes);
}

function randomBase64(byteLength) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return toBase64(bytes);
}

function toBase64(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function toBase64Url(bytes) {
  return toBase64(bytes)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/g, '');
}

function fromBase64(value) {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function timingSafeEqual(left, right) {
  if (
    typeof left !== 'string' ||
    typeof right !== 'string' ||
    left.length !== right.length
  ) {
    return false;
  }

  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
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

function sessionCookie(token, maxAge) {
  return `${SESSION_COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${maxAge}`;
}

function isSameOrigin(request, url) {
  const origin = request.headers.get('origin');
  return origin === null || origin === url.origin;
}

function isReasonableToken(token) {
  return (
    token.length >= 32 &&
    token.length <= 128 &&
    /^[A-Za-z0-9_-]+$/.test(token)
  );
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
      ...extraHeaders,
    },
  });
}

function jsonError(message, status) {
  return json({ ok: false, error: message }, status);
}

function htmlHeaders() {
  return {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Security-Policy':
      "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
  };
}

function htmlMessage(title, message, status = 200, link = null) {
  const safeTitle = escapeHtml(title);
  const safeMessage = escapeHtml(message);
  const action = link
    ? `<p><a href="${escapeHtml(link)}">OPEN ADMIN</a></p>`
    : '';

  return new Response(
    `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${safeTitle}</title>
<style>
body{margin:0;background:#f2f0e8;color:#1c1c1a;font-family:Georgia,serif}
main{max-width:620px;margin:64px auto;padding:24px}
small,a{font-family:"Courier New",monospace;font-weight:700;letter-spacing:.06em}
h1{font-weight:400;font-size:42px;line-height:1;margin:18px 0}
p{font-size:19px;line-height:1.45}
a{color:#1c1c1a}
</style>
</head>
<body>
<main>
<small>EVIL SPACE / ADMIN</small>
<h1>${safeTitle}</h1>
<p>${safeMessage}</p>
${action}
</main>
</body>
</html>`,
    { status, headers: htmlHeaders() },
  );
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}
