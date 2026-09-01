from pathlib import Path
import re


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1))


def replace_all_required(path, old, new, minimum=1):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f'{path}: expected >= {minimum} matches, found {count}: {old[:80]!r}')
    p.write_text(text.replace(old, new))


def insert_before(path, marker, addition):
    p = Path(path)
    text = p.read_text()
    if marker not in text:
        raise SystemExit(f'{path}: marker not found: {marker[:80]!r}')
    p.write_text(text.replace(marker, addition + marker, 1))


Path('migrations/0009_pricing_promotions.sql').write_text(r'''CREATE TABLE IF NOT EXISTS pricing_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  day_pass_vnd INTEGER NOT NULL CHECK (day_pass_vnd > 0),
  month_pass_vnd INTEGER NOT NULL CHECK (month_pass_vnd > 0),
  locker_month_vnd INTEGER NOT NULL CHECK (locker_month_vnd > 0),
  updated_at INTEGER NOT NULL DEFAULT 0,
  updated_by_email TEXT
);

INSERT OR IGNORE INTO pricing_settings
  (id, day_pass_vnd, month_pass_vnd, locker_month_vnd, updated_at)
VALUES (1, 200000, 2500000, 1000000, 0);

CREATE TABLE IF NOT EXISTS promotions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  description TEXT NOT NULL,
  start_day INTEGER NOT NULL,
  end_day INTEGER NOT NULL,
  start_minute INTEGER,
  end_minute INTEGER,
  day_pass_vnd INTEGER,
  month_pass_vnd INTEGER,
  locker_month_vnd INTEGER,
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
  created_at INTEGER NOT NULL,
  created_by_email TEXT NOT NULL,
  CHECK (end_day >= start_day),
  CHECK ((start_minute IS NULL AND end_minute IS NULL) OR
         (start_minute >= 0 AND start_minute < end_minute AND end_minute <= 1440)),
  CHECK (day_pass_vnd IS NULL OR day_pass_vnd > 0),
  CHECK (month_pass_vnd IS NULL OR month_pass_vnd > 0),
  CHECK (locker_month_vnd IS NULL OR locker_month_vnd > 0),
  CHECK (day_pass_vnd IS NOT NULL OR month_pass_vnd IS NOT NULL OR locker_month_vnd IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_promotions_active_window
ON promotions(enabled, start_day, end_day, id DESC);
''')

Path('worker/pricing.js').write_text(r'''import {
  nhaTrangSecondsIntoDay,
  serviceDayForOffset,
} from './booking_rules.js';

export const DEFAULT_DAY_PASS_VND = 200000;
export const DEFAULT_MONTH_PASS_VND = 2500000;
export const DEFAULT_LOCKER_MONTH_VND = 1000000;

function positivePrice(value, fallback) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : fallback;
}

export function promotionApplies(promotion, serviceDay, now) {
  if (Number(promotion?.enabled ?? 0) !== 1) return false;
  const target = Number(serviceDay);
  const startDay = Number(promotion?.start_day ?? 0);
  const endDay = Number(promotion?.end_day ?? 0);
  if (!Number.isFinite(target) || target < startDay || target > endDay) return false;

  const startMinute = promotion?.start_minute;
  const endMinute = promotion?.end_minute;
  if (startMinute == null && endMinute == null) return true;
  if (startMinute == null || endMinute == null) return false;

  const today = serviceDayForOffset(0, now);
  if (target !== today) return false;
  const minute = Math.floor(nhaTrangSecondsIntoDay(now) / 60);
  return minute >= Number(startMinute) && minute < Number(endMinute);
}

export async function loadPricingConfig(env) {
  const row = await env.evil_space
    .prepare(`
      SELECT day_pass_vnd, month_pass_vnd, locker_month_vnd
      FROM pricing_settings
      WHERE id = 1
    `)
    .first();
  return {
    dayPassVnd: positivePrice(row?.day_pass_vnd, DEFAULT_DAY_PASS_VND),
    monthPassVnd: positivePrice(row?.month_pass_vnd, DEFAULT_MONTH_PASS_VND),
    lockerMonthVnd: positivePrice(row?.locker_month_vnd, DEFAULT_LOCKER_MONTH_VND),
  };
}

export async function listPromotions(env) {
  const result = await env.evil_space
    .prepare(`
      SELECT id, description, start_day, end_day, start_minute, end_minute,
             day_pass_vnd, month_pass_vnd, locker_month_vnd, enabled,
             created_at, created_by_email
      FROM promotions
      ORDER BY enabled DESC, start_day DESC, id DESC
      LIMIT 100
    `)
    .all();
  return result.results ?? [];
}

export async function activePromotion(env, serviceDay, now) {
  const result = await env.evil_space
    .prepare(`
      SELECT id, description, start_day, end_day, start_minute, end_minute,
             day_pass_vnd, month_pass_vnd, locker_month_vnd, enabled,
             created_at, created_by_email
      FROM promotions
      WHERE enabled = 1 AND start_day <= ? AND end_day >= ?
      ORDER BY id DESC
      LIMIT 30
    `)
    .bind(serviceDay, serviceDay)
    .all();
  return (result.results ?? []).find((item) => promotionApplies(item, serviceDay, now)) ?? null;
}

export async function resolvePricing(env, serviceDay, now) {
  const [base, promotion] = await Promise.all([
    loadPricingConfig(env),
    activePromotion(env, serviceDay, now),
  ]);
  return {
    base,
    promotion,
    dayPassVnd: positivePrice(promotion?.day_pass_vnd, base.dayPassVnd),
    monthPassVnd: positivePrice(promotion?.month_pass_vnd, base.monthPassVnd),
    lockerMonthVnd: positivePrice(promotion?.locker_month_vnd, base.lockerMonthVnd),
  };
}

export async function pricingSnapshot(env, now) {
  const today = serviceDayForOffset(0, now);
  const resolved = await resolvePricing(env, today, now);
  return {
    day_pass_vnd: resolved.base.dayPassVnd,
    month_pass_vnd: resolved.base.monthPassVnd,
    locker_month_vnd: resolved.base.lockerMonthVnd,
    current_day_pass_vnd: resolved.dayPassVnd,
    current_month_pass_vnd: resolved.monthPassVnd,
    current_locker_month_vnd: resolved.lockerMonthVnd,
    active_promo_id: Number(resolved.promotion?.id ?? 0),
    active_promo_description: resolved.promotion?.description ?? '',
  };
}
''')

