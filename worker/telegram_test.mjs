import assert from 'node:assert/strict';
import test from 'node:test';

import { telegramTest } from './telegram.js';

test('Telegram commands parse arguments and bot mentions', () => {
  assert.deepEqual(telegramTest.parseCommand('/day Alex Smith'), {
    name: 'day',
    args: 'Alex Smith',
  });
  assert.deepEqual(
    telegramTest.parseCommand('/today@CoworkingEvilAdminBot'),
    { name: 'today', args: '' },
  );
  assert.equal(telegramTest.parseCommand('hello'), null);
});

test('Telegram money labels match the admin product prices', () => {
  assert.equal(telegramTest.formatMoney(0), '0 VND');
  assert.equal(telegramTest.formatMoney(250000), '250K VND');
  assert.equal(telegramTest.formatMoney(2500000), '2.5 MLN VND');
});

test('Webhook secret comparison rejects unequal values', () => {
  assert.equal(telegramTest.constantTimeEqual('same-secret', 'same-secret'), true);
  assert.equal(telegramTest.constantTimeEqual('same-secret', 'other-secret'), false);
  assert.equal(telegramTest.constantTimeEqual('short', 'much-longer'), false);
});

test('Nha Trang day boundary is midnight UTC+7', () => {
  const noonUtc = Math.floor(Date.UTC(2026, 7, 30, 5, 0, 0) / 1000);
  const bounds = telegramTest.nhaTrangDayBounds(noonUtc);
  assert.equal(
    new Date(bounds.start * 1000).toISOString(),
    '2026-08-29T17:00:00.000Z',
  );
  assert.equal(bounds.end - bounds.start, 86400);
});
