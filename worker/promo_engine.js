const CUSTOMER_SESSION_COOKIE = '__Host-evil_customer_session';
const ADMIN_SESSION_COOKIE = '__Host-evil_admin_session';
const MAX_BODY_BYTES = 64 * 1024;
const MAX_KEY_LENGTH = 64;
const MAX_NAME_LENGTH = 100;
const MAX_DESCRIPTION_LENGTH = 240;
const MAX_CODE_LENGTH = 48;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    try {
      if (request.method === 'GET' && url.pathname === '/api/public/account/promos') {
        return handleCustomerPromos(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/public/account/promos/claim') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleClaimCode(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/public/menu/promos') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleEligiblePromos(request, env);
      }
      if (request.method === 'GET' && url.pathname === '/api/admin/promos') {
        return handleAdminPromos(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/promos') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleCreatePromotion(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/promos/update') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleUpdatePromotion(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/promos/disable') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleDisablePromotion(request, env);
      }
      if (request.method === 'GET' && url.pathname === '/api/admin/customers') {
        return handleAdminCustomers(request, url, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/customers/promos/grant') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleAdminGrant(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/customers/promos/revoke') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleAdminRevoke(request, env);
      }
      return jsonError('Not found.', 404);
    } catch (error) {
      console.error('Promo engine error', safeError(error));
      return jsonError('Promo request failed. Please try again.', 500);
    }
  },
};

export async function grantSignupPromos(env, customerId, now = nowSeconds()) {
  const id = toPositiveInt(customerId);
  if (!id) return;
  const result = await env.evil_space
    .prepare(`
      SELECT p.id, p.promo_key, p.max_uses_per_customer
      FROM marketing_promotions p
      WHERE p.active = 1
        AND p.superseded_at IS NULL
        AND p.distribution_type = 'signup'
        AND p.valid_from <= ?
        AND (p.expires_at IS NULL OR p.expires_at > ?)
      ORDER BY p.promo_key, p.revision DESC, p.id DESC
    `)
    .bind(now, now)
    .all();

  const seen = new Set();
  const statements = [];
  for (const row of result.results ?? []) {
    const key = String(row.promo_key);
    if (seen.has(key)) continue;
    seen.add(key);
    statements.push(
      env.evil_space
        .prepare(`
          INSERT OR IGNORE INTO customer_promo_grants
            (customer_id, promotion_id, grant_key, source, granted_uses,
             used_uses, reserved_uses, status, granted_at, granted_by_email)
          VALUES (?, ?, ?, 'signup', ?, 0, 0, 'active', ?, 'system')
        `)
        .bind(id, Number(row.id), `signup:${key}`, Number(row.max_uses_per_customer), now),
    );
  }
  if (statements.length) await env.evil_space.batch(statements);
}

