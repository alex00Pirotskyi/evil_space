import { buildVietQrPayload, VIETCOMBANK_BIN } from './vietqr.js';

const SESSION_COOKIE = '__Host-evil_admin_session';
const ORDER_TTL_SECONDS = 30 * 60;
const MAX_MENU_BYTES = 256 * 1024;
const MAX_GROUPS = 50;
const MAX_ITEMS = 500;
const MAX_NAME_LENGTH = 100;
const MAX_DESCRIPTION_LENGTH = 240;
const MAX_ID_LENGTH = 64;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    try {
      if (request.method === 'GET' && url.pathname === '/api/public/menu') {
        return handlePublicMenu(env);
      }
      if (request.method === 'POST' && url.pathname === '/api/public/menu/order') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleCreateOrder(request, env, ctx);
      }
      if (request.method === 'GET' && url.pathname === '/api/public/menu/order') {
        return handleOrderStatus(url, env);
      }
      if (request.method === 'GET' && url.pathname === '/api/admin/menu') {
        return handleAdminMenu(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/menu/upload') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleUploadMenu(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/menu/order/paid') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleAdminMarkPaid(request, env);
      }
      return jsonError('Not found.', 404);
    } catch (error) {
      console.error('Menu API error', safeError(error));
      return jsonError('Server error. Please try again.', 500);
    }
  },
};

async function handlePublicMenu(env) {
  const catalog = await activeCatalog(env);
  if (!catalog) {
    return json({ ok: true, menu: { version: 0, updatedAt: 0, groups: [] } });
  }
  const groups = await catalogGroups(env, catalog.id, false);
  return json({
    ok: true,
    menu: {
      version: Number(catalog.version),
      updatedAt: Number(catalog.created_at),
      groups,
    },
  });
}

async function handleCreateOrder(request, env, ctx) {
  const body = await readJson(request, 16 * 1024);
  if (!body) return jsonError('Invalid request.', 400);

  const itemKey = cleanId(body.itemId);
  if (!itemKey) return jsonError('Menu item is required.', 400);

  const accountNumber = cleanAccountNumber(env.VIETQR_ACCOUNT_NUMBER);
  if (!accountNumber) {
    return jsonError('Payment QR is not configured yet.', 503);
  }
  const bankBin = cleanBankBin(env.VIETQR_BANK_BIN) || VIETCOMBANK_BIN;

  const item = await env.evil_space
    .prepare(`
      SELECT
        mi.id, mi.catalog_id, mi.item_key, mi.name, mi.price_vnd,
        mi.description, mc.version
      FROM menu_items mi
      JOIN menu_catalogs mc ON mc.id = mi.catalog_id
      WHERE mc.active = 1 AND mi.enabled = 1 AND mi.item_key = ?
      LIMIT 1
    `)
    .bind(itemKey)
    .first();

  if (!item) return jsonError('This menu item is unavailable.', 404);

  const now = nowSeconds();
  const expiresAt = now + ORDER_TTL_SECONDS;
  const token = randomToken(32);
  const tokenHash = await hashToken(token);

  let order = null;
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const orderCode = randomOrderCode();
    const paymentMessage = `EVIL ${orderCode}`;
    try {
      const result = await env.evil_space
        .prepare(`
          INSERT INTO menu_orders
            (public_token_hash, order_code, catalog_id, item_id, item_key,
             item_name, amount_vnd, payment_message, status, created_at, expires_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
        `)
        .bind(
          tokenHash,
          orderCode,
          item.catalog_id,
          item.id,
          item.item_key,
          item.name,
          item.price_vnd,
          paymentMessage,
          now,
          expiresAt,
        )
        .run();
      order = {
        id: Number(result.meta?.last_row_id ?? 0),
        orderCode,
        paymentMessage,
      };
      break;
    } catch (error) {
      if (!String(error).toLowerCase().includes('unique')) throw error;
    }
  }

  if (!order?.id) return jsonError('Could not create payment order.', 503);

  const qrPayload = buildVietQrPayload({
    bankBin,
    accountNumber,
    amountVnd: Number(item.price_vnd),
    description: order.paymentMessage,
  });

  const notification = notifyAdminsMenuOrder(env, {
    id: order.id,
    orderCode: order.orderCode,
    itemName: String(item.name),
    amountVnd: Number(item.price_vnd),
    paymentMessage: order.paymentMessage,
  });
  if (ctx && typeof ctx.waitUntil === 'function') ctx.waitUntil(notification);
  else notification.catch((error) => console.error('Menu notification failed', safeError(error)));

  return json(
    {
      ok: true,
      order: {
        token,
        orderCode: order.orderCode,
        itemId: String(item.item_key),
        itemName: String(item.name),
        amountVnd: Number(item.price_vnd),
        paymentMessage: order.paymentMessage,
        qrPayload,
        status: 'pending',
        createdAt: now,
        expiresAt,
      },
    },
    201,
  );
}