Path('worker/pricing_test.mjs').write_text(r'''import test from 'node:test';
import assert from 'node:assert/strict';

import { promotionApplies } from './pricing.js';
import { serviceDayForOffset } from './booking_rules.js';

function utcSeconds(value) {
  return Math.floor(Date.parse(value) / 1000);
}

test('date-only promotion applies to every service day in its inclusive range', () => {
  const now = utcSeconds('2026-09-20T05:00:00Z');
  const today = serviceDayForOffset(0, now);
  const promotion = {
    enabled: 1,
    start_day: today,
    end_day: today + 3 * 86400,
    start_minute: null,
    end_minute: null,
  };
  assert.equal(promotionApplies(promotion, today, now), true);
  assert.equal(promotionApplies(promotion, today + 3 * 86400, now), true);
  assert.equal(promotionApplies(promotion, today + 4 * 86400, now), false);
});

test('time-limited promotion applies only to today while the Nha Trang clock is inside the window', () => {
  const inside = utcSeconds('2026-09-20T14:30:00Z');
  const outside = utcSeconds('2026-09-20T16:30:00Z');
  const today = serviceDayForOffset(0, inside);
  const promotion = {
    enabled: 1,
    start_day: today,
    end_day: today + 86400,
    start_minute: 20 * 60,
    end_minute: 23 * 60,
  };
  assert.equal(promotionApplies(promotion, today, inside), true);
  assert.equal(promotionApplies(promotion, today, outside), false);
  assert.equal(promotionApplies(promotion, today + 86400, inside), false);
});

test('paused promotion never applies', () => {
  const now = utcSeconds('2026-09-20T05:00:00Z');
  const today = serviceDayForOffset(0, now);
  assert.equal(
    promotionApplies({ enabled: 0, start_day: today, end_day: today }, today, now),
    false,
  );
});
''')

Path('worker/booking_rules.js').write_text(r'''export const NHA_TRANG_OFFSET_SECONDS = 7 * 3600;

export function nhaTrangDayBounds(now) {
  const seconds = Number(now);
  const localDay = Math.floor((seconds + NHA_TRANG_OFFSET_SECONDS) / 86400);
  const start = localDay * 86400 - NHA_TRANG_OFFSET_SECONDS;
  return { start, end: start + 86400 };
}

export function serviceDayForOffset(offsetDays, now) {
  const { start } = nhaTrangDayBounds(now);
  return start + Number(offsetDays) * 86400;
}

export function serviceDateKey(serviceDay) {
  const local = new Date((Number(serviceDay) + NHA_TRANG_OFFSET_SECONDS) * 1000);
  return `${local.getUTCFullYear()}-${String(local.getUTCMonth() + 1).padStart(2, '0')}-${String(local.getUTCDate()).padStart(2, '0')}`;
}

export function compactServiceDate(serviceDay) {
  return serviceDateKey(serviceDay).replaceAll('-', '');
}

export function serviceDayFromDateKey(raw) {
  if (typeof raw !== 'string') return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(raw);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const utcMidnight = Date.UTC(year, month - 1, day) / 1000;
  const serviceDay = utcMidnight - NHA_TRANG_OFFSET_SECONDS;
  return serviceDateKey(serviceDay) === raw ? serviceDay : null;
}

export function serviceDayFromCompactDate(raw) {
  if (typeof raw !== 'string' || !/^\d{8}$/.test(raw)) return null;
  return serviceDayFromDateKey(`${raw.slice(0, 4)}-${raw.slice(4, 6)}-${raw.slice(6, 8)}`);
}

export function isBookableServiceDay(serviceDay, now) {
  const today = serviceDayForOffset(0, now);
  return serviceDay === today || serviceDay === today + 86400;
}

export function nhaTrangSecondsIntoDay(now) {
  const { start } = nhaTrangDayBounds(now);
  return Number(now) - start;
}

export function visitTimestampForServiceDay(serviceDay, now) {
  const today = serviceDayForOffset(0, now);
  if (serviceDay === today) return Number(now);
  return Number(serviceDay) + 11 * 3600;
}

export function bookingWindow(now) {
  const today = serviceDayForOffset(0, now);
  return {
    today,
    tomorrow: today + 86400,
    end: today + 2 * 86400,
  };
}

export function bookingDayKind(serviceDay, now) {
  const { today, tomorrow } = bookingWindow(now);
  if (serviceDay === today) return 'today';
  if (serviceDay === tomorrow) return 'tomorrow';
  return 'other';
}
''')

Path('worker/booking_rules_test.mjs').write_text(r'''import test from 'node:test';
import assert from 'node:assert/strict';

import {
  bookingDayKind,
  isBookableServiceDay,
  serviceDateKey,
  serviceDayForOffset,
  serviceDayFromDateKey,
  visitTimestampForServiceDay,
} from './booking_rules.js';

function utcSeconds(value) {
  return Math.floor(Date.parse(value) / 1000);
}

test('service dates round-trip at Nha Trang midnight', () => {
  const serviceDay = serviceDayFromDateKey('2026-09-01');
  assert.ok(serviceDay);
  assert.equal(serviceDateKey(serviceDay), '2026-09-01');
});

test('only today and tomorrow are bookable', () => {
  const now = utcSeconds('2026-08-31T10:00:00Z');
  assert.equal(isBookableServiceDay(serviceDayForOffset(0, now), now), true);
  assert.equal(isBookableServiceDay(serviceDayForOffset(1, now), now), true);
  assert.equal(isBookableServiceDay(serviceDayForOffset(2, now), now), false);
});

test('future accepted booking visit lands inside the booked service day', () => {
  const now = utcSeconds('2026-08-31T10:00:00Z');
  const tomorrow = serviceDayForOffset(1, now);
  const timestamp = visitTimestampForServiceDay(tomorrow, now);
  assert.equal(bookingDayKind(tomorrow, now), 'tomorrow');
  assert.equal(timestamp, tomorrow + 11 * 3600);
});
''')

# worker/entry.js
replace_once(
    'worker/entry.js',
    "  bookingWindow,\n  dayPassAmount,\n  isBookableServiceDay,",
    "  bookingWindow,\n  isBookableServiceDay,",
)
replace_once(
    'worker/entry.js',
    "} from './booking_rules.js';\n\nconst MAX_NAME_LENGTH",
    "} from './booking_rules.js';\nimport { resolvePricing } from './pricing.js';\n\nconst MAX_NAME_LENGTH",
)
replace_once(
    'worker/entry.js',
    "  const total = Math.max(1, Number(row?.total ?? 10));\n  const occupied = Math.min(total, Math.max(0, Number(row?.today_occupied ?? 0)));\n  const tomorrowOccupied = Math.min(total, Math.max(0, Number(row?.tomorrow_occupied ?? 0)));\n  return json({",
    "  const total = Math.max(1, Number(row?.total ?? 10));\n  const occupied = Math.min(total, Math.max(0, Number(row?.today_occupied ?? 0)));\n  const tomorrowOccupied = Math.min(total, Math.max(0, Number(row?.tomorrow_occupied ?? 0)));\n  const [todayPricing, tomorrowPricing] = await Promise.all([\n    resolvePricing(env, today, now),\n    resolvePricing(env, tomorrow, now),\n  ]);\n  return json({",
)
replace_once(
    'worker/entry.js',
    "      todayPrice: dayPassAmount(today, now),\n      tomorrowPrice: dayPassAmount(tomorrow, now),\n      tomorrowOccupied,",
    "      baseDayPassPrice: todayPricing.base.dayPassVnd,\n      baseMonthPassPrice: todayPricing.base.monthPassVnd,\n      baseLockerMonthPrice: todayPricing.base.lockerMonthVnd,\n      todayPrice: todayPricing.dayPassVnd,\n      tomorrowPrice: tomorrowPricing.dayPassVnd,\n      todayPromoDescription: todayPricing.promotion?.description ?? '',\n      tomorrowPromoDescription: tomorrowPricing.promotion?.description ?? '',\n      tomorrowOccupied,",
)
replace_once(
    'worker/entry.js',
    "  const amountVnd = dayPassAmount(serviceDay, now);",
    "  const amountVnd = (await resolvePricing(env, serviceDay, now)).dayPassVnd;",
)

