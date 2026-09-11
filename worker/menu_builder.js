import localizedMenuWorker, { normalizeMenuGroupNames } from './menu_i18n.js';

const ADMIN_SESSION_COOKIE = '__Host-evil_admin_session';
const MAX_MENU_BYTES = 256 * 1024;
const MAX_GROUPS = 50;
const MAX_ITEMS = 500;
const MAX_NAME_LENGTH = 100;
const MAX_DESCRIPTION_LENGTH = 240;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    try {
      if (request.method === 'GET' && url.pathname === '/api/admin/menu/draft') {
        return handleGetDraft(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/menu/draft') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handleSaveDraft(request, env);
      }
      if (request.method === 'POST' && url.pathname === '/api/admin/menu/publish') {
        if (!isSameOrigin(request, url)) return jsonError('Invalid origin.', 403);
        return handlePublish(request, env, ctx);
      }
      return jsonError('Not found.', 404);
    } catch (error) {
      console.error('Menu builder error', safeError(error));
      return jsonError('Menu builder request failed. Please try again.', 500);
    }
  },
};

async function handleGetDraft(request, env) {
  const admin = await authenticatedAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const [draft, active, references] = await Promise.all([
    env.evil_space.prepare('SELECT source_json, base_catalog_id, updated_at, updated_by_email FROM menu_drafts WHERE id = 1').first(),
    env.evil_space.prepare('SELECT id, source_json, version FROM menu_catalogs WHERE active = 1 LIMIT 1').first(),
    promotionReferences(env),
  ]);

  let menu = null;
  let source = 'empty';
  let updatedAt = 0;
  let updatedByEmail = '';
  let baseCatalogId = active?.id == null ? null : Number(active.id);
  if (draft?.source_json) {
    menu = parseStoredMenu(draft.source_json);
    source = 'draft';
    updatedAt = Number(draft.updated_at ?? 0);
    updatedByEmail = String(draft.updated_by_email ?? '');
    baseCatalogId = draft.base_catalog_id == null ? baseCatalogId : Number(draft.base_catalog_id);
  } else if (active?.source_json) {
    menu = parseStoredMenu(active.source_json);
    source = 'published';
  }
  if (!menu) menu = { version: Number(active?.version ?? 1), groups: [] };

  return json({
    ok: true,
    draft: {
      source,
      baseCatalogId,
      updatedAt,
      updatedByEmail,
      menu,
      promoReferences: references,
    },
  });
}

async function handleSaveDraft(request, env) {
  const admin = await authenticatedAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request, MAX_MENU_BYTES);
  const raw = body?.menu ?? body;
  const checked = validateDraftMenu(raw, { allowEmptyGroups: true });
  if (checked.error) return jsonError(checked.error, 400);
  const active = await env.evil_space.prepare('SELECT id FROM menu_catalogs WHERE active = 1 LIMIT 1').first();
  const now = nowSeconds();
  await env.evil_space
    .prepare(`
      INSERT INTO menu_drafts (id, source_json, base_catalog_id, updated_at, updated_by_email)
      VALUES (1, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        source_json = excluded.source_json,
        base_catalog_id = excluded.base_catalog_id,
        updated_at = excluded.updated_at,
        updated_by_email = excluded.updated_by_email
    `)
    .bind(JSON.stringify(checked.menu, null, 2), active?.id ?? null, now, String(admin.email))
    .run();
  return json({
    ok: true,
    draft: {
      source: 'draft',
      baseCatalogId: active?.id == null ? null : Number(active.id),
      updatedAt: now,
      updatedByEmail: String(admin.email),
      menu: checked.menu,
      promoReferences: await promotionReferences(env),
    },
  });
}

async function handlePublish(request, env, ctx) {
  const admin = await authenticatedAdmin(request, env);
  if (!admin) return jsonError('Sign in required.', 401);
  const body = await readJson(request, MAX_MENU_BYTES);
  let raw = body?.menu ?? null;
  if (!raw) {
    const draft = await env.evil_space.prepare('SELECT source_json FROM menu_drafts WHERE id = 1').first();
    raw = draft?.source_json ? parseStoredMenu(draft.source_json) : null;
  }
  const checked = validateDraftMenu(raw, { allowEmptyGroups: false });
  if (checked.error) return jsonError(checked.error, 400);

  const headers = new Headers(request.headers);
  headers.delete('content-length');
  headers.set('Content-Type', 'application/json');
  const forwarded = new Request(new URL('/api/admin/menu/upload', request.url), {
    method: 'POST',
    headers,
    body: JSON.stringify({ menu: checked.menu }),
  });
  const response = await localizedMenuWorker.fetch(forwarded, env, ctx);
  if (!response.ok) return response;
  const payload = await response.clone().json();
  const catalogId = Number(payload?.snapshot?.catalog?.id ?? 0) || null;
  const now = nowSeconds();
  await env.evil_space
    .prepare(`
      INSERT INTO menu_drafts (id, source_json, base_catalog_id, updated_at, updated_by_email)
      VALUES (1, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        source_json = excluded.source_json,
        base_catalog_id = excluded.base_catalog_id,
        updated_at = excluded.updated_at,
        updated_by_email = excluded.updated_by_email
    `)
    .bind(JSON.stringify(checked.menu, null, 2), catalogId, now, String(admin.email))
    .run();

  return replaceJson(response, {
    ...payload,
    draft: {
      source: 'published',
      baseCatalogId: catalogId,
      updatedAt: now,
      updatedByEmail: String(admin.email),
      menu: checked.menu,
      promoReferences: await promotionReferences(env),
    },
  });
}

