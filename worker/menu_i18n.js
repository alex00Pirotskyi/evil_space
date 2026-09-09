import menuWorker from './menu.js';

const MAX_MENU_BYTES = 256 * 1024;
const MAX_NAME_LENGTH = 100;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/api/admin/menu/upload') {
      return handleLocalizedUpload(request, env, ctx);
    }

    const response = await menuWorker.fetch(request, env, ctx);
    if (!response.ok) return response;

    if (request.method === 'GET' && url.pathname === '/api/public/menu') {
      return localizePublicMenu(response, env);
    }
    if (request.method === 'GET' && url.pathname === '/api/admin/menu') {
      return localizeAdminMenu(response, env);
    }

    return response;
  },
};

async function handleLocalizedUpload(request, env, ctx) {
  const parsedBody = await readJson(request, MAX_MENU_BYTES);
  if (!parsedBody) return jsonError('Invalid JSON menu.', 400);

  const rawMenu =
    parsedBody.menu && typeof parsedBody.menu === 'object'
      ? parsedBody.menu
      : parsedBody;

  let normalized;
  try {
    normalized = normalizeMenuGroupNames(rawMenu);
  } catch (error) {
    return jsonError(error instanceof Error ? error.message : String(error), 400);
  }

  const transformedBody =
    parsedBody.menu && typeof parsedBody.menu === 'object'
      ? { ...parsedBody, menu: normalized.workerMenu }
      : normalized.workerMenu;

  const forwarded = new Request(request.url, {
    method: request.method,
    headers: request.headers,
    body: JSON.stringify(transformedBody),
  });

  const response = await menuWorker.fetch(forwarded, env, ctx);
  if (!response.ok) return response;

  const payload = await response.clone().json();
  const catalog = payload?.snapshot?.catalog;
  if (!catalog?.id || !Array.isArray(catalog.groups)) return response;

  const catalogId = Number(catalog.id);
  const statements = [];
  for (const group of catalog.groups) {
    const names = normalized.namesByGroup.get(String(group.id));
    if (!names) continue;
    statements.push(
      env.evil_space
        .prepare(`
          INSERT OR REPLACE INTO menu_group_translations
            (catalog_id, group_key, name_en, name_ru, name_vi)
          VALUES (?, ?, ?, ?, ?)
        `)
        .bind(catalogId, String(group.id), names.en, names.ru, names.vi),
    );
  }

  const localizedSource = localizedSourceJson(catalog.sourceJson, normalized.namesByGroup);
  statements.push(
    env.evil_space
      .prepare('UPDATE menu_catalogs SET source_json = ? WHERE id = ?')
      .bind(localizedSource, catalogId),
  );
  await env.evil_space.batch(statements);

  applyTranslationsToGroups(catalog.groups, normalized.namesByGroup);
  catalog.sourceJson = localizedSource;
  return replaceJson(response, payload);
}

async function localizePublicMenu(response, env) {
  const payload = await response.clone().json();
  if (!Array.isArray(payload?.menu?.groups) || payload.menu.groups.length === 0) {
    return response;
  }

  const catalog = await env.evil_space
    .prepare('SELECT id FROM menu_catalogs WHERE active = 1 LIMIT 1')
    .first();
  if (!catalog?.id) return response;

  const translations = await loadTranslations(env, Number(catalog.id));
  applyTranslationsToGroups(payload.menu.groups, translations);
  return replaceJson(response, payload);
}

async function localizeAdminMenu(response, env) {
  const payload = await response.clone().json();
  const catalog = payload?.snapshot?.catalog;
  if (!catalog?.id || !Array.isArray(catalog.groups)) return response;

  const translations = await loadTranslations(env, Number(catalog.id));
  applyTranslationsToGroups(catalog.groups, translations);
  return replaceJson(response, payload);
}

async function loadTranslations(env, catalogId) {
  const rows = await env.evil_space
    .prepare(`
      SELECT group_key, name_en, name_ru, name_vi
      FROM menu_group_translations
      WHERE catalog_id = ?
    `)
    .bind(catalogId)
    .all();

  const result = new Map();
  for (const row of rows.results ?? []) {
    result.set(String(row.group_key), {
      en: String(row.name_en),
      ru: String(row.name_ru),
      vi: String(row.name_vi),
    });
  }
  return result;
}

function applyTranslationsToGroups(groups, translations) {
  for (const group of groups) {
    const names = translations.get(String(group.id));
    if (names) group.name = { ...names };
    else if (typeof group.name === 'string') {
      group.name = {
        en: group.name,
        ru: group.name,
        vi: group.name,
      };
    }
  }
}

function localizedSourceJson(sourceJson, translations) {
  try {
    const source = JSON.parse(String(sourceJson));
    if (Array.isArray(source?.groups)) {
      applyTranslationsToGroups(source.groups, translations);
    }
    return JSON.stringify(source, null, 2);
  } catch {
    return String(sourceJson ?? '');
  }
}

export function normalizeMenuGroupNames(menu) {
  if (!menu || typeof menu !== 'object' || Array.isArray(menu)) {
    throw new Error('Menu must be a JSON object.');
  }
  if (!Array.isArray(menu.groups)) {
    throw new Error('Menu must contain groups.');
  }

  const namesByGroup = new Map();
  const groups = menu.groups.map((group) => {
    const id = normalizedId(group?.id);
    const names = normalizeLocalizedText(group?.name);
    if (!id || !names) {
      throw new Error('Every group needs a valid id and localized name.');
    }
    namesByGroup.set(id, names);
    return {
      ...group,
      id,
      name: names.en,
    };
  });

  return {
    workerMenu: { ...menu, groups },
    namesByGroup,
  };
}

function normalizeLocalizedText(value) {
  if (typeof value === 'string') {
    const text = cleanText(value);
    return text ? { en: text, ru: text, vi: text } : null;
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;

  const en = cleanText(value.en);
  const ru = cleanText(value.ru);
  const vi = cleanText(value.vi);
  if (!en || !ru || !vi) return null;
  return { en, ru, vi };
}

function normalizedId(value) {
  const text = typeof value === 'string' ? value.trim().toLowerCase() : '';
  return /^[a-z0-9][a-z0-9_-]{0,63}$/.test(text) ? text : '';
}

function cleanText(value) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  return text && text.length <= MAX_NAME_LENGTH ? text : '';
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

function jsonError(message, status) {
  return new Response(JSON.stringify({ ok: false, error: message }), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}