export async function resolvePromoForCart(env, customerId, grantId, lines, now = nowSeconds()) {
  const cid = toPositiveInt(customerId);
  const gid = toPositiveInt(grantId);
  if (!cid || !gid) return { error: 'Promo is not available.' };
  await releaseExpiredPromoReservations(env, now);

  const grant = await env.evil_space
    .prepare(`
      SELECT
        g.id, g.customer_id, g.promotion_id, g.granted_uses, g.used_uses,
        g.reserved_uses, g.status,
        p.promo_key, p.revision, p.name, p.description, p.discount_type,
        p.discount_value, p.max_discount_vnd, p.minimum_subtotal_vnd,
        p.valid_from, p.expires_at, p.max_total_uses, p.active
      FROM customer_promo_grants g
      JOIN marketing_promotions p ON p.id = g.promotion_id
      WHERE g.id = ? AND g.customer_id = ?
      LIMIT 1
    `)
    .bind(gid, cid)
    .first();
  if (!grant) return { error: 'Promo is not available.' };
  if (String(grant.status) !== 'active') return { error: 'Promo is not active.' };
  if (Number(grant.active) !== 1) return { error: 'Promo has been disabled.' };
  if (Number(grant.valid_from) > now) return { error: 'Promo is not active yet.' };
  if (grant.expires_at != null && Number(grant.expires_at) <= now) {
    return { error: 'Promo has expired.' };
  }
  const remaining = Number(grant.granted_uses) - Number(grant.used_uses) - Number(grant.reserved_uses);
  if (remaining < 1) return { error: 'Promo has no uses remaining.' };

  const originalAmountVnd = lines.reduce((sum, line) => sum + Number(line.lineTotalVnd || 0), 0);
  if (!Number.isSafeInteger(originalAmountVnd) || originalAmountVnd <= 0) {
    return { error: 'Invalid order amount.' };
  }
  if (originalAmountVnd < Number(grant.minimum_subtotal_vnd || 0)) {
    return { error: 'Order does not meet the promo minimum.' };
  }

  if (grant.max_total_uses != null) {
    const used = await env.evil_space
      .prepare(`
        SELECT COUNT(*) AS count
        FROM promo_redemptions
        WHERE customer_promo_id IN (
          SELECT id FROM customer_promo_grants WHERE promotion_id = ?
        ) AND status IN ('reserved', 'consumed')
      `)
      .bind(Number(grant.promotion_id))
      .first();
    if (Number(used?.count ?? 0) >= Number(grant.max_total_uses)) {
      return { error: 'Promo campaign has reached its usage limit.' };
    }
  }

  const [groupsResult, itemsResult] = await Promise.all([
    env.evil_space
      .prepare('SELECT group_key FROM marketing_promotion_groups WHERE promotion_id = ?')
      .bind(Number(grant.promotion_id))
      .all(),
    env.evil_space
      .prepare('SELECT item_key, rule FROM marketing_promotion_items WHERE promotion_id = ?')
      .bind(Number(grant.promotion_id))
      .all(),
  ]);
  const groups = new Set((groupsResult.results ?? []).map((row) => String(row.group_key)));
  const includedItems = new Set();
  const excludedItems = new Set();
  for (const row of itemsResult.results ?? []) {
    if (String(row.rule) === 'include') includedItems.add(String(row.item_key));
    if (String(row.rule) === 'exclude') excludedItems.add(String(row.item_key));
  }

  let eligibleAmountVnd = 0;
  for (const line of lines) {
    const groupOk = groups.size === 0 || groups.has(String(line.groupKey));
    const itemKey = String(line.itemKey);
    const includeOk = includedItems.size === 0 || includedItems.has(itemKey);
    const excludeOk = !excludedItems.has(itemKey);
    if (groupOk && includeOk && excludeOk) eligibleAmountVnd += Number(line.lineTotalVnd || 0);
  }
  if (!eligibleAmountVnd) return { error: 'Promo does not apply to this order.' };

  let discountVnd = 0;
  if (String(grant.discount_type) === 'percent') {
    discountVnd = Math.floor((eligibleAmountVnd * Number(grant.discount_value)) / 100);
  } else {
    discountVnd = Math.min(eligibleAmountVnd, Number(grant.discount_value));
  }
  if (grant.max_discount_vnd != null) {
    discountVnd = Math.min(discountVnd, Number(grant.max_discount_vnd));
  }
  // Existing VietQR/menu order storage requires a positive amount. Keep 1 VND payable
  // for a 100% promo until zero-value order settlement is introduced explicitly.
  discountVnd = Math.min(discountVnd, originalAmountVnd - 1);
  if (!Number.isSafeInteger(discountVnd) || discountVnd <= 0) {
    return { error: 'Promo does not reduce this order.' };
  }

  return {
    grantId: Number(grant.id),
    promotionId: Number(grant.promotion_id),
    promoKey: String(grant.promo_key),
    name: String(grant.name),
    description: String(grant.description ?? ''),
    discountType: String(grant.discount_type),
    discountValue: Number(grant.discount_value),
    originalAmountVnd,
    eligibleAmountVnd,
    discountVnd,
    finalAmountVnd: originalAmountVnd - discountVnd,
    remainingUses: remaining,
    expiresAt: grant.expires_at == null ? null : Number(grant.expires_at),
  };
}

export async function reservePromoForMenuOrder(env, customerId, grantId, orderId, pricing, expiresAt, now = nowSeconds()) {
  if (!pricing || pricing.error) return { error: pricing?.error ?? 'Promo is not available.' };
  const updated = await env.evil_space
    .prepare(`
      UPDATE customer_promo_grants
      SET reserved_uses = reserved_uses + 1
      WHERE id = ? AND customer_id = ? AND status = 'active'
        AND used_uses + reserved_uses < granted_uses
    `)
    .bind(toPositiveInt(grantId), toPositiveInt(customerId))
    .run();
  if (Number(updated.meta?.changes ?? 0) !== 1) {
    return { error: 'Promo is no longer available.' };
  }
  try {
    await env.evil_space
      .prepare(`
        INSERT INTO promo_redemptions
          (customer_promo_id, customer_id, order_type, order_id,
           original_amount_vnd, eligible_amount_vnd, discount_vnd, final_amount_vnd,
           status, reserved_at, expires_at)
        VALUES (?, ?, 'menu', ?, ?, ?, ?, ?, 'reserved', ?, ?)
      `)
      .bind(
        toPositiveInt(grantId),
        toPositiveInt(customerId),
        toPositiveInt(orderId),
        pricing.originalAmountVnd,
        pricing.eligibleAmountVnd,
        pricing.discountVnd,
        pricing.finalAmountVnd,
        now,
        Number(expiresAt),
      )
      .run();
    return { ok: true };
  } catch (error) {
    await env.evil_space
      .prepare(`
        UPDATE customer_promo_grants
        SET reserved_uses = CASE WHEN reserved_uses > 0 THEN reserved_uses - 1 ELSE 0 END
        WHERE id = ? AND customer_id = ?
      `)
      .bind(toPositiveInt(grantId), toPositiveInt(customerId))
      .run()
      .catch(() => null);
    throw error;
  }
}

export async function consumePromoForMenuOrder(env, orderId, now = nowSeconds()) {
  const redemption = await env.evil_space
    .prepare(`
      SELECT id, customer_promo_id
      FROM promo_redemptions
      WHERE order_type = 'menu' AND order_id = ? AND status = 'reserved'
      LIMIT 1
    `)
    .bind(toPositiveInt(orderId))
    .first();
  if (!redemption) return;

  await env.evil_space.batch([
    env.evil_space
      .prepare(`
        UPDATE promo_redemptions
        SET status = 'consumed', consumed_at = ?
        WHERE id = ? AND status = 'reserved'
      `)
      .bind(now, Number(redemption.id)),
    env.evil_space
      .prepare(`
        UPDATE customer_promo_grants
        SET reserved_uses = CASE WHEN reserved_uses > 0 THEN reserved_uses - 1 ELSE 0 END,
            used_uses = used_uses + 1,
            status = CASE
              WHEN used_uses + 1 >= granted_uses THEN 'exhausted'
              ELSE status
            END
        WHERE id = ?
      `)
      .bind(Number(redemption.customer_promo_id)),
  ]);
}