export function validateDraftMenu(value, { allowEmptyGroups = false } = {}) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { error: 'Menu must be a JSON object.' };
  }
  let localized;
  try {
    localized = normalizeMenuGroupNames(value);
  } catch (error) {
    if (allowEmptyGroups && Array.isArray(value.groups) && value.groups.length === 0) {
      return { menu: { version: positiveVersion(value.version), groups: [] } };
    }
    return { error: error instanceof Error ? error.message : String(error) };
  }
  const rawGroups = Array.isArray(value.groups) ? value.groups : [];
  if ((!allowEmptyGroups && rawGroups.length < 1) || rawGroups.length > MAX_GROUPS) {
    return { error: `Menu must contain ${allowEmptyGroups ? '0' : '1'}-${MAX_GROUPS} groups.` };
  }
  const groupIds = new Set();
  const itemIds = new Set();
  let itemCount = 0;
  const groups = [];
  for (const rawGroup of rawGroups) {
    const id = cleanId(rawGroup?.id);
    if (!id || groupIds.has(id)) return { error: `Invalid or duplicate group id: ${String(rawGroup?.id ?? '')}` };
    groupIds.add(id);
    const names = normalizeLocalizedName(rawGroup?.name);
    if (!names) return { error: `Group ${id} needs English, Russian and Vietnamese names.` };
    const rawItems = Array.isArray(rawGroup?.items) ? rawGroup.items : [];
    if (!allowEmptyGroups && rawItems.length < 1) return { error: `Group ${id} must contain at least one item.` };
    const items = [];
    for (const rawItem of rawItems) {
      itemCount += 1;
      if (itemCount > MAX_ITEMS) return { error: `Menu is limited to ${MAX_ITEMS} items.` };
      const itemId = cleanId(rawItem?.id);
      const name = cleanText(rawItem?.name, MAX_NAME_LENGTH);
      const priceVnd = Number(rawItem?.priceVnd);
      if (!itemId || !name || itemIds.has(itemId)) return { error: `Invalid or duplicate item in ${id}.` };
      if (!Number.isSafeInteger(priceVnd) || priceVnd <= 0 || priceVnd > 999999999) return { error: `Invalid price for item ${itemId}.` };
      itemIds.add(itemId);
      let description = null;
      if (rawItem?.description != null && String(rawItem.description).trim() !== '') {
        description = cleanText(rawItem.description, MAX_DESCRIPTION_LENGTH);
        if (!description) return { error: `Invalid description for item ${itemId}.` };
      }
      items.push({
        id: itemId,
        name,
        priceVnd,
        description,
        enabled: rawItem?.enabled !== false,
      });
    }
    groups.push({ id, name: names, items });
  }
  return { menu: { version: positiveVersion(value.version), groups } };
}

async function promotionReferences(env) {
  const result = await env.evil_space
    .prepare(`
      SELECT pg.group_key, p.id, p.name, p.promo_key
      FROM marketing_promotion_groups pg
      JOIN marketing_promotions p ON p.id = pg.promotion_id
      WHERE p.active = 1 AND p.superseded_at IS NULL
      ORDER BY pg.group_key, p.name
    `)
    .all();
  const map = {};
  for (const row of result.results ?? []) {
    const key = String(row.group_key);
    map[key] ??= [];
    map[key].push({ id: Number(row.id), name: String(row.name), promoKey: String(row.promo_key) });
  }
  return map;
}

function parseStoredMenu(value) {
  try {
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function normalizeLocalizedName(value) {
  if (typeof value === 'string') {
    const text = cleanText(value, MAX_NAME_LENGTH);
    return text ? { en: text, ru: text, vi: text } : null;
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const en = cleanText(value.en, MAX_NAME_LENGTH);
  const ru = cleanText(value.ru, MAX_NAME_LENGTH);
  const vi = cleanText(value.vi, MAX_NAME_LENGTH);
  return en && ru && vi ? { en, ru, vi } : null;
}

function positiveVersion(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : 1;
}

function cleanId(value) {
  const text = typeof value === 'string' ? value.trim().toLowerCase() : '';
  return /^[a-z0-9][a-z0-9_-]{0,63}$/.test(text) ? text : '';
}

function cleanText(value, maxLength) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  return text && text.length <= maxLength ? text : '';
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

function replaceJson(response, payload) {
  const headers = new Headers(response.headers);
  headers.delete('content-length');
  headers.set('Content-Type', 'application/json; charset=utf-8');
  return new Response(JSON.stringify(payload), {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
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