# worker/index.js
replace_once(
    'worker/index.js',
    "import { DAY_PASS_VND, dayPassAmount, serviceDayForOffset } from './booking_rules.js';",
    "import { serviceDayForOffset, serviceDayFromDateKey } from './booking_rules.js';\nimport {\n  DEFAULT_DAY_PASS_VND,\n  listPromotions,\n  pricingSnapshot,\n  resolvePricing,\n} from './pricing.js';",
)
replace_once('worker/index.js', "const MONTH_PASS_VND = 2500000;\n", "")
route_marker = "      if (request.method === 'POST' && url.pathname === '/api/admin/day-pass') {"
insert_before('worker/index.js', route_marker, r'''      if (request.method === 'POST' && url.pathname === '/api/admin/pricing') {
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
''')
insert_before('worker/index.js', "async function handleDayPass(request, env) {", r'''async function handlePricingUpdate(request, env) {
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

''')
replace_once(
    'worker/index.js',
    "  const now = nowSeconds();\n  const customer = await ensureCustomer(env, { name });\n  await env.evil_space\n    .prepare(`\n      INSERT INTO visits\n        (name, kind, membership_id, amount, created_at, created_by_email, customer_id)\n      VALUES (?, 'day', NULL, ?, ?, ?, ?)\n    `)\n    .bind(name, dayPassAmount(serviceDayForOffset(0, now), now), now, session.email, customer.id)",
    "  const now = nowSeconds();\n  const customer = await ensureCustomer(env, { name });\n  const pricing = await resolvePricing(env, serviceDayForOffset(0, now), now);\n  await env.evil_space\n    .prepare(`\n      INSERT INTO visits\n        (name, kind, membership_id, amount, created_at, created_by_email, customer_id)\n      VALUES (?, 'day', NULL, ?, ?, ?, ?)\n    `)\n    .bind(name, pricing.dayPassVnd, now, session.email, customer.id)",
)
replace_once(
    'worker/index.js',
    "  const expiresAt = addCalendarMonth(now);\n  const membership = await env.evil_space",
    "  const expiresAt = addCalendarMonth(now);\n  const pricing = await resolvePricing(env, serviceDayForOffset(0, now), now);\n  const membership = await env.evil_space",
)
replace_once(
    'worker/index.js',
    ".bind(name, membership.id, MONTH_PASS_VND, now, session.email, customer.id)",
    ".bind(name, membership.id, pricing.monthPassVnd, now, session.email, customer.id)",
)
replace_once('worker/index.js', ".bind(booking.name, DAY_PASS_VND, now, session.email, customer.id)", ".bind(booking.name, DEFAULT_DAY_PASS_VND, now, session.email, customer.id)")
replace_once(
    'worker/index.js',
    "  return {\n    today_visits: todayVisits.results ?? [],",
    "  const [pricing, promotions] = await Promise.all([\n    pricingSnapshot(env, now),\n    listPromotions(env),\n  ]);\n\n  return {\n    today_visits: todayVisits.results ?? [],",
)
replace_once(
    'worker/index.js',
    "    purchase_history: history.results ?? [],\n    income: {",
    "    purchase_history: history.results ?? [],\n    pricing,\n    promotions,\n    income: {",
)
insert_before('worker/index.js', "async function readJson(request) {", r'''function toPriceInt(value) {
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

''')

# worker/telegram.js
p = Path('worker/telegram.js')
text = p.read_text()
text = text.replace("  DAY_PASS_VND,\n", "")
text = text.replace("  HALF_DAY_VND,\n", "")
text = text.replace("  MONTH_PASS_VND,\n", "")
text = text.replace("  dayPassAmount,\n", "")
text = text.replace("} from './booking_rules.js';\nconst SESSION_COOKIE", "} from './booking_rules.js';\nimport { resolvePricing } from './pricing.js';\nconst SESSION_COOKIE", 1)
text = re.sub(r"\n\s*halfDay: '[^']*',", "", text)
text = text.replace("  const amountVnd = dayPassAmount(serviceDay, now);", "  const amountVnd = (await resolvePricing(env, serviceDay, now)).dayPassVnd;", 1)
text = text.replace("      const amountVnd = Number(claimed.amount_vnd ?? dayPassAmount(serviceStart, now));", "      const fallbackPricing = await resolvePricing(env, serviceStart, now);\n      const amountVnd = Number(claimed.amount_vnd ?? fallbackPricing.dayPassVnd);", 1)
text = text.replace("    .bind(name, dayPassAmount(serviceDayForOffset(0, now), now), now, admin.email, customer.id)", "    .bind(name, (await resolvePricing(env, serviceDayForOffset(0, now), now)).dayPassVnd, now, admin.email, customer.id)", 1)
text = text.replace("    .bind(name, membership.id, MONTH_PASS_VND, now, admin.email, customer.id)", "    .bind(name, membership.id, (await resolvePricing(env, serviceDayForOffset(0, now), now)).monthPassVnd, now, admin.email, customer.id)", 1)
for stale in ['HALF_DAY_VND', 'MONTH_PASS_VND', 'DAY_PASS_VND', 'dayPassAmount(']:
    if stale in text:
        raise SystemExit(f'worker/telegram.js: stale pricing token remains: {stale}')
p.write_text(text)

