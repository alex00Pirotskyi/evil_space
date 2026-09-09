import {
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