export async function releasePromoForMenuOrder(env, orderId, now = nowSeconds()) {
  const redemption = await env.evil_space
    .prepare(`
      SELECT id, customer_promo_id
      FROM promo_redemptions
      WHERE order_type = 'menu' AND order_id = ? AND status = 'reserved'
      LIMIT 1
    `)
    .bind(toPositiveInt(orderId))
    .first();
  if (!redemption) return;
  await env.evil_space.batch([
    env.evil_space
      .prepare(`
        UPDATE promo_redemptions
        SET status = 'released', released_at = ?
        WHERE id = ? AND status = 'reserved'
      `)
      .bind(now, Number(redemption.id)),
    env.evil_space
      .prepare(`
        UPDATE customer_promo_grants
        SET reserved_uses = CASE WHEN reserved_uses > 0 THEN reserved_uses - 1 ELSE 0 END,
            status = CASE WHEN status = 'exhausted' AND used_uses < granted_uses THEN 'active' ELSE status END
        WHERE id = ?
      `)
      .bind(Number(redemption.customer_promo_id)),
  ]);
}

export async function releaseExpiredPromoReservations(env, now = nowSeconds()) {
  const expired = await env.evil_space
    .prepare(`
      SELECT id, customer_promo_id
      FROM promo_redemptions
      WHERE status = 'reserved' AND expires_at <= ?
      ORDER BY id
      LIMIT 100
    `)
    .bind(now)
    .all();
  for (const row of expired.results ?? []) {
    await env.evil_space.batch([
      env.evil_space
        .prepare("UPDATE promo_redemptions SET status = 'released', released_at = ? WHERE id = ? AND status = 'reserved'")
        .bind(now, Number(row.id)),
      env.evil_space
        .prepare(`
          UPDATE customer_promo_grants
          SET reserved_uses = CASE WHEN reserved_uses > 0 THEN reserved_uses - 1 ELSE 0 END,
              status = CASE WHEN status = 'exhausted' AND used_uses < granted_uses THEN 'active' ELSE status END
          WHERE id = ?
        `)
        .bind(Number(row.customer_promo_id)),
    ]);
  }
}

async function handleCustomerPromos(request, env) {
  const customer = await authenticatedCustomer(request, env);
  if (!customer) return jsonError('Sign in required.', 401);
  const now = nowSeconds();
  await releaseExpiredPromoReservations(env, now);
  await grantEveryonePromos(env, Number(customer.id), now);
  return json({ ok: true, promos: await customerPromoWallet(env, Number(customer.id), now) });
}

async function handleClaimCode(request, env) {
  const customer = await authenticatedCustomer(request, env);
  if (!customer) return jsonError('Sign in required.', 401);
  const body = await readJson(request, MAX_BODY_BYTES);
  const code = cleanCode(body?.code);
  if (!code) return jsonError('Enter a valid promo code.', 400);
  const now = nowSeconds();
  const promo = await env.evil_space
    .prepare(`
      SELECT id, promo_key, max_uses_per_customer
      FROM marketing_promotions
      WHERE upper(code) = ? AND active = 1 AND superseded_at IS NULL
        AND distribution_type = 'code' AND valid_from <= ?
        AND (expires_at IS NULL OR expires_at > ?)
      ORDER BY revision DESC, id DESC
      LIMIT 1
    `)
    .bind(code, now, now)
    .first();
  if (!promo) return jsonError('Promo code is invalid or expired.', 404);
  const grantKey = `code:${String(promo.promo_key)}`;
  const inserted = await env.evil_space
    .prepare(`
      INSERT OR IGNORE INTO customer_promo_grants
        (customer_id, promotion_id, grant_key, source, granted_uses,
         used_uses, reserved_uses, status, granted_at)
      VALUES (?, ?, ?, 'code', ?, 0, 0, 'active', ?)
    `)
    .bind(Number(customer.id), Number(promo.id), grantKey, Number(promo.max_uses_per_customer), now)
    .run();
  if (Number(inserted.meta?.changes ?? 0) === 0) {
    return jsonError('This promo has already been claimed.', 409);
  }
  return json({ ok: true, promos: await customerPromoWallet(env, Number(customer.id), now) }, 201);
}

async function handleEligiblePromos(request, env) {
  const customer = await authenticatedCustomer(request, env);
  if (!customer) return json({ ok: true, authenticated: false, promos: [] });
  const body = await readJson(request, MAX_BODY_BYTES);
  const normalized = normalizeRequestedCart(body?.items);
  if (normalized.error) return jsonError(normalized.error, 400);
  const lines = await loadTrustedCartLines(env, normalized.items);
  if (lines.error) return jsonError(lines.error, 409);
  const now = nowSeconds();
  await grantEveryonePromos(env, Number(customer.id), now);
  const wallet = await customerPromoWallet(env, Number(customer.id), now);
  const applicable = [];
  for (const promo of wallet) {
    if (promo.status !== 'active' || promo.remainingUses < 1) continue;
    const pricing = await resolvePromoForCart(env, Number(customer.id), promo.id, lines.lines, now);
    if (!pricing.error) applicable.push(pricing);
  }
  applicable.sort((a, b) => b.discountVnd - a.discountVnd || a.name.localeCompare(b.name));
  return json({ ok: true, authenticated: true, promos: applicable });
}