# lib/coworking_model.dart
replace_once(
    'lib/coworking_model.dart',
    "    this.todayPrice = 200000,\n    this.tomorrowPrice = 200000,\n    this.tomorrowOccupied = 0,",
    "    this.todayPrice = 200000,\n    this.tomorrowPrice = 200000,\n    this.baseDayPassPrice = 200000,\n    this.baseMonthPassPrice = 2500000,\n    this.baseLockerMonthPrice = 1000000,\n    this.todayPromoDescription = '',\n    this.tomorrowPromoDescription = '',\n    this.tomorrowOccupied = 0,",
)
replace_once(
    'lib/coworking_model.dart',
    "  final int todayPrice;\n  final int tomorrowPrice;\n  final int tomorrowOccupied;",
    "  final int todayPrice;\n  final int tomorrowPrice;\n  final int baseDayPassPrice;\n  final int baseMonthPassPrice;\n  final int baseLockerMonthPrice;\n  final String todayPromoDescription;\n  final String tomorrowPromoDescription;\n  final int tomorrowOccupied;",
)
replace_once(
    'lib/coworking_model.dart',
    "      todayPrice: (json['todayPrice'] as num?)?.toInt() ?? 200000,\n      tomorrowPrice: (json['tomorrowPrice'] as num?)?.toInt() ?? 200000,\n      tomorrowOccupied: rawTomorrow.clamp(0, normalizedTotal).toInt(),",
    "      todayPrice: (json['todayPrice'] as num?)?.toInt() ?? 200000,\n      tomorrowPrice: (json['tomorrowPrice'] as num?)?.toInt() ?? 200000,\n      baseDayPassPrice: (json['baseDayPassPrice'] as num?)?.toInt() ?? 200000,\n      baseMonthPassPrice: (json['baseMonthPassPrice'] as num?)?.toInt() ?? 2500000,\n      baseLockerMonthPrice: (json['baseLockerMonthPrice'] as num?)?.toInt() ?? 1000000,\n      todayPromoDescription: json['todayPromoDescription']?.toString() ?? '',\n      tomorrowPromoDescription: json['tomorrowPromoDescription']?.toString() ?? '',\n      tomorrowOccupied: rawTomorrow.clamp(0, normalizedTotal).toInt(),",
)
replace_once(
    'lib/coworking_model.dart',
    "      SitePrice(labelKey: 'price_day_pass', price: '200K VND'),\n      SitePrice(labelKey: 'price_half_day', price: '100K VND'),\n      SitePrice(labelKey: 'price_month', price: '2.5 MLN VND'),",
    "      SitePrice(labelKey: 'price_day_pass', price: '200K VND'),\n      SitePrice(labelKey: 'price_month', price: '2.5 MLN VND'),",
)

# localization: English AVAILABLE, remove fixed half-day copy, add promo label.
p = Path('lib/localization.dart')
text = p.read_text()
text = text.replace("'desk_free': 'DESK FREE'", "'desk_free': 'DESK AVAILABLE'")
text = text.replace("'desks_free': 'DESKS FREE'", "'desks_free': 'DESKS AVAILABLE'")
text = text.replace("'free_short': 'FREE'", "'free_short': 'AVAILABLE'")
text = re.sub(r"\n\s*'half_day_note': '[^']*',", "", text)
text = re.sub(r"\n\s*'price_half_day': '[^']*',", "", text)
text = text.replace("      'prices_title': 'SIMPLE PRICES',", "      'prices_title': 'SIMPLE PRICES',\n      'promo_label': 'PROMO',", 1)
text = text.replace("      'prices_title': 'ПРОСТЫЕ ЦЕНЫ',", "      'prices_title': 'ПРОСТЫЕ ЦЕНЫ',\n      'promo_label': 'АКЦИЯ',", 1)
text = text.replace("      'prices_title': 'BẢNG GIÁ',", "      'prices_title': 'BẢNG GIÁ',\n      'promo_label': 'KHUYẾN MÃI',", 1)
p.write_text(text)

# public shell: promo notices and live base price table
replace_once(
    'lib/app_shell.dart',
    "        const SizedBox(height: 8),\n        Text(\n          widget.localization.t('half_day_note'),\n          style: _mono(9, color: BrandPalette.inkMuted, spacing: 0.35),\n        ),",
    "        if (status.todayPromoDescription.isNotEmpty) ...[\n          const SizedBox(height: 10),\n          _promoNotice(widget.localization.t('booking_today'), status.todayPromoDescription),\n        ],\n        if (status.tomorrowPromoDescription.isNotEmpty &&\n            status.tomorrowPromoDescription != status.todayPromoDescription) ...[\n          const SizedBox(height: 8),\n          _promoNotice(widget.localization.t('booking_tomorrow'), status.tomorrowPromoDescription),\n        ],",
)
insert_before('lib/app_shell.dart', "  Widget _bookingCard(DeskBookingState booking, bool tomorrow) {", r'''  Widget _promoNotice(String dayLabel, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BrandPalette.paperDeep,
        border: Border.all(color: BrandPalette.ink),
      ),
      child: Text(
        '${widget.localization.t('promo_label')} · $dayLabel · $description',
        style: _mono(9.5, spacing: 0.45, height: 1.35),
      ),
    );
  }

''')
p = Path('lib/app_shell.dart')
text = p.read_text()
start = text.find('  Widget _prices(bool compact) {')
end = text.find('  Widget _openings(bool compact) {', start)
if start < 0 or end < 0:
    raise SystemExit('lib/app_shell.dart: prices method markers missing')
new_prices = r'''  Widget _prices(bool compact) {
    final status = _liveStatus ?? _content.status;
    final prices = <(String, int)>[
      ('price_day_pass', status.baseDayPassPrice),
      ('price_month', status.baseMonthPassPrice),
      ('price_locker', status.baseLockerMonthPrice),
    ];
    return _Section(
      title: widget.localization.t('prices_title'),
      child: Column(
        children: prices.map((price) {
          return Container(
            constraints: const BoxConstraints(minHeight: 76),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: BrandPalette.rule)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.localization.t(price.$1),
                    style: _mono(11, spacing: 0.8),
                  ),
                ),
                Text(
                  _moneyLabel(price.$2),
                  textAlign: TextAlign.right,
                  style: _serif(compact ? 24 : 30),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

'''
p.write_text(text[:start] + new_prices + text[end:])

# static fallback content
replace_once(
    'assets/content/status.json',
    '    {"label_key": "price_day_pass", "price": "200K VND"},\n    {"label_key": "price_half_day", "price": "100K VND"},\n    {"label_key": "price_month", "price": "2.5 MLN VND"},',
    '    {"label_key": "price_day_pass", "price": "200K VND"},\n    {"label_key": "price_month", "price": "2.5 MLN VND"},',
)

