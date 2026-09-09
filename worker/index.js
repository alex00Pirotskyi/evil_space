import { serviceDayForOffset, serviceDayFromDateKey } from './booking_rules.js';
import {
  DEFAULT_DAY_PASS_VND,
  listPromotions,
  pricingSnapshot,
  resolvePricing,
} from './pricing.js';
const encoder = new TextEncoder();

const OWNER_EMAIL = 'evilssspace79@gmail.com';
const FROM_EMAIL = 'admin@evils.space';
const SESSION_COOKIE = '__Host-evil_admin_session';
const SESSION_TTL_SECONDS = 60 * 60 * 24 * 14;
const APPROVAL_TTL_SECONDS = 60 * 60 * 24;
const PBKDF2_ITERATIONS = 50000;
const MAX_NAME_LENGTH = 100;
const MAX_PURCHASE_LENGTH = 180;
const MAX_CONTACT_LENGTH = 160;
const MAX_NOTES_LENGTH = 600;

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
      if (request.method === 'GET' && url.pathname === '/api/public/status') {
        return handlePublicStatus(env);
      }
      if (request.method === 'POST' && url.pathname === '/api/public/book') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handlePublicBooking(request, env);
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
        return handleDecision(request, env);
      }
      if (request.method === 'GET' && url.pathname === '/api/admin/admins') {
        return handleAdmins(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/delete') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleDeleteAdmin(request, env);
      }
      if (request.method === 'GET' && url.pathname === '/api/admin/operations') {
        return handleOperations(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/pricing') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handlePricingUpdate(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/promotions') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleCreatePromotion(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/promotions/toggle') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleTogglePromotion(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/promotions/delete') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleDeletePromotion(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/day-pass') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleDayPass(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/month-new') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleNewMonth(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/month-active') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleActiveMonth(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/booking/accept') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleAcceptBooking(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/customers/update') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleUpdateCustomer(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/customers/delete') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleDeleteCustomer(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/purchases') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleAddPurchase(request, env);
      }
      if (
        request.method === 'POST' &&
        url.pathname === '/api/admin/purchases/bought'
      ) {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handlePurchaseBought(request, env);
      }

      return jsonError('Not found.', 404);
    } catch (error) {
      console.error('Unhandled API error', error);
      return jsonError('Server error. Please try again.', 500);
    }
  },
};

async function handlePublicStatus(env) {
  const now = nowSeconds();
  const { start, end } = nhaTrangDayBounds(now);
  const [state, occupied] = await Promise.all([
    env.evil_space
      .prepare('SELECT total_desks FROM site_state WHERE id = 1')
      .first(),
    env.evil_space
      .prepare(`
        SELECT COUNT(*) AS count
        FROM visits
        WHERE created_at >= ? AND created_at < ?
      `)
      .bind(start, end)
      .first(),
  ]);

  const total = Math.max(1, Number(state?.total_desks ?? 10));
  const used = Math.min(total, Math.max(0, Number(occupied?.count ?? 0)));
  return json({
    ok: true,
    status: {
      total,
      occupied: used,
      free: Math.max(0, total - used),
      updated: new Date().toISOString(),
    },
  });
}

async function handlePublicBooking(request, env) {
  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const name = cleanText(body.name, MAX_NAME_LENGTH);
  const contactType = body.contactType === 'phone' || body.contactType === 'telegram'
    ? body.contactType
    : '';
  const contactValue = cleanText(body.contactValue, MAX_CONTACT_LENGTH);

  if (!name) return jsonError('Name is required.', 400);
  if (!contactType || contactValue.length < 3) {
    return jsonError('Phone or Telegram is required.', 400);
  }

  const now = nowSeconds();
  const duplicate = await env.evil_space
    .prepare(`
      SELECT id
      FROM booking_requests
      WHERE status = 'new'
        AND contact_type = ?
        AND lower(contact_value) = lower(?)
        AND created_at >= ?
      LIMIT 1
    `)
    .bind(contactType, contactValue, now - 15 * 60)
    .first();

  if (!duplicate) {
    await env.evil_space
      .prepare(`
        INSERT INTO booking_requests
          (name, contact_type, contact_value, status, created_at)
        VALUES (?, ?, ?, 'new', ?)
      `)
      .bind(name, contactType, contactValue, now)
      .run();
  }

  return json({
    ok: true,
    message: 'Desk request sent. Evil Space staff can now see it.',
  }, duplicate ? 200 : 201);
}