async function handleOrderStatus(url, env) {
  const token = url.searchParams.get('token') ?? '';
  if (!isReasonableToken(token)) return jsonError('Order not found.', 404);
  const tokenHash = await hashToken(token);
  const order = await env.evil_space
    .prepare(`
      SELECT id, order_code, item_key, item_name, amount_vnd, payment_message,
             status, created_at, expires_at, paid_at
      FROM menu_orders
      WHERE public_token_hash = ?
      LIMIT 1
    `)
    .bind(tokenHash)
    .first();
  if (!order) return jsonError('Order not found.', 404);

  let status = String(order.status);
  const now = nowSeconds();
  if (status === 'pending' && Number(order.expires_at) <= now) {
    await env.evil_space
      .prepare("UPDATE menu_orders SET status = 'expired' WHERE id = ? AND status = 'pending'")
      .bind(order.id)
      .run();
    status = 'expired';
  }

  return json({ ok: true, order: publicOrder(order, status) });
}

async function handleAdminMenu(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  return json({ ok: true, snapshot: await adminSnapshot(env) });
}

async function handleUploadMenu(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);

  const body = await readJson(request, MAX_MENU_BYTES);
  if (!body) return jsonError('Invalid JSON menu.', 400);
  const rawMenu = body.menu && typeof body.menu === 'object' ? body.menu : body;
  const current = await env.evil_space
    .prepare('SELECT COALESCE(MAX(version), 0) AS version FROM menu_catalogs')
    .first();
  const parsed = validateMenu(rawMenu, Number(current?.version ?? 0) + 1);
  if (parsed.error) return jsonError(parsed.error, 400);

  const normalized = parsed.menu;
  const sourceJson = JSON.stringify(normalized, null, 2);
  if (new TextEncoder().encode(sourceJson).length > MAX_MENU_BYTES) {
    return jsonError('Menu JSON is too large.', 400);
  }

  const now = nowSeconds();
  const insertCatalog = await env.evil_space
    .prepare(`
      INSERT INTO menu_catalogs
        (version, source_json, active, created_at, created_by_email)
      VALUES (?, ?, 0, ?, ?)
    `)
    .bind(normalized.version, sourceJson, now, session.email)
    .run();
  const catalogId = Number(insertCatalog.meta?.last_row_id ?? 0);
  if (!catalogId) return jsonError('Could not store menu.', 500);

  const statements = [];
  for (let groupOrder = 0; groupOrder < normalized.groups.length; groupOrder += 1) {
    const group = normalized.groups[groupOrder];
    for (let itemOrder = 0; itemOrder < group.items.length; itemOrder += 1) {
      const item = group.items[itemOrder];
      statements.push(
        env.evil_space
          .prepare(`
            INSERT INTO menu_items
              (catalog_id, group_key, group_name, group_order, item_key, name,
               price_vnd, description, item_order, enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          `)
          .bind(
            catalogId,
            group.id,
            group.name,
            groupOrder,
            item.id,
            item.name,
            item.priceVnd,
            item.description,
            itemOrder,
            item.enabled ? 1 : 0,
          ),
      );
    }
  }
  statements.push(env.evil_space.prepare('UPDATE menu_catalogs SET active = 0 WHERE active = 1'));
  statements.push(env.evil_space.prepare('UPDATE menu_catalogs SET active = 1 WHERE id = ?').bind(catalogId));
  await env.evil_space.batch(statements);

  return json({ ok: true, snapshot: await adminSnapshot(env) }, 201);
}

async function handleAdminMarkPaid(request, env) {
  const session = await authenticatedAdmin(request, env);
  if (!session) return jsonError('Sign in required.', 401);
  const body = await readJson(request, 16 * 1024);
  const id = toPositiveInt(body?.id);
  if (!id) return jsonError('Order is required.', 400);

  const result = await markOrderPaid(env, id, {
    email: session.email,
    telegramUserId: null,
  });
  if (result.status === 'missing') return jsonError('Order not found.', 404);
  if (result.status === 'expired') return jsonError('Order has expired.', 409);
  return json({ ok: true, order: result.order, snapshot: await adminSnapshot(env) });
}

