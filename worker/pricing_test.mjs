import test from 'node:test';
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