# Admin models
pricing_models = r'''class PricingConfig {
  const PricingConfig({
    required this.dayPassVnd,
    required this.monthPassVnd,
    required this.lockerMonthVnd,
    required this.currentDayPassVnd,
    required this.currentMonthPassVnd,
    required this.currentLockerMonthVnd,
    required this.activePromoId,
    required this.activePromoDescription,
  });

  static const defaults = PricingConfig(
    dayPassVnd: 200000,
    monthPassVnd: 2500000,
    lockerMonthVnd: 1000000,
    currentDayPassVnd: 200000,
    currentMonthPassVnd: 2500000,
    currentLockerMonthVnd: 1000000,
    activePromoId: 0,
    activePromoDescription: '',
  );

  final int dayPassVnd;
  final int monthPassVnd;
  final int lockerMonthVnd;
  final int currentDayPassVnd;
  final int currentMonthPassVnd;
  final int currentLockerMonthVnd;
  final int activePromoId;
  final String activePromoDescription;

  factory PricingConfig.fromJson(Map<String, dynamic> json) {
    return PricingConfig(
      dayPassVnd: _asInt(json['day_pass_vnd']) ?? 200000,
      monthPassVnd: _asInt(json['month_pass_vnd']) ?? 2500000,
      lockerMonthVnd: _asInt(json['locker_month_vnd']) ?? 1000000,
      currentDayPassVnd: _asInt(json['current_day_pass_vnd']) ?? 200000,
      currentMonthPassVnd: _asInt(json['current_month_pass_vnd']) ?? 2500000,
      currentLockerMonthVnd: _asInt(json['current_locker_month_vnd']) ?? 1000000,
      activePromoId: _asInt(json['active_promo_id']) ?? 0,
      activePromoDescription: json['active_promo_description']?.toString() ?? '',
    );
  }
}

class PromotionRecord {
  const PromotionRecord({
    required this.id,
    required this.description,
    required this.startDay,
    required this.endDay,
    required this.enabled,
    required this.createdAt,
    required this.createdByEmail,
    this.startMinute,
    this.endMinute,
    this.dayPassVnd,
    this.monthPassVnd,
    this.lockerMonthVnd,
  });

  final int id;
  final String description;
  final int startDay;
  final int endDay;
  final int? startMinute;
  final int? endMinute;
  final int? dayPassVnd;
  final int? monthPassVnd;
  final int? lockerMonthVnd;
  final bool enabled;
  final int createdAt;
  final String createdByEmail;

  bool get hasTimeWindow => startMinute != null && endMinute != null;

  factory PromotionRecord.fromJson(Map<String, dynamic> json) {
    return PromotionRecord(
      id: _asInt(json['id']) ?? 0,
      description: json['description']?.toString() ?? '',
      startDay: _asInt(json['start_day']) ?? 0,
      endDay: _asInt(json['end_day']) ?? 0,
      startMinute: _asInt(json['start_minute']),
      endMinute: _asInt(json['end_minute']),
      dayPassVnd: _asInt(json['day_pass_vnd']),
      monthPassVnd: _asInt(json['month_pass_vnd']),
      lockerMonthVnd: _asInt(json['locker_month_vnd']),
      enabled: (_asInt(json['enabled']) ?? 0) == 1,
      createdAt: _asInt(json['created_at']) ?? 0,
      createdByEmail: json['created_by_email']?.toString() ?? '',
    );
  }
}

'''
insert_before('lib/admin_api_models.dart', 'class OperationsSnapshot {', pricing_models)
replace_once(
    'lib/admin_api_models.dart',
    "    required this.purchaseHistory,\n    required this.income,",
    "    required this.purchaseHistory,\n    required this.pricing,\n    required this.promotions,\n    required this.income,",
)
replace_once(
    'lib/admin_api_models.dart',
    "  final List<PurchaseRequestRecord> purchaseHistory;\n  final IncomeSummary income;",
    "  final List<PurchaseRequestRecord> purchaseHistory;\n  final PricingConfig pricing;\n  final List<PromotionRecord> promotions;\n  final IncomeSummary income;",
)
replace_once(
    'lib/admin_api_models.dart',
    "      purchaseHistory: _listOf(\n        json['purchase_history'],\n        PurchaseRequestRecord.fromJson,\n      ),\n      income: IncomeSummary.fromJson(_map(json['income'])),",
    "      purchaseHistory: _listOf(\n        json['purchase_history'],\n        PurchaseRequestRecord.fromJson,\n      ),\n      pricing: PricingConfig.fromJson(_map(json['pricing'])),\n      promotions: _listOf(json['promotions'], PromotionRecord.fromJson),\n      income: IncomeSummary.fromJson(_map(json['income'])),",
)

# Admin API web/stub
insert_before('lib/admin_api_web.dart', "  Future<OperationsSnapshot> addDayPass(String name) async {", r'''  Future<OperationsSnapshot> updatePricing({
    required int dayPassVnd,
    required int monthPassVnd,
    required int lockerMonthVnd,
  }) async {
    return _operation('POST', '/api/admin/pricing', {
      'dayPassVnd': dayPassVnd,
      'monthPassVnd': monthPassVnd,
      'lockerMonthVnd': lockerMonthVnd,
    });
  }

  Future<OperationsSnapshot> createPromotion({
    required String description,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    int? dayPassVnd,
    int? monthPassVnd,
    int? lockerMonthVnd,
  }) async {
    return _operation('POST', '/api/admin/promotions', {
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'startTime': startTime,
      'endTime': endTime,
      'dayPassVnd': dayPassVnd,
      'monthPassVnd': monthPassVnd,
      'lockerMonthVnd': lockerMonthVnd,
    });
  }

  Future<OperationsSnapshot> setPromotionEnabled(int id, bool enabled) async {
    return _operation('POST', '/api/admin/promotions/toggle', {
      'id': id,
      'enabled': enabled,
    });
  }

  Future<OperationsSnapshot> deletePromotion(int id) async {
    return _operation('POST', '/api/admin/promotions/delete', {'id': id});
  }

''')
insert_before('lib/admin_api_stub.dart', "  Future<OperationsSnapshot> addDayPass(String name) async => _webOnly();", r'''  Future<OperationsSnapshot> updatePricing({
    required int dayPassVnd,
    required int monthPassVnd,
    required int lockerMonthVnd,
  }) async => _webOnly();

  Future<OperationsSnapshot> createPromotion({
    required String description,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    int? dayPassVnd,
    int? monthPassVnd,
    int? lockerMonthVnd,
  }) async => _webOnly();

  Future<OperationsSnapshot> setPromotionEnabled(int id, bool enabled) async =>
      _webOnly();

  Future<OperationsSnapshot> deletePromotion(int id) async => _webOnly();

''')