export async function markMenuOrderPaidByTelegram(env, orderId, telegramUserId) {
  const id = toPositiveInt(orderId);
  const userId = toPositiveInt(telegramUserId);
  if (!id || !userId) return { status: 'invalid' };

  const admin = await env.evil_space
    .prepare(`
      SELECT a.email
      FROM admin_telegram_links atl
      JOIN admins a ON a.id = atl.admin_id
      WHERE atl.telegram_user_id = ? AND a.status = 'approved'
      LIMIT 1
    `)
    .bind(userId)
    .first();
  if (!admin) return { status: 'forbidden' };

  return markOrderPaid(env, id, {
    email: String(admin.email),
    telegramUserId: userId,
  });
}

async function markOrderPaid(env, id, actor) {
  const now = nowSeconds();
  const current = await env.evil_space
    .prepare(`
      SELECT id, order_code, item_name, amount_vnd, payment_message, status,
             created_at, expires_at, paid_at, paid_by_email
      FROM menu_orders
      WHERE id = ?
      LIMIT 1
    `)
    .bind(id)
    .first();
  if (!current) return { status: 'missing' };

  if (current.status === 'paid') {
    return { status: 'paid', order: adminOrder(current) };
  }
  if (current.status !== 'pending' || Number(current.expires_at) <= now) {
    if (current.status === 'pending') {
      await env.evil_space
        .prepare("UPDATE menu_orders SET status = 'expired' WHERE id = ? AND status = 'pending'")
        .bind(id)
        .run();
    }
    return { status: 'expired', order: adminOrder({ ...current, status: 'expired' }) };
  }

  const result = await env.evil_space
    .prepare(`
      UPDATE menu_orders
      SET status = 'paid', paid_at = ?, paid_by_email = ?, paid_by_telegram_user_id = ?
      WHERE id = ? AND status = 'pending'
    `)
    .bind(now, actor.email, actor.telegramUserId, id)
    .run();
  if (Number(result.meta?.changes ?? 0) < 1) {
    const raced = await env.evil_space
      .prepare(`
        SELECT id, order_code, item_name, amount_vnd, payment_message, status,
               created_at, expires_at, paid_at, paid_by_email
        FROM menu_orders WHERE id = ?
      `)
      .bind(id)
      .first();
    return raced?.status === 'paid'
      ? { status: 'paid', order: adminOrder(raced) }
      : { status: 'missing' };
  }

  return {
    status: 'paid',
    order: adminOrder({
      ...current,
      status: 'paid',
      paid_at: now,
      paid_by_email: actor.email,
    }),
  };
}

async function adminSnapshot(env) {
  const catalog = await activeCatalog(env);
  const groups = catalog ? await catalogGroups(env, catalog.id, true) : [];
  const orders = await env.evil_space
    .prepare(`
      SELECT id, order_code, item_name, amount_vnd, payment_message, status,
             created_at, expires_at, paid_at, paid_by_email
      FROM menu_orders
      ORDER BY CASE status WHEN 'pending' THEN 0 ELSE 1 END,
               created_at DESC, id DESC
      LIMIT 100
    `)
    .all();

  return {
    paymentConfigured: Boolean(cleanAccountNumber(env.VIETQR_ACCOUNT_NUMBER)),
    bankBin: cleanBankBin(env.VIETQR_BANK_BIN) || VIETCOMBANK_BIN,
    catalog: catalog
      ? {
          id: Number(catalog.id),
          version: Number(catalog.version),
          createdAt: Number(catalog.created_at),
          createdByEmail: String(catalog.created_by_email),
          sourceJson: String(catalog.source_json),
          groups,
        }
      : null,
    orders: (orders.results ?? []).map(adminOrder),
  };
}

async function activeCatalog(env) {
  return env.evil_space
    .prepare(`
      SELECT id, version, source_json, created_at, created_by_email
      FROM menu_catalogs
      WHERE active = 1
      LIMIT 1
    `)
    .first();
}

