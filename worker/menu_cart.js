import localizedMenuWorker from './menu_i18n.js';
import { buildVietQrPayload, VIETCOMBANK_BIN } from './vietqr.js';
import {
  releasePromoForMenuOrder,
  reservePromoForMenuOrder,
  resolvePromoForCart,
} from './promo_engine.js';

const CUSTOMER_SESSION_COOKIE = '__Host-evil_customer_session';
const ORDER_TTL_SECONDS = 30 * 60;
const MAX_LINES = 20;
const MAX_QUANTITY = 20;
const MAX_TOTAL_QUANTITY = 100;
const MAX_ID_LENGTH = 64;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method === 'POST' && url.pathname === '/api/public/menu/order') {
      if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
      return handleCreateCartOrder(request, env, ctx);
    }
    return localizedMenuWorker.fetch(request, env, ctx);
  },
};

async function handleCreateCartOrder(request, env, ctx) {
  const body = await readJson(request, 32 * 1024);
  const normalized = normalizeCartInput(body);
  if (normalized.error) return jsonError(normalized.error, 400);

  const accountNumber = cleanAccountNumber(env.VIETQR_ACCOUNT_NUMBER);
  if (!accountNumber) return jsonError('Payment QR is not configured yet.', 503);
  const bankBin = cleanBankBin(env.VIETQR_BANK_BIN) || VIETCOMBANK_BIN;

  const requestedKeys = normalized.items.map((line) => line.itemId);
  const placeholders = requestedKeys.map(() => '?').join(', ');
  const rows = await env.evil_space
    .prepare(`
      SELECT mi.id, mi.catalog_id, mi.item_key, mi.group_key, mi.name, mi.price_vnd
      FROM menu_items mi
      JOIN menu_catalogs mc ON mc.id = mi.catalog_id
      WHERE mc.active = 1
        AND mi.enabled = 1
        AND mi.item_key IN (${placeholders})
    `)
    .bind(...requestedKeys)
    .all();

  const byKey = new Map((rows.results ?? []).map((row) => [String(row.item_key), row]));
  if (byKey.size !== requestedKeys.length) {
    return jsonError('One or more menu items are unavailable. Refresh the menu and try again.', 409);
  }

  const lines = normalized.items.map((requested) => {
    const item = byKey.get(requested.itemId);
    const unitPriceVnd = Number(item.price_vnd);
    return {
      itemId: Number(item.id),
      catalogId: Number(item.catalog_id),
      itemKey: String(item.item_key),
      groupKey: String(item.group_key),
      itemName: String(item.name),
      unitPriceVnd,
      quantity: requested.quantity,
      lineTotalVnd: unitPriceVnd * requested.quantity,
    };
  });

  const catalogId = lines[0].catalogId;
  if (lines.some((line) => line.catalogId !== catalogId)) {
    return jsonError('Menu changed while checking out. Refresh and try again.', 409);
  }

  const originalAmountVnd = lines.reduce((total, line) => total + line.lineTotalVnd, 0);
  if (!Number.isSafeInteger(originalAmountVnd) || originalAmountVnd <= 0 || originalAmountVnd > 999999999) {
    return jsonError('Invalid cart total.', 400);
  }

  const customer = await authenticatedCustomer(request, env);
  const requestedPromoGrantId = toPositiveInt(body?.promoGrantId);
  if (body?.promoGrantId != null && !requestedPromoGrantId) {
    return jsonError('Invalid promo selection.', 400);
  }
  if (requestedPromoGrantId && !customer) {
    return jsonError('Sign in to use this promo.', 401);
  }

  let promo = null;
  if (requestedPromoGrantId) {
    promo = await resolvePromoForCart(
      env,
      Number(customer.id),
      requestedPromoGrantId,
      lines,
    );
    if (promo.error) return jsonError(promo.error, 409);
  }
  const amountVnd = promo?.finalAmountVnd ?? originalAmountVnd;

  const now = nowSeconds();
  const expiresAt = now + ORDER_TTL_SECONDS;
  const publicToken = randomToken(32);
  const publicTokenHash = await hashToken(publicToken);
  const deviceId = customer ? await latestDeviceId(env, customer.id) : null;
  const summary = cartSummary(lines);
  const first = lines[0];

  let order = null;
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const orderCode = randomOrderCode();
    const paymentMessage = `EVIL ${orderCode}`;
    try {
      const inserted = await env.evil_space
        .prepare(`
          INSERT INTO menu_orders
            (public_token_hash, order_code, catalog_id, item_id, item_key,
             item_name, amount_vnd, original_amount_vnd, promo_eligible_amount_vnd,
             promo_discount_vnd, promo_grant_id, payment_message, status,
             created_at, expires_at, customer_id, device_id)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)
        `)
        .bind(
          publicTokenHash,
          orderCode,
          catalogId,
          first.itemId,
          lines.length === 1 ? first.itemKey : 'cart',
          summary,
          amountVnd,
          originalAmountVnd,
          promo?.eligibleAmountVnd ?? 0,
          promo?.discountVnd ?? 0,
          promo?.grantId ?? null,
          paymentMessage,
          now,
          expiresAt,
          customer?.id ?? null,
          deviceId,
        )
        .run();
      order = {
        id: Number(inserted.meta?.last_row_id ?? 0),
        orderCode,
        paymentMessage,
      };
      break;
    } catch (error) {
      if (!String(error).toLowerCase().includes('unique')) throw error;
    }
  }

  if (!order?.id) return jsonError('Could not create payment order.', 503);

  let promoReserved = false;
  try {
    await env.evil_space.batch(
      lines.map((line) =>
        env.evil_space
          .prepare(`
            INSERT INTO menu_order_items
              (order_id, item_id, item_key, item_name, unit_price_vnd,
               quantity, line_total_vnd, created_at, group_key)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          `)
          .bind(
            order.id,
            line.itemId,
            line.itemKey,
            line.itemName,
            line.unitPriceVnd,
            line.quantity,
            line.lineTotalVnd,
            now,
            line.groupKey,
          ),
      ),
    );

    if (promo) {
      const reserved = await reservePromoForMenuOrder(
        env,
        Number(customer.id),
        promo.grantId,
        order.id,
        promo,
        expiresAt,
        now,
      );
      if (reserved.error) {
        await env.evil_space.prepare('DELETE FROM menu_orders WHERE id = ?').bind(order.id).run();
        return jsonError(reserved.error, 409);
      }
      promoReserved = true;
    }
  } catch (error) {
    if (promoReserved) await releasePromoForMenuOrder(env, order.id, now).catch(() => null);
    await env.evil_space.prepare('DELETE FROM menu_orders WHERE id = ?').bind(order.id).run().catch(() => null);
    throw error;
  }

  const qrPayload = buildVietQrPayload({
    bankBin,
    accountNumber,
    amountVnd,
    description: order.paymentMessage,
  });

  const notification = notifyAdminsCartOrder(env, {
    id: order.id,
    orderCode: order.orderCode,
    paymentMessage: order.paymentMessage,
    amountVnd,
    originalAmountVnd,
    promoDiscountVnd: promo?.discountVnd ?? 0,
    promoName: promo?.name ?? null,
    lines,
  });
  if (ctx && typeof ctx.waitUntil === 'function') ctx.waitUntil(notification);
  else notification.catch((error) => console.error('Cart notification failed', safeError(error)));

  return json(
    {
      ok: true,
      order: {
        token: publicToken,
        orderCode: order.orderCode,
        itemId: lines.length === 1 ? first.itemKey : 'cart',
        itemName: summary,
        items: lines.map(publicLine),
        originalAmountVnd,
        promoEligibleAmountVnd: promo?.eligibleAmountVnd ?? 0,
        promoDiscountVnd: promo?.discountVnd ?? 0,
        promoGrantId: promo?.grantId ?? null,
        promoName: promo?.name ?? null,
        amountVnd,
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

export function normalizeCartInput(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'Invalid cart.' };
  }

  const rawLines = Array.isArray(body.items)
    ? body.items
    : body.itemId != null
      ? [{ itemId: body.itemId, quantity: 1 }]
      : [];
  if (rawLines.length < 1) return { error: 'Your cart is empty.' };
  if (rawLines.length > MAX_LINES) return { error: `Cart is limited to ${MAX_LINES} different items.` };

  const quantities = new Map();
  let totalQuantity = 0;
  for (const raw of rawLines) {
    const itemId = cleanId(raw?.itemId);
    const quantity = Number(raw?.quantity ?? 1);
    if (!itemId) return { error: 'Cart contains an invalid item.' };
    if (!Number.isSafeInteger(quantity) || quantity < 1 || quantity > MAX_QUANTITY) {
      return { error: `Each item quantity must be between 1 and ${MAX_QUANTITY}.` };
    }
    const next = (quantities.get(itemId) ?? 0) + quantity;
    if (next > MAX_QUANTITY) {
      return { error: `Each item quantity must be between 1 and ${MAX_QUANTITY}.` };
    }
    quantities.set(itemId, next);
    totalQuantity += quantity;
  }

  if (quantities.size > MAX_LINES || totalQuantity > MAX_TOTAL_QUANTITY) {
    return { error: `Cart is limited to ${MAX_TOTAL_QUANTITY} total items.` };
  }

  return {
    items: [...quantities.entries()].map(([itemId, quantity]) => ({ itemId, quantity })),
  };
}

function publicLine(line) {
  return {
    itemId: line.itemKey,
    groupId: line.groupKey,
    itemName: line.itemName,
    unitPriceVnd: line.unitPriceVnd,
    quantity: line.quantity,
    lineTotalVnd: line.lineTotalVnd,
  };
}

function cartSummary(lines) {
  if (lines.length === 1 && lines[0].quantity === 1) return lines[0].itemName;
  const parts = lines.slice(0, 3).map((line) => `${line.quantity} × ${line.itemName}`);
  if (lines.length > 3) parts.push(`+${lines.length - 3} more`);
  return parts.join(' · ').slice(0, 220);
}

async function authenticatedCustomer(request, env) {
  const token = cookieValue(request, CUSTOMER_SESSION_COOKIE);
  if (!token || token.length < 32 || token.length > 256) return null;
  const tokenHash = await hashToken(token);
  const now = nowSeconds();
  return env.evil_space
    .prepare(`
      SELECT c.id, c.name
      FROM customer_sessions s
      JOIN customers c ON c.id = s.customer_id
      WHERE s.token_hash = ? AND s.expires_at > ?
      LIMIT 1
    `)
    .bind(tokenHash, now)
    .first();
}

async function latestDeviceId(env, customerId) {
  const row = await env.evil_space
    .prepare(`
      SELECT device_id FROM customer_devices
      WHERE customer_id = ?
      ORDER BY last_seen_at DESC, id DESC
      LIMIT 1
    `)
    .bind(customerId)
    .first();
  return row?.device_id == null ? null : String(row.device_id);
}

async function notifyAdminsCartOrder(env, order) {
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
      const language = normalizeLanguage(link.language);
      const copy = cartOrderCopy(language, order);
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
        console.error('Telegram cart notification failed', safeError(error));
      }
    }),
  );
}