async function handleAdminPromos(request, env) {
  const admin = await authenticatedAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  return json({ ok: true, snapshot: await adminPromoSnapshot(env) });
}

async function handleCreatePromotion(request, env) {
  const admin = await authenticatedAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request, MAX_BODY_BYTES);
  const parsed = validatePromotionInput(body);
  if (parsed.error) return jsonError(parsed.error, 400);
  const now = nowSeconds();
  const existing = await env.evil_space
    .prepare('SELECT MAX(revision) AS revision FROM marketing_promotions WHERE promo_key = ?')
    .bind(parsed.promoKey)
    .first();
  if (Number(existing?.revision ?? 0) > 0) return jsonError('Promo key already exists. Edit the existing promotion instead.', 409);
  await insertPromotionRevision(env, parsed, 1, admin.email, now);
  return json({ ok: true, snapshot: await adminPromoSnapshot(env) }, 201);
}

async function handleUpdatePromotion(request, env) {
  const admin = await authenticatedAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request, MAX_BODY_BYTES);
  const id = toPositiveInt(body?.id);
  if (!id) return jsonError('Promotion is required.', 400);
  const current = await env.evil_space
    .prepare('SELECT promo_key, revision FROM marketing_promotions WHERE id = ? LIMIT 1')
    .bind(id)
    .first();
  if (!current) return jsonError('Promotion not found.', 404);
  const parsed = validatePromotionInput({ ...body, promoKey: String(current.promo_key) });
  if (parsed.error) return jsonError(parsed.error, 400);
  const now = nowSeconds();
  await env.evil_space
    .prepare('UPDATE marketing_promotions SET superseded_at = ? WHERE id = ? AND superseded_at IS NULL')
    .bind(now, id)
    .run();
  await insertPromotionRevision(env, parsed, Number(current.revision) + 1, admin.email, now);
  return json({ ok: true, snapshot: await adminPromoSnapshot(env) });
}

async function handleDisablePromotion(request, env) {
  const admin = await authenticatedAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request, MAX_BODY_BYTES);
  const id = toPositiveInt(body?.id);
  if (!id) return jsonError('Promotion is required.', 400);
  const current = await env.evil_space
    .prepare('SELECT promo_key FROM marketing_promotions WHERE id = ? LIMIT 1')
    .bind(id)
    .first();
  if (!current) return jsonError('Promotion not found.', 404);
  await env.evil_space
    .prepare('UPDATE marketing_promotions SET active = 0 WHERE promo_key = ?')
    .bind(String(current.promo_key))
    .run();
  return json({ ok: true, snapshot: await adminPromoSnapshot(env) });
}

async function handleAdminCustomers(request, url, env) {
  const admin = await authenticatedAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const customerId = toPositiveInt(url.searchParams.get('id'));
  if (customerId) return json({ ok: true, customer: await adminCustomerDetail(env, customerId) });
  const query = cleanShortText(url.searchParams.get('q'), 100);
  const pattern = `%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%`;
  const result = await env.evil_space
    .prepare(`
      SELECT c.id, c.name, c.phone, c.email, c.telegram, c.created_at, c.updated_at,
             (SELECT COUNT(*) FROM customer_promo_grants g WHERE g.customer_id = c.id AND g.status = 'active') AS active_promos,
             (SELECT COUNT(*) FROM menu_orders o WHERE o.customer_id = c.id) AS menu_orders
      FROM customers c
      WHERE ? = '' OR c.name LIKE ? ESCAPE '\\' OR COALESCE(c.phone, '') LIKE ? ESCAPE '\\'
        OR COALESCE(c.email, '') LIKE ? ESCAPE '\\' OR COALESCE(c.telegram, '') LIKE ? ESCAPE '\\'
      ORDER BY c.updated_at DESC, c.id DESC
      LIMIT 100
    `)
    .bind(query, pattern, pattern, pattern, pattern)
    .all();
  return json({ ok: true, customers: (result.results ?? []).map(adminCustomerSummary) });
}

async function handleAdminGrant(request, env) {
  const admin = await authenticatedAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request, MAX_BODY_BYTES);
  const customerId = toPositiveInt(body?.customerId);
  const promotionId = toPositiveInt(body?.promotionId);
  const uses = toPositiveInt(body?.uses ?? 1);
  if (!customerId || !promotionId || !uses || uses > 100) return jsonError('Invalid promo grant.', 400);
  const promotion = await env.evil_space
    .prepare(`
      SELECT id FROM marketing_promotions
      WHERE id = ? AND active = 1
      LIMIT 1
    `)
    .bind(promotionId)
    .first();
  if (!promotion) return jsonError('Promotion not found or disabled.', 404);
  const now = nowSeconds();
  await env.evil_space
    .prepare(`
      INSERT INTO customer_promo_grants
        (customer_id, promotion_id, grant_key, source, granted_uses,
         used_uses, reserved_uses, status, granted_at, granted_by_email)
      VALUES (?, ?, NULL, 'manual', ?, 0, 0, 'active', ?, ?)
    `)
    .bind(customerId, promotionId, uses, now, admin.email)
    .run();
  return json({ ok: true, customer: await adminCustomerDetail(env, customerId) }, 201);
}

