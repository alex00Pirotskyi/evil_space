const encoder = new TextEncoder();

export default {
  review,
  decision,
};

async function review(url, env) {
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
    return htmlMessage('Request unavailable', 'This request was already handled.', 404);
  }
  if (Number(admin.approval_expires_at) <= now) {
    return htmlMessage('Request expired', 'Ask the admin to register again.', 410);
  }

  const safeEmail = escapeHtml(admin.email);
  const safeToken = escapeHtml(token);
  return new Response(
    `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Review Evil Space admin</title><style>
body{margin:0;background:#f2f0e8;color:#1c1c1a;font-family:Georgia,serif}main{max-width:620px;margin:64px auto;padding:24px}small{font-family:"Courier New",monospace;font-weight:700;letter-spacing:.08em}h1{font-weight:400;font-size:42px;line-height:1;margin:18px 0}.card{border-top:1px solid #1c1c1a;border-bottom:1px solid #1c1c1a;padding:24px 0;margin:28px 0}.email{font-family:"Courier New",monospace;font-weight:700;word-break:break-all}.actions{display:grid;grid-template-columns:1fr 1fr;gap:12px}button{width:100%;min-height:54px;border:1px solid #1c1c1a;font:700 13px "Courier New",monospace;cursor:pointer}.approve{background:#1c1c1a;color:#f8f6ef}.reject{background:transparent;color:#1c1c1a}@media(max-width:520px){.actions{grid-template-columns:1fr}}
</style></head><body><main><small>EVIL SPACE / ADMIN</small><h1>Review admin.</h1><div class="card"><p class="email">${safeEmail}</p></div><div class="actions"><form method="post" action="/api/admin/decision"><input type="hidden" name="token" value="${safeToken}"><input type="hidden" name="decision" value="approve"><button class="approve" type="submit">APPROVE ADMIN</button></form><form method="post" action="/api/admin/decision"><input type="hidden" name="token" value="${safeToken}"><input type="hidden" name="decision" value="reject"><button class="reject" type="submit">REJECT ADMIN</button></form></div></main></body></html>`,
    { status: 200, headers: htmlHeaders() },
  );
}

async function decision(request, env) {
  const url = new URL(request.url);
  const origin = request.headers.get('origin');
  if (origin !== null && origin !== url.origin) {
    return htmlMessage('Invalid request', 'The approval request has an invalid origin.', 403);
  }

  let form;
  try {
    form = await request.formData();
  } catch {
    return htmlMessage('Invalid request', 'The approval request is invalid.', 400);
  }

  const token = String(form.get('token') ?? '');
  const choice = String(form.get('decision') ?? '');
  if (!isReasonableToken(token) || (choice !== 'approve' && choice !== 'reject')) {
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

  if (!admin) return htmlMessage('Request unavailable', 'Already handled.', 404);
  if (Number(admin.approval_expires_at) <= now) {
    return htmlMessage('Request expired', 'This approval link has expired.', 410);
  }

  if (choice === 'approve') {
    await env.evil_space
      .prepare(`
        UPDATE admins
        SET status = 'approved', approved_at = ?,
            approval_token_hash = NULL, approval_expires_at = NULL
        WHERE id = ? AND status = 'pending'
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

  await env.evil_space
    .prepare(`
      UPDATE admins
      SET status = 'rejected', approved_at = NULL,
          approval_token_hash = NULL, approval_expires_at = NULL
      WHERE id = ? AND status = 'pending'
    `)
    .bind(admin.id)
    .run();
  return htmlMessage(
    'Admin rejected',
    `${admin.email} was not granted access.`,
    200,
    '/',
  );
}

async function hashToken(token) {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(token));
  return toBase64Url(new Uint8Array(digest));
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
  return token.length >= 32 && token.length <= 128 && /^[A-Za-z0-9_-]+$/.test(token);
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
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
  const action = link ? `<p><a href="${escapeHtml(link)}">CONTINUE</a></p>` : '';
  return new Response(
    `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${safeTitle}</title><style>body{margin:0;background:#f2f0e8;color:#1c1c1a;font-family:Georgia,serif}main{max-width:620px;margin:64px auto;padding:24px}small,a{font-family:"Courier New",monospace;font-weight:700;letter-spacing:.06em}h1{font-weight:400;font-size:42px;line-height:1;margin:18px 0}p{font-size:19px;line-height:1.45}a{color:#1c1c1a}</style></head><body><main><small>EVIL SPACE / ADMIN</small><h1>${safeTitle}</h1><p>${safeMessage}</p>${action}</main></body></html>`,
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