async function handleSession(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return json({ ok: true, authenticated: false });
  return json({ ok: true, authenticated: true, email: session.email });
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
    return jsonError('An approval email was just sent. Please wait a minute.', 429);
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
        'This link expires in 24 hours.',
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
    return jsonError('Could not send the approval email.', 503);
  }

  return json({ ok: true, message: 'Approval request sent.' }, 202);
}

async function handleLogin(request, env) {
  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const email = normalizeEmail(body.email);
  const password = typeof body.password === 'string' ? body.password : '';
  if (validateCredentials(email, password)) {
    return jsonError('Invalid email or password.', 401);
  }

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
    { ok: true, authenticated: true, email: admin.email },
    200,
    { 'Set-Cookie': sessionCookie(token, SESSION_TTL_SECONDS) },
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
  return json({ ok: true }, 200, { 'Set-Cookie': sessionCookie('', 0) });
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
<title>Approve Evil Space admin</title><style>
body{margin:0;background:#f2f0e8;color:#1c1c1a;font-family:Georgia,serif}main{max-width:620px;margin:64px auto;padding:24px}small{font-family:"Courier New",monospace;font-weight:700;letter-spacing:.08em}h1{font-weight:400;font-size:42px;line-height:1;margin:18px 0}.card{border-top:1px solid #1c1c1a;border-bottom:1px solid #1c1c1a;padding:24px 0;margin:28px 0}.email{font-family:"Courier New",monospace;font-weight:700;word-break:break-all}button{width:100%;min-height:54px;border:1px solid #1c1c1a;background:#1c1c1a;color:#f8f6ef;font:700 13px "Courier New",monospace;cursor:pointer}
</style></head><body><main><small>EVIL SPACE / ADMIN</small><h1>Approve admin.</h1><div class="card"><p class="email">${safeEmail}</p></div><form method="post" action="/api/admin/decision"><input type="hidden" name="token" value="${safeToken}"><input type="hidden" name="decision" value="approve"><button type="submit">APPROVE ADMIN</button></form></main></body></html>`,
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

  if (!admin) return htmlMessage('Request unavailable', 'Already handled.', 404);
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

  return json({ ok: true, admins: result.results ?? [] });
}

async function handleDeleteAdmin(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);

  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const email = normalizeEmail(body.email);
  const superPassword = typeof body.superPassword === 'string' ? body.superPassword : '';
  if (!email) return jsonError('Admin email is required.', 400);
  if (typeof env.SUPER_ADMIN_PASSWORD !== 'string' || !env.SUPER_ADMIN_PASSWORD) {
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
    { ok: true, email: admin.email, deletedSelf },
    200,
    deletedSelf ? { 'Set-Cookie': sessionCookie('', 0) } : {},
  );
}

async function handleOperations(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  return json({ ok: true, snapshot: await operationsSnapshot(env) });
}

async function handlePricingUpdate(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const dayPassVnd = toPriceInt(body.dayPassVnd);
  const monthPassVnd = toPriceInt(body.monthPassVnd);
  const lockerMonthVnd = toPriceInt(body.lockerMonthVnd);
  if (!dayPassVnd || !monthPassVnd || !lockerMonthVnd) {
    return jsonError('All base prices must be positive VND amounts.', 400);
  }

  await env.evil_space
    .prepare(`
      UPDATE pricing_settings
      SET day_pass_vnd = ?, month_pass_vnd = ?, locker_month_vnd = ?,
          updated_at = ?, updated_by_email = ?
      WHERE id = 1
    `)
    .bind(dayPassVnd, monthPassVnd, lockerMonthVnd, nowSeconds(), session.email)
    .run();
  return json({ ok: true, snapshot: await operationsSnapshot(env) });
}

async function handleCreatePromotion(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const description = cleanText(body.description, 240);
  const startDay = serviceDayFromDateKey(body.startDate);
  const endDay = serviceDayFromDateKey(body.endDate);
  if (!description) return jsonError('Promotion description is required.', 400);
  if (startDay == null || endDay == null || endDay < startDay) {
    return jsonError('Choose a valid promotion date range.', 400);
  }

  const hasStartTime = typeof body.startTime === 'string' && body.startTime.trim() !== '';
  const hasEndTime = typeof body.endTime === 'string' && body.endTime.trim() !== '';
  if (hasStartTime !== hasEndTime) {
    return jsonError('Set both start and end time, or leave both empty.', 400);
  }
  const startMinute = hasStartTime ? parseTimeMinute(body.startTime) : null;
  const endMinute = hasEndTime ? parseTimeMinute(body.endTime) : null;
  if (hasStartTime && (startMinute == null || endMinute == null || endMinute <= startMinute)) {
    return jsonError('Choose a valid daily time window.', 400);
  }

  const dayPassVnd = optionalPriceInt(body.dayPassVnd);
  const monthPassVnd = optionalPriceInt(body.monthPassVnd);
  const lockerMonthVnd = optionalPriceInt(body.lockerMonthVnd);
  if (dayPassVnd === false || monthPassVnd === false || lockerMonthVnd === false) {
    return jsonError('Promotion prices must be positive VND amounts.', 400);
  }
  if (dayPassVnd == null && monthPassVnd == null && lockerMonthVnd == null) {
    return jsonError('Set at least one promotional price.', 400);
  }

  await env.evil_space
    .prepare(`
      INSERT INTO promotions
        (description, start_day, end_day, start_minute, end_minute,
         day_pass_vnd, month_pass_vnd, locker_month_vnd, enabled,
         created_at, created_by_email)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    `)
    .bind(
      description,
      startDay,
      endDay,
      startMinute,
      endMinute,
      dayPassVnd,
      monthPassVnd,
      lockerMonthVnd,
      nowSeconds(),
      session.email,
    )
    .run();
  return json({ ok: true, snapshot: await operationsSnapshot(env) }, 201);
}

async function handleTogglePromotion(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const id = toPositiveInt(body?.id);
  if (!id || typeof body?.enabled !== 'boolean') {
    return jsonError('Promotion and enabled state are required.', 400);
  }
  const result = await env.evil_space
    .prepare('UPDATE promotions SET enabled = ? WHERE id = ?')
    .bind(body.enabled ? 1 : 0, id)
    .run();
  if (!result.meta?.changes) return jsonError('Promotion not found.', 404);
  return json({ ok: true, snapshot: await operationsSnapshot(env) });
}

async function handleDeletePromotion(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const id = toPositiveInt(body?.id);
  if (!id) return jsonError('Promotion is required.', 400);
  const result = await env.evil_space.prepare('DELETE FROM promotions WHERE id = ?').bind(id).run();
  if (!result.meta?.changes) return jsonError('Promotion not found.', 404);
  return json({ ok: true, snapshot: await operationsSnapshot(env) });
}

async function handleDayPass(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const name = cleanText(body?.name, MAX_NAME_LENGTH);
  if (!name) return jsonError('Name is required.', 400);

  const now = nowSeconds();
  const customer = await ensureCustomer(env, { name });
  const pricing = await resolvePricing(env, serviceDayForOffset(0, now), now);
  await env.evil_space
    .prepare(`
      INSERT INTO visits
        (name, kind, membership_id, amount, created_at, created_by_email, customer_id)
      VALUES (?, 'day', NULL, ?, ?, ?, ?)
    `)
    .bind(name, pricing.dayPassVnd, now, session.email, customer.id)
    .run();

  return json({ ok: true, snapshot: await operationsSnapshot(env) }, 201);
}

async function handleNewMonth(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const name = cleanText(body?.name, MAX_NAME_LENGTH);
  if (!name) return jsonError('Name is required.', 400);

  const now = nowSeconds();
  const customer = await ensureCustomer(env, { name });
  const existing = await env.evil_space
    .prepare(`
      SELECT id FROM memberships
      WHERE customer_id = ? AND expires_at > ?
      LIMIT 1
    `)
    .bind(customer.id, now)
    .first();
  if (existing) {
    return jsonError('This customer already has an active month pass.', 409);
  }

  const expiresAt = addCalendarMonth(now);
  const pricing = await resolvePricing(env, serviceDayForOffset(0, now), now);
  const membership = await env.evil_space
    .prepare(`
      INSERT INTO memberships (name, starts_at, expires_at, created_at, customer_id)
      VALUES (?, ?, ?, ?, ?)
      RETURNING id
    `)
    .bind(name, now, expiresAt, now, customer.id)
    .first();

  await env.evil_space
    .prepare(`
      INSERT INTO visits
        (name, kind, membership_id, amount, created_at, created_by_email, customer_id)
      VALUES (?, 'month', ?, ?, ?, ?, ?)
    `)
    .bind(name, membership.id, pricing.monthPassVnd, now, session.email, customer.id)
    .run();

  return json({ ok: true, snapshot: await operationsSnapshot(env) }, 201);
}

async function handleActiveMonth(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const membershipId = toPositiveInt(body?.membershipId);
  if (!membershipId) return jsonError('Active membership is required.', 400);

  const now = nowSeconds();
  const membership = await env.evil_space
    .prepare(`
      SELECT id, name, customer_id FROM memberships
      WHERE id = ? AND expires_at > ?
    `)
    .bind(membershipId, now)
    .first();
  if (!membership) return jsonError('This membership is expired or missing.', 404);

  const { start, end } = nhaTrangDayBounds(now);
  const already = await env.evil_space
    .prepare(`
      SELECT id FROM visits
      WHERE membership_id = ? AND created_at >= ? AND created_at < ?
      LIMIT 1
    `)
    .bind(membership.id, start, end)
    .first();
  if (already) return jsonError('This customer is already checked in today.', 409);

  await env.evil_space
    .prepare(`
      INSERT INTO visits
        (name, kind, membership_id, amount, created_at, created_by_email, customer_id)
      VALUES (?, 'month', ?, 0, ?, ?, ?)
    `)
    .bind(membership.name, membership.id, now, session.email, membership.customer_id)
    .run();

  return json({ ok: true, snapshot: await operationsSnapshot(env) }, 201);
}

async function handleAcceptBooking(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const bookingId = toPositiveInt(body?.id);
  if (!bookingId) return jsonError('Booking request is required.', 400);

  const booking = await env.evil_space
    .prepare(`
      SELECT id, name, contact_type, contact_value
      FROM booking_requests
      WHERE id = ? AND status = 'new'
    `)
    .bind(bookingId)
    .first();
  if (!booking) return jsonError('Booking request was already handled.', 409);

  const customerData = {
    name: booking.name,
    phone: booking.contact_type === 'phone' ? booking.contact_value : '',
    telegram: booking.contact_type === 'telegram' ? booking.contact_value : '',
  };
  const customer = await ensureCustomer(env, customerData);
  const now = nowSeconds();
  const { start, end } = nhaTrangDayBounds(now);
  const already = await env.evil_space
    .prepare(`
      SELECT id FROM visits
      WHERE customer_id = ? AND created_at >= ? AND created_at < ?
      LIMIT 1
    `)
    .bind(customer.id, start, end)
    .first();

  if (!already) {
    await env.evil_space
      .prepare(`
        INSERT INTO visits
          (name, kind, membership_id, amount, created_at, created_by_email, customer_id)
        VALUES (?, 'day', NULL, ?, ?, ?, ?)
      `)
      .bind(booking.name, DEFAULT_DAY_PASS_VND, now, session.email, customer.id)
      .run();
  }

  await env.evil_space
    .prepare(`
      UPDATE booking_requests
      SET status = 'accepted', handled_at = ?, handled_by_email = ?, customer_id = ?
      WHERE id = ? AND status = 'new'
    `)
    .bind(now, session.email, customer.id, booking.id)
    .run();

  return json({ ok: true, snapshot: await operationsSnapshot(env) });
}

async function handleUpdateCustomer(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  if (!body) return jsonError('Invalid request.', 400);

  const id = toPositiveInt(body.id);
  const name = cleanText(body.name, MAX_NAME_LENGTH);
  const phone = cleanOptionalText(body.phone, MAX_CONTACT_LENGTH);
  const email = cleanOptionalText(body.email, MAX_CONTACT_LENGTH);
  const telegram = cleanOptionalText(body.telegram, MAX_CONTACT_LENGTH);
  const contactOther = cleanOptionalText(body.contactOther, MAX_CONTACT_LENGTH);
  const notes = cleanOptionalText(body.notes, MAX_NOTES_LENGTH);

  if (!id || !name) return jsonError('Customer and name are required.', 400);
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return jsonError('Email address is invalid.', 400);
  }

  const result = await env.evil_space
    .prepare(`
      UPDATE customers
      SET name = ?, phone = ?, email = ?, telegram = ?, contact_other = ?,
          notes = ?, updated_at = ?
      WHERE id = ?
    `)
    .bind(name, phone, email, telegram, contactOther, notes, nowSeconds(), id)
    .run();
  if (!result.meta?.changes) return jsonError('Customer not found.', 404);

  await env.evil_space.batch([
    env.evil_space.prepare('UPDATE memberships SET name = ? WHERE customer_id = ?').bind(name, id),
    env.evil_space.prepare('UPDATE visits SET name = ? WHERE customer_id = ?').bind(name, id),
  ]);

  return json({ ok: true, snapshot: await operationsSnapshot(env) });
}

async function handleDeleteCustomer(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const id = toPositiveInt(body?.id);
  if (!id) return jsonError('Customer is required.', 400);

  const customer = await env.evil_space
    .prepare('SELECT id FROM customers WHERE id = ?')
    .bind(id)
    .first();
  if (!customer) return jsonError('Customer not found.', 404);

  await env.evil_space.batch([
    env.evil_space.prepare('UPDATE visits SET customer_id = NULL WHERE customer_id = ?').bind(id),
    env.evil_space.prepare('DELETE FROM memberships WHERE customer_id = ?').bind(id),
    env.evil_space.prepare('DELETE FROM booking_requests WHERE customer_id = ?').bind(id),
    env.evil_space.prepare('DELETE FROM customers WHERE id = ?').bind(id),
  ]);

  return json({ ok: true, snapshot: await operationsSnapshot(env) });
}

async function handleAddPurchase(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const title = cleanText(body?.title, MAX_PURCHASE_LENGTH);
  if (!title) return jsonError('What to buy is required.', 400);

  await env.evil_space
    .prepare(`
      INSERT INTO purchase_requests (title, status, created_at, created_by_email)
      VALUES (?, 'needed', ?, ?)
    `)
    .bind(title, nowSeconds(), session.email)
    .run();

  return json({ ok: true, snapshot: await operationsSnapshot(env) }, 201);
}

async function handlePurchaseBought(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request);
  const id = toPositiveInt(body?.id);
  if (!id) return jsonError('Purchase is required.', 400);

  const result = await env.evil_space
    .prepare(`
      UPDATE purchase_requests
      SET status = 'bought', bought_at = ?, bought_by_email = ?
      WHERE id = ? AND status = 'needed'
    `)
    .bind(nowSeconds(), session.email, id)
    .run();

  if (!result.meta?.changes) return jsonError('Purchase was already completed.', 409);
  return json({ ok: true, snapshot: await operationsSnapshot(env) });
}

async function ensureCustomer(env, data) {
  const name = cleanText(data.name, MAX_NAME_LENGTH);
  if (!name) throw new Error('Customer name is required.');

  const phone = cleanOptionalText(data.phone, MAX_CONTACT_LENGTH);
  const telegram = cleanOptionalText(data.telegram, MAX_CONTACT_LENGTH);
  let customer = null;

  if (phone) {
    customer = await env.evil_space
      .prepare('SELECT id FROM customers WHERE lower(phone) = lower(?) LIMIT 1')
      .bind(phone)
      .first();
  }
  if (!customer && telegram) {
    customer = await env.evil_space
      .prepare('SELECT id FROM customers WHERE lower(telegram) = lower(?) LIMIT 1')
      .bind(telegram)
      .first();
  }
  if (!customer) {
    customer = await env.evil_space
      .prepare('SELECT id FROM customers WHERE lower(name) = lower(?) ORDER BY id LIMIT 1')
      .bind(name)
      .first();
  }

  const now = nowSeconds();
  if (customer) {
    await env.evil_space
      .prepare(`
        UPDATE customers
        SET name = ?,
            phone = CASE WHEN ? <> '' THEN ? ELSE phone END,
            telegram = CASE WHEN ? <> '' THEN ? ELSE telegram END,
            updated_at = ?
        WHERE id = ?
      `)
      .bind(name, phone, phone, telegram, telegram, now, customer.id)
      .run();
    return { id: Number(customer.id), name };
  }

  const created = await env.evil_space
    .prepare(`
      INSERT INTO customers
        (name, phone, email, telegram, contact_other, notes, created_at, updated_at)
      VALUES (?, ?, '', ?, '', '', ?, ?)
      RETURNING id
    `)
    .bind(name, phone, telegram, now, now)
    .first();
  return { id: Number(created.id), name };
}

async function operationsSnapshot(env) {
  const now = nowSeconds();
  const { start, end } = nhaTrangDayBounds(now);
  const sevenDaysStart = start - 6 * 86400;
  const thirtyDaysStart = start - 29 * 86400;

  const [
    todayVisits,
    activeMemberships,
    bookingRequests,
    customers,
    toBuy,
    history,
    income,
  ] = await Promise.all([
    env.evil_space
      .prepare(`
        SELECT id, name, kind, amount, created_at, customer_id
        FROM visits
        WHERE created_at >= ? AND created_at < ?
        ORDER BY created_at DESC, id DESC
      `)
      .bind(start, end)
      .all(),
    env.evil_space
      .prepare(`
        SELECT id, name, starts_at, expires_at, customer_id
        FROM memberships
        WHERE expires_at > ?
        ORDER BY expires_at ASC, name COLLATE NOCASE ASC
      `)
      .bind(now)
      .all(),
    env.evil_space
      .prepare(`
        SELECT id, name, contact_type, contact_value, status, created_at,
     service_day, amount_vnd, handled_at, handled_by_email
        FROM booking_requests
        WHERE service_day >= ? AND service_day < ?
AND (status = 'new' OR (status = 'accepted' AND service_day >= ?))
        ORDER BY service_day ASC, created_at DESC, id DESC
        LIMIT 100
      `)
      .bind(start, end + 86400, end)
      .all(),
    env.evil_space
      .prepare(`
        SELECT
          c.id, c.name, COALESCE(c.phone, '') AS phone,
          COALESCE(c.email, '') AS email,
          COALESCE(c.telegram, '') AS telegram,
          COALESCE(c.contact_other, '') AS contact_other,
          COALESCE(c.notes, '') AS notes,
          c.created_at,
          MAX(CASE WHEN m.expires_at > ? THEN m.expires_at ELSE NULL END) AS active_until
        FROM customers c
        LEFT JOIN memberships m ON m.customer_id = c.id
        GROUP BY c.id
        ORDER BY c.name COLLATE NOCASE ASC, c.id ASC
      `)
      .bind(now)
      .all(),
    env.evil_space
      .prepare(`
        SELECT id, title, status, created_at, bought_at
        FROM purchase_requests
        WHERE status = 'needed'
        ORDER BY created_at DESC, id DESC
      `)
      .all(),
    env.evil_space
      .prepare(`
        SELECT id, title, status, created_at, bought_at
        FROM purchase_requests
        WHERE status = 'bought'
        ORDER BY bought_at DESC, id DESC
        LIMIT 100
      `)
      .all(),
    env.evil_space
      .prepare(`
        SELECT
          COALESCE(SUM(CASE WHEN created_at >= ? AND created_at < ? THEN amount ELSE 0 END), 0) AS today,
          COALESCE(SUM(CASE WHEN created_at >= ? THEN amount ELSE 0 END), 0) AS seven_days,
          COALESCE(SUM(CASE WHEN created_at >= ? THEN amount ELSE 0 END), 0) AS thirty_days,
          COALESCE(SUM(amount), 0) AS all_total
        FROM visits
      `)
      .bind(start, end, sevenDaysStart, thirtyDaysStart)
      .first(),
  ]);

  const [pricing, promotions] = await Promise.all([
    pricingSnapshot(env, now),
    listPromotions(env),
  ]);

  return {
    today_visits: todayVisits.results ?? [],
    active_memberships: activeMemberships.results ?? [],
    booking_requests: bookingRequests.results ?? [],
    customers: customers.results ?? [],
    to_buy: toBuy.results ?? [],
    purchase_history: history.results ?? [],
    pricing,
    promotions,
    income: {
      today: Number(income?.today ?? 0),
      seven_days: Number(income?.seven_days ?? 0),
      thirty_days: Number(income?.thirty_days ?? 0),
      all: Number(income?.all_total ?? 0),
    },
  };
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
  if (!email || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return 'Enter a valid email address.';
  }
  if (password.length < 4) return 'Password must be at least 4 characters.';
  if (password.length > 200) return 'Password is too long.';
  return null;
}

function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function cleanText(value, maxLength) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  if (!text || text.length > maxLength) return '';
  return text;
}

function cleanOptionalText(value, maxLength) {
  if (value === null || value === undefined || value === '') return '';
  return cleanText(value, maxLength);
}

function toPositiveInt(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : null;
}

function toPriceInt(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 && number <= 1000000000 ? number : null;
}

function optionalPriceInt(value) {
  if (value === null || value === undefined || value === '') return null;
  return toPriceInt(value) ?? false;
}

function parseTimeMinute(value) {
  if (typeof value !== 'string') return null;
  const match = /^(\d{2}):(\d{2})$/.exec(value.trim());
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
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

function nhaTrangDayBounds(now) {
  const offset = 7 * 3600;
  const local = new Date((now + offset) * 1000);
  const localMidnightUtc = Date.UTC(
    local.getUTCFullYear(),
    local.getUTCMonth(),
    local.getUTCDate(),
  ) / 1000;
  const start = localMidnightUtc - offset;
  return { start, end: start + 86400 };
}

function addCalendarMonth(now) {
  const value = new Date(now * 1000);
  const year = value.getUTCFullYear();
  const month = value.getUTCMonth();
  const day = value.getUTCDate();
  const targetMonth = month + 1;
  const targetYear = year + Math.floor(targetMonth / 12);
  const normalizedMonth = ((targetMonth % 12) + 12) % 12;
  const lastDay = new Date(Date.UTC(targetYear, normalizedMonth + 1, 0)).getUTCDate();
  const targetDay = Math.min(day, lastDay);
  return Math.floor(
    Date.UTC(
      targetYear,
      normalizedMonth,
      targetDay,
      value.getUTCHours(),
      value.getUTCMinutes(),
      value.getUTCSeconds(),
    ) / 1000,
  );
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
  if (typeof left !== 'string' || typeof right !== 'string' || left.length !== right.length) {
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
  return token.length >= 32 && token.length <= 128 && /^[A-Za-z0-9_-]+$/.test(token);
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
  const action = link ? `<p><a href="${escapeHtml(link)}">OPEN ADMIN</a></p>` : '';
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
