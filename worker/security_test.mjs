import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import { securityGate } from './security.js';

function request(path, body, headers = {}) {
  return new Request(`https://evils.space${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'CF-Connecting-IP': '203.0.113.10',
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

function limiter(success) {
  const calls = [];
  return {
    calls,
    async limit(input) {
      calls.push(input);
      return { success };
    },
  };
}

test('admin login is rate limited without exposing email in the key', async () => {
  const auth = limiter(false);
  const response = await securityGate(
    request('/api/admin/login', {
      email: ' Admin@Example.com ',
      password: '1234',
    }),
    { AUTH_RATE_LIMITER: auth },
  );

  assert.equal(response?.status, 429);
  assert.equal(response?.headers.get('Retry-After'), '60');
  assert.equal(auth.calls.length, 1);
  assert.match(auth.calls[0].key, /^admin-login:[a-f0-9]{64}$/);
  assert.equal(auth.calls[0].key.includes('admin@example.com'), false);
});

test('successful auth rate limit check lets the request continue', async () => {
  const auth = limiter(true);
  const response = await securityGate(
    request('/api/admin/register', {
      email: 'new@example.com',
      password: '1234',
    }),
    { AUTH_RATE_LIMITER: auth },
  );

  assert.equal(response, null);
  assert.equal(auth.calls.length, 1);
  assert.match(auth.calls[0].key, /^admin-register:[a-f0-9]{64}$/);
});

test('Google customer sign-in is rate limited per client IP', async () => {
  const auth = limiter(false);
  const response = await securityGate(
    request('/api/public/account/google', { idToken: 'credential' }),
    { AUTH_RATE_LIMITER: auth },
  );

  assert.equal(response?.status, 429);
  assert.equal(auth.calls.length, 1);
  assert.match(auth.calls[0].key, /^public-google:[a-f0-9]{64}$/);
  assert.equal(auth.calls[0].key.includes('credential'), false);
});

test('public booking is rate limited by contact plus client identity', async () => {
  const bookings = limiter(false);
  const response = await securityGate(
    request('/api/public/book', {
      name: 'Alex',
      contactType: 'phone',
      contactValue: '+84 123 456 789',
      serviceDate: '2026-09-08',
    }),
    { PUBLIC_BOOKING_RATE_LIMITER: bookings },
  );

  assert.equal(response?.status, 429);
  assert.equal(bookings.calls.length, 1);
  assert.match(bookings.calls[0].key, /^public-book:[a-f0-9]{64}$/);
  assert.equal(bookings.calls[0].key.includes('+84'), false);
});

test('admin delete attempts are rate limited per session', async () => {
  const auth = limiter(false);
  const response = await securityGate(
    request(
      '/api/admin/delete',
      { email: 'staff@example.com', superPassword: 'test' },
      { Cookie: '__Host-evil_admin_session=secret-session-token' },
    ),
    { AUTH_RATE_LIMITER: auth },
  );

  assert.equal(response?.status, 429);
  assert.match(auth.calls[0].key, /^admin-delete:[a-f0-9]{64}$/);
  assert.equal(auth.calls[0].key.includes('secret-session-token'), false);
});

test('missing rate limiter binding keeps local development working', async () => {
  const response = await securityGate(
    request('/api/admin/login', {
      email: 'admin@example.com',
      password: '1234',
    }),
    {},
  );
  assert.equal(response, null);
});

test('wrangler points production at the security wrapper and binds both limiters', () => {
  const config = fs.readFileSync(new URL('../wrangler.toml', import.meta.url), 'utf8');
  assert.match(config, /main = "worker\/secure_entry\.js"/);
  assert.match(config, /name = "AUTH_RATE_LIMITER"/);
  assert.match(config, /name = "PUBLIC_BOOKING_RATE_LIMITER"/);
  assert.match(config, /limit = 8/);
  assert.match(config, /limit = 6/);
});