async function handleAdminRevoke(request, env) {
  const admin = await authenticatedAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request, MAX_BODY_BYTES);
  const grantId = toPositiveInt(body?.grantId);
  if (!grantId) return jsonError('Promo grant is required.', 400);
  const grant = await env.evil_space
    .prepare('SELECT customer_id, reserved_uses, status FROM customer_promo_grants WHERE id = ? LIMIT 1')
    .bind(grantId)
    .first();
  if (!grant) return jsonError('Promo grant not found.', 404);
  if (Number(grant.reserved_uses) > 0) return jsonError('Promo is reserved by an unpaid order. Cancel or expire that order first.', 409);
  await env.evil_space
    .prepare("UPDATE customer_promo_grants SET status = 'revoked', revoked_at = ? WHERE id = ? AND status != 'revoked'")
    .bind(nowSeconds(), grantId)
    .run();
  return json({ ok: true, customer: await adminCustomerDetail(env, Number(grant.customer_id)) });
}

async function insertPromotionRevision(env, promo, revision, createdByEmail, now) {
  const inserted = await env.evil_space
    .prepare(`
      INSERT INTO marketing_promotions
        (promo_key, revision, name, description, code, discount_type,
         discount_value, max_discount_vnd, minimum_subtotal_vnd, valid_from,
         expires_at, max_uses_per_customer, max_total_uses, distribution_type,
         active, created_at, created_by_email)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    `)
    .bind(
      promo.promoKey,
      revision,
      promo.name,
      promo.description,
      promo.code,
      promo.discountType,
      promo.discountValue,
      promo.maxDiscountVnd,
      promo.minimumSubtotalVnd,
      promo.validFrom,
      promo.expiresAt,
      promo.maxUsesPerCustomer,
      promo.maxTotalUses,
      promo.distributionType,
      now,
      createdByEmail,
    )
    .run();
  const promotionId = Number(inserted.meta?.last_row_id ?? 0);
  if (!promotionId) throw new Error('Could not create promotion.');
  const statements = [];
  for (const groupKey of promo.groupKeys) {
    statements.push(
      env.evil_space
        .prepare('INSERT INTO marketing_promotion_groups (promotion_id, group_key) VALUES (?, ?)')
        .bind(promotionId, groupKey),
    );
  }
  for (const itemKey of promo.includeItemKeys) {
    statements.push(
      env.evil_space
        .prepare("INSERT INTO marketing_promotion_items (promotion_id, item_key, rule) VALUES (?, ?, 'include')")
        .bind(promotionId, itemKey),
    );
  }
  for (const itemKey of promo.excludeItemKeys) {
    statements.push(
      env.evil_space
        .prepare("INSERT INTO marketing_promotion_items (promotion_id, item_key, rule) VALUES (?, ?, 'exclude')")
        .bind(promotionId, itemKey),
    );
  }
  if (statements.length) await env.evil_space.batch(statements);

  if (promo.distributionType === 'everyone') {
    const customers = await env.evil_space.prepare('SELECT id FROM customers ORDER BY id').all();
    const grants = (customers.results ?? []).map((customer) =>
      env.evil_space
        .prepare(`
          INSERT OR IGNORE INTO customer_promo_grants
            (customer_id, promotion_id, grant_key, source, granted_uses,
             used_uses, reserved_uses, status, granted_at, granted_by_email)
          VALUES (?, ?, ?, 'everyone', ?, 0, 0, 'active', ?, ?)
        `)
        .bind(Number(customer.id), promotionId, `everyone:${promo.promoKey}`, promo.maxUsesPerCustomer, now, createdByEmail),
    );
    if (grants.length) await env.evil_space.batch(grants);
  }
  return promotionId;
}

async function grantEveryonePromos(env, customerId, now) {
  const result = await env.evil_space
    .prepare(`
      SELECT id, promo_key, max_uses_per_customer
      FROM marketing_promotions
      WHERE active = 1 AND superseded_at IS NULL AND distribution_type = 'everyone'
        AND valid_from <= ? AND (expires_at IS NULL OR expires_at > ?)
      ORDER BY promo_key, revision DESC
    `)
    .bind(now, now)
    .all();
  const statements = [];
  const seen = new Set();
  for (const row of result.results ?? []) {
    const key = String(row.promo_key);
    if (seen.has(key)) continue;
    seen.add(key);
    statements.push(
      env.evil_space
        .prepare(`
          INSERT OR IGNORE INTO customer_promo_grants
            (customer_id, promotion_id, grant_key, source, granted_uses,
             used_uses, reserved_uses, status, granted_at, granted_by_email)
          VALUES (?, ?, ?, 'everyone', ?, 0, 0, 'active', ?, 'system')
        `)
        .bind(customerId, Number(row.id), `everyone:${key}`, Number(row.max_uses_per_customer), now),
    );
  }
  if (statements.length) await env.evil_space.batch(statements);
}

