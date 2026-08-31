export const DAY_PASS_VND = 200000;
export const HALF_DAY_VND = 100000;
export const MONTH_PASS_VND = 2500000;
export const HALF_DAY_START_HOUR = 16;
export const NHA_TRANG_OFFSET_SECONDS = 7 * 3600;

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

export function dayPassAmount(serviceDay, now) {
  const today = serviceDayForOffset(0, now);
  if (
    serviceDay === today &&
    nhaTrangSecondsIntoDay(now) >= HALF_DAY_START_HOUR * 3600
  ) {
    return HALF_DAY_VND;
  }
  return DAY_PASS_VND;
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