# Admin screen: dynamic add-customer prices, navigation, dedicated pricing page.
replace_once('lib/admin_screen.dart', "            subtitle: _money(_currentDayPassAmount()),", "            subtitle: _money(_snapshot?.pricing.currentDayPassVnd ?? 200000),")
replace_once('lib/admin_screen.dart', "            subtitle: '2.5 MLN VND',", "            subtitle: _money(_snapshot?.pricing.currentMonthPassVnd ?? 2500000),")
p = Path('lib/admin_screen.dart')
text = p.read_text()
text = re.sub(r"\n  int _currentDayPassAmount\(\) \{.*?\n  \}\n", "\n", text, flags=re.S)
p.write_text(text)
replace_once(
    'lib/admin_screen.dart',
    "      t('ДОХОД', 'INCOME'),\n      '${t('КУПИТЬ', 'BUY')}",
    "      t('ДОХОД', 'INCOME'),\n      t('ЦЕНЫ', 'PRICES'),\n      '${t('КУПИТЬ', 'BUY')}",
)
replace_once(
    'lib/admin_screen.dart',
    "      Icons.payments_outlined,\n      Icons.shopping_cart_outlined,",
    "      Icons.payments_outlined,\n      Icons.local_offer_outlined,\n      Icons.shopping_cart_outlined,",
)
replace_once(
    'lib/admin_screen.dart',
    "      3 => _income(snapshot),\n      _ => _buy(snapshot),",
    "      3 => _income(snapshot),\n      4 => _pricing(snapshot),\n      _ => _buy(snapshot),",
)
replace_once(
    'lib/admin_screen.dart',
    "      _sectionTitle(t('ТАРИФЫ', 'PRICES')),\n      _row(t('ДНЕВНОЙ ПРОПУСК', 'DAY PASS'), '', '200K VND'),\n      _row(t('ПОЛДНЯ · ПОСЛЕ 16:00', 'HALF DAY · AFTER 16:00'), '', '100K VND'),\n      _row(t('МЕСЯЧНЫЙ ПРОПУСК', 'MONTH PASS'), '', '2.5 MLN VND'),",
    "      _sectionTitle(t('ТАРИФЫ', 'PRICES')),\n      _row(t('ДНЕВНОЙ ПРОПУСК', 'DAY PASS'), '', _money(snapshot.pricing.dayPassVnd)),\n      _row(t('МЕСЯЧНЫЙ ПРОПУСК', 'MONTH PASS'), '', _money(snapshot.pricing.monthPassVnd)),\n      _row(t('ЛИЧНЫЙ ШКАФЧИК', 'PERSONAL LOCKER'), '', _money(snapshot.pricing.lockerMonthVnd)),",
)
pricing_methods = r'''  Future<void> _editPricing(OperationsSnapshot snapshot) async {
    if (_busy) return;
    final result = await showDialog<_PricingEditResult>(
      context: context,
      builder: (_) => _PricingEditorDialog(
        russian: _russian,
        pricing: snapshot.pricing,
      ),
    );
    if (!mounted || result == null) return;
    await _apply(
      () => widget.api.updatePricing(
        dayPassVnd: result.dayPassVnd,
        monthPassVnd: result.monthPassVnd,
        lockerMonthVnd: result.lockerMonthVnd,
      ),
      success: t('Цены обновлены', 'Prices updated'),
    );
  }

  Future<void> _addPromotion() async {
    if (_busy) return;
    final result = await showDialog<_PromotionDraft>(
      context: context,
      builder: (_) => _PromotionEditorDialog(russian: _russian),
    );
    if (!mounted || result == null) return;
    await _apply(
      () => widget.api.createPromotion(
        description: result.description,
        startDate: result.startDate,
        endDate: result.endDate,
        startTime: result.startTime,
        endTime: result.endTime,
        dayPassVnd: result.dayPassVnd,
        monthPassVnd: result.monthPassVnd,
        lockerMonthVnd: result.lockerMonthVnd,
      ),
      success: t('Акция запущена', 'Promotion created'),
    );
  }

  Future<void> _deletePromotion(PromotionRecord promotion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: BrandPalette.paper,
        shape: const RoundedRectangleBorder(),
        title: Text(t('Удалить акцию?', 'Delete promotion?'), style: _serif(26)),
        content: Text(promotion.description, style: _serif(17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t('ОТМЕНА', 'CANCEL'), style: _mono(10)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: _darkButton(),
            child: Text(t('УДАЛИТЬ', 'DELETE'), style: _mono(10, color: BrandPalette.paperLift)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _apply(
      () => widget.api.deletePromotion(promotion.id),
      success: t('Акция удалена', 'Promotion deleted'),
    );
  }

  Widget _pricing(OperationsSnapshot snapshot) {
    final pricing = snapshot.pricing;
    return _page([
      _sectionTitle(t('ОСНОВНЫЕ ЦЕНЫ', 'BASE PRICES')),
      _row(t('ДНЕВНОЙ ПРОПУСК', 'DAY PASS'), '', _money(pricing.dayPassVnd)),
      _row(t('МЕСЯЧНЫЙ ПРОПУСК', 'MONTH PASS'), '', _money(pricing.monthPassVnd)),
      _row(t('ЛИЧНЫЙ ШКАФЧИК', 'PERSONAL LOCKER'), '', _money(pricing.lockerMonthVnd)),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _editPricing(snapshot),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(t('ИЗМЕНИТЬ ЦЕНЫ', 'EDIT PRICES'), style: _mono(10)),
        style: _outlineButton(minHeight: 50),
      ),
      const SizedBox(height: 32),
      Row(
        children: [
          Expanded(child: _sectionTitle(t('АКЦИИ', 'PROMOTIONS'))),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _addPromotion,
            icon: const Icon(Icons.add, size: 18),
            label: Text(t('ДОБАВИТЬ АКЦИЮ', 'ADD PROMO'), style: _mono(9.5, color: BrandPalette.paperLift)),
            style: _darkButton(minHeight: 46),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (snapshot.promotions.isEmpty)
        _empty(t('Акций пока нет.', 'No promotions yet.'))
      else
        ...snapshot.promotions.map(_promotionRow),
    ]);
  }

  Widget _promotionRow(PromotionRecord promotion) {
    final dateRange = promotion.startDay == promotion.endDay
        ? _date(promotion.startDay)
        : '${_date(promotion.startDay)} – ${_date(promotion.endDay)}';
    final timeRange = promotion.hasTimeWindow
        ? ' · ${_minuteLabel(promotion.startMinute!)}–${_minuteLabel(promotion.endMinute!)}'
        : '';
    final prices = <String>[
      if (promotion.dayPassVnd != null) '${t('ДЕНЬ', 'DAY')} ${_money(promotion.dayPassVnd!)}',
      if (promotion.monthPassVnd != null) '${t('МЕСЯЦ', 'MONTH')} ${_money(promotion.monthPassVnd!)}',
      if (promotion.lockerMonthVnd != null) '${t('ШКАФ', 'LOCKER')} ${_money(promotion.lockerMonthVnd!)}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(promotion.description, style: _serif(19)),
                    const SizedBox(height: 5),
                    Text('$dateRange$timeRange', style: _mono(9.5, color: BrandPalette.inkMuted)),
                    const SizedBox(height: 4),
                    Text(prices, style: _mono(9.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: promotion.enabled,
                onChanged: _busy
                    ? null
                    : (enabled) => _apply(
                        () => widget.api.setPromotionEnabled(promotion.id, enabled),
                        success: enabled
                            ? t('Акция запущена', 'Promotion running')
                            : t('Акция приостановлена', 'Promotion paused'),
                      ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _deletePromotion(promotion),
              icon: const Icon(Icons.delete_outline, size: 17),
              label: Text(t('УДАЛИТЬ', 'DELETE'), style: _mono(9)),
            ),
          ),
        ],
      ),
    );
  }

  String _minuteLabel(int minute) {
    final hour = minute ~/ 60;
    final rest = minute % 60;
    return '${hour.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

'''
insert_before('lib/admin_screen.dart', '  Widget _buy(OperationsSnapshot snapshot) {', pricing_methods)