async function customerPromoWallet(env, customerId, now) {
  const result = await env.evil_space
    .prepare(`
      SELECT
        g.id, g.promotion_id, g.source, g.granted_uses, g.used_uses,
        g.reserved_uses, g.status, g.granted_at,
        p.promo_key, p.revision, p.name, p.description, p.code,
        p.discount_type, p.discount_value, p.max_discount_vnd,
        p.minimum_subtotal_vnd, p.valid_from, p.expires_at,
        p.distribution_type, p.active
      FROM customer_promo_grants g
      JOIN marketing_promotions p ON p.id = g.promotion_id
      WHERE g.customer_id = ?
      ORDER BY CASE g.status WHEN 'active' THEN 0 ELSE 1 END,
               g.granted_at DESC, g.id DESC
      LIMIT 100
    `)
    .bind(customerId)
    .all();
  const promos = [];
  for (const row of result.results ?? []) {
    const groups = await env.evil_space
      .prepare('SELECT group_key FROM marketing_promotion_groups WHERE promotion_id = ? ORDER BY group_key')
      .bind(Number(row.promotion_id))
      .all();
    let status = String(row.status);
    if (status === 'active' && Number(row.active) !== 1) status = 'disabled';
    if (status === 'active' && Number(row.valid_from) > now) status = 'upcoming';
    if (status === 'active' && row.expires_at != null && Number(row.expires_at) <= now) status = 'expired';
    const remainingUses = Math.max(0, Number(row.granted_uses) - Number(row.used_uses) - Number(row.reserved_uses));
    promos.push({
      id: Number(row.id),
      promotionId: Number(row.promotion_id),
      promoKey: String(row.promo_key),
      revision: Number(row.revision),
      name: String(row.name),
      description: String(row.description ?? ''),
      code: row.code == null ? null : String(row.code),
      discountType: String(row.discount_type),
      discountValue: Number(row.discount_value),
      maxDiscountVnd: row.max_discount_vnd == null ? null : Number(row.max_discount_vnd),
      minimumSubtotalVnd: Number(row.minimum_subtotal_vnd),
      groupIds: (groups.results ?? []).map((group) => String(group.group_key)),
      source: String(row.source),
      status,
      grantedUses: Number(row.granted_uses),
      usedUses: Number(row.used_uses),
      reservedUses: Number(row.reserved_uses),
      remainingUses,
      grantedAt: Number(row.granted_at),
      validFrom: Number(row.valid_from),
      expiresAt: row.expires_at == null ? null : Number(row.expires_at),
    });
  }
  return promos;
}

async function adminPromoSnapshot(env) {
  const result = await env.evil_space
    .prepare(`
      SELECT p.*,
        (SELECT COUNT(*) FROM customer_promo_grants g WHERE g.promotion_id = p.id) AS grants,
        (SELECT COUNT(*) FROM promo_redemptions r
          JOIN customer_promo_grants g ON g.id = r.customer_promo_id
          WHERE g.promotion_id = p.id AND r.status = 'consumed') AS consumed
      FROM marketing_promotions p
      WHERE p.superseded_at IS NULL
      ORDER BY p.active DESC, p.created_at DESC, p.id DESC
      LIMIT 100
    `)
    .all();
  const promos = [];
  for (const row of result.results ?? []) {
    const [groups, items] = await Promise.all([
      env.evil_space.prepare('SELECT group_key FROM marketing_promotion_groups WHERE promotion_id = ? ORDER BY group_key').bind(Number(row.id)).all(),
      env.evil_space.prepare('SELECT item_key, rule FROM marketing_promotion_items WHERE promotion_id = ? ORDER BY rule, item_key').bind(Number(row.id)).all(),
    ]);
    promos.push({
      id: Number(row.id),
      promoKey: String(row.promo_key),
      revision: Number(row.revision),
      name: String(row.name),
      description: String(row.description ?? ''),
      code: row.code == null ? null : String(row.code),
      discountType: String(row.discount_type),
      discountValue: Number(row.discount_value),
      maxDiscountVnd: row.max_discount_vnd == null ? null : Number(row.max_discount_vnd),
      minimumSubtotalVnd: Number(row.minimum_subtotal_vnd),
      validFrom: Number(row.valid_from),
      expiresAt: row.expires_at == null ? null : Number(row.expires_at),
      maxUsesPerCustomer: Number(row.max_uses_per_customer),
      maxTotalUses: row.max_total_uses == null ? null : Number(row.max_total_uses),
      distributionType: String(row.distribution_type),
      active: Number(row.active) === 1,
      createdAt: Number(row.created_at),
      createdByEmail: String(row.created_by_email),
      groupIds: (groups.results ?? []).map((g) => String(g.group_key)),
      includeItemIds: (items.results ?? []).filter((i) => i.rule === 'include').map((i) => String(i.item_key)),
      excludeItemIds: (items.results ?? []).filter((i) => i.rule === 'exclude').map((i) => String(i.item_key)),
      grants: Number(row.grants ?? 0),
      consumed: Number(row.consumed ?? 0),
    });
  }
  return { promos };
}

