import assert from 'node:assert/strict';
import test from 'node:test';
import assistantBooking, {
  assistantKeyAuthorized,
  assistantKeyConfigured,
} from './assistant_booking.js';

const key = 'test-assistant-booking-key-0123456789';
const env = { ASSISTANT_BOOKING_KEY: key };
const request = (body, authorization = `Bearer ${key}`) => new Request(
  'https://evils.space/api/assistant/booking',
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: authorization },
    body: JSON.stringify(body),
  },
);
const guest = {
  name: 'Guest', contactType: 'phone', contactValue: '+84912345678',
  serviceDate: '2026-09-25', language: 'en', userConfirmed: true,
};

test('booking credential is separate from public availability', async () => {
  assert.equal(assistantKeyConfigured({ ASSISTANT_BOOKING_KEY: 'short' }), false);
  assert.equal(assistantKeyConfigured(env), true);
  assert.equal(assistantKeyAuthorized(request(guest), env), true);
  assert.equal(assistantKeyAuthorized(request(guest, 'Bearer wrong'), env), false);
  assert.equal((await assistantBooking.fetch(request(guest), {}, {})).status, 503);
  assert.equal((await assistantBooking.fetch(request(guest, 'Bearer wrong'), env, {})).status, 401);
});

test('assistant booking rejects unconfirmed and invented contact details before touching D1', async () => {
  const noConsent = await assistantBooking.fetch(request({ ...guest, userConfirmed: false }), env, {});
  assert.equal(noConsent.status, 400);
  assert.match((await noConsent.json()).error, /confirm/);
  const invalidPhone = await assistantBooking.fetch(request({ ...guest, contactValue: 'fake' }), env, {});
  assert.equal(invalidPhone.status, 400);
  const invalidTelegram = await assistantBooking.fetch(request({ ...guest, contactType: 'telegram', contactValue: '@x' }), env, {});
  assert.equal(invalidTelegram.status, 400);
});