# Reuse existing outline helper; it currently may have no minHeight arg. Patch signature if needed.
p = Path('lib/admin_screen.dart')
text = p.read_text()
if 'ButtonStyle _outlineButton({' not in text:
    # Existing helper is a no-arg function; change it to accept optional height.
    text = text.replace(
        'ButtonStyle _outlineButton() {\n  return OutlinedButton.styleFrom(',
        'ButtonStyle _outlineButton({double minHeight = 48}) {\n  return OutlinedButton.styleFrom(',
    )
    text = text.replace('minimumSize: const Size.fromHeight(48),', 'minimumSize: Size.fromHeight(minHeight),')
p.write_text(text)

# Add editor classes before the first existing private helper class after AdminScreen state.
admin_dialogs = r'''class _PricingEditResult {
  const _PricingEditResult(this.dayPassVnd, this.monthPassVnd, this.lockerMonthVnd);
  final int dayPassVnd;
  final int monthPassVnd;
  final int lockerMonthVnd;
}

class _PricingEditorDialog extends StatefulWidget {
  const _PricingEditorDialog({required this.russian, required this.pricing});
  final bool russian;
  final PricingConfig pricing;

  @override
  State<_PricingEditorDialog> createState() => _PricingEditorDialogState();
}

class _PricingEditorDialogState extends State<_PricingEditorDialog> {
  late final TextEditingController _day;
  late final TextEditingController _month;
  late final TextEditingController _locker;
  String? _error;

  String t(String ru, String en) => widget.russian ? ru : en;

  @override
  void initState() {
    super.initState();
    _day = TextEditingController(text: '${widget.pricing.dayPassVnd}');
    _month = TextEditingController(text: '${widget.pricing.monthPassVnd}');
    _locker = TextEditingController(text: '${widget.pricing.lockerMonthVnd}');
  }

  @override
  void dispose() {
    _day.dispose();
    _month.dispose();
    _locker.dispose();
    super.dispose();
  }

  int? _price(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim().replaceAll(RegExp(r'[^0-9]'), ''));
    return value != null && value > 0 ? value : null;
  }

  void _save() {
    final day = _price(_day);
    final month = _price(_month);
    final locker = _price(_locker);
    if (day == null || month == null || locker == null) {
      setState(() => _error = t('Введите все цены в VND.', 'Enter all prices in VND.'));
      return;
    }
    Navigator.of(context).pop(_PricingEditResult(day, month, locker));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      title: Text(t('Основные цены', 'Base prices'), style: _serif(28)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _day, keyboardType: TextInputType.number, decoration: _inputDecoration(t('ДЕНЬ · VND', 'DAY PASS · VND'))),
            const SizedBox(height: 12),
            TextField(controller: _month, keyboardType: TextInputType.number, decoration: _inputDecoration(t('МЕСЯЦ · VND', 'MONTH PASS · VND'))),
            const SizedBox(height: 12),
            TextField(controller: _locker, keyboardType: TextInputType.number, decoration: _inputDecoration(t('ШКАФ · VND', 'LOCKER / MONTH · VND'))),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: _mono(9.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t('ОТМЕНА', 'CANCEL'), style: _mono(10))),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: BrandPalette.ink, foregroundColor: BrandPalette.paperLift, shape: const RoundedRectangleBorder()),
          child: Text(t('СОХРАНИТЬ', 'SAVE'), style: _mono(10, color: BrandPalette.paperLift)),
        ),
      ],
    );
  }
}

class _PromotionDraft {
  const _PromotionDraft({
    required this.description,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    this.dayPassVnd,
    this.monthPassVnd,
    this.lockerMonthVnd,
  });
  final String description;
  final String startDate;
  final String endDate;
  final String? startTime;
  final String? endTime;
  final int? dayPassVnd;
  final int? monthPassVnd;
  final int? lockerMonthVnd;
}

class _PromotionEditorDialog extends StatefulWidget {
  const _PromotionEditorDialog({required this.russian});
  final bool russian;

  @override
  State<_PromotionEditorDialog> createState() => _PromotionEditorDialogState();
}

class _PromotionEditorDialogState extends State<_PromotionEditorDialog> {
  final _description = TextEditingController();
  final _dayPrice = TextEditingController();
  final _monthPrice = TextEditingController();
  final _lockerPrice = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  bool _limitTime = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 0);
  String? _error;

  String t(String ru, String en) => widget.russian ? ru : en;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate;
  }

  @override
  void dispose() {
    _description.dispose();
    _dayPrice.dispose();
    _monthPrice.dispose();
    _lockerPrice.dispose();
    super.dispose();
  }

  String _dateValue(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String _timeValue(TimeOfDay value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  int? _optionalPrice(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    final value = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    return value != null && value > 0 ? value : -1;
  }

  Future<void> _pickDate(bool start) async {
    final current = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _startTime : _endTime);
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  void _save() {
    final description = _description.text.trim();
    final day = _optionalPrice(_dayPrice);
    final month = _optionalPrice(_monthPrice);
    final locker = _optionalPrice(_lockerPrice);
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (description.isEmpty) {
      setState(() => _error = t('Добавьте описание акции.', 'Add a promotion description.'));
      return;
    }
    if ([day, month, locker].contains(-1)) {
      setState(() => _error = t('Цена должна быть больше 0.', 'Price must be greater than 0.'));
      return;
    }
    if (day == null && month == null && locker == null) {
      setState(() => _error = t('Укажите хотя бы одну акционную цену.', 'Set at least one promotional price.'));
      return;
    }
    if (_limitTime && endMinutes <= startMinutes) {
      setState(() => _error = t('Время окончания должно быть позже начала.', 'End time must be after start time.'));
      return;
    }
    Navigator.of(context).pop(
      _PromotionDraft(
        description: description,
        startDate: _dateValue(_startDate),
        endDate: _dateValue(_endDate),
        startTime: _limitTime ? _timeValue(_startTime) : null,
        endTime: _limitTime ? _timeValue(_endTime) : null,
        dayPassVnd: day,
        monthPassVnd: month,
        lockerMonthVnd: locker,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      title: Text(t('Новая акция', 'New promotion'), style: _serif(28)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _description,
                maxLength: 240,
                decoration: _inputDecoration(t('ОПИСАНИЕ', 'DESCRIPTION')),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text('${t('С', 'FROM')} ${_dateValue(_startDate)}', style: _mono(9.5)))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text('${t('ДО', 'TO')} ${_dateValue(_endDate)}', style: _mono(9.5)))),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _limitTime,
                onChanged: (value) => setState(() => _limitTime = value),
                title: Text(t('Ограничить по времени дня', 'Limit by time of day'), style: _serif(16)),
              ),
              if (_limitTime)
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => _pickTime(true), child: Text('${t('С', 'FROM')} ${_timeValue(_startTime)}', style: _mono(9.5)))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => _pickTime(false), child: Text('${t('ДО', 'TO')} ${_timeValue(_endTime)}', style: _mono(9.5)))),
                  ],
                ),
              const SizedBox(height: 16),
              Text(t('Акционные цены · оставьте ненужные поля пустыми', 'Promo prices · leave unused fields empty'), style: _mono(9.5, color: BrandPalette.inkMuted)),
              const SizedBox(height: 10),
              TextField(controller: _dayPrice, keyboardType: TextInputType.number, decoration: _inputDecoration(t('ДЕНЬ · VND', 'DAY PASS · VND'))),
              const SizedBox(height: 10),
              TextField(controller: _monthPrice, keyboardType: TextInputType.number, decoration: _inputDecoration(t('МЕСЯЦ · VND', 'MONTH PASS · VND'))),
              const SizedBox(height: 10),
              TextField(controller: _lockerPrice, keyboardType: TextInputType.number, decoration: _inputDecoration(t('ШКАФ · VND', 'LOCKER / MONTH · VND'))),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: _mono(9.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t('ОТМЕНА', 'CANCEL'), style: _mono(10))),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: BrandPalette.ink, foregroundColor: BrandPalette.paperLift, shape: const RoundedRectangleBorder()),
          child: Text(t('ЗАПУСТИТЬ', 'RUN PROMO'), style: _mono(10, color: BrandPalette.paperLift)),
        ),
      ],
    );
  }
}

'''
# Insert before _MetricCard, which is a stable top-level helper near end.
insert_before('lib/admin_screen.dart', 'class _MetricCard {', admin_dialogs)

