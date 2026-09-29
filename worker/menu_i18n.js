import menuWorker from './menu.js';

const MAX_MENU_BYTES = 256 * 1024;
const MAX_NAME_LENGTH = 100;
const MAX_DESCRIPTION_LENGTH = 240;

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

  const headers = new Headers(request.headers);
  headers.delete('content-length');
  const forwarded = new Request(request.url, {
    method: request.method,
    headers,
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
    if (names) {
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

    for (const item of group.items ?? []) {
      const itemKey = String(item.id);
      const itemNames = normalized.namesByItem.get(itemKey);
      if (!itemNames) continue;
      const descriptions = normalized.descriptionsByItem.get(itemKey) ?? null;
      statements.push(
        env.evil_space
          .prepare(`
            INSERT OR REPLACE INTO menu_item_translations
              (catalog_id, item_key, name_en, name_ru, name_vi,
               description_en, description_ru, description_vi)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          `)
          .bind(
            catalogId,
            itemKey,
            itemNames.en,
            itemNames.ru,
            itemNames.vi,
            descriptions?.en ?? null,
            descriptions?.ru ?? null,
            descriptions?.vi ?? null,
          ),
      );
    }
  }

  const localizedSource = localizedSourceJson(
    catalog.sourceJson,
    normalized.namesByGroup,
    normalized.namesByItem,
    normalized.descriptionsByItem,
  );
  statements.push(
    env.evil_space
      .prepare('UPDATE menu_catalogs SET source_json = ? WHERE id = ?')
      .bind(localizedSource, catalogId),
  );
  await env.evil_space.batch(statements);

  applyTranslationsToGroups(
    catalog.groups,
    normalized.namesByGroup,
    normalized.namesByItem,
    normalized.descriptionsByItem,
  );
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
  applyTranslationsToGroups(
    payload.menu.groups,
    translations.namesByGroup,
    translations.namesByItem,
    translations.descriptionsByItem,
  );
  return replaceJson(response, payload);
}

async function localizeAdminMenu(response, env) {
  const payload = await response.clone().json();
  const catalog = payload?.snapshot?.catalog;
  if (!catalog?.id || !Array.isArray(catalog.groups)) return response;

  const translations = await loadTranslations(env, Number(catalog.id));
  applyTranslationsToGroups(
    catalog.groups,
    translations.namesByGroup,
    translations.namesByItem,
    translations.descriptionsByItem,
  );
  return replaceJson(response, payload);
}

async function loadTranslations(env, catalogId) {
  const [groupRows, itemRows] = await Promise.all([
    env.evil_space
      .prepare(`
        SELECT group_key, name_en, name_ru, name_vi
        FROM menu_group_translations
        WHERE catalog_id = ?
      `)
      .bind(catalogId)
      .all(),
    env.evil_space
      .prepare(`
        SELECT item_key, name_en, name_ru, name_vi,
               description_en, description_ru, description_vi
        FROM menu_item_translations
        WHERE catalog_id = ?
      `)
      .bind(catalogId)
      .all(),
  ]);

  const namesByGroup = new Map();
  for (const row of groupRows.results ?? []) {
    namesByGroup.set(String(row.group_key), {
      en: String(row.name_en),
      ru: String(row.name_ru),
      vi: String(row.name_vi),
    });
  }

  const namesByItem = new Map();
  const descriptionsByItem = new Map();
  for (const row of itemRows.results ?? []) {
    const key = String(row.item_key);
    namesByItem.set(key, {
      en: String(row.name_en),
      ru: String(row.name_ru),
      vi: String(row.name_vi),
    });
    if (row.description_en != null || row.description_ru != null || row.description_vi != null) {
      descriptionsByItem.set(key, {
        en: row.description_en == null ? '' : String(row.description_en),
        ru: row.description_ru == null ? '' : String(row.description_ru),
        vi: row.description_vi == null ? '' : String(row.description_vi),
      });
    }
  }

  return { namesByGroup, namesByItem, descriptionsByItem };
}

function applyTranslationsToGroups(groups, groupTranslations, itemTranslations, itemDescriptions) {
  for (const group of groups) {
    const names = groupTranslations.get(String(group.id));
    if (names) group.name = { ...names };
    else if (typeof group.name === 'string') {
      group.name = {
        en: group.name,
        ru: group.name,
        vi: group.name,
      };
    }

    for (const item of group.items ?? []) {
      const itemKey = String(item.id);
      const itemNames = itemTranslations.get(itemKey);
      if (itemNames) item.name = { ...itemNames };
      else if (typeof item.name === 'string') {
        item.name = { en: item.name, ru: item.name, vi: item.name };
      }

      const descriptions = itemDescriptions.get(itemKey);
      if (descriptions) item.description = { ...descriptions };
      else if (typeof item.description === 'string' && item.description.trim()) {
        item.description = {
          en: item.description,
          ru: item.description,
          vi: item.description,
        };
      }
    }
  }
}

function localizedSourceJson(sourceJson, groupTranslations, itemTranslations, itemDescriptions) {
  try {
    const source = JSON.parse(String(sourceJson));
    if (Array.isArray(source?.groups)) {
      applyTranslationsToGroups(
        source.groups,
        groupTranslations,
        itemTranslations,
        itemDescriptions,
      );
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
  const namesByItem = new Map();
  const descriptionsByItem = new Map();

  const groups = menu.groups.map((group) => {
    const id = normalizedId(group?.id);
    const names = normalizeLocalizedText(group?.name, MAX_NAME_LENGTH);
    if (!id || !names) {
      throw new Error('Every group needs a valid id and localized name.');
    }
    namesByGroup.set(id, names);

    const items = Array.isArray(group?.items)
      ? group.items.map((item) => {
          const itemId = normalizedId(item?.id);
          const itemNames = normalizeLocalizedText(item?.name, MAX_NAME_LENGTH);
          if (!itemId || !itemNames) {
            throw new Error(`Every item in ${id} needs a valid id and localized name.`);
          }
          namesByItem.set(itemId, itemNames);

          const description = normalizeOptionalLocalizedText(
            item?.description,
            MAX_DESCRIPTION_LENGTH,
          );
          if (description) descriptionsByItem.set(itemId, description);

          return {
            ...item,
            id: itemId,
            name: itemNames.en,
            description: description?.en ?? null,
          };
        })
      : group?.items;

    return {
      ...group,
      id,
      name: names.en,
      items,
    };
  });

  return {
    workerMenu: { ...menu, groups },
    namesByGroup,
    namesByItem,
    descriptionsByItem,
  };
}

function normalizeLocalizedText(value, maxLength) {
  if (typeof value === 'string') {
    const text = cleanText(value, maxLength);
    return text ? { en: text, ru: text, vi: text } : null;
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;

  const en = cleanText(value.en, maxLength);
  const ru = cleanText(value.ru, maxLength);
  const vi = cleanText(value.vi, maxLength);
  if (!en || !ru || !vi) return null;
  return { en, ru, vi };
}

function normalizeOptionalLocalizedText(value, maxLength) {
  if (value == null || value === '') return null;
  if (typeof value === 'string') {
    const text = cleanText(value, maxLength);
    return text ? { en: text, ru: text, vi: text } : null;
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;

  const raw = [value.en, value.ru, value.vi];
  if (raw.every((entry) => entry == null || String(entry).trim() === '')) return null;
  const en = cleanText(value.en, maxLength);
  const ru = cleanText(value.ru, maxLength);
  const vi = cleanText(value.vi, maxLength);
  if (!en || !ru || !vi) {
    throw new Error('Localized item description requires en, ru and vi.');
  }
  return { en, ru, vi };
}

function normalizedId(value) {
  const text = typeof value === 'string' ? value.trim().toLowerCase() : '';
  return /^[a-z0-9][a-z0-9_-]{0,63}$/.test(text) ? text : '';
}

function cleanText(value, maxLength) {
  if (typeof value !== 'string') return '';
  const text = value.trim().replace(/\s+/g, ' ');
  return text && text.length <= maxLength ? text : '';
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