function cartOrderCopy(language, order) {
  const lines = order.lines
    .map((line) => `${line.quantity} × ${escapeHtml(line.itemName)} — ${formatVnd(line.lineTotalVnd)}`)
    .join('\n');
  const code = escapeHtml(order.orderCode);
  const reference = escapeHtml(order.paymentMessage);
  const total = formatVnd(order.amountVnd);
  const promo = order.promoDiscountVnd > 0
    ? `\n${escapeHtml(order.promoName ?? 'Promo')}: -${formatVnd(order.promoDiscountVnd)}\nOriginal: ${formatVnd(order.originalAmountVnd)}`
    : '';
  if (language === 'ru') {
    return {
      text: `🛒 <b>НОВЫЙ ЗАКАЗ</b>\n\nЗаказ: <b>${code}</b>\n${lines}${promo}\n\n<b>ИТОГО: ${total}</b>\nПеревод: <code>${reference}</code>\n\nПроверьте оплату в банке.`,
      button: '✅ ЗАКАЗ ОПЛАЧЕН',
    };
  }
  if (language === 'vi') {
    return {
      text: `🛒 <b>ĐƠN HÀNG MỚI</b>\n\nĐơn: <b>${code}</b>\n${lines}${promo}\n\n<b>TỔNG: ${total}</b>\nNội dung CK: <code>${reference}</code>\n\nHãy kiểm tra thanh toán trong ngân hàng.`,
      button: '✅ ĐÃ THANH TOÁN',
    };
  }
  return {
    text: `🛒 <b>NEW ORDER</b>\n\nOrder: <b>${code}</b>\n${lines}${promo}\n\n<b>TOTAL: ${total}</b>\nTransfer reference: <code>${reference}</code>\n\nCheck the bank payment, then confirm below.`,
    button: '✅ ORDER PAID',
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

function cleanId(value) {
  const text = typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (!text || text.length > MAX_ID_LENGTH || !/^[a-z0-9][a-z0-9_-]*$/.test(text)) return '';
  return text;
}

function toPositiveInt(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : 0;
}

function cleanAccountNumber(value) {
  const text = typeof value === 'string' ? value.trim() : '';
  return /^[A-Za-z0-9]{6,32}$/.test(text) ? text : '';
}

function cleanBankBin(value) {
  const text = typeof value === 'string' ? value.trim() : '';
  return /^\d{6}$/.test(text) ? text : '';
}

function normalizeLanguage(value) {
  const language = String(value ?? '').toLowerCase();
  return language === 'ru' || language === 'vi' ? language : 'en';
}

function formatVnd(value) {
  return `${Number(value).toLocaleString('en-US')} VND`;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
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

function randomOrderCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  let value = '';
  for (const byte of bytes) value += alphabet[byte % alphabet.length];
  return value;
}

function randomToken(size) {
  const bytes = crypto.getRandomValues(new Uint8Array(size));
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
}

async function hashToken(token) {
  const bytes = new TextEncoder().encode(token);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return arrayBufferToBase64Url(digest);
}

function arrayBufferToBase64Url(buffer) {
  let binary = '';
  for (const byte of new Uint8Array(buffer)) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
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