# Tests: remove half-day assumptions and add dynamic pricing/promo contracts.
replace_once(
    'test/widget_test.dart',
    "          '200K VND',\n          '100K VND',\n          '2.5 MLN VND',",
    "          '200K VND',\n          '2.5 MLN VND',",
)
p = Path('test/booking_service_day_contract_test.dart')
text = p.read_text()
text = text.replace("    expect(entry, contains('todayPrice: dayPassAmount(today, now)'));\n    expect(entry, contains('tomorrowPrice: dayPassAmount(tomorrow, now)'));", "    expect(entry, contains('resolvePricing(env, today, now)'));\n    expect(entry, contains('resolvePricing(env, tomorrow, now)'));")
text = text.replace("    expect(shell, contains(\"widget.localization.t('half_day_note')\"));\n", "    expect(shell, contains('_promoNotice'));\n")
text = text.replace("    expect(localization, contains(\"'price_half_day': 'HALF DAY · AFTER 16:00'\"));\n    expect(localization, contains(\"'price_half_day': 'ПОЛДНЯ · ПОСЛЕ 16:00'\"));\n    expect(localization, contains(\"'price_half_day': 'NỬA NGÀY · SAU 16:00'\"));", "    expect(localization, isNot(contains('price_half_day')));\n    expect(localization, contains(\"'promo_label': 'PROMO'\"));")
p.write_text(text)

p = Path('test/telegram_contract_test.dart')
text = p.read_text()
old = r'''    test('admin displays full-day and half-day prices', () {
      final screen = File('lib/admin_screen.dart').readAsStringSync();
      expect(screen, contains("'200K VND'"));
      expect(screen, contains("'100K VND'"));
      expect(screen, isNot(contains("'250K VND'")));
    });

    test('public pricing includes half day and monthly personal locker', () {
      final content = File('assets/content/status.json').readAsStringSync();
      final localization = File('lib/localization.dart').readAsStringSync();
      expect(content, contains('"price_half_day"'));
      expect(content, contains('"100K VND"'));
      expect(content, contains('"price_locker"'));
      expect(content, contains('"1 MLN VND / MONTH"'));
      expect(
        localization,
        contains("'price_half_day': 'HALF DAY · AFTER 16:00'"),
      );
      expect(localization, contains("'price_locker': 'PERSONAL LOCKER'"));
      expect(localization, contains("'price_locker': 'ЛИЧНЫЙ ШКАФЧИК'"));
      expect(localization, contains("'price_locker': 'TỦ CÁ NHÂN'"));
    });
'''
new = r'''    test('admin exposes editable base pricing and scheduled promotions', () {
      final screen = File('lib/admin_screen.dart').readAsStringSync();
      final api = File('lib/admin_api_web.dart').readAsStringSync();
      final worker = File('worker/index.js').readAsStringSync();
      expect(screen, contains("t('ЦЕНЫ', 'PRICES')"));
      expect(screen, contains("t('ИЗМЕНИТЬ ЦЕНЫ', 'EDIT PRICES')"));
      expect(screen, contains("t('ДОБАВИТЬ АКЦИЮ', 'ADD PROMO')"));
      expect(api, contains("'/api/admin/pricing'"));
      expect(api, contains("'/api/admin/promotions'"));
      expect(worker, contains('handleCreatePromotion'));
      expect(worker, contains('handlePricingUpdate'));
    });

    test('public pricing has no fixed half-day promo and keeps personal locker', () {
      final content = File('assets/content/status.json').readAsStringSync();
      final localization = File('lib/localization.dart').readAsStringSync();
      final shell = File('lib/app_shell.dart').readAsStringSync();
      expect(content, isNot(contains('"price_half_day"')));
      expect(content, isNot(contains('"100K VND"')));
      expect(content, contains('"price_locker"'));
      expect(content, contains('"1 MLN VND / MONTH"'));
      expect(localization, isNot(contains('price_half_day')));
      expect(shell, isNot(contains('half_day_note')));
      expect(localization, contains("'price_locker': 'PERSONAL LOCKER'"));
      expect(localization, contains("'price_locker': 'ЛИЧНЫЙ ШКАФЧИК'"));
      expect(localization, contains("'price_locker': 'TỦ CÁ NHÂN'"));
    });
'''
if old not in text:
    raise SystemExit('test/telegram_contract_test.dart: old pricing test block not found')
text = text.replace(old, new, 1)
text = text.replace("        'worker/booking_rules.js',\n", "        'worker/booking_rules.js',\n        'worker/pricing.js',\n")
p.write_text(text)

# Release/CI should test pricing rules too.
replace_once(
    'tool/release.dart',
    "  await _run('node', ['--test', 'worker/telegram_test.mjs']);",
    "  await _run('node', [\n    '--test',\n    'worker/telegram_test.mjs',\n    'worker/booking_rules_test.mjs',\n    'worker/pricing_test.mjs',\n  ]);",
)
replace_once(
    '.github/workflows/web-ci.yml',
    '      - name: Test Telegram bot helpers\n        run: node --test worker/telegram_test.mjs',
    '      - name: Test Worker helpers\n        run: node --test worker/telegram_test.mjs worker/booking_rules_test.mjs worker/pricing_test.mjs',
)

# Sanity checks before formatter/compiler.
for path in ['lib/app_shell.dart', 'lib/admin_screen.dart', 'lib/localization.dart', 'assets/content/status.json']:
    text = Path(path).read_text()
    if 'half_day_note' in text or 'price_half_day' in text:
        raise SystemExit(f'{path}: fixed half-day promo reference remains')

# The feature script and workflow are temporary and should not land in the feature commit.
Path('.github/implement_pricing_promotions.py').unlink(missing_ok=True)
Path('.github/workflows/implement-pricing-promotions.yml').unlink(missing_ok=True)
