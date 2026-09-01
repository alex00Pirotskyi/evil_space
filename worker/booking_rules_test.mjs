import test from 'node:test';
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