async function adminCustomerDetail(env, customerId) {
  const customer = await env.evil_space
    .prepare('SELECT id, name, phone, email, telegram, created_at, updated_at FROM customers WHERE id = ? LIMIT 1')
    .bind(customerId)
    .first();
  if (!customer) return null;
  const [identities, devices, orders, redemptions] = await Promise.all([
    env.evil_space.prepare('SELECT provider, display_value, verified_at FROM customer_identities WHERE customer_id = ? ORDER BY verified_at').bind(customerId).all(),
    env.evil_space.prepare('SELECT device_id, platform, language, first_seen_at, last_seen_at FROM customer_devices WHERE customer_id = ? ORDER BY last_seen_at DESC LIMIT 20').bind(customerId).all(),
    env.evil_space.prepare('SELECT id, order_code, item_name, original_amount_vnd, amount_vnd, promo_discount_vnd, status, created_at, paid_at FROM menu_orders WHERE customer_id = ? ORDER BY created_at DESC LIMIT 50').bind(customerId).all(),
    env.evil_space.prepare(`
      SELECT r.id, r.customer_promo_id, r.order_type, r.order_id, r.original_amount_vnd,
             r.discount_vnd, r.final_amount_vnd, r.status, r.reserved_at, r.consumed_at,
             p.name AS promo_name
      FROM promo_redemptions r
      JOIN customer_promo_grants g ON g.id = r.customer_promo_id
      JOIN marketing_promotions p ON p.id = g.promotion_id
      WHERE r.customer_id = ?
      ORDER BY r.reserved_at DESC, r.id DESC LIMIT 50
    `).bind(customerId).all(),
  ]);
  return {
    ...adminCustomerSummary(customer),
    identities: identities.results ?? [],
    devices: devices.results ?? [],
    promos: await customerPromoWallet(env, customerId, nowSeconds()),
    orders: (orders.results ?? []).map((row) => ({
      id: Number(row.id),
      orderCode: String(row.order_code),
      itemName: String(row.item_name),
      originalAmountVnd: Number(row.original_amount_vnd ?? row.amount_vnd),
      amountVnd: Number(row.amount_vnd),
      promoDiscountVnd: Number(row.promo_discount_vnd ?? 0),
      status: String(row.status),
      createdAt: Number(row.created_at),
      paidAt: row.paid_at == null ? null : Number(row.paid_at),
    })),
    redemptions: (redemptions.results ?? []).map((row) => ({
      id: Number(row.id),
      customerPromoId: Number(row.customer_promo_id),
      promoName: String(row.promo_name),
      orderType: String(row.order_type),
      orderId: Number(row.order_id),
      originalAmountVnd: Number(row.original_amount_vnd),
      discountVnd: Number(row.discount_vnd),
      finalAmountVnd: Number(row.final_amount_vnd),
      status: String(row.status),
      reservedAt: Number(row.reserved_at),
      consumedAt: row.consumed_at == null ? null : Number(row.consumed_at),
    })),
  };
}

function adminCustomerSummary(row) {
  return {
    id: Number(row.id),
    name: String(row.name ?? ''),
    phone: row.phone == null ? null : String(row.phone),
    email: row.email == null ? null : String(row.email),
    telegram: row.telegram == null ? null : String(row.telegram),
    createdAt: Number(row.created_at ?? 0),
    updatedAt: Number(row.updated_at ?? 0),
    activePromos: Number(row.active_promos ?? 0),
    menuOrders: Number(row.menu_orders ?? 0),
  };
}

function validatePromotionInput(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return { error: 'Invalid promotion.' };
  const promoKey = cleanKey(body.promoKey);
  const name = cleanText(body.name, MAX_NAME_LENGTH);
  const description = cleanText(body.description ?? '', MAX_DESCRIPTION_LENGTH, true);
  const code = body.code == null || String(body.code).trim() === '' ? null : cleanCode(body.code);
  const discountType = body.discountType === 'fixed_vnd' ? 'fixed_vnd' : body.discountType === 'percent' ? 'percent' : '';
  const discountValue = toPositiveInt(body.discountValue);
  const maxDiscountVnd = nullablePositiveInt(body.maxDiscountVnd);
  const minimumSubtotalVnd = toNonNegativeInt(body.minimumSubtotalVnd ?? 0);
  const validFrom = toNonNegativeInt(body.validFrom ?? 0);
  const expiresAt = nullablePositiveInt(body.expiresAt);
  const maxUsesPerCustomer = toPositiveInt(body.maxUsesPerCustomer ?? 1);
  const maxTotalUses = nullablePositiveInt(body.maxTotalUses);
  const distributionType = ['signup', 'manual', 'everyone', 'code'].includes(body.distributionType)
    ? body.distributionType
    : '';
  if (!promoKey || !name) return { error: 'Promo key and name are required.' };
  if (!discountType || !discountValue) return { error: 'Choose a valid discount.' };
  if (discountType === 'percent' && discountValue > 100) return { error: 'Percent discount cannot exceed 100%.' };
  if (code === '' || (distributionType === 'code' && !code)) return { error: 'Promo code is required for code-only promotions.' };
  if (!Number.isSafeInteger(minimumSubtotalVnd) || minimumSubtotalVnd < 0) return { error: 'Invalid minimum subtotal.' };
  if (!Number.isSafeInteger(validFrom) || validFrom < 0) return { error: 'Invalid start time.' };
  if (expiresAt != null && expiresAt <= validFrom) return { error: 'Expiry must be after the start time.' };
  if (!maxUsesPerCustomer || maxUsesPerCustomer > 1000) return { error: 'Invalid customer usage limit.' };
  if (!distributionType) return { error: 'Choose how this promo is distributed.' };
  const groupKeys = uniqueIds(body.groupIds);
  const includeItemKeys = uniqueIds(body.includeItemIds);
  const excludeItemKeys = uniqueIds(body.excludeItemIds);
  if (includeItemKeys.some((id) => excludeItemKeys.includes(id))) return { error: 'An item cannot be both included and excluded.' };
  return {
    promoKey,
    name,
    description,
    code,
    discountType,
    discountValue,
    maxDiscountVnd,
    minimumSubtotalVnd,
    validFrom,
    expiresAt,
    maxUsesPerCustomer,
    maxTotalUses,
    distributionType,
    groupKeys,
    includeItemKeys,
    excludeItemKeys,
  };
}

