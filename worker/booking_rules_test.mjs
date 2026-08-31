import test from 'node:test';
import assert from 'node:assert/strict';

import {
  DAY_PASS_VND,
  HALF_DAY_VND,
  bookingDayKind,
  dayPassAmount,
  isBookableServiceDay,
  serviceDateKey,
  serviceDayForOffset,
  serviceDayFromDateKey,
  visitTimestampForServiceDay,
} from './booking_rules.js';

function utcSeconds(value) {
  return Math.floor(Date.parse(value) / 1000);
}

test('today switches from 200K to 100K exactly at 16:00 Nha Trang', () => {
  const before = utcSeconds('2026-08-31T08:59:59Z');
  const at = utcSeconds('2026-08-31T09:00:00Z');
  const today = serviceDayForOffset(0, before);
  assert.equal(dayPassAmount(today, before), DAY_PASS_VND);
  assert.equal(dayPassAmount(today, at), HALF_DAY_VND);
});

test('tomorrow always remains the full 200K day pass', () => {
  const late = utcSeconds('2026-08-31T16:59:00Z');
  const tomorrow = serviceDayForOffset(1, late);
  assert.equal(dayPassAmount(tomorrow, late), DAY_PASS_VND);
});

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