async function catalogGroups(env, catalogId, includeDisabled) {
  const rows = await env.evil_space
    .prepare(`
      SELECT group_key, group_name, group_order, item_key, name, price_vnd,
             description, item_order, enabled
      FROM menu_items
      WHERE catalog_id = ? ${includeDisabled ? '' : 'AND enabled = 1'}
      ORDER BY group_order, item_order, id
    `)
    .bind(catalogId)
    .all();

  const groups = [];
  const byKey = new Map();
  for (const row of rows.results ?? []) {
    const key = String(row.group_key);
    let group = byKey.get(key);
    if (!group) {
      group = { id: key, name: String(row.group_name), items: [] };
      byKey.set(key, group);
      groups.push(group);
    }
    group.items.push({
      id: String(row.item_key),
      name: String(row.name),
      priceVnd: Number(row.price_vnd),
      description: row.description == null ? null : String(row.description),
      enabled: Number(row.enabled) === 1,
    });
  }
  return groups;
}

function validateMenu(value, defaultVersion) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { error: 'Menu must be a JSON object.' };
  }
  const rawGroups = value.groups;
  if (!Array.isArray(rawGroups) || rawGroups.length < 1 || rawGroups.length > MAX_GROUPS) {
    return { error: `Menu must contain 1-${MAX_GROUPS} groups.` };
  }

  const version = Number.isSafeInteger(Number(value.version)) && Number(value.version) > 0
    ? Number(value.version)
    : defaultVersion;
  const groupIds = new Set();
  const itemIds = new Set();
  let itemCount = 0;
  const groups = [];

  for (const rawGroup of rawGroups) {
    const id = cleanId(rawGroup?.id);
    const name = cleanText(rawGroup?.name, MAX_NAME_LENGTH);
    if (!id || !name) return { error: 'Every group needs a valid id and name.' };
    if (groupIds.has(id)) return { error: `Duplicate group id: ${id}` };
    groupIds.add(id);
    if (!Array.isArray(rawGroup.items) || rawGroup.items.length < 1) {
      return { error: `Group ${id} must contain at least one item.` };
    }

    const items = [];
    for (const rawItem of rawGroup.items) {
      itemCount += 1;
      if (itemCount > MAX_ITEMS) return { error: `Menu is limited to ${MAX_ITEMS} items.` };
      const itemId = cleanId(rawItem?.id);
      const itemName = cleanText(rawItem?.name, MAX_NAME_LENGTH);
      const priceVnd = Number(rawItem?.priceVnd);
      if (!itemId || !itemName) return { error: `Every item in ${id} needs a valid id and name.` };
      if (itemIds.has(itemId)) return { error: `Duplicate item id: ${itemId}` };
      if (!Number.isSafeInteger(priceVnd) || priceVnd <= 0 || priceVnd > 999999999) {
        return { error: `Invalid price for item ${itemId}.` };
      }
      itemIds.add(itemId);

      let description = null;
      if (rawItem?.description != null) {
        description = cleanText(rawItem.description, MAX_DESCRIPTION_LENGTH);
        if (!description) return { error: `Invalid description for item ${itemId}.` };
      }
      items.push({
        id: itemId,
        name: itemName,
        priceVnd,
        description,
        enabled: rawItem?.enabled !== false,
      });
    }
    groups.push({ id, name, items });
  }

  return { menu: { version, groups } };
}

async function authenticatedAdmin(request, env) {
  const token = cookieValue(request, SESSION_COOKIE);
  if (!token || !isReasonableToken(token)) return null;
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  return env.evil_space
    .prepare(`
      SELECT a.id, a.email
      FROM admin_sessions s
      JOIN admins a ON a.id = s.admin_id
      WHERE s.token_hash = ? AND s.expires_at > ? AND a.status = 'approved'
      LIMIT 1
    `)
    .bind(tokenHash, now)
    .first();
}

async function notifyAdminsMenuOrder(env, order) {
  if (!env.TELEGRAM_BOT_TOKEN) return;
  const links = await env.evil_space
    .prepare(`
      SELECT telegram_chat_id, language
      FROM admin_telegram_links
      WHERE notifications_enabled = 1 AND purchase_notifications = 1
    `)
    .all();

  await Promise.all(
    (links.results ?? []).map(async (link) => {
      const lang = normalizeLanguage(link.language);
      const copy = menuOrderCopy(lang, order);
      try {
        await telegramApi(env, 'sendMessage', {
          chat_id: link.telegram_chat_id,
          text: copy.text,
          parse_mode: 'HTML',
          reply_markup: {
            inline_keyboard: [[{ text: copy.button, callback_data: `mp:${order.id}` }]],
          },
        });
      } catch (error) {
        console.error('Telegram menu order notification failed', safeError(error));
      }
    }),
  );
}