function normalizeRequestedCart(value) {
  if (!Array.isArray(value) || value.length < 1 || value.length > 20) return { error: 'Your cart is empty.' };
  const quantities = new Map();
  for (const raw of value) {
    const itemId = cleanKey(raw?.itemId);
    const quantity = Number(raw?.quantity ?? 1);
    if (!itemId || !Number.isSafeInteger(quantity) || quantity < 1 || quantity > 20) return { error: 'Invalid cart item.' };
    quantities.set(itemId, Math.min(20, (quantities.get(itemId) ?? 0) + quantity));
  }
  return { items: [...quantities.entries()].map(([itemId, quantity]) => ({ itemId, quantity })) };
}

async function loadTrustedCartLines(env, requested) {
  const keys = requested.map((line) => line.itemId);
  const placeholders = keys.map(() => '?').join(', ');
  const result = await env.evil_space
    .prepare(`
      SELECT mi.id, mi.item_key, mi.group_key, mi.name, mi.price_vnd
      FROM menu_items mi
      JOIN menu_catalogs mc ON mc.id = mi.catalog_id
      WHERE mc.active = 1 AND mi.enabled = 1 AND mi.item_key IN (${placeholders})
    `)
    .bind(...keys)
    .all();
  const byKey = new Map((result.results ?? []).map((row) => [String(row.item_key), row]));
  if (byKey.size !== keys.length) return { error: 'One or more menu items are unavailable.' };
  return {
    lines: requested.map((line) => {
      const row = byKey.get(line.itemId);
      const unitPriceVnd = Number(row.price_vnd);
      return {
        itemId: Number(row.id),
        itemKey: String(row.item_key),
        groupKey: String(row.group_key),
        itemName: String(row.name),
        unitPriceVnd,
        quantity: line.quantity,
        lineTotalVnd: unitPriceVnd * line.quantity,
      };
    }),
  };
}

async function authenticatedCustomer(request, env) {
  const token = cookieValue(request, CUSTOMER_SESSION_COOKIE);
  if (!isReasonableToken(token)) return null;
  const tokenHash = await hashToken(token);
  return env.evil_space
    .prepare(`
      SELECT c.id, c.name
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
  if (!isReasonableToken(token)) return null;
  const tokenHash = await hashToken(token);
  return env.evil_space
    .prepare(`
      SELECT a.id, a.email
      FROM admin_sessions s
      JOIN admins a ON a.id = s.admin_id
      WHERE s.token_hash = ? AND s.expires_at > ? AND a.status = 'approved'
      LIMIT 1
    `)
    .bind(tokenHash, nowSeconds())
    .first();
}

function uniqueIds(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map(cleanKey).filter(Boolean))].slice(0, 500);
}

function cleanKey(value) {
  const text = typeof value === 'string' ? value.trim().toLowerCase() : '';
  return text && text.length <= MAX_KEY_LENGTH && /^[a-z0-9][a-z0-9_-]*$/.test(text) ? text : '';
}

function cleanCode(value) {
  const text = typeof value === 'string' ? value.trim().toUpperCase() : '';
  return text && text.length <= MAX_CODE_LENGTH && /^[A-Z0-9][A-Z0-9_-]*$/.test(text) ? text : '';
}

function cleanText(value, maxLength, allowEmpty = false) {
  if (typeof value !== 'string') return allowEmpty ? '' : '';
  const text = value.trim().replace(/\s+/g, ' ');
  if ((!text && !allowEmpty) || text.length > maxLength) return '';
  return text;
}

function cleanShortText(value, maxLength) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, maxLength);
}

function toPositiveInt(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : 0;
}

function nullablePositiveInt(value) {
  if (value == null || value === '') return null;
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : null;
}

function toNonNegativeInt(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number >= 0 ? number : -1;
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

function cookieValue(request, name) {
  const header = request.headers.get('Cookie') ?? '';
  for (const chunk of header.split(';')) {
    const [key, ...rest] = chunk.trim().split('=');
    if (key === name) return decodeURIComponent(rest.join('='));
  }
  return '';
}

async function hashToken(token) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  let binary = '';
  for (const byte of new Uint8Array(digest)) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
}

function isReasonableToken(value) {
  return typeof value === 'string' && value.length >= 32 && value.length <= 256 && /^[A-Za-z0-9_-]+$/.test(value);
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
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function jsonError(message, status) {
  return json({ ok: false, error: message }, status);
}

function safeError(error) {
  return error instanceof Error ? error.message : String(error);
}
