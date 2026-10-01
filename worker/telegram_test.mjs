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
  assert.equal(telegramTest.formatMoney(200000), '200K VND');
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

test('Telegram languages preserve EN RU VI and fall back to English', () => {
  assert.equal(telegramTest.normalizeLanguage('en'), 'en');
  assert.equal(telegramTest.normalizeLanguage('RU'), 'ru');
  assert.equal(telegramTest.normalizeLanguage('vi'), 'vi');
  assert.equal(telegramTest.normalizeLanguage('de'), 'en');
  assert.equal(telegramTest.normalizeLanguage(null), 'en');
});

test('one-tap Telegram booking uses the verified Telegram identity', () => {
  assert.deepEqual(
    telegramTest.telegramBookingIdentity({ username: 'alex' }),
    { name: '@alex', contact: '@alex' },
  );
  assert.deepEqual(
    telegramTest.telegramBookingIdentity({ first_name: 'Alex', last_name: 'P' }),
    { name: 'Alex P', contact: 'Alex P' },
  );
});


test('automatically accepted Telegram bookings offer cancellation', () => {
  for (const language of ['en', 'ru', 'vi']) {
    const keyboard = telegramTest.bookingAdminKeyboard(42, language, 'accepted');
    assert.equal(keyboard.inline_keyboard[0][0].callback_data, 'bc:42');
    assert.equal(keyboard.inline_keyboard.flat().some(b => b.callback_data === 'ba:42'), false);
    const text = telegramTest.bookingAdminText({name: 'Guest', contact_type: 'phone',
      contact_value: '0123456', amount_vnd: 200000, service_day: 1788109200,
      created_at: 1788109200}, 'accepted', 'automatic', language);
    assert.match(text, /automatic/);
  }
});

test('cancelled Telegram bookings have no further booking actions', () => {
  const keyboard = telegramTest.bookingAdminKeyboard(42, 'en', 'cancelled');
  assert.equal(keyboard.inline_keyboard.flat().some(b => b.callback_data), false);
});