function menuOrderCopy(lang, order) {
  const amount = formatVnd(order.amountVnd);
  const safeItem = escapeHtml(order.itemName);
  const safeCode = escapeHtml(order.orderCode);
  const safeMessage = escapeHtml(order.paymentMessage);
  if (lang === 'ru') {
    return {
      text: `🥤 <b>НОВЫЙ ЗАКАЗ МЕНЮ</b>\n\nЗаказ: <b>${safeCode}</b>\n${safeItem}\n${amount}\n\nПеревод: <code>${safeMessage}</code>\n\nПроверьте оплату в банке.`,
      button: '✅ ТОВАР ОПЛАЧЕН',
    };
  }
  if (lang === 'vi') {
    return {
      text: `🥤 <b>ĐƠN MENU MỚI</b>\n\nĐơn: <b>${safeCode}</b>\n${safeItem}\n${amount}\n\nNội dung CK: <code>${safeMessage}</code>\n\nHãy kiểm tra thanh toán trong ngân hàng.`,
      button: '✅ ĐÃ THANH TOÁN',
    };
  }
  return {
    text: `🥤 <b>NEW MENU ORDER</b>\n\nOrder: <b>${safeCode}</b>\n${safeItem}\n${amount}\n\nTransfer reference: <code>${safeMessage}</code>\n\nCheck the bank payment, then confirm below.`,
    button: '✅ ITEM PAID',
  };
}

async function telegramApi(env, method, payload) {
  const response = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const data = await response.json().catch(() => null);
  if (!response.ok || data?.ok !== true) {
    throw new Error(`Telegram ${method} failed (${response.status}).`);
  }
  return data;
}

function publicOrder(order, status = String(order.status)) {
  return {
    orderCode: String(order.order_code),
    itemId: String(order.item_key),
    itemName: String(order.item_name),
    amountVnd: Number(order.amount_vnd),
    paymentMessage: String(order.payment_message),
    status,
    createdAt: Number(order.created_at),
    expiresAt: Number(order.expires_at),
    paidAt: order.paid_at == null ? null : Number(order.paid_at),
  };
}

function adminOrder(order) {
  return {
    id: Number(order.id),
    orderCode: String(order.order_code),
    itemName: String(order.item_name),
    amountVnd: Number(order.amount_vnd),
    paymentMessage: String(order.payment_message),
    status: String(order.status),
    createdAt: Number(order.created_at),
    expiresAt: Number(order.expires_at),
    paidAt: order.paid_at == null ? null : Number(order.paid_at),
    paidByEmail: order.paid_by_email == null ? null : String(order.paid_by_email),
  };
}

function cleanId(value) {
  const text = typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (!text || text.length > MAX_ID_LENGTH || !/^[a-z0-9][a-z0-9_-]*$/.test(text)) return '';
  return text;
}

function cleanText(value, maxLength) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  return text && text.length <= maxLength ? text : '';
}

function cleanAccountNumber(value) {
  const text = typeof value === 'string' ? value.trim() : '';
  return /^[A-Za-z0-9]{6,32}$/.test(text) ? text : '';
}

function cleanBankBin(value) {
  const text = typeof value === 'string' ? value.trim() : '';
  return /^\d{6}$/.test(text) ? text : '';
}

function cookieValue(request, name) {
  const raw = request.headers.get('cookie') ?? '';
  for (const part of raw.split(';')) {
    const separator = part.indexOf('=');
    if (separator < 0) continue;
    if (part.slice(0, separator).trim() === name) return part.slice(separator + 1).trim();
  }
  return '';
}

function isReasonableToken(value) {
  return typeof value === 'string' && value.length >= 32 && value.length <= 256 && /^[A-Za-z0-9_-]+$/.test(value);
}

async function hashToken(value) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return bytesToBase64Url(new Uint8Array(digest));
}

function randomToken(byteCount) {
  const bytes = new Uint8Array(byteCount);
  crypto.getRandomValues(bytes);
  return bytesToBase64Url(bytes);
}

function bytesToBase64Url(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
}

function randomOrderCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  let code = '';
  for (const byte of bytes) code += alphabet[byte % alphabet.length];
  return code;
}

function toPositiveInt(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : 0;
}

function normalizeLanguage(value) {
  const lang = typeof value === 'string' ? value.toLowerCase() : '';
  return lang === 'ru' || lang === 'vi' ? lang : 'en';
}

function formatVnd(value) {
  return `${Number(value).toLocaleString('en-US')} VND`;
}

function isSameOrigin(request, url) {
  const origin = request.headers.get('Origin');
  return origin === url.origin;
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

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
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
