import test from 'node:test';
import assert from 'node:assert/strict';

import {
  bookingDayKind,
  isBookableServiceDay,
  isOpenServiceDay,
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
  assert.equal(timestamp, tomorrow + 10 * 3600);
});


test('weekends are closed; Friday cannot book Saturday; Sunday can book Monday', () => {
  const friday = utcSeconds('2026-11-06T07:00:00Z');
  const sunday = utcSeconds('2026-11-08T07:00:00Z');
  assert.equal(isOpenServiceDay(serviceDayFromDateKey('2026-11-06')), true);
  assert.equal(isOpenServiceDay(serviceDayFromDateKey('2026-11-07')), false);
  assert.equal(isOpenServiceDay(serviceDayFromDateKey('2026-11-08')), false);
  assert.equal(isOpenServiceDay(serviceDayFromDateKey('2026-11-09')), true);
  assert.equal(isBookableServiceDay(serviceDayForOffset(0, friday), friday), true);
  assert.equal(isBookableServiceDay(serviceDayForOffset(1, friday), friday), false);
  assert.equal(isBookableServiceDay(serviceDayForOffset(0, sunday), sunday), false);
  assert.equal(isBookableServiceDay(serviceDayForOffset(1, sunday), sunday), true);
});


test('same-day bookings stop at 23:00 Nha Trang time and early bookings start at 10:00', () => {
  const early = utcSeconds('2026-11-05T00:00:00Z'); // 07:00 ICT
  const beforeClose = utcSeconds('2026-11-05T15:59:00Z'); // 22:59 ICT
  const closed = utcSeconds('2026-11-05T16:00:00Z'); // 23:00 ICT
  const today = serviceDayForOffset(0, early);
  assert.equal(isBookableServiceDay(today, early), true);
  assert.equal(visitTimestampForServiceDay(today, early), today + 10 * 3600);
  assert.equal(isBookableServiceDay(today, beforeClose), true);
  assert.equal(isBookableServiceDay(today, closed), false);
});
